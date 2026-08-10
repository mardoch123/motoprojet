import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import pool from '../../config/db.js';
import type { AuthRequest } from '../../types/index.js';
import { Response, NextFunction } from 'express';

const router = Router();

router.use(authenticate);
router.use(authorize('super_admin'));

/**
 * GET /api/v1/audit
 * Consulte le journal d'audit (Super Admin uniquement).
 * Query : ?action=CREATE_CHAUFFEUR&resource_type=chauffeur&date_debut=2025-01-01&limit=50&offset=0
 */
router.get('/', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const {
      action, resource_type, user_id, date_debut, date_fin,
      limit = '50', offset = '0',
    } = req.query;

    const conditions: string[] = [];
    const params: any[] = [];
    let paramIdx = 1;

    if (action) {
      conditions.push(`a.action = $${paramIdx++}`);
      params.push(action);
    }
    if (resource_type) {
      conditions.push(`a.resource_type = $${paramIdx++}`);
      params.push(resource_type);
    }
    if (user_id) {
      conditions.push(`a.user_id = $${paramIdx++}`);
      params.push(user_id);
    }
    if (date_debut) {
      conditions.push(`a.date_action >= $${paramIdx++}`);
      params.push(date_debut);
    }
    if (date_fin) {
      conditions.push(`a.date_action <= $${paramIdx++}`);
      params.push(date_fin);
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    // Compter le total
    const { rows: countResult } = await pool.query(
      `SELECT COUNT(*) as total FROM journal_audit a ${whereClause}`,
      params,
    );
    const total = parseInt(countResult[0].total, 10);

    // Récupérer les entrées
    const { rows } = await pool.query(
      `SELECT a.id, a.user_id, a.action, a.cible, a.details,
              a.valeur_avant, a.valeur_apres, a.ip_address,
              a.resource_type, a.resource_id, a.date_action,
              u.telephone AS user_telephone, u.role AS user_role
       FROM journal_audit a
       LEFT JOIN users u ON u.id = a.user_id
       ${whereClause}
       ORDER BY a.date_action DESC
       LIMIT $${paramIdx++} OFFSET $${paramIdx++}`,
      [...params, parseInt(limit as string, 10), parseInt(offset as string, 10)],
    );

    res.json({
      success: true,
      data: rows,
      meta: {
        total,
        limit: parseInt(limit as string, 10),
        offset: parseInt(offset as string, 10),
      },
    });
  } catch (err) { next(err); }
});

/**
 * GET /api/v1/audit/security
 * Consulte les événements de sécurité (Super Admin).
 */
router.get('/security', async (req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const {
      type, severity, user_id,
      limit = '50', offset = '0',
    } = req.query;

    const conditions: string[] = [];
    const params: any[] = [];
    let paramIdx = 1;

    if (type) {
      conditions.push(`s.type = $${paramIdx++}`);
      params.push(type);
    }
    if (severity) {
      conditions.push(`s.severity = $${paramIdx++}`);
      params.push(severity);
    }
    if (user_id) {
      conditions.push(`s.user_id = $${paramIdx++}`);
      params.push(user_id);
    }

    const whereClause = conditions.length > 0 ? `WHERE ${conditions.join(' AND ')}` : '';

    const { rows } = await pool.query(
      `SELECT s.id, s.user_id, s.type, s.severity, s.details,
              s.ip_address, s.user_agent, s.date_event,
              u.telephone AS user_telephone, u.role AS user_role
       FROM security_events s
       LEFT JOIN users u ON u.id = s.user_id
       ${whereClause}
       ORDER BY s.date_event DESC
       LIMIT $${paramIdx++} OFFSET $${paramIdx++}`,
      [...params, parseInt(limit as string, 10), parseInt(offset as string, 10)],
    );

    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
});

/**
 * GET /api/v1/audit/stats
 * Statistiques d'audit (Super Admin).
 */
router.get('/stats', async (_req: AuthRequest, res: Response, next: NextFunction) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        COUNT(*) AS total_actions,
        COUNT(*) FILTER (WHERE date_action > NOW() - INTERVAL '24 hours') AS actions_24h,
        COUNT(*) FILTER (WHERE date_action > NOW() - INTERVAL '7 days') AS actions_7j,
        COUNT(DISTINCT user_id) AS utilisateurs_uniques,
        COUNT(DISTINCT action) AS types_actions
      FROM journal_audit
    `);

    const { rows: topActions } = await pool.query(`
      SELECT action, COUNT(*) AS count
      FROM journal_audit
      WHERE date_action > NOW() - INTERVAL '7 days'
      GROUP BY action
      ORDER BY count DESC
      LIMIT 10
    `);

    const { rows: securityStats } = await pool.query(`
      SELECT
        COUNT(*) FILTER (WHERE type = 'login_failure') AS login_failures_24h,
        COUNT(*) FILTER (WHERE type = 'account_locked') AS lockouts_7j,
        COUNT(*) FILTER (WHERE severity = 'critical') AS events_critiques_7j
      FROM security_events
      WHERE date_event > NOW() - INTERVAL '7 days'
    `);

    res.json({
      success: true,
      data: {
        audit: rows[0],
        top_actions: topActions,
        security: securityStats[0],
      },
    });
  } catch (err) { next(err); }
});

export default router;
