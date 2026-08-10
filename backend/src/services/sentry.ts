import * as Sentry from '@sentry/node';
import { nodeProfilingIntegration } from '@sentry/profiling-node';
import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';

/**
 * ═══════════════════════════════════════════════════════════════════════════
 * SENTRY — Initialisation & configuration (SDK v10)
 * ═══════════════════════════════════════════════════════════════════════════
 *
 * Capture les erreurs non gérées, exceptions, et performances.
 * Désactivé en développement par défaut (SENTRY_ENABLED=false).
 *
 * SDK v10 : intégration Express automatique, plus besoin de middleware manuel.
 * ═══════════════════════════════════════════════════════════════════════════
 */

let isInitialized = false;

/**
 * Initialise Sentry avec la configuration courante.
 * À appeler AVANT le démarrage du serveur Express.
 */
export function initSentry(): void {
  if (!config.sentry.enabled || !config.sentry.dsn) {
    logger.info('[Sentry] Désactivé (SENTRY_ENABLED=false ou DSN manquant)');
    return;
  }

  Sentry.init({
    dsn: config.sentry.dsn,
    environment: config.sentry.environment,

    // Performance tracing
    tracesSampleRate: config.sentry.tracesSampleRate,

    // Profiling CPU
    integrations: [
      nodeProfilingIntegration(),
    ],

    // Profiling sample rate
    profilesSampleRate: 0.5,

    // Filtrage : ignorer les erreurs bénignes
    ignoreErrors: [
      'ECONNRESET',
      'EPIPE',
      'ECONNREFUSED',
      'NetworkError',
      'AbortError',
      /ETIMEDOUT/,
    ],

    // Sanitize : ne pas envoyer de données sensibles
    beforeSend(event) {
      // Supprimer les headers sensibles
      if (event.request?.headers) {
        delete event.request.headers['authorization'];
        delete event.request.headers['cookie'];
      }
      return event;
    },

    // Tags globaux
    initialScope: {
      tags: {
        service: 'motoprojet-api',
        version: '1.0.0',
      },
    },
  });

  isInitialized = true;
  logger.info('[Sentry] Initialisé', {
    dsn: config.sentry.dsn.substring(0, 30) + '...',
    environment: config.sentry.environment,
    tracesSampleRate: config.sentry.tracesSampleRate,
  });
}

/**
 * Capture manuellement une exception vers Sentry.
 */
export function captureException(error: Error, context?: Record<string, unknown>): void {
  if (!isInitialized) return;
  Sentry.captureException(error, { extra: context });
}

/**
 * Envoie un message vers Sentry (sans exception).
 */
export function captureMessage(message: string, level: 'fatal' | 'error' | 'warning' | 'info' | 'debug' = 'warning', context?: Record<string, unknown>): void {
  if (!isInitialized) return;
  Sentry.captureMessage(message, { level, extra: context });
}

/**
 * Définit l'utilisateur courant pour le contexte Sentry.
 */
export function setSentryUser(userId: string, role: string): void {
  if (!isInitialized) return;
  Sentry.setUser({ id: userId, role });
}

/**
 * Crée un span de performance (remplace startTransaction en v10).
 */
export function startSpan(name: string, op: string, fn: () => any): any {
  if (!isInitialized) return fn();
  return Sentry.startSpan({ name, op }, fn);
}

/**
 * Vérifie si Sentry est actif.
 */
export function isSentryEnabled(): boolean {
  return isInitialized;
}
