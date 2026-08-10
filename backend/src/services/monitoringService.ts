import pool from '../config/db.js';
import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';
import { captureMessage, captureException } from './sentry.js';

/**
 * ═══════════════════════════════════════════════════════════════════════════
 * MONITORING SERVICE — Métriques techniques & alertes
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Collecte en mémoire (fenêtre glissante 5 min) :
 * - Temps de réponse API (moyenne, p95, p99)
 * - Taux d'erreur HTTP (5xx / total)
 * - Connexions DB actives
 * - Requêtes DB lentes
 * - État des jobs planifiés
 *
 * Alertes automatiques via webhook (Slack/Discord) ou email.
 * ═══════════════════════════════════════════════════════════════════════════
 */

// ─── Types ───────────────────────────────────────────────────────────────────
interface MetricEntry {
  timestamp: number;
  method: string;
  path: string;
  statusCode: number;
  responseTimeMs: number;
}

interface JobStatus {
  name: string;
  lastRun: Date | null;
  lastSuccess: boolean;
  lastDuration: number | null;
  lastError: string | null;
  nextExpectedRun: Date | null;
}

interface AlertPayload {
  severity: 'critical' | 'warning' | 'info';
  title: string;
  message: string;
  metrics?: Record<string, unknown>;
  timestamp: string;
}

// ─── State en mémoire (fenêtre glissante) ────────────────────────────────────
const METRIC_WINDOW_MS = 5 * 60 * 1000; // 5 minutes
const metrics: MetricEntry[] = [];
const jobStatuses = new Map<string, JobStatus>();
let lastAlertTime = 0;
const ALERT_COOLDOWN_MS = 5 * 60 * 1000; // 5 min entre alertes

// ─── Collecte de métriques API ───────────────────────────────────────────────

/**
 * Enregistre une requête HTTP dans les métriques.
 * Appelé par le middleware de monitoring.
 */
export function recordRequest(method: string, path: string, statusCode: number, responseTimeMs: number): void {
  const now = Date.now();
  metrics.push({ timestamp: now, method, path, statusCode, responseTimeMs });

  // Nettoyer les entrées expirées
  const cutoff = now - METRIC_WINDOW_MS;
  while (metrics.length > 0 && metrics[0].timestamp < cutoff) {
    metrics.shift();
  }

  // Vérifier les seuils d'alerte
  checkAlerts();
}

/**
 * Calcule les métriques agrégées sur la fenêtre courante.
 */
export function getApiMetrics(): {
  totalRequests: number;
  avgResponseTimeMs: number;
  p95ResponseTimeMs: number;
  p99ResponseTimeMs: number;
  errorRate: number;
  requestsByStatus: Record<string, number>;
  slowestEndpoints: { path: string; avgMs: number; count: number }[];
} {
  const now = Date.now();
  const cutoff = now - METRIC_WINDOW_MS;
  const recent = metrics.filter(m => m.timestamp >= cutoff);

  if (recent.length === 0) {
    return {
      totalRequests: 0,
      avgResponseTimeMs: 0,
      p95ResponseTimeMs: 0,
      p99ResponseTimeMs: 0,
      errorRate: 0,
      requestsByStatus: {},
      slowestEndpoints: [],
    };
  }

  // Trier par temps de réponse
  const sorted = [...recent].sort((a, b) => a.responseTimeMs - b.responseTimeMs);

  // Percentiles
  const p95Index = Math.floor(sorted.length * 0.95);
  const p99Index = Math.floor(sorted.length * 0.99);

  // Agrégation par status
  const byStatus: Record<string, number> = {};
  for (const m of recent) {
    const key = `${Math.floor(m.statusCode / 100)}xx`;
    byStatus[key] = (byStatus[key] ?? 0) + 1;
  }

  // Erreurs 5xx
  const errors5xx = recent.filter(m => m.statusCode >= 500).length;
  const errorRate = (errors5xx / recent.length) * 100;

  // Moyenne
  const avgMs = recent.reduce((sum, m) => sum + m.responseTimeMs, 0) / recent.length;

  // Endpoints les plus lents
  const byPath = new Map<string, { total: number; count: number }>();
  for (const m of recent) {
    const entry = byPath.get(m.path) ?? { total: 0, count: 0 };
    entry.total += m.responseTimeMs;
    entry.count += 1;
    byPath.set(m.path, entry);
  }
  const slowest = [...byPath.entries()]
    .map(([path, { total, count }]) => ({ path, avgMs: total / count, count }))
    .sort((a, b) => b.avgMs - a.avgMs)
    .slice(0, 5);

  return {
    totalRequests: recent.length,
    avgResponseTimeMs: Math.round(avgMs),
    p95ResponseTimeMs: sorted[p95Index]?.responseTimeMs ?? 0,
    p99ResponseTimeMs: sorted[p99Index]?.responseTimeMs ?? 0,
    errorRate: Math.round(errorRate * 100) / 100,
    requestsByStatus: byStatus,
    slowestEndpoints: slowest,
  };
}

// ─── Métriques DB (Neon) ────────────────────────────────────────────────────

/**
 * Récupère les métriques de la base Neon.
 */
export async function getDbMetrics(): Promise<{
  activeConnections: number;
  slowQueries: { query: string; durationMs: number }[];
  tableSizes: { table: string; sizeMb: number; rowCount: number }[];
  cacheHitRatio: number;
}> {
  try {
    // Connexions actives
    const { rows: connRows } = await pool.query(
      `SELECT count(*)::int AS active FROM pg_stat_activity WHERE state = 'active'`
    );
    const activeConnections = connRows[0]?.active ?? 0;

    // Requêtes lentes (> seuil configuré)
    const { rows: slowRows } = await pool.query(
      `SELECT query, EXTRACT(EPOCH FROM (now() - query_start)) * 1000 AS duration_ms
       FROM pg_stat_activity
       WHERE state = 'active'
         AND query NOT ILIKE '%pg_stat_activity%'
         AND EXTRACT(EPOCH FROM (now() - query_start)) * 1000 > $1
       ORDER BY duration_ms DESC
       LIMIT 5`,
      [config.monitoring.slowQueryThresholdMs]
    );
    const slowQueries = slowRows.map(r => ({
      query: r.query?.substring(0, 200) ?? '',
      durationMs: Math.round(r.duration_ms),
    }));

    // Taille des tables principales
    const { rows: sizeRows } = await pool.query(`
      SELECT
        relname AS table_name,
        pg_total_relation_size(oid) AS total_size,
        n_live_tup AS row_count
      FROM pg_class
      JOIN pg_stat_user_tables ON relname = relname
      WHERE relkind = 'r'
        AND relname IN ('paiements', 'chauffeurs', 'vehicules', 'contrats', 'users', 'incidents')
      ORDER BY pg_total_relation_size(oid) DESC
    `);
    const tableSizes = sizeRows.map(r => ({
      table: r.table_name,
      sizeMb: Math.round(r.total_size / 1024 / 1024 * 100) / 100,
      rowCount: r.row_count ?? 0,
    }));

    // Cache hit ratio (performance Neon)
    const { rows: cacheRows } = await pool.query(`
      SELECT
        round(sum(blks_hit) * 100.0 / nullif(sum(blks_hit) + sum(blks_read), 0), 2) AS ratio
      FROM pg_stat_database
    `);
    const cacheHitRatio = parseFloat(cacheRows[0]?.ratio ?? '0');

    return { activeConnections, slowQueries, tableSizes, cacheHitRatio };
  } catch (err: any) {
    logger.error('[Monitoring] Erreur métriques DB', { error: err.message });
    return { activeConnections: -1, slowQueries: [], tableSizes: [], cacheHitRatio: -1 };
  }
}

// ─── Monitoring des jobs ─────────────────────────────────────────────────────

/**
 * Enregistre le résultat d'un job planifié.
 */
export function recordJobResult(
  jobName: string,
  success: boolean,
  durationMs: number,
  error?: string
): void {
  const status: JobStatus = {
    name: jobName,
    lastRun: new Date(),
    lastSuccess: success,
    lastDuration: durationMs,
    lastError: error ?? null,
    nextExpectedRun: null, // Sera calculé selon le job
  };
  jobStatuses.set(jobName, status);

  if (!success) {
    // Alerte immédiate pour job en échec
    sendAlert({
      severity: 'critical',
      title: `Job échoué : ${jobName}`,
      message: error ?? 'Erreur inconnue',
      metrics: { jobName, durationMs },
      timestamp: new Date().toISOString(),
    });
    captureMessage(`[JOB FAILED] ${jobName}: ${error}`, 'error', { jobName, durationMs });
  }
}

/**
 * Définit la prochaine exécution attendue d'un job.
 */
export function setJobNextRun(jobName: string, nextRun: Date): void {
  const status = jobStatuses.get(jobName);
  if (status) {
    status.nextExpectedRun = nextRun;
  }
}

/**
 * Retourne le statut de tous les jobs.
 */
export function getJobStatuses(): JobStatus[] {
  return [...jobStatuses.values()];
}

/**
 * Vérifie si des jobs n'ont pas exécuté dans leur fenêtre prévue.
 */
export function checkMissedJobs(): { missed: string[]; overdue: string[] } {
  const now = new Date();
  const missed: string[] = [];
  const overdue: string[] = [];

  for (const [name, status] of jobStatuses) {
    if (!status.lastRun) continue;

    if (status.nextExpectedRun) {
      const delay = now.getTime() - status.nextExpectedRun.getTime();
      if (delay > 2 * 60 * 60 * 1000) {
        // Plus de 2h de retard
        missed.push(name);
      } else if (delay > 30 * 60 * 1000) {
        // Plus de 30 min de retard
        overdue.push(name);
      }
    }
  }

  return { missed, overdue };
}

// ─── Alertes ─────────────────────────────────────────────────────────────────

/**
 * Vérifie les seuils et déclenche des alertes si nécessaire.
 */
function checkAlerts(): void {
  const now = Date.now();
  if (now - lastAlertTime < ALERT_COOLDOWN_MS) return;

  const apiMetrics = getApiMetrics();

  // Alerte : taux d'erreur élevé
  if (apiMetrics.errorRate > config.monitoring.errorRateThreshold && apiMetrics.totalRequests > 10) {
    sendAlert({
      severity: 'critical',
      title: 'Taux d\'erreur élevé',
      message: `Le taux d'erreur HTTP 5xx est de ${apiMetrics.errorRate}% (seuil: ${config.monitoring.errorRateThreshold}%)`,
      metrics: { errorRate: apiMetrics.errorRate, totalRequests: apiMetrics.totalRequests },
      timestamp: new Date().toISOString(),
    });
    captureMessage(`[ALERT] High error rate: ${apiMetrics.errorRate}%`, 'error');
    lastAlertTime = now;
  }

  // Alerte : latence anormale
  if (apiMetrics.p95ResponseTimeMs > config.monitoring.latencyThresholdMs && apiMetrics.totalRequests > 10) {
    sendAlert({
      severity: 'warning',
      title: 'Latence élevée',
      message: `Le P95 est de ${apiMetrics.p95ResponseTimeMs}ms (seuil: ${config.monitoring.latencyThresholdMs}ms)`,
      metrics: { p95: apiMetrics.p95ResponseTimeMs, avg: apiMetrics.avgResponseTimeMs },
      timestamp: new Date().toISOString(),
    });
    captureMessage(`[ALERT] High latency P95: ${apiMetrics.p95ResponseTimeMs}ms`, 'warning');
    lastAlertTime = now;
  }
}

/**
 * Envoie une alerte via webhook (Slack/Discord) et/ou log.
 */
async function sendAlert(alert: AlertPayload): Promise<void> {
  // Log local
  logger.error(`[ALERT ${alert.severity.toUpperCase()}] ${alert.title}: ${alert.message}`, {
    metrics: alert.metrics,
  });

  // Webhook Slack/Discord
  if (config.monitoring.alertWebhookUrl) {
    try {
      const slackPayload = {
        text: `🚨 *MotoProjet — ${alert.severity.toUpperCase()}*\n*${alert.title}*\n${alert.message}`,
        attachments: alert.metrics ? [{
          color: alert.severity === 'critical' ? '#C62828' : '#FF8F00',
          fields: Object.entries(alert.metrics).map(([k, v]) => ({
            title: k,
            value: String(v),
            short: true,
          })),
        }] : [],
      };

      await fetch(config.monitoring.alertWebhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(slackPayload),
      });
    } catch (err: any) {
      logger.error('[Monitoring] Erreur envoi webhook alerte', { error: err.message });
    }
  }

  // Sentry
  if (alert.severity === 'critical') {
    captureMessage(`[CRITICAL ALERT] ${alert.title}: ${alert.message}`, 'fatal', alert.metrics);
  }
}

// ─── Dashboard complet ───────────────────────────────────────────────────────

/**
 * Retourne toutes les métriques pour le dashboard de monitoring.
 */
export async function getFullDashboard(): Promise<{
  api: ReturnType<typeof getApiMetrics>;
  db: Awaited<ReturnType<typeof getDbMetrics>>;
  jobs: JobStatus[];
  missedJobs: { missed: string[]; overdue: string[] };
  uptime: number;
  timestamp: string;
}> {
  const [dbMetrics] = await Promise.all([getDbMetrics()]);

  return {
    api: getApiMetrics(),
    db: dbMetrics,
    jobs: getJobStatuses(),
    missedJobs: checkMissedJobs(),
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  };
}

// ─── Middleware Express ───────────────────────────────────────────────────────

/**
 * Middleware Express pour enregistrer les métriques de chaque requête.
 */
export function monitoringMiddleware() {
  return (req: any, res: any, next: any) => {
    const start = Date.now();

    res.on('finish', () => {
      const duration = Date.now() - start;
      recordRequest(req.method, req.path, res.statusCode, duration);
    });

    next();
  };
}
