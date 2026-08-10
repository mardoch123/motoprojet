import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import type { AuthRequest } from '../types/index.js';
import { getAppelIA, type IaContexteChauffeur } from '../services/iaService.js';
import { logger } from '../utils/logger.js';
import { AppError } from '../utils/errors.js';

/**
 * POST /api/v1/ia/recommandations
 *
 * Le chauffeur envoie son contexte du jour (revenu, km, zones).
 * L'API agrège les données des 7 derniers jours, appelle le modèle IA,
 * stocke la recommandation et la retourne.
 *
 * Body :
 * {
 *   revenu_jour: number,
 *   km_jour: number,
 *   zones: string[]
 * }
 */
export async function getRecommandation(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const user = req.user!;
    const { revenu_jour, km_jour, zones } = req.body as {
      revenu_jour: number;
      km_jour: number;
      zones: string[];
    };

    // 1. Récupérer le chauffeur lié à cet utilisateur
    const { rows: chauffeurRows } = await pool.query(
      `SELECT c.id, c.nom, COALESCE(c.objectif_journalier, 5000) AS objectif_journalier
       FROM chauffeurs c
       JOIN users u ON u.id = c.user_id
       WHERE u.id = $1 AND c.statut = 'actif'`,
      [user.sub],
    );

    if (chauffeurRows.length === 0) {
      throw AppError.notFound('Chauffeur actif non trouvé');
    }

    const chauffeur = chauffeurRows[0];
    const chauffeurId = chauffeur.id as string;
    const objectifJour = parseFloat(chauffeur.objectif_journalier);

    // 2. Récupérer les trajets des 7 derniers jours
    const { rows: trajets7j } = await pool.query(
      `SELECT date, km_parcourus, zones, revenu_genere
       FROM trajets
       WHERE chauffeur_id = $1
         AND date >= CURRENT_DATE - INTERVAL '7 days'
       ORDER BY date DESC`,
      [chauffeurId],
    );

    // 3. Calculer les agrégats
    const km7j = trajets7j.reduce((sum: number, t: { km_parcourus: string }) => sum + parseFloat(t.km_parcourus), 0);
    const revenu7j = trajets7j.reduce((sum: number, t: { revenu_genere: string }) => sum + parseFloat(t.revenu_genere), 0);

    // Zones fréquentées (anonymisées, pas de coordonnées GPS)
    const toutesZones = trajets7j.flatMap((t: { zones: string[] }) =>
      Array.isArray(t.zones) ? t.zones : [],
    );
    const zonesCount = new Map<string, number>();
    toutesZones.forEach((z: string) => zonesCount.set(z, (zonesCount.get(z) ?? 0) + 1));
    const zonesFrequentees = [...zonesCount.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([zone]) => zone);

    // Historique jour par jour
    const historique7j = trajets7j.map((t: { date: string; revenu_genere: string; km_parcourus: string }) => ({
      date: t.date,
      revenu: parseFloat(t.revenu_genere),
      km: parseFloat(t.km_parcourus),
      objectif_atteint: parseFloat(t.revenu_genere) >= objectifJour,
    }));

    // Performance semaine
    const joursTravailles = trajets7j.length;
    const joursObjectifAtteint = trajets7j.filter(
      (t: { revenu_genere: string }) => parseFloat(t.revenu_genere) >= objectifJour,
    ).length;

    const contexte: IaContexteChauffeur = {
      chauffeur_nom: chauffeur.nom,
      objectif_jour: objectifJour,
      revenu_jour: revenu_jour ?? 0,
      km_jour: km_jour ?? 0,
      km_7j: km7j,
      zones_frequentees: zones ?? zonesFrequentees,
      historique_7j: historique7j,
      performance_semaine: {
        jours_travailles: joursTravailles,
        jours_objectif_atteint: joursObjectifAtteint,
        revenu_total: revenu7j + (revenu_jour ?? 0),
        objectif_total: objectifJour * 7,
      },
    };

    // 4. Appeler le modèle IA
    const reponseIA = await getAppelIA(contexte);

    const objectifAtteint = (revenu_jour ?? 0) >= objectifJour;

    // 5. Stocker la recommandation en base
    const { rows: recoRows } = await pool.query(
      `INSERT INTO ia_recommendations
        (chauffeur_id, modele_utilise, revenu_jour, objectif_jour, km_jour, km_7j, zones_frequentees, recommandation, objectif_atteint)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, date_creation`,
      [
        chauffeurId,
        reponseIA.modele_utilise,
        revenu_jour ?? 0,
        objectifJour,
        km_jour ?? 0,
        km7j,
        JSON.stringify(zones ?? zonesFrequentees),
        reponseIA.recommandation,
        objectifAtteint,
      ],
    );

    // 6. Mettre à jour l'historique de performance du jour
    const today = new Date().toISOString().split('T')[0];
    await pool.query(
      `INSERT INTO historique_performance
        (chauffeur_id, periode_type, periode_label, objectif, revenu_realise, ecart, objectif_atteint, km_parcourus, nb_jours_activite)
       VALUES ($1, 'jour', $2, $3, $4, $5, $6, $7, 1)
       ON CONFLICT (chauffeur_id, periode_type, periode_label)
       DO UPDATE SET
         revenu_realise = EXCLUDED.revenu_realise,
         ecart = EXCLUDED.ecart,
         objectif_atteint = EXCLUDED.objectif_atteint,
         km_parcourus = EXCLUDED.km_parcourus`,
      [
        chauffeurId,
        today,
        objectifJour,
        revenu_jour ?? 0,
        (revenu_jour ?? 0) - objectifJour,
        objectifAtteint,
        km_jour ?? 0,
      ],
    );

    // 7. Mettre à jour le résumé hebdomadaire
    const weekStart = getWeekLabel();
    await pool.query(
      `INSERT INTO historique_performance
        (chauffeur_id, periode_type, periode_label, objectif, revenu_realise, ecart, objectif_atteint, km_parcourus, nb_jours_activite)
       VALUES ($1, 'semaine', $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (chauffeur_id, periode_type, periode_label)
       DO UPDATE SET
         revenu_realise = EXCLUDED.revenu_realise,
         ecart = EXCLUDED.ecart,
         objectif_atteint = EXCLUDED.objectif_atteint,
         km_parcourus = EXCLUDED.km_parcourus,
         nb_jours_activite = EXCLUDED.nb_jours_activite`,
      [
        chauffeurId,
        weekStart,
        objectifJour * 7,
        revenu7j + (revenu_jour ?? 0),
        (revenu7j + (revenu_jour ?? 0)) - (objectifJour * 7),
        (revenu7j + (revenu_jour ?? 0)) >= (objectifJour * 7),
        km7j + (km_jour ?? 0),
        joursTravailles + 1,
      ],
    );

    // 8. Répondre
    res.json({
      success: true,
      data: {
        id: recoRows[0].id,
        recommandation: reponseIA.recommandation,
        objectif_atteint: objectifAtteint,
        modele_utilise: reponseIA.modele_utilise,
        contexte: {
          revenu_jour: revenu_jour ?? 0,
          objectif_jour: objectifJour,
          ecart: (revenu_jour ?? 0) - objectifJour,
          km_jour: km_jour ?? 0,
          km_7j: km7j,
          zones_frequentees: zones ?? zonesFrequentees,
          jours_travailles_7j: joursTravailles,
          jours_objectif_atteint_7j: joursObjectifAtteint,
        },
        date: recoRows[0].date_creation,
      },
    });
  } catch (err) {
    logger.error('[IA] Erreur getRecommandation', { err });
    next(err);
  }
}

/**
 * GET /api/v1/ia/historique
 *
 * Retourne l'historique des recommandations et performances du chauffeur.
 * Query params : limit (défaut 14, max 90)
 */
export async function getHistorique(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const user = req.user!;
    const limit = Math.min(90, Math.max(1, parseInt(req.query.limit as string) || 14));

    // Récupérer le chauffeur
    const { rows: chauffeurRows } = await pool.query(
      `SELECT c.id FROM chauffeurs c JOIN users u ON u.id = c.user_id WHERE u.id = $1`,
      [user.sub],
    );

    if (chauffeurRows.length === 0) {
      throw AppError.notFound('Chauffeur non trouvé');
    }

    const chauffeurId = chauffeurRows[0].id as string;

    const [recommandations, performances] = await Promise.all([
      pool.query(
        `SELECT id, modele_utilise, revenu_jour, objectif_jour, km_jour, km_7j,
                zones_frequentees, recommandation, objectif_atteint, date_creation
         FROM ia_recommendations
         WHERE chauffeur_id = $1
         ORDER BY date_creation DESC
         LIMIT $2`,
        [chauffeurId, limit],
      ),
      pool.query(
        `SELECT periode_type, periode_label, objectif, revenu_realise, ecart,
                objectif_atteint, km_parcourus, nb_jours_activite, date_creation
         FROM historique_performance
         WHERE chauffeur_id = $1
         ORDER BY date_creation DESC
         LIMIT $2`,
        [chauffeurId, limit],
      ),
    ]);

    // Calculer les stats globales
    const totalJours = recommandations.rows.length;
    const joursAtteints = recommandations.rows.filter(
      (r: { objectif_atteint: boolean }) => r.objectif_atteint,
    ).length;

    res.json({
      success: true,
      data: {
        recommandations: recommandations.rows,
        performances: performances.rows,
        stats: {
          total_jours_analyses: totalJours,
          jours_objectif_atteint: joursAtteints,
          taux_reussite: totalJours > 0 ? Math.round((joursAtteints / totalJours) * 100) : 0,
        },
      },
    });
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/ia/objectif
 *
 * Met à jour l'objectif de revenu journalier du chauffeur.
 * Body : { objectif_journalier: number }
 */
export async function updateObjectif(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const user = req.user!;
    const { objectif_journalier } = req.body as { objectif_journalier: number };

    if (!objectif_journalier || objectif_journalier <= 0) {
      throw AppError.badRequest('L\'objectif doit être supérieur à 0');
    }

    const { rows } = await pool.query(
      `UPDATE chauffeurs SET objectif_journalier = $1
       WHERE user_id = $2
       RETURNING id, nom, objectif_journalier`,
      [objectif_journalier, user.sub],
    );

    if (rows.length === 0) {
      throw AppError.notFound('Chauffeur non trouvé');
    }

    res.json({
      success: true,
      data: {
        chauffeur_id: rows[0].id,
        nom: rows[0].nom,
        objectif_journalier: parseFloat(rows[0].objectif_journalier),
      },
    });
  } catch (err) { next(err); }
}

// ─── Utilitaire ───────────────────────────────────────────────────────────────
function getWeekLabel(): string {
  const now = new Date();
  const startOfWeek = new Date(now);
  startOfWeek.setDate(now.getDate() - now.getDay() + 1); // Lundi
  return startOfWeek.toISOString().split('T')[0];
}
