import pool from '../config/db.js';
import { logger } from '../utils/logger.js';
import { sendNotification } from './notificationService.js';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface ParametresSalaire {
  pctProprietaire: number; // % du revenu encaissé
  pctEmploye: number;
  seuilVehicules: number; // nb min de véhicules actifs
  actif: boolean;
}

export interface ResultatCalculSalaire {
  profil: 'proprietaire' | 'employe';
  mois: string; // 'YYYY-MM'
  revenuEncaisse: number;
  vehiculesActifs: number;
  pctApplique: number;
  montant: number;
  seuilAtteint: boolean;
  note?: string;
}

export interface SimulationMois {
  mois: string;
  vehiculesActifs: number;
  vehiculesRembourses: number;
  revenuEncaisse: number;
  salaireProprietaire: number;
  salaireEmploye: number;
  cashApresSalaires: number;
  seuilAtteint: boolean;
}

export interface SimulationResultat {
  scenarios: SimulationMois[];
  totalSalairesProprietaire: number;
  totalSalairesEmploye: number;
  totalVerse: number;
  moisDefaillance: string | null; // premier mois où salaire = 0
}

// ─── Chargement des paramètres ───────────────────────────────────────────────

export async function chargerParametresSalaire(): Promise<ParametresSalaire> {
  const { rows } = await pool.query(
    `SELECT cle, valeur FROM parametres WHERE cle IN (
      'salaire_pct_proprietaire', 'salaire_pct_employe',
      'salaire_seuil_vehicules', 'salaire_actif'
    )`,
  );

  const params: Record<string, string> = {};
  for (const r of rows) params[r.cle] = r.valeur;

  return {
    pctProprietaire: parseFloat(params['salaire_pct_proprietaire'] ?? '8'),
    pctEmploye: parseFloat(params['salaire_pct_employe'] ?? '4'),
    seuilVehicules: parseInt(params['salaire_seuil_vehicules'] ?? '5', 10),
    actif: (params['salaire_actif'] ?? 'true') === 'true',
  };
}

export async function updateParametreSalaire(cle: string, valeur: string): Promise<void> {
  const cleFull = `salaire_${cle}`;
  await pool.query(
    `UPDATE parametres SET valeur = $1, date_modification = NOW() WHERE cle = $2`,
    [valeur, cleFull],
  );
}

// ─── Calcul du salaire pour un mois ──────────────────────────────────────────

/**
 * Calcule les salaires pour un mois donné.
 *
 * Règles :
 * 1. Compter les véhicules actifs (en cours de remboursement)
 * 2. Si < seuil → salaire = 0 (100% réinvesti)
 * 3. Sinon → calculer le revenu réellement encaissé sur le mois
 * 4. Appliquer les pourcentages
 * 5. Déduire de la trésorerie avant tout nouvel achat
 */
export async function calculerSalairesMois(mois: string): Promise<{
  proprietaire: ResultatCalculSalaire;
  employe: ResultatCalculSalaire;
}> {
  const params = await chargerParametresSalaire();

  if (!params.actif) {
    logger.info('[Salaires] Module désactivé');
    return {
      proprietaire: zeroResult('proprietaire', mois),
      employe: zeroResult('employe', mois),
    };
  }

  // 1. Compter les véhicules actifs (en cours de remboursement à la fin du mois)
  const finMois = `${mois}-28`; // approximation fin de mois
  const { rows: vehiculesActifsRows } = await pool.query(`
    SELECT COUNT(*)::int AS nb
    FROM vehicules
    WHERE statut = 'en_remboursement'
      AND (date_fin_remboursement IS NULL OR date_fin_remboursement > $1)
  `, [finMois]);
  const vehiculesActifs = vehiculesActifsRows[0]?.nb ?? 0;

  // 2. Vérifier le seuil
  const seuilAtteint = vehiculesActifs >= params.seuilVehicules;

  // 3. Calculer le revenu réellement encaissé sur le mois
  const { rows: revenuRows } = await pool.query(`
    SELECT COALESCE(SUM(montant), 0)::float AS total
    FROM paiements
    WHERE TO_CHAR(date, 'YYYY-MM') = $1
      AND statut = 'confirme'
  `, [mois]);
  const revenuEncaisse = revenuRows[0]?.total ?? 0;

  // 4. Calculer les montants
  const montantProprietaire = seuilAtteint
    ? Math.round(revenuEncaisse * params.pctProprietaire / 100)
    : 0;
  const montantEmploye = seuilAtteint
    ? Math.round(revenuEncaisse * params.pctEmploye / 100)
    : 0;

  const noteProprietaire = seuilAtteint
    ? undefined
    : `Seuil non atteint : ${vehiculesActifs}/${params.seuilVehicules} véhicules actifs — 100% réinvesti`;
  const noteEmploye = seuilAtteint
    ? undefined
    : `Seuil non atteint : ${vehiculesActifs}/${params.seuilVehicules} véhicules actifs — 100% réinvesti`;

  logger.info(`[Salaires] Mois ${mois} : ${vehiculesActifs} véhicules actifs, revenu ${revenuEncaisse} FCFA` +
    (seuilAtteint
      ? ` → Prop: ${montantProprietaire} F (${params.pctProprietaire}%), Emp: ${montantEmploye} F (${params.pctEmploye}%)`
      : ` → Seuil ${params.seuilVehicules} non atteint, salaires à 0`));

  return {
    proprietaire: {
      profil: 'proprietaire',
      mois,
      revenuEncaisse,
      vehiculesActifs,
      pctApplique: seuilAtteint ? params.pctProprietaire : 0,
      montant: montantProprietaire,
      seuilAtteint,
      note: noteProprietaire,
    },
    employe: {
      profil: 'employe',
      mois,
      revenuEncaisse,
      vehiculesActifs,
      pctApplique: seuilAtteint ? params.pctEmploye : 0,
      montant: montantEmploye,
      seuilAtteint,
      note: noteEmploye,
    },
  };
}

// ─── Enregistrement en base ──────────────────────────────────────────────────

export async function enregistrerSalaires(
  calcul: { proprietaire: ResultatCalculSalaire; employe: ResultatCalculSalaire },
): Promise<{ proprietaire: any; employe: any }> {
  const results: any = {};

  for (const profil of ['proprietaire', 'employe'] as const) {
    const s = calcul[profil];
    const { rows } = await pool.query(`
      INSERT INTO salaires (profil, mois, montant, date_versement, revenu_encaisse, vehicules_actifs, pct_applique, statut, note)
      VALUES ($1, $2, $3, NULL, $4, $5, $6, 'calcule', $7)
      ON CONFLICT (profil, mois) DO UPDATE SET
        montant = EXCLUDED.montant,
        revenu_encaisse = EXCLUDED.revenu_encaisse,
        vehicules_actifs = EXCLUDED.vehicules_actifs,
        pct_applique = EXCLUDED.pct_applique,
        note = EXCLUDED.note
      RETURNING *`,
      [s.profil, s.mois, s.montant, s.revenuEncaisse, s.vehiculesActifs, s.pctApplique, s.note ?? null],
    );
    results[profil] = rows[0];
  }

  return results;
}

// ─── Validation et versement ─────────────────────────────────────────────────

export async function validerSalaire(salaireId: string, userId: string): Promise<any> {
  const { rows } = await pool.query(`
    UPDATE salaires SET statut = 'verse', verse_par = $2, date_versement = CURRENT_DATE
    WHERE id = $1 AND statut IN ('calcule', 'valide')
    RETURNING *`,
    [salaireId, userId],
  );
  return rows[0];
}

export async function annulerSalaire(salaireId: string): Promise<any> {
  const { rows } = await pool.query(`
    UPDATE salaires SET statut = 'annule'
    WHERE id = $1 AND statut != 'verse'
    RETURNING *`,
    [salaireId],
  );
  return rows[0];
}

// ─── Simulateur d'impact ─────────────────────────────────────────────────────

/**
 * Simule l'impact d'un changement de paramètres sur les 12 prochains mois.
 * Utilise les données réelles actuelles et projette avec les nouveaux paramètres.
 */
export async function simulerImpact(params: {
  pctProprietaire?: number;
  pctEmploye?: number;
  seuilVehicules?: number;
  nbMois?: number;
}): Promise<SimulationResultat> {
  const currentParams = await chargerParametresSalaire();
  const pctProp = params.pctProprietaire ?? currentParams.pctProprietaire;
  const pctEmp = params.pctEmploye ?? currentParams.pctEmploye;
  const seuil = params.seuilVehicules ?? currentParams.seuilVehicules;
  const nbMois = params.nbMois ?? 12;

  const scenarios: SimulationMois[] = [];
  let totalProp = 0;
  let totalEmp = 0;
  let moisDefaillance: string | null = null;

  // Obtenir les données réelles actuelles
  const { rows: vehiculesData } = await pool.query(`
    SELECT
      COUNT(*) FILTER (WHERE statut = 'en_remboursement')::int AS actifs,
      COUNT(*) FILTER (WHERE statut = 'rembourse')::int AS rembourses,
      COUNT(*)::int AS total
    FROM vehicules
  `);
  const vehiculesActifsInit = vehiculesData[0]?.actifs ?? 0;

  // Obtenir le revenu mensuel moyen des 3 derniers mois
  const { rows: revenuData } = await pool.query(`
    SELECT COALESCE(AVG(mensuel), 0)::float AS moyenne
    FROM (
      SELECT TO_CHAR(date, 'YYYY-MM') AS m, SUM(montant) AS mensuel
      FROM paiements
      WHERE statut = 'confirme'
        AND date >= CURRENT_DATE - INTERVAL '3 months'
      GROUP BY TO_CHAR(date, 'YYYY-MM')
    ) sub
  `);
  const revenuMoyen = revenuData[0]?.moyenne ?? 0;

  // Projeter mois par mois
  let vehiculesActifs = vehiculesActifsInit;

  for (let i = 1; i <= nbMois; i++) {
    const now = new Date();
    const futureDate = new Date(now.getFullYear(), now.getMonth() + i, 1);
    const mois = `${futureDate.getFullYear()}-${String(futureDate.getMonth() + 1).padStart(2, '0')}`;

    // Estimation : les véhicules qui atteignent leur fin de remboursement sortent
    const { rows: finsMois } = await pool.query(`
      SELECT COUNT(*)::int AS nb FROM vehicules
      WHERE statut = 'en_remboursement'
        AND date_fin_remboursement IS NOT NULL
        AND TO_CHAR(date_fin_remboursement, 'YYYY-MM') = $1
    `, [mois]);
    vehiculesActifs = Math.max(0, vehiculesActifs - (finsMois[0]?.nb ?? 0));

    // Estimation revenu : proportionnel au nombre de véhicules actifs
    const ratio = vehiculesActifsInit > 0 ? vehiculesActifs / vehiculesActifsInit : 0;
    const revenuEstime = Math.round(revenuMoyen * ratio);

    const seuilAtteint = vehiculesActifs >= seuil;
    const salaireProp = seuilAtteint ? Math.round(revenuEstime * pctProp / 100) : 0;
    const salaireEmp = seuilAtteint ? Math.round(revenuEstime * pctEmp / 100) : 0;
    const cashApres = revenuEstime - salaireProp - salaireEmp;

    if ((salaireProp === 0 && salaireEmp === 0) && !moisDefaillance) {
      moisDefaillance = mois;
    }

    scenarios.push({
      mois,
      vehiculesActifs,
      vehiculesRembourses: vehiculesData[0]?.rembourses ?? 0,
      revenuEncaisse: revenuEstime,
      salaireProprietaire: salaireProp,
      salaireEmploye: salaireEmp,
      cashApresSalaires: cashApres,
      seuilAtteint,
    });

    totalProp += salaireProp;
    totalEmp += salaireEmp;
  }

  return {
    scenarios,
    totalSalairesProprietaire: totalProp,
    totalSalairesEmploye: totalEmp,
    totalVerse: totalProp + totalEmp,
    moisDefaillance,
  };
}

// ─── Détection anomalie salaire ──────────────────────────────────────────────

/**
 * Vérifie si le salaire d'un mois est anormalement bas et crée une anomalie.
 */
export async function verifierAnomalieSalaire(mois: string): Promise<void> {
  // Charger les salaires du mois
  const { rows } = await pool.query(
    `SELECT * FROM salaires WHERE mois = $1 AND statut != 'annule'`,
    [mois],
  );

  if (rows.length === 0) return;

  // Charger la moyenne des 6 derniers mois
  const { rows: moyenneRows } = await pool.query(`
    SELECT COALESCE(AVG(montant), 0)::float AS moyenne
    FROM salaires
    WHERE mois < $1 AND statut != 'annule'
  `, [mois]);
  const moyenne = moyenneRows[0]?.moyenne ?? 0;

  for (const salaire of rows) {
    const montant = parseFloat(salaire.montant);

    // Alerte si salaire = 0 OU < 30% de la moyenne
    const estAnormal = montant === 0 || (moyenne > 0 && montant < moyenne * 0.3);

    if (estAnormal) {
      const motif = montant === 0
        ? `Salaire ${salaire.profil} à 0 F en ${mois}. Cause probable : seuil de véhicules actifs non atteint ou aucun revenu encaissé.`
        : `Salaire ${salaire.profil} anormalement bas (${montant.toLocaleString('fr-FR')} F) en ${mois}, soit ${Math.round(montant / moyenne * 100)}% de la moyenne (${moyenne.toLocaleString('fr-FR')} F).`;

      // Vérifier si une anomalie similaire existe déjà pour ce mois
      const { rows: existing } = await pool.query(`
        SELECT id FROM anomalies_detectees
        WHERE type_anomalie = 'salaire_anormalement_bas'
          AND TO_CHAR(date_detection, 'YYYY-MM') = $1
          AND metadata->>'profil' = $2
      `, [mois, salaire.profil]);

      if (existing.length === 0) {
        await pool.query(`
          INSERT INTO anomalies_detectees (type_anomalie, severite, description, metadata, statut)
          VALUES ('salaire_anormalement_bas', $1, $2, $3, 'nouveau')`,
          [
            montant === 0 ? 'critique' : 'haute',
            motif,
            JSON.stringify({
              profil: salaire.profil,
              mois,
              montant,
              moyenne: Math.round(moyenne),
              vehicules_actifs: salaire.vehicules_actifs,
            }),
          ],
        );

        // Notification in-app admin
        await sendNotification({
          type: 'alerte_admin_j5',
          channel: 'in_app',
          titre: `⚠️ Salaire ${salaire.profil} anormal — ${mois}`,
          message: motif,
          metadata: { profil: salaire.profil, mois, montant },
        });

        logger.warn(`[Salaires] Anomalie détectée : ${motif}`);
      }
    }
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function zeroResult(profil: 'proprietaire' | 'employe', mois: string): ResultatCalculSalaire {
  return {
    profil,
    mois,
    revenuEncaisse: 0,
    vehiculesActifs: 0,
    pctApplique: 0,
    montant: 0,
    seuilAtteint: false,
    note: 'Module salaires désactivé',
  };
}
