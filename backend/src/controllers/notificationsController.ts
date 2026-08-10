import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import type { AuthRequest } from '../types/index.js';

/**
 * GET /api/v1/notifications
 * Liste des notifications pour l'utilisateur connecté.
 * Admin/gestionnaire voient toutes les notifications.
 * Chauffeur ne voit que les siennes.
 *
 * Query params : type, statut, page, limit
 */
export async function listNotifications(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const user = req.user!;
    const typeFilter = req.query.type as string;
    const statutFilter = req.query.statut as string;
    const page = Math.max(1, parseInt(req.query.page as string) || 1);
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit as string) || 50));
    const offset = (page - 1) * limit;

    let query: string;
    let countQuery: string;
    let params: unknown[] = [];
    let paramIdx = 1;
    const conditions: string[] = [];

    // Un chauffeur ne voit que ses notifications
    if (user.role === 'chauffeur') {
      conditions.push(`n.user_id = $${paramIdx}`);
      params.push(user.sub);
      paramIdx++;
    }

    if (typeFilter) {
      conditions.push(`n.type = $${paramIdx}`);
      params.push(typeFilter);
      paramIdx++;
    }
    if (statutFilter) {
      conditions.push(`n.statut = $${paramIdx}`);
      params.push(statutFilter);
      paramIdx++;
    }

    const whereClause = conditions.length > 0 ? 'WHERE ' + conditions.join(' AND ') : '';

    query = `
      SELECT n.id, n.user_id, n.titre, n.message, n.type, n.canal, n.statut,
             n.tentatives, n.erreur, n.lu, n.date_creation, n.date_envoi,
             u.telephone AS destinataire_telephone
      FROM notifications_log n
      LEFT JOIN users u ON u.id = n.user_id
      ${whereClause}
      ORDER BY n.date_creation DESC
      LIMIT $${paramIdx} OFFSET $${paramIdx + 1}
    `;
    params.push(limit, offset);

    countQuery = `SELECT COUNT(*) AS total FROM notifications_log n ${whereClause}`;

    const [dataResult, countResult] = await Promise.all([
      pool.query(query, params),
      pool.query(countQuery, params.slice(0, -2)), // sans limit/offset
    ]);

    res.json({
      success: true,
      data: dataResult.rows,
      meta: {
        total: parseInt(countResult.rows[0].total, 10),
        page,
        limit,
        pages: Math.ceil(parseInt(countResult.rows[0].total, 10) / limit),
      },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/notifications/stats
 * Statistiques des notifications (admin uniquement).
 */
export async function getNotificationStats(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { rows } = await pool.query(`
      SELECT
        COUNT(*) AS total,
        COUNT(*) FILTER (WHERE statut = 'envoye') AS envoyes,
        COUNT(*) FILTER (WHERE statut = 'echec') AS echecs,
        COUNT(*) FILTER (WHERE statut = 'en_attente') AS en_attente,
        COUNT(*) FILTER (WHERE statut = 'lu') AS lus,
        COUNT(*) FILTER (WHERE lu = TRUE) AS marqués_lus,
        COUNT(*) FILTER (WHERE type = 'rappel_j1') AS rappels_j1,
        COUNT(*) FILTER (WHERE type = 'relance_j2') AS relances_j2,
        COUNT(*) FILTER (WHERE type = 'alerte_admin_j5') AS alertes_j5,
        COUNT(*) FILTER (WHERE type = 'defaut_j10') AS defauts_j10,
        COUNT(*) FILTER (WHERE type = 'transfert_propriete') AS transferts,
        COUNT(*) FILTER (WHERE type = 'achat_possible') AS achats,
        COUNT(*) FILTER (WHERE canal = 'sms') AS total_sms,
        COUNT(*) FILTER (WHERE canal = 'whatsapp') AS total_whatsapp,
        COUNT(*) FILTER (WHERE canal = 'in_app') AS total_in_app
      FROM notifications_log
      WHERE date_creation >= CURRENT_DATE - INTERVAL '30 days'
    `);

    const stats = rows[0];
    res.json({
      success: true,
      data: {
        periode: '30 derniers jours',
        total: parseInt(stats.total, 10),
        par_statut: {
          envoyes: parseInt(stats.envoyes, 10),
          echecs: parseInt(stats.echecs, 10),
          en_attente: parseInt(stats.en_attente, 10),
          lus: parseInt(stats.lus, 10),
        },
        par_type: {
          rappels_j1: parseInt(stats.rappels_j1, 10),
          relances_j2: parseInt(stats.relances_j2, 10),
          alertes_j5: parseInt(stats.alertes_j5, 10),
          defauts_j10: parseInt(stats.defauts_j10, 10),
          transferts: parseInt(stats.transferts, 10),
          achats: parseInt(stats.achats, 10),
        },
        par_canal: {
          sms: parseInt(stats.total_sms, 10),
          whatsapp: parseInt(stats.total_whatsapp, 10),
          in_app: parseInt(stats.total_in_app, 10),
        },
        taux_succes: parseInt(stats.total, 10) > 0
          ? Math.round((parseInt(stats.envoyes, 10) / parseInt(stats.total, 10)) * 100)
          : 100,
      },
    });
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/notifications/:id/lu
 * Marque une notification comme lue.
 */
export async function markAsRead(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { id } = req.params;
    const user = req.user!;

    // Un chauffeur ne peut marquer que ses propres notifications
    const { rows } = await pool.query(
      `UPDATE notifications_log SET lu = TRUE, statut = 'lu' WHERE id = $1
       ${user.role === 'chauffeur' ? 'AND user_id = $2' : ''}
       RETURNING id`,
      user.role === 'chauffeur' ? [id, user.sub] : [id],
    );

    if (rows.length === 0) {
      res.status(404).json({ success: false, error: 'Notification non trouvée' });
      return;
    }

    res.json({ success: true, data: { id: rows[0].id } });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/notifications/retry
 * Force le retry des notifications en échec (admin).
 */
export async function retryFailedNotifications(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { processRetryQueue } = await import('../services/notificationService.js');
    const result = await processRetryQueue();
    res.json({ success: true, data: result });
  } catch (err) { next(err); }
}
