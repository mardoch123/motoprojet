import { Request, Response, NextFunction } from 'express';
import pool from '../config/db.js';
import { logger } from '../utils/logger.js';
import { forceAnomalyScan } from '../jobs/scheduler.js';

/**
 * Contrôleur des anomalies détectées par l'IA.
 *
 * Endpoints :
 * - GET /anomalies : liste les anomalies avec filtres (statut, sévérité, type)
 * - GET /anomalies/:id : détail d'une anomalie
 * - PUT /anomalies/:id/statut : changer le statut (vu, ignoré, traité)
 * - POST /anomalies/scan : forcer un scan manuel
 * - GET /anomalies/stats : statistiques globales
 */

/**
 * GET /anomalies
 * Liste les anomalies avec filtres optionnels.
 */
export async function getAnomalies(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { statut, severite, type, limit = '50', offset = '0' } = req.query;

    let query = `
      SELECT
        id, type_anomalie, severite, titre, description, cause_probable,
        actions_suggerees, contexte_json, statut, notif_envoyee,
        date_detection, date_traitement, traite_par
      FROM anomalies_detectees
      WHERE 1=1
    `;
    const params: any[] = [];
    let paramIndex = 1;

    if (statut) {
      query += ` AND statut = $${paramIndex}`;
      params.push(statut);
      paramIndex++;
    }

    if (severite) {
      query += ` AND severite = $${paramIndex}`;
      params.push(severite);
      paramIndex++;
    }

    if (type) {
      query += ` AND type_anomalie = $${paramIndex}`;
      params.push(type);
      paramIndex++;
    }

    query += ` ORDER BY date_detection DESC LIMIT $${paramIndex} OFFSET $${paramIndex + 1}`;
    params.push(parseInt(limit as string, 10), parseInt(offset as string, 10));

    const { rows } = await pool.query(query, params);

    // Compter le total pour la pagination
    let countQuery = `SELECT COUNT(*) FROM anomalies_detectees WHERE 1=1`;
    const countParams: any[] = [];
    let countIndex = 1;

    if (statut) {
      countQuery += ` AND statut = $${countIndex}`;
      countParams.push(statut);
      countIndex++;
    }
    if (severite) {
      countQuery += ` AND severite = $${countIndex}`;
      countParams.push(severite);
      countIndex++;
    }
    if (type) {
      countQuery += ` AND type_anomalie = $${countIndex}`;
      countParams.push(type);
      countIndex++;
    }

    const { rows: countRows } = await pool.query(countQuery, countParams);
    const total = parseInt(countRows[0].count, 10);

    res.json({ anomalies: rows, total, limit: parseInt(limit as string, 10), offset: parseInt(offset as string, 10) });
  } catch (err: any) {
    logger.error(`[AnomaliesController] Erreur getAnomalies: ${err.message}`);
    next(err);
  }
}

/**
 * GET /anomalies/stats
 * Statistiques globales sur les anomalies.
 */
export async function getAnomaliesStats(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { rows } = await pool.query(`
      SELECT
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE statut = 'nouveau') AS nouveaux,
        COUNT(*) FILTER (WHERE statut = 'vu') AS vus,
        COUNT(*) FILTER (WHERE statut = 'ignore') AS ignores,
        COUNT(*) FILTER (WHERE statut = 'traite') AS traites,
        COUNT(*) FILTER (WHERE severite = 'critique' AND statut = 'nouveau') AS critiques_nouveaux,
        COUNT(*) FILTER (WHERE date_detection >= NOW() - INTERVAL '7 days') AS derniers_7j,
        COUNT(*) FILTER (WHERE date_detection >= NOW() - INTERVAL '30 days') AS derniers_30j
      FROM anomalies_detectees
    `);

    // Stats par type
    const { rows: parType } = await pool.query(`
      SELECT
        type_anomalie,
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE statut = 'nouveau') AS nouveaux
      FROM anomalies_detectees
      GROUP BY type_anomalie
      ORDER BY total DESC
    `);

    res.json({
      global: rows[0],
      par_type: parType,
    });
  } catch (err: any) {
    logger.error(`[AnomaliesController] Erreur getAnomaliesStats: ${err.message}`);
    next(err);
  }
}

/**
 * GET /anomalies/:id
 * Détail d'une anomalie.
 */
export async function getAnomalieById(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { id } = req.params;

    const { rows } = await pool.query(
      `SELECT * FROM anomalies_detectees WHERE id = $1`,
      [id],
    );

    if (rows.length === 0) {
      res.status(404).json({ error: 'Anomalie non trouvée' });
      return;
    }

    res.json(rows[0]);
  } catch (err: any) {
    logger.error(`[AnomaliesController] Erreur getAnomalieById: ${err.message}`);
    next(err);
  }
}

/**
 * PUT /anomalies/:id/statut
 * Change le statut d'une anomalie (vu, ignore, traite).
 */
export async function updateAnomalieStatut(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { id } = req.params;
    const { statut } = req.body;

    if (!['vu', 'ignore', 'traite'].includes(statut)) {
      res.status(400).json({ error: 'Statut invalide. Valeurs acceptées : vu, ignore, traite' });
      return;
    }

    const userId = (req as any).user?.id;

    const { rows } = await pool.query(
      `UPDATE anomalies_detectees SET
         statut = $1,
         date_traitement = CASE WHEN $1 IN ('traite', 'ignore') THEN NOW() ELSE date_traitement END,
         traite_par = CASE WHEN $1 IN ('traite', 'ignore') THEN $2 ELSE traite_par END
       WHERE id = $3
       RETURNING *`,
      [statut, userId, id],
    );

    if (rows.length === 0) {
      res.status(404).json({ error: 'Anomalie non trouvée' });
      return;
    }

    res.json(rows[0]);
  } catch (err: any) {
    logger.error(`[AnomaliesController] Erreur updateAnomalieStatut: ${err.message}`);
    next(err);
  }
}

/**
 * POST /anomalies/scan
 * Force un scan manuel des anomalies.
 */
export async function forceScan(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    logger.info(`[AnomaliesController] Scan forcé par ${req.params.userId ?? 'admin'}`);
    const result = await forceAnomalyScan();
    res.json({
      message: 'Scan terminé',
      ...result,
    });
  } catch (err: any) {
    logger.error(`[AnomaliesController] Erreur forceScan: ${err.message}`);
    next(err);
  }
}
