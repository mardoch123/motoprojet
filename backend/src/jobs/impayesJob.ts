import pool from '../config/db.js';
import { logger } from '../utils/logger.js';
import { writeAuditLog } from '../services/audit.js';
import { executeRappels, type ReminderResult } from '../services/reminderService.js';

/**
 * Job nocturne — Calcul automatique des impayés et du taux de recouvrement.
 *
 * Exécution : chaque nuit à l'heure configurée (paramètre job_impayes_heure).
 * Peut aussi être déclenché manuellement via POST /api/v1/jobs/impayes.
 *
 * Étapes :
 * 1. Pour chaque véhicule actif, vérifier si un paiement a été enregistré aujourd'hui
 * 2. Sinon, écrire dans vehicule_impayes et incrémenter jours_impayes_cumules
 * 3. Mettre à jour le statut chauffeur : retard (≥ seuil_retard_jours) → défaut (≥ seuil_defaut_jours)
 * 4. Calculer et stocker le snapshot du taux de recouvrement
 * 5. Mettre à jour dernier_paiement_date pour chaque chauffeur
 */

export async function executeImpayesJob(): Promise<JobResult> {
  const startTime = Date.now();
  logger.info('[JobImpayes] Démarrage du job nocturne impayés');

  const result: JobResult = {
    date: new Date().toISOString().split('T')[0],
    vehicules_verifies: 0,
    impayes_detectes: 0,
    statuts_mis_a_jour: 0,
    taux_recouvrement: 0,
    duree_ms: 0,
  };

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // ── Lire les seuils configurables ─────────────────────────────────────
    const { rows: params } = await client.query(
      `SELECT cle, valeur FROM parametres WHERE cle IN ('seuil_defaut_jours', 'seuil_retard_jours')`,
    );
    const seuilDefaut = parseInt(params.find(p => p.cle === 'seuil_defaut_jours')?.valeur ?? '10', 10);
    const seuilRetard = parseInt(params.find(p => p.cle === 'seuil_retard_jours')?.valeur ?? '1', 10);

    // ── 1. Récupérer tous les véhicules en remboursement avec leur chauffeur ─
    // EXCLUSION : véhicules avec un incident actif (panne/accident/vol non résolu)
    const { rows: vehicules } = await client.query(`
      SELECT
        v.id AS vehicule_id,
        v.plaque,
        COALESCE(c.id, '00000000-0000-0000-0000-000000000000') AS chauffeur_id,
        COALESCE(c.nom, 'Non affecté') AS chauffeur_nom,
        COALESCE(c.objectif_journalier, 5000) AS objectif_journalier
      FROM vehicules v
      LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
      LEFT JOIN chauffeurs c ON c.id = a.chauffeur_id
      WHERE v.statut = 'en_remboursement'
        AND NOT EXISTS (
          SELECT 1 FROM incidents i
          WHERE i.vehicule_id = v.id
            AND i.statut NOT IN ('resolu', 'classe_sans_suite')
        )
    `);

    result.vehicules_verifies = vehicules.length;
    const today = new Date().toISOString().split('T')[0];

    // ── 2. Pour chaque véhicule, vérifier le paiement du jour ─────────────
    for (const v of vehicules) {
      // Vérifier si déjà traité aujourd'hui
      const { rows: existing } = await client.query(
        `SELECT id FROM vehicule_impayes WHERE vehicule_id = $1 AND date = $2`,
        [v.vehicule_id, today],
      );
      if (existing.length > 0) continue; // Déjà traité

      // Calculer le montant versé aujourd'hui pour ce véhicule
      const { rows: paiementsJour } = await client.query(
        `SELECT COALESCE(SUM(montant), 0) AS total FROM paiements
         WHERE vehicule_id = $1 AND date = $2`,
        [v.vehicule_id, today],
      );
      const montantVerse = parseFloat(paiementsJour[0].total);
      const objectif = parseFloat(v.objectif_journalier);
      const ecart = objectif - montantVerse;

      let statut: string;
      if (montantVerse >= objectif) {
        statut = 'paye';
      } else if (montantVerse > 0) {
        statut = 'partiel';
      } else {
        statut = 'impaye';
      }

      // Écrire dans vehicule_impayes
      await client.query(
        `INSERT INTO vehicule_impayes (vehicule_id, chauffeur_id, date, montant_attendu, montant_verse, ecart, statut)
         VALUES ($1, $2, $3, $4, $5, $6, $7)`,
        [v.vehicule_id, v.chauffeur_id, today, objectif, montantVerse, ecart, statut],
      );

      if (statut !== 'paye') {
        result.impayes_detectes++;
      }
    }

    // ── 3. Mettre à jour jours_impayes_cumules + statut pour chaque chauffeur ─
    const { rows: chauffeurs } = await client.query(`
      SELECT
        c.id,
        c.nom,
        c.statut AS statut_actuel,
        COALESCE(c.jours_impayes_cumules, 0) AS jours_cumules,
        MAX(p.date) AS dernier_paiement
      FROM chauffeurs c
      LEFT JOIN affectations a ON a.chauffeur_id = c.id AND a.date_fin IS NULL
      LEFT JOIN vehicules v ON v.id = a.vehicule_id AND v.statut = 'en_remboursement'
      LEFT JOIN paiements p ON p.chauffeur_id = c.id
      WHERE c.statut IN ('actif', 'retard', 'defaut')
      GROUP BY c.id, c.nom, c.statut, c.jours_impayes_cumules
    `);

    for (const c of chauffeurs) {
      const dernierPaiement = c.dernier_paiement ? new Date(c.dernier_paiement) : null;
      const aujourdHui = new Date();
      aujourdHui.setHours(0, 0, 0, 0);

      let joursImpayes: number;
      if (dernierPaiement) {
        const diffMs = aujourdHui.getTime() - dernierPaiement.getTime();
        joursImpayes = Math.max(0, Math.floor(diffMs / (1000 * 60 * 60 * 24)));
      } else {
        // Jamais payé → compter depuis la date de création
        joursImpayes = 999;
      }

      // Déterminer le nouveau statut
      let nouveauStatut: string;
      if (joursImpayes >= seuilDefaut) {
        nouveauStatut = 'defaut';
      } else if (joursImpayes >= seuilRetard) {
        nouveauStatut = 'retard';
      } else {
        nouveauStatut = 'actif';
      }

      // Mettre à jour le chauffeur
      await client.query(
        `UPDATE chauffeurs SET
           jours_impayes_cumules = $1,
           dernier_paiement_date = $2,
           statut = $3
         WHERE id = $4 AND statut != 'termine'`,
        [joursImpayes, c.dernier_paiement ?? null, nouveauStatut, c.id],
      );

      if (nouveauStatut !== c.statut_actuel) {
        result.statuts_mis_a_jour++;
        logger.info(`[JobImpayes] ${c.nom}: ${c.statut_actuel} → ${nouveauStatut} (${joursImpayes}j impayés)`);
      }
    }

    // ── 4. Calculer et stocker le snapshot du taux de recouvrement ──────────
    // EXCLUSION : véhicules avec incident actif du calcul du taux
    const { rows: statsVehicules } = await client.query(`
      SELECT
        COUNT(*) AS total_actifs,
        COUNT(*) FILTER (WHERE sub.jours_sans_paiement = 0) AS a_jour,
        COUNT(*) FILTER (WHERE sub.jours_sans_paiement BETWEEN 1 AND $1 - 1) AS en_retard,
        COUNT(*) FILTER (WHERE sub.jours_sans_paiement >= $1) AS en_defaut
      FROM vehicules v
      LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
      LEFT JOIN chauffeurs c ON c.id = a.chauffeur_id
      LEFT JOIN LATERAL (
        SELECT
          CASE
            WHEN MAX(p.date) IS NULL THEN 999
            ELSE (CURRENT_DATE - MAX(p.date))
          END AS jours_sans_paiement
        FROM paiements p
        WHERE p.vehicule_id = v.id
      ) sub ON true
      WHERE v.statut = 'en_remboursement'
        AND NOT EXISTS (
          SELECT 1 FROM incidents i
          WHERE i.vehicule_id = v.id
            AND i.statut NOT IN ('resolu', 'classe_sans_suite')
        )
    `, [seuilDefaut]);

    const { rows: montants } = await client.query(`
      SELECT
        COALESCE(SUM(
          CASE
            WHEN v.date_mise_circulation IS NOT NULL THEN
              GREATEST(0, (CURRENT_DATE - v.date_mise_circulation)) * COALESCE(c.objectif_journalier, 5000)
            ELSE 0
          END
        ), 0) AS montant_theorique_global,
        COALESCE(SUM(p_total.total_verse), 0) AS montant_reel_global
      FROM vehicules v
      LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
      LEFT JOIN chauffeurs c ON c.id = a.chauffeur_id
      LEFT JOIN LATERAL (
        SELECT COALESCE(SUM(montant), 0) AS total_verse
        FROM paiements WHERE vehicule_id = v.id
      ) p_total ON true
      WHERE v.statut = 'en_remboursement'
        AND NOT EXISTS (
          SELECT 1 FROM incidents i
          WHERE i.vehicule_id = v.id
            AND i.statut NOT IN ('resolu', 'classe_sans_suite')
        )
    `);

    const montantTheorique = parseFloat(montants[0].montant_theorique_global);
    const montantReel = parseFloat(montants[0].montant_reel_global);
    const tauxRecouvrement = montantTheorique > 0
      ? Math.round((montantReel / montantTheorique) * 10000) / 100
      : 0;

    await client.query(
      `INSERT INTO historique_taux_recouvrement
         (date, montant_reel, montant_theorique, taux_recouvrement,
          nb_vehicules_actifs, nb_vehicules_a_jour, nb_vehicules_en_retard, nb_vehicules_en_defaut)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (date) DO UPDATE SET
         montant_reel = EXCLUDED.montant_reel,
         montant_theorique = EXCLUDED.montant_theorique,
         taux_recouvrement = EXCLUDED.taux_recouvrement,
         nb_vehicules_actifs = EXCLUDED.nb_vehicules_actifs,
         nb_vehicules_a_jour = EXCLUDED.nb_vehicules_a_jour,
         nb_vehicules_en_retard = EXCLUDED.nb_vehicules_en_retard,
         nb_vehicules_en_defaut = EXCLUDED.nb_vehicules_en_defaut`,
      [
        today,
        montantReel,
        montantTheorique,
        tauxRecouvrement,
        parseInt(statsVehicules[0].total_actifs, 10),
        parseInt(statsVehicules[0].a_jour, 10),
        parseInt(statsVehicules[0].en_retard, 10),
        parseInt(statsVehicules[0].en_defaut, 10),
      ],
    );

    result.taux_recouvrement = tauxRecouvrement;

    await client.query('COMMIT');

    // Audit log (hors transaction)
    await writeAuditLog('system', 'JOB_IMPAYES', today, {
      vehicules_verifies: result.vehicules_verifies,
      impayes_detectes: result.impayes_detectes,
      statuts_mis_a_jour: result.statuts_mis_a_jour,
      taux_recouvrement: tauxRecouvrement,
    });

    // ── 6. Déclencher les rappels automatiques ───────────────────────────
    try {
      const rappels = await executeRappels();
      result.rappels = rappels;
    } catch (err: any) {
      logger.error(`[JobImpayes] Erreur rappels: ${err.message}`);
      // Ne pas faire échouer le job pour un échec de rappels
    }

    result.duree_ms = Date.now() - startTime;
    logger.info(`[JobImpayes] Terminé en ${result.duree_ms}ms — ${result.impayes_detectes} impayés, taux: ${tauxRecouvrement}%`);

    return result;
  } catch (err: any) {
    await client.query('ROLLBACK');
    logger.error(`[JobImpayes] Erreur: ${err.message}`);
    throw err;
  } finally {
    client.release();
  }
}

export interface JobResult {
  date: string;
  vehicules_verifies: number;
  impayes_detectes: number;
  statuts_mis_a_jour: number;
  taux_recouvrement: number;
  duree_ms: number;
  rappels?: ReminderResult;
}
