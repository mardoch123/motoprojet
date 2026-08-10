import pool from '../config/db.js';
import { writeAuditLog } from './audit.js';

// ─── PATRIMOINE ──────────────────────────────────────────────────────────────

export interface PatrimoineData {
  cashEnCaisse: number;
  valeurVehiculesActifs: number;
  patrimoineTotal: number;
  nbVehiculesActifs: number;
  nbVehiculesRembourses: number;
  detail: any[];
}

/**
 * Calcule le patrimoine en temps réel
 */
export async function calculerPatrimoine(): Promise<PatrimoineData> {
  // Cash en caisse = total encaissé - salaires versés - dépenses - achats
  const { rows: cashRows } = await pool.query(`
    SELECT 
      COALESCE(SUM(montant), 0)::float AS total_encaisse
    FROM paiements WHERE statut = 'confirme'
  `);
  const totalEncaisse = cashRows[0]?.total_encaisse ?? 0;

  const { rows: salaireRows } = await pool.query(`
    SELECT COALESCE(SUM(montant), 0)::float AS total
    FROM salaires WHERE statut = 'verse'
  `);
  const totalSalaires = salaireRows[0]?.total ?? 0;

  const { rows: depenseRows } = await pool.query(`
    SELECT COALESCE(SUM(cout_reparation), 0)::float AS total
    FROM incidents WHERE cout_reparation > 0
  `);
  const totalDepenses = depenseRows[0]?.total ?? 0;

  const { rows: achatsRows } = await pool.query(`
    SELECT COALESCE(SUM(prix_achat), 0)::float AS total
    FROM vehicules
  `);
  const totalAchats = achatsRows[0]?.total ?? 0;

  const cashEnCaisse = totalEncaisse - totalSalaires - totalDepenses - totalAchats;

  // Valeur des véhicules actifs = somme des restes dus
  const { rows: vehiculesActifs } = await pool.query(`
    SELECT 
      id, type, plaque, marque, prix_achat,
      COALESCE(solde_restant, prix_achat)::float AS valeur_residuelle,
      date_achat, statut
    FROM vehicules
    WHERE statut IN ('en_remboursement', 'actif')
    ORDER BY date_achat DESC
  `);

  let valeurVehiculesActifs = 0;
  const detail: any[] = [];

  for (const v of vehiculesActifs) {
    const valeur = parseFloat(v.valeur_residuelle) || 0;
    valeurVehiculesActifs += valeur;
    detail.push({
      id: v.id,
      type: v.type,
      plaque: v.plaque,
      marque: v.marque,
      prixAchat: parseFloat(v.prix_achat) || 0,
      valeurResiduelle: valeur,
      dateAchat: v.date_achat,
    });
  }

  // Nombre de véhicules remboursés
  const { rows: rembRows } = await pool.query(`
    SELECT COUNT(*)::int AS nb FROM vehicules WHERE statut = 'rembourse'
  `);
  const nbVehiculesRembourses = rembRows[0]?.nb ?? 0;

  return {
    cashEnCaisse: Math.round(cashEnCaisse),
    valeurVehiculesActifs: Math.round(valeurVehiculesActifs),
    patrimoineTotal: Math.round(cashEnCaisse + valeurVehiculesActifs),
    nbVehiculesActifs: vehiculesActifs.length,
    nbVehiculesRembourses,
    detail,
  };
}

/**
 * Enregistre un snapshot du patrimoine (à appeler périodiquement)
 */
export async function enregistrerSnapshotPatrimoine(): Promise<void> {
  const patrimoine = await calculerPatrimoine();
  const today = new Date().toISOString().split('T')[0];

  await pool.query(`
    INSERT INTO patrimoine_snapshots (date_snapshot, cash_en_caisse, valeur_vehicules_actifs, nb_vehicules_actifs, nb_vehicules_rembourses, detail)
    VALUES ($1, $2, $3, $4, $5, $6)
    ON CONFLICT (date_snapshot) DO UPDATE SET
      cash_en_caisse = EXCLUDED.cash_en_caisse,
      valeur_vehicules_actifs = EXCLUDED.valeur_vehicules_actifs,
      nb_vehicules_actifs = EXCLUDED.nb_vehicules_actifs,
      nb_vehicules_rembourses = EXCLUDED.nb_vehicules_rembourses,
      detail = EXCLUDED.detail
  `, [today, patrimoine.cashEnCaisse, patrimoine.valeurVehiculesActifs, patrimoine.nbVehiculesActifs, patrimoine.nbVehiculesRembourses, JSON.stringify(patrimoine.detail)]);
}

// ─── DÉPÔTS BANQUE ───────────────────────────────────────────────────────────

export interface DepotBanque {
  id: string;
  dateDepot: string;
  montantTheorique: number;
  montantReel: number;
  ecart: number;
  banque?: string;
  reference?: string;
  note?: string;
  rapproche: boolean;
  rapprochePar?: string;
  rapprocheLe?: string;
}

/**
 * Liste les dépôts en banque
 */
export async function listerDepots(options: {
  dateDebut?: string;
  dateFin?: string;
  rapproche?: boolean;
}): Promise<DepotBanque[]> {
  let query = `SELECT * FROM depots_banque WHERE 1=1`;
  const params: any[] = [];
  let paramIndex = 1;

  if (options.dateDebut) {
    query += ` AND date_depot >= $${paramIndex++}`;
    params.push(options.dateDebut);
  }
  if (options.dateFin) {
    query += ` AND date_depot <= $${paramIndex++}`;
    params.push(options.dateFin);
  }
  if (options.rapproche !== undefined) {
    query += ` AND rapproche = $${paramIndex++}`;
    params.push(options.rapproche);
  }

  query += ` ORDER BY date_depot DESC LIMIT 100`;

  const { rows } = await pool.query(query, params);
  return rows.map((r: any) => ({
    id: r.id,
    dateDepot: r.date_depot,
    montantTheorique: parseFloat(r.montant_theorique),
    montantReel: parseFloat(r.montant_reel),
    ecart: parseFloat(r.ecart),
    banque: r.banque,
    reference: r.reference,
    note: r.note,
    rapproche: r.rapproche,
    rapprochePar: r.rapproche_par,
    rapprocheLe: r.rapproche_le,
  }));
}

/**
 * Enregistre un dépôt en banque
 */
export async function enregistrerDepot(data: {
  dateDepot: string;
  montantTheorique: number;
  montantReel: number;
  banque?: string;
  reference?: string;
  note?: string;
  userId: string;
}): Promise<DepotBanque> {
  const { rows } = await pool.query(`
    INSERT INTO depots_banque (date_depot, montant_theorique, montant_reel, banque, reference, note, cree_par)
    VALUES ($1, $2, $3, $4, $5, $6, $7)
    RETURNING *
  `, [data.dateDepot, data.montantTheorique, data.montantReel, data.banque, data.reference, data.note, data.userId]);

  const r = rows[0];
  return {
    id: r.id,
    dateDepot: r.date_depot,
    montantTheorique: parseFloat(r.montant_theorique),
    montantReel: parseFloat(r.montant_reel),
    ecart: parseFloat(r.ecart),
    banque: r.banque,
    reference: r.reference,
    note: r.note,
    rapproche: r.rapproche,
  };
}

/**
 * Rapproche un dépôt (confirme que le montant réel correspond)
 */
export async function rapprocherDepot(depotId: string, userId: string): Promise<void> {
  await pool.query(`
    UPDATE depots_banque 
    SET rapproche = true, rapproche_par = $1, rapproche_le = NOW()
    WHERE id = $2
  `, [userId, depotId]);

  await writeAuditLog(userId, 'rapprochement_depot', depotId, { depotId });
}

// ─── EXPORT COMPTABLE ────────────────────────────────────────────────────────

export interface ExportComptableData {
  periode: { debut: string; fin: string };
  resume: {
    totalEncaisse: number;
    totalSalaires: number;
    totalDepenses: number;
    totalAchats: number;
    cashNet: number;
    nbPaiements: number;
    patrimoineFinal: number;
  };
  paiements: any[];
  salaires: any[];
  incidents: any[];
  depots: any[];
  patrimoine: PatrimoineData;
}

/**
 * Génère les données pour l'export comptable sur une période
 */
export async function genererExportComptable(dateDebut: string, dateFin: string): Promise<ExportComptableData> {
  // Paiements de la période
  const { rows: paiements } = await pool.query(`
    SELECT p.id, p.date, p.montant, p.mode, p.statut,
           c.nom AS chauffeur_nom, v.plaque, v.type AS vehicule_type
    FROM paiements p
    LEFT JOIN chauffeurs c ON p.chauffeur_id = c.id
    LEFT JOIN vehicules v ON p.vehicule_id = v.id
    WHERE p.statut = 'confirme'
      AND p.date >= $1 AND p.date <= $2
    ORDER BY p.date DESC
  `, [dateDebut, dateFin]);

  // Salaires de la période
  const { rows: salaires } = await pool.query(`
    SELECT s.id, s.mois, s.profil, s.montant, s.statut, s.date_versement,
           u.telephone AS verse_par_telephone
    FROM salaires s
    LEFT JOIN users u ON s.verse_par = u.id
    WHERE s.mois >= $1 AND s.mois <= $2
    ORDER BY s.mois DESC
  `, [dateDebut.substring(0, 7), dateFin.substring(0, 7)]);

  // Incidents de la période
  const { rows: incidents } = await pool.query(`
    SELECT i.id, i.date_incident, i.type_incident, i.cout_reparation, i.statut,
           v.plaque, c.nom AS chauffeur_nom
    FROM incidents i
    LEFT JOIN vehicules v ON i.vehicule_id = v.id
    LEFT JOIN chauffeurs c ON i.chauffeur_id = c.id
    WHERE i.date_incident >= $1 AND i.date_incident <= $2
    ORDER BY i.date_incident DESC
  `, [dateDebut, dateFin]);

  // Dépôts de la période
  const { rows: depots } = await pool.query(`
    SELECT * FROM depots_banque
    WHERE date_depot >= $1 AND date_depot <= $2
    ORDER BY date_depot DESC
  `, [dateDebut, dateFin]);

  // Totaux
  const totalEncaisse = paiements.reduce((sum, p) => sum + parseFloat(p.montant || 0), 0);
  const totalSalaires = salaires.filter(s => s.statut === 'verse').reduce((sum, s) => sum + parseFloat(s.montant || 0), 0);
  const totalDepenses = incidents.reduce((sum, i) => sum + parseFloat(i.cout_reparation || 0), 0);

  // Achats de véhicules dans la période
  const { rows: achats } = await pool.query(`
    SELECT COALESCE(SUM(prix_achat), 0)::float AS total
    FROM vehicules
    WHERE date_achat >= $1 AND date_achat <= $2
  `, [dateDebut, dateFin]);
  const totalAchats = achats[0]?.total ?? 0;

  // Patrimoine actuel
  const patrimoine = await calculerPatrimoine();

  return {
    periode: { debut: dateDebut, fin: dateFin },
    resume: {
      totalEncaisse: Math.round(totalEncaisse),
      totalSalaires: Math.round(totalSalaires),
      totalDepenses: Math.round(totalDepenses),
      totalAchats: Math.round(totalAchats),
      cashNet: Math.round(totalEncaisse - totalSalaires - totalDepenses - totalAchats),
      nbPaiements: paiements.length,
      patrimoineFinal: patrimoine.patrimoineTotal,
    },
    paiements: paiements.map(p => ({
      id: p.id,
      date: p.date,
      montant: parseFloat(p.montant),
      mode: p.mode,
      chauffeur: p.chauffeur_nom,
      vehicule: p.plaque,
      type: p.vehicule_type,
    })),
    salaires: salaires.map(s => ({
      id: s.id,
      mois: s.mois,
      profil: s.profil,
      montant: parseFloat(s.montant),
      statut: s.statut,
      dateVersement: s.date_versement,
      versePar: s.verse_par_telephone,
    })),
    incidents: incidents.map(i => ({
      id: i.id,
      date: i.date_incident,
      type: i.type_incident,
      cout: parseFloat(i.cout_reparation),
      statut: i.statut,
      vehicule: i.plaque,
      chauffeur: i.chauffeur_nom,
    })),
    depots: depots.map(d => ({
      id: d.id,
      date: d.date_depot,
      theorique: parseFloat(d.montant_theorique),
      reel: parseFloat(d.montant_reel),
      ecart: parseFloat(d.ecart),
      banque: d.banque,
      rapproche: d.rapproche,
    })),
    patrimoine,
  };
}

// ─── RAPPORT MENSUEL ─────────────────────────────────────────────────────────

export async function genererRapportMensuel(mois: string): Promise<any> {
  // Vérifier si le rapport existe déjà
  const { rows: existing } = await pool.query(`
    SELECT id FROM rapports_mensuels WHERE mois = $1 AND type_rapport = 'financier'
  `, [mois]);

  if (existing.length > 0) {
    // Récupérer le rapport existant
    const { rows } = await pool.query(`
      SELECT * FROM rapports_mensuels WHERE mois = $1 AND type_rapport = 'financier'
    `, [mois]);
    return rows[0];
  }

  // Générer le rapport
  const [annee, moisNum] = mois.split('-');
  const dateDebut = `${mois}-01`;
  const dernierJour = new Date(parseInt(annee), parseInt(moisNum), 0).getDate();
  const dateFin = `${mois}-${dernierJour.toString().padStart(2, '0')}`;

  const data = await genererExportComptable(dateDebut, dateFin);

  const contenu = {
    mois,
    resume: data.resume,
    nbPaiements: data.paiements.length,
    nbIncidents: data.incidents.length,
    patrimoine: data.patrimoine,
    genereLe: new Date().toISOString(),
  };

  const { rows } = await pool.query(`
    INSERT INTO rapports_mensuels (mois, type_rapport, titre, contenu)
    VALUES ($1, 'financier', $2, $3)
    RETURNING *
  `, [mois, `Rapport financier ${mois}`, JSON.stringify(contenu)]);

  return rows[0];
}

// ─── APPORTS PERSONNELS ─────────────────────────────────────────────────────

export interface ApportPersonnel {
  id: string;
  libelle: string;
  montant: number;
  frequence: 'hebdomadaire' | 'mensuel' | 'trimestriel';
  jourPrealable?: number;
  actif: boolean;
  dateDebut: string;
  dateFin?: string;
  objectif: 'moto' | 'voiture';
  note?: string;
}

export interface ApportVersement {
  id: string;
  apportId: string;
  dateVersement: string;
  montant: number;
  note?: string;
  valide: boolean;
}

/**
 * Liste les apports personnels configurés
 */
export async function listerApports(actifsOnly = false): Promise<ApportPersonnel[]> {
  let query = `SELECT * FROM apports_personnels`;
  if (actifsOnly) query += ` WHERE actif = true`;
  query += ` ORDER BY cree_le DESC`;

  const { rows } = await pool.query(query);
  return rows.map((r: any) => ({
    id: r.id,
    libelle: r.libelle,
    montant: parseFloat(r.montant),
    frequence: r.frequence,
    jourPrealable: r.jour_prealable,
    actif: r.actif,
    dateDebut: r.date_debut,
    dateFin: r.date_fin,
    objectif: r.objectif,
    note: r.note,
  }));
}

/**
 * Crée un nouvel apport personnel
 */
export async function creerApport(data: {
  libelle: string;
  montant: number;
  frequence: 'hebdomadaire' | 'mensuel' | 'trimestriel';
  jourPrealable?: number;
  dateDebut: string;
  dateFin?: string;
  objectif: 'moto' | 'voiture';
  note?: string;
  userId: string;
}): Promise<ApportPersonnel> {
  const { rows } = await pool.query(`
    INSERT INTO apports_personnels (libelle, montant, frequence, jour_prealable, date_debut, date_fin, objectif, note, cree_par)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING *
  `, [data.libelle, data.montant, data.frequence, data.jourPrealable, data.dateDebut, data.dateFin, data.objectif, data.note, data.userId]);

  const r = rows[0];
  return {
    id: r.id,
    libelle: r.libelle,
    montant: parseFloat(r.montant),
    frequence: r.frequence,
    jourPrealable: r.jour_prealable,
    actif: r.actif,
    dateDebut: r.date_debut,
    dateFin: r.date_fin,
    objectif: r.objectif,
    note: r.note,
  };
}

/**
 * Met à jour un apport personnel
 */
export async function updateApport(id: string, data: Partial<{
  libelle: string;
  montant: number;
  frequence: 'hebdomadaire' | 'mensuel' | 'trimestriel';
  jourPrealable?: number;
  actif: boolean;
  dateDebut: string;
  dateFin?: string;
  objectif: 'moto' | 'voiture';
  note?: string;
}>): Promise<ApportPersonnel | null> {
  const fields: string[] = [];
  const values: any[] = [];
  let idx = 1;

  if (data.libelle !== undefined) { fields.push(`libelle = $${idx++}`); values.push(data.libelle); }
  if (data.montant !== undefined) { fields.push(`montant = $${idx++}`); values.push(data.montant); }
  if (data.frequence !== undefined) { fields.push(`frequence = $${idx++}`); values.push(data.frequence); }
  if (data.jourPrealable !== undefined) { fields.push(`jour_prealable = $${idx++}`); values.push(data.jourPrealable); }
  if (data.actif !== undefined) { fields.push(`actif = $${idx++}`); values.push(data.actif); }
  if (data.dateDebut !== undefined) { fields.push(`date_debut = $${idx++}`); values.push(data.dateDebut); }
  if (data.dateFin !== undefined) { fields.push(`date_fin = $${idx++}`); values.push(data.dateFin); }
  if (data.objectif !== undefined) { fields.push(`objectif = $${idx++}`); values.push(data.objectif); }
  if (data.note !== undefined) { fields.push(`note = $${idx++}`); values.push(data.note); }

  if (fields.length === 0) return null;

  fields.push(`modifie_le = NOW()`);
  values.push(id);

  const { rows } = await pool.query(`
    UPDATE apports_personnels SET ${fields.join(', ')} WHERE id = $${idx}
    RETURNING *
  `, values);

  if (rows.length === 0) return null;

  const r = rows[0];
  return {
    id: r.id,
    libelle: r.libelle,
    montant: parseFloat(r.montant),
    frequence: r.frequence,
    jourPrealable: r.jour_prealable,
    actif: r.actif,
    dateDebut: r.date_debut,
    dateFin: r.date_fin,
    objectif: r.objectif,
    note: r.note,
  };
}

/**
 * Supprime un apport personnel
 */
export async function supprimerApport(id: string): Promise<boolean> {
  const { rowCount } = await pool.query(`DELETE FROM apports_personnels WHERE id = $1`, [id]);
  return (rowCount ?? 0) > 0;
}

/**
 * Calcule le montant total des apports prévus sur une période (en jours)
 */
export async function calculerApportsPrevus(nbJours: number, objectif?: 'moto' | 'voiture'): Promise<number> {
  const apports = await listerApports(true);
  const now = new Date();
  let total = 0;

  for (const apport of apports) {
    // Filtrer par objectif si spécifié
    if (objectif && apport.objectif !== objectif) continue;

    // Vérifier que l'apport est dans la période
    const dateDebut = new Date(apport.dateDebut);
    const dateFin = apport.dateFin ? new Date(apport.dateFin) : null;

    // Calculer le nombre d'occurrences sur la période
    let occurrences = 0;
    const periodeFin = new Date(now.getTime() + nbJours * 86400000);

    switch (apport.frequence) {
      case 'hebdomadaire':
        occurrences = Math.floor(nbJours / 7);
        break;
      case 'mensuel':
        occurrences = Math.floor(nbJours / 30);
        break;
      case 'trimestriel':
        occurrences = Math.floor(nbJours / 90);
        break;
    }

    // Vérifier les dates
    if (dateDebut > now) {
      const joursAvantDebut = Math.ceil((dateDebut.getTime() - now.getTime()) / 86400000);
      if (joursAvantDebut >= nbJours) continue;
      occurrences = Math.floor((nbJours - joursAvantDebut) / (apport.frequence === 'hebdomadaire' ? 7 : apport.frequence === 'mensuel' ? 30 : 90));
    }

    if (dateFin && dateFin < periodeFin) {
      const joursJusquAFin = Math.ceil((dateFin.getTime() - now.getTime()) / 86400000);
      if (joursJusquAFin <= 0) continue;
      occurrences = Math.min(occurrences, Math.floor(joursJusquAFin / (apport.frequence === 'hebdomadaire' ? 7 : apport.frequence === 'mensuel' ? 30 : 90)));
    }

    total += occurrences * apport.montant;
  }

  return total;
}

/**
 * Enregistre un versement réel d'apport
 */
export async function enregistrerVersement(data: {
  apportId: string;
  dateVersement: string;
  montant: number;
  note?: string;
}): Promise<ApportVersement> {
  const { rows } = await pool.query(`
    INSERT INTO apports_versements (apport_id, date_versement, montant, note)
    VALUES ($1, $2, $3, $4)
    RETURNING *
  `, [data.apportId, data.dateVersement, data.montant, data.note]);

  const r = rows[0];
  return {
    id: r.id,
    apportId: r.apport_id,
    dateVersement: r.date_versement,
    montant: parseFloat(r.montant),
    note: r.note,
    valide: r.valide,
  };
}

/**
 * Liste les versements réels d'apports
 */
export async function listerVersements(apportId?: string): Promise<ApportVersement[]> {
  let query = `SELECT * FROM apports_versements WHERE valide = true`;
  const params: any[] = [];

  if (apportId) {
    query += ` AND apport_id = $1`;
    params.push(apportId);
  }

  query += ` ORDER BY date_versement DESC LIMIT 100`;

  const { rows } = await pool.query(query, params);
  return rows.map((r: any) => ({
    id: r.id,
    apportId: r.apport_id,
    dateVersement: r.date_versement,
    montant: parseFloat(r.montant),
    note: r.note,
    valide: r.valide,
  }));
}
