import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import swaggerUi from 'swagger-ui-express';
import { config } from './config/env.js';
import { testConnection } from './config/db.js';
import pool from './config/db.js';
import { errorHandler } from './middleware/errorHandler.js';
import { globalRateLimiter } from './middleware/security.js';
import v1Routes from './routes/v1/index.js';
import { swaggerDocument } from './docs/swagger.js';
import { logger } from './utils/logger.js';
import { startScheduler, stopScheduler } from './jobs/scheduler.js';
import { initSentry, captureException } from './services/sentry.js';
import { monitoringMiddleware } from './services/monitoringService.js';

const app = express();

// ─── Sentry (initialisation avant démarrage) ────────────────────────────────
initSentry();

// ─── Middlewares globaux ─────────────────────────────────────────────────────
app.use(helmet());
// CORS restrictif : uniquement le domaine Flutter + API
app.use(cors({
  origin: config.nodeEnv === 'production'
    ? ['https://motoprojet.bj', 'https://www.motoprojet.bj']
    : true, // En dev, accepter tout
  credentials: true,
}));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true }));

// Rate limiting global (120 req/min/IP)
app.use(globalRateLimiter);

// Monitoring middleware (métriques API)
app.use(monitoringMiddleware());

// Trust proxy (pour récupérer la vraie IP derrière nginx/reverse proxy)
app.set('trust proxy', 1);

// Morgan → format JSON structuré
app.use(morgan(':method :url :status :response-time ms', {
  stream: { write: (msg: string) => logger.info('HTTP', { request: msg.trim() }) },
}));

// ─── Swagger UI ──────────────────────────────────────────────────────────────
app.use('/api-docs', swaggerUi.serve, swaggerUi.setup(swaggerDocument, {
  customCss: '.swagger-ui .topbar { display: none }',
  customSiteTitle: 'MotoProjet API — Documentation',
}));

// ─── Routes versionnées ──────────────────────────────────────────────────────
app.use('/api/v1', v1Routes);

// ─── Health check ────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString(), version: '1.0.0' });
});

// Health check avec vérification DB
app.get('/health/db', async (_req, res) => {
  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();
    res.json({
      status: 'ok',
      database: 'connected',
      timestamp: new Date().toISOString(),
    });
  } catch (err: any) {
    res.status(503).json({
      status: 'error',
      database: 'disconnected',
      error: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// ─── 404 ─────────────────────────────────────────────────────────────────────
app.use((_req, res) => {
  res.status(404).json({ success: false, error: 'Route non trouvée' });
});

// ─── Gestion centralisée des erreurs ─────────────────────────────────────────
app.use(errorHandler);

// ─── Gestionnaires d'erreurs non capturées ────────────────────────────────────
process.on('uncaughtException', (err) => {
  logger.error('Uncaught exception', { message: err.message, stack: err.stack });
  captureException(err, { source: 'uncaughtException' });
  setTimeout(() => process.exit(1), 1000);
});

process.on('unhandledRejection', (reason: any) => {
  logger.error('Unhandled rejection', { message: reason?.message ?? String(reason) });
  captureException(reason instanceof Error ? reason : new Error(String(reason)), { source: 'unhandledRejection' });
});

// ─── Démarrage ───────────────────────────────────────────────────────────────
async function start() {
  await testConnection();

  app.listen(config.port, () => {
    logger.info(`Serveur démarré sur le port ${config.port}`, {
      env: config.nodeEnv,
      port: config.port,
      swagger: `http://localhost:${config.port}/api-docs`,
    });
    console.log(`\n📖 Swagger : http://localhost:${config.port}/api-docs`);
    console.log(`🏥 Health  : http://localhost:${config.port}/health\n`);

    // Démarrer le scheduler de jobs nocturnes
    startScheduler();
  });

  // Arrêt propre du scheduler
  process.on('SIGTERM', () => {
    logger.info('[Server] SIGTERM reçu — arrêt du scheduler');
    stopScheduler();
    process.exit(0);
  });
}

start();

export default app;
