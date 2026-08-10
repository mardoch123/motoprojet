import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import type { AuthRequest } from '../types/index.js';
import { forceRunJob } from '../jobs/scheduler.js';

/**
 * GET /api/v1/dashboard/retards
 * Liste des chauffeurs en retard triée par gravité.
 *
 * Exemple de réponse JSON :
 * {
 *   "success": true,
 *   "data": [
 *     {
 *       "chauffeur_id": "abc-123...",
 *       "nom": "Koffi AGBANLON",
 *       "statut": "defaut",
 *       "jours_impayes_cumules": 15,
 *       "dernier_paiement_date": "2026-07-26",
 *       "objectif_journalier": 5000,
 *       "nb_vehicules": 1,
 *       "montant_du": 75000,
 *       "jours_depuis_dernier_paiement": 15,
 *       "vehicules": [
 *         { "plaque": "MOTO-001-BJ", "taux_recouvrement": 45.2, "solde_restant": 247500 }
 *       ]
 *     }
 *   ],
 *   "meta": {
 *     "total_en_retard": 3,
 *     "total_en_defaut": 1,
 *     "montant_total_du": 225000
 *   }
 * }
 */
export async function getDashboardRetards(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    // Chauffeurs en retard/défaut avec détails
    const { rows: chauffeurs } = await pool.query(`
      SELECT
        c.id AS chauffeur_id,
        c.nom,
        c.statut AS statut_chauffeur,
        c.jours_impayes_cumules,
        c.dernier_paiement_date,
        COALESCE(c.objectif_journalier, 5000) AS objectif_journalier,
        CASE
          WHEN c.dernier_paiement_date IS NULL THEN 999
          ELSE (CURRENT_DATE - c.dernier_paiement_date)
        END AS jours_depuis_dernier_paiement
      FROM chauffeurs c
      WHERE c.statut IN ('retard', 'defaut')
      ORDER BY
        CASE c.statut WHEN 'defaut' THEN 0 WHEN 'retard' THEN 1 ELSE 2 END,
        c.jours_impayes_cumules DESC
    `);

    // Pour chaque chauffeur, récupérer les détails de ses véhicules
    const data = [];
    let montantTotalDu = 0;
    let totalRetard = 0;
    let totalDefaut = 0;

    for (const c of chauffeurs) {
      const { rows: vehicules } = await pool.query(`
        SELECT
          v.id AS vehicule_id,
          v.plaque,
          v.type,
          v.prix_achat,
          COALESCE(SUM(p.montant), 0) AS total_verse,
          v.prix_achat - COALESCE(SUM(p.montant), 0) AS solde_restant,
          CASE
            WHEN v.date_mise_circulation IS NOT NULL THEN
              ROUND(
                (COALESCE(SUM(p.montant), 0) /
                 NULLIF(GREATEST(1, (CURRENT_DATE - v.date_mise_circulation)) * COALESCE($1, 5000), 0)
                ) * 100, 2
              )
            ELSE 0
          END AS taux_recouvrement
        FROM vehicules v
        LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL AND a.chauffeur_id = $2
        LEFT JOIN paiements p ON p.vehicule_id = v.id
        WHERE a.chauffeur_id = $2 AND v.statut = 'en_remboursement'
        GROUP BY v.id, v.plaque, v.type, v.prix_achat, v.date_mise_circulation
      `, [c.objectif_journalier, c.chauffeur_id]);

      const montantDu = vehicules.reduce((sum: number, v: any) => sum + parseFloat(v.solde_restant), 0);
      montantTotalDu += montantDu;

      if (c.statut_chauffeur === 'retard') totalRetard++;
      if (c.statut_chauffeur === 'defaut') totalDefaut++;

      data.push({
        chauffeur_id: c.chauffeur_id,
        nom: c.nom,
        statut: c.statut_chauffeur,
        jours_impayes_cumules: c.jours_impayes_cumules,
        dernier_paiement_date: c.dernier_paiement_date,
        objectif_journalier: parseFloat(c.objectif_journalier),
        nb_vehicules: vehicules.length,
        montant_du: Math.round(montantDu),
        jours_depuis_dernier_paiement: c.jours_depuis_dernier_paiement,
        vehicules: vehicules.map((v: any) => ({
          vehicule_id: v.vehicule_id,
          plaque: v.plaque,
          type: v.type,
          prix_achat: parseFloat(v.prix_achat),
          total_verse: parseFloat(v.total_verse),
          solde_restant: parseFloat(v.solde_restant),
          taux_recouvrement: parseFloat(v.taux_recouvrement),
        })),
      });
    }

    res.json({
      success: true,
      data,
      meta: {
        total_en_retard: totalRetard,
        total_en_defaut: totalDefaut,
        montant_total_du: Math.round(montantTotalDu),
      },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/dashboard/recuperation
 * Taux de recouvrement global + historique (graphique semaine/mois).
 *
 * Exemple de réponse JSON :
 * {
 *   "success": true,
 *   "data": {
 *     "actuel": {
 *       "taux_recouvrement": 67.34,
 *       "montant_reel": 450000,
 *       "montant_theorique": 668000,
 *       "nb_vehicules_actifs": 5,
 *       "nb_a_jour": 2,
 *       "nb_en_retard": 2,
 *       "nb_en_defaut": 1
 *     },
 *     "historique": [
 *       { "date": "2026-08-01", "taux": 65.2, "montant_reel": 440000, "montant_theorique": 675000 },
 *       { "date": "2026-08-02", "taux": 66.1, "montant_reel": 445000, "montant_theorique": 673000 }
 *     ],
 *     "par_vehicule": [
 *       { "plaque": "MOTO-001-BJ", "taux": 72.5, "montant_reel": 326000, "montant_theorique": 450000 }
 *     ]
 *   }
 * }
 */
export async function getDashboardRecuperation(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const periode = (req.query.periode as string) || 'mois'; // 'semaine' | 'mois' | 'tout'
    const jours = periode === 'semaine' ? 7 : periode === 'mois' ? 30 : 365;

    // ── Snapshot actuel (dernier calcul) ──────────────────────────────────
    const { rows: actuel } = await pool.query(`
      SELECT * FROM historique_taux_recouvrement
      ORDER BY date DESC LIMIT 1
    `);

    // ── Historique (pour graphique) ───────────────────────────────────────
    const { rows: historique } = await pool.query(`
      SELECT
        date,
        taux_recouvrement,
        montant_reel,
        montant_theorique,
        nb_vehicules_actifs,
        nb_vehicules_a_jour,
        nb_vehicules_en_retard,
        nb_vehicules_en_defaut
      FROM historique_taux_recouvrement
      WHERE date >= CURRENT_DATE - INTERVAL '${jours} days'
      ORDER BY date ASC
    `);

    // ── Détail par véhicule ───────────────────────────────────────────────
    const { rows: parVehicule } = await pool.query(`
      SELECT * FROM vue_recouvrement_par_vehicule
      ORDER BY taux_recouvrement ASC
    `);

    // ── Tendance (comparaison début/fin de période) ───────────────────────
    const { rows: tendance } = await pool.query(`
      SELECT
        (SELECT taux_recouvrement FROM historique_taux_recouvrement
         WHERE date >= CURRENT_DATE - INTERVAL '${jours} days' ORDER BY date ASC LIMIT 1) AS debut_periode,
        (SELECT taux_recouvrement FROM historique_taux_recouvrement
         ORDER BY date DESC LIMIT 1) AS fin_periode
    `);

    const tendanceEvolution = tendance[0]?.debut_periode && tendance[0]?.fin_periode
      ? Math.round((parseFloat(tendance[0].fin_periode) - parseFloat(tendance[0].debut_periode)) * 100) / 100
      : 0;

    res.json({
      success: true,
      data: {
        actuel: actuel[0] ? {
          date: actuel[0].date,
          taux_recouvrement: parseFloat(actuel[0].taux_recouvrement),
          montant_reel: parseFloat(actuel[0].montant_reel),
          montant_theorique: parseFloat(actuel[0].montant_theorique),
          nb_vehicules_actifs: actuel[0].nb_vehicules_actifs,
          nb_a_jour: actuel[0].nb_vehicules_a_jour,
          nb_en_retard: actuel[0].nb_vehicules_en_retard,
          nb_en_defaut: actuel[0].nb_vehicules_en_defaut,
        } : null,
        historique: historique.map(h => ({
          date: h.date,
          taux: parseFloat(h.taux_recouvrement),
          montant_reel: parseFloat(h.montant_reel),
          montant_theorique: parseFloat(h.montant_theorique),
          nb_vehicules: h.nb_vehicules_actifs,
          nb_a_jour: h.nb_vehicules_a_jour,
          nb_en_retard: h.nb_vehicules_en_retard,
          nb_en_defaut: h.nb_vehicules_en_defaut,
        })),
        par_vehicule: parVehicule.map(v => ({
          vehicule_id: v.vehicule_id,
          plaque: v.plaque,
          chauffeur_nom: v.chauffeur_nom,
          prix_achat: parseFloat(v.prix_achat),
          objectif_journalier: parseFloat(v.objectif_journalier),
          montant_theorique: parseFloat(v.montant_theorique),
          montant_reel: parseFloat(v.montant_reel),
          taux_recouvrement: parseFloat(v.taux_recouvrement),
          jours_sans_paiement: parseInt(v.jours_sans_paiement, 10),
        })),
        tendance: {
          periode_jours: jours,
          evolution_pp: tendanceEvolution, // en points de pourcentage
          direction: tendanceEvolution > 0 ? 'amélioration' : tendanceEvolution < 0 ? 'dégradation' : 'stable',
        },
      },
    });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/jobs/impayes
 * Déclenche manuellement le job des impayés.
 */
export async function triggerImpayesJob(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const result = await forceRunJob();
    res.json({
      success: true,
      data: { message: 'Job impayés exécuté avec succès' },
      meta: result,
    });
  } catch (err) { next(err); }
}
