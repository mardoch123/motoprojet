import rateLimit from 'express-rate-limit';
import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import { writeSecurityEvent } from '../services/audit.js';
import { AppError } from '../utils/errors.js';
import { logger } from '../utils/logger.js';
import type { AuthRequest } from '../types/index.js';

// ─── Rate Limiting global ────────────────────────────────────────────────────

/**
 * Rate limiter global : 120 requêtes/minute/IP.
 * Protège contre les abus généraux.
 */
export const globalRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 120,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Trop de requêtes, veuillez réessayer dans une minute' },
  keyGenerator: (req) => req.ip ?? 'unknown',
});

/**
 * Rate limiter pour les endpoints sensibles (écriture) : 30 req/min/IP.
 */
export const sensitiveRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 30,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Trop de requêtes sensibles, veuillez ralentir' },
  keyGenerator: (req) => req.ip ?? 'unknown',
});

/**
 * Rate limiter strict pour l'authentification : 5 tentatives/minute/IP.
 */
export const authRateLimiter = rateLimit({
  windowMs: 60 * 1000,
  max: 5,
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, error: 'Trop de tentatives de connexion, réessayez dans 1 minute' },
  keyGenerator: (req) => req.ip ?? 'unknown',
  handler: async (req, _res, next) => {
    // Logger l'événement de sécurité
    await writeSecurityEvent(
      null,
      'rate_limit_exceeded',
      'warning',
      { path: req.path, ip: req.ip },
      { ip: req.ip, userAgent: req.headers['user-agent'] },
    ).catch(() => {});
    next(AppError.tooMany());
  },
});

// ─── Verrouillage de compte ──────────────────────────────────────────────────

const MAX_LOGIN_ATTEMPTS = 5;
const LOCKOUT_DURATION_MINUTES = 15;

/**
 * Vérifie si le compte est verrouillé avant de permettre la connexion.
 * À placer AVANT la logique de login.
 */
export async function checkAccountLock(
  req: AuthRequest,
  _res: Response,
  next: NextFunction,
): Promise<void> {
  const { telephone } = req.body;
  if (!telephone) return next();

  try {
    const { rows } = await pool.query(
      `SELECT id, locked_until, login_attempts FROM users WHERE telephone = $1`,
      [telephone],
    );

    if (rows.length === 0) return next(); // L'utilisateur n'existe pas, laisser le login gérer

    const user = rows[0];

    // Vérifier si le compte est verrouillé
    if (user.locked_until && new Date(user.locked_until) > new Date()) {
      const remainingMs = new Date(user.locked_until).getTime() - Date.now();
      const remainingMin = Math.ceil(remainingMs / 60000);

      await writeSecurityEvent(
        user.id,
        'login_failure',
        'warning',
        { reason: 'account_locked', telephone, remaining_minutes: remainingMin },
        { ip: req.ip, userAgent: req.headers['user-agent'] },
      ).catch(() => {});

      return next(
        AppError.forbidden(
          `Compte temporairement verrouillé. Réessayez dans ${remainingMin} minute(s).`,
        ),
      );
    }

    next();
  } catch (err: any) {
    logger.error('Erreur vérification verrouillage', { error: err.message });
    next(); // En cas d'erreur DB, on laisse passer (le login gérera)
  }
}

/**
 * Enregistre un échec de connexion et verrouille le compte si nécessaire.
 * À appeler après un échec de PIN.
 */
export async function recordLoginFailure(telephone: string, userId: string, ip?: string): Promise<void> {
  try {
    const { rows } = await pool.query(
      `UPDATE users
       SET login_attempts = login_attempts + 1,
           last_login_attempt = NOW(),
           locked_until = CASE
             WHEN login_attempts + 1 >= $1 THEN NOW() + INTERVAL '$2 minutes'
             ELSE locked_until
           END
       WHERE id = $3
       RETURNING login_attempts, locked_until`,
      [MAX_LOGIN_ATTEMPTS, LOCKOUT_DURATION_MINUTES, userId],
    );

    const updated = rows[0];

    // Logger l'échec
    await writeSecurityEvent(
      userId,
      'login_failure',
      updated?.locked_until && new Date(updated.locked_until) > new Date() ? 'critical' : 'warning',
      {
        telephone,
        attempts: updated?.login_attempts,
        locked: updated?.locked_until ? new Date(updated.locked_until) > new Date() : false,
      },
      { ip },
    ).catch(() => {});

    // Si le compte vient d'être verrouillé, logger
    if (updated?.login_attempts >= MAX_LOGIN_ATTEMPTS) {
      logger.warn('Compte verrouillé', { userId, telephone, attempts: updated.login_attempts });
      await writeSecurityEvent(
        userId,
        'account_locked',
        'critical',
        { telephone, attempts: updated.login_attempts },
        { ip },
      ).catch(() => {});
    }
  } catch (err: any) {
    logger.error('Erreur enregistrement échec login', { error: err.message });
  }
}

/**
 * Réinitialise les compteurs d'échecs après une connexion réussie.
 */
export async function resetLoginAttempts(userId: string): Promise<void> {
  try {
    await pool.query(
      `UPDATE users SET login_attempts = 0, locked_until = NULL WHERE id = $1`,
      [userId],
    );
  } catch (err: any) {
    logger.error('Erreur reset login attempts', { error: err.message });
  }
}

/**
 * Middleware : vérifie que le compte de l'utilisateur authentifié n'est pas verrouillé.
 */
export function requireActiveAccount(req: AuthRequest, _res: Response, next: NextFunction): void {
  if (!req.user?.sub) return next(AppError.unauthorized());

  pool.query(
    `SELECT locked_until, statut FROM users WHERE id = $1`,
    [req.user.sub],
  )
    .then(({ rows }) => {
      if (rows.length === 0) return next(AppError.unauthorized());
      const user = rows[0];

      if (user.statut !== 'actif') {
        return next(AppError.forbidden('Compte désactivé'));
      }

      if (user.locked_until && new Date(user.locked_until) > new Date()) {
        const remainingMin = Math.ceil(
          (new Date(user.locked_until).getTime() - Date.now()) / 60000,
        );
        return next(
          AppError.forbidden(`Compte verrouillé. Réessayez dans ${remainingMin} minute(s).`),
        );
      }

      next();
    })
    .catch(() => next(AppError.internal()));
}
