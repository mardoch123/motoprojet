import { Request, Response } from 'express';
import { getFullDashboard, getApiMetrics, getDbMetrics, getJobStatuses, checkMissedJobs } from '../services/monitoringService.js';
import { isSentryEnabled } from '../services/sentry.js';
import { logger } from '../utils/logger.js';
import type { ApiResponse } from '../types/index.js';

/**
 * ═══════════════════════════════════════════════════════════════════════════
 * MONITORING CONTROLLER — Dashboard & métriques
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Endpoints :
 * - GET /monitoring           → Dashboard complet (super_admin uniquement)
 * - GET /monitoring/api       → Métriques API seules
 * - GET /monitoring/db        → Métriques DB (Neon)
 * - GET /monitoring/jobs      → État des jobs planifiés
 * - GET /monitoring/health    → Health check détaillé
 * ═══════════════════════════════════════════════════════════════════════════
 */

/**
 * GET /monitoring — Dashboard complet
 */
export async function getDashboard(_req: Request, res: Response): Promise<void> {
  try {
    const dashboard = await getFullDashboard();

    const body: ApiResponse = {
      success: true,
      data: {
        ...dashboard,
        sentry: {
          enabled: isSentryEnabled(),
        },
        memory: {
          rssMb: Math.round(process.memoryUsage().rss / 1024 / 1024),
          heapUsedMb: Math.round(process.memoryUsage().heapUsed / 1024 / 1024),
          heapTotalMb: Math.round(process.memoryUsage().heapTotal / 1024 / 1024),
        },
      },
    };
    res.json(body);
  } catch (err: any) {
    logger.error('[Monitoring] Erreur dashboard', { error: err.message });
    res.status(500).json({ success: false, error: 'Erreur récupération métriques' });
  }
}

/**
 * GET /monitoring/api — Métriques API seules
 */
export function getApiMetricsEndpoint(_req: Request, res: Response): void {
  const body: ApiResponse = {
    success: true,
    data: getApiMetrics(),
  };
  res.json(body);
}

/**
 * GET /monitoring/db — Métriques DB
 */
export async function getDbMetricsEndpoint(_req: Request, res: Response): Promise<void> {
  try {
    const dbMetrics = await getDbMetrics();
    const body: ApiResponse = {
      success: true,
      data: dbMetrics,
    };
    res.json(body);
  } catch (err: any) {
    logger.error('[Monitoring] Erreur métriques DB', { error: err.message });
    res.status(500).json({ success: false, error: 'Erreur métriques DB' });
  }
}

/**
 * GET /monitoring/jobs — État des jobs
 */
export function getJobsEndpoint(_req: Request, res: Response): void {
  const jobs = getJobStatuses();
  const missed = checkMissedJobs();

  const body: ApiResponse = {
    success: true,
    data: {
      jobs,
      missed,
    },
  };
  res.json(body);
}

/**
 * GET /monitoring/health — Health check détaillé
 */
export async function getDetailedHealth(_req: Request, res: Response): Promise<void> {
  const health: Record<string, unknown> = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: '1.0.0',
    sentry: isSentryEnabled(),
    node: process.version,
    memory: {
      rssMb: Math.round(process.memoryUsage().rss / 1024 / 1024),
    },
  };

  // Vérifier DB
  try {
    const { rows } = await (await import('../config/db.js')).default.query('SELECT 1');
    health.database = 'connected';
  } catch {
    health.database = 'disconnected';
    health.status = 'degraded';
  }

  // Vérifier jobs en retard
  const missed = checkMissedJobs();
  if (missed.missed.length > 0) {
    health.missedJobs = missed.missed;
    health.status = 'degraded';
  }

  const statusCode = health.status === 'ok' ? 200 : 503;
  res.status(statusCode).json(health);
}
