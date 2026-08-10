import { Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config/env.js';
import { AppError } from '../utils/errors.js';
import pool from '../config/db.js';
import type { AuthRequest, JwtPayload, Role } from '../types/index.js';

/**
 * Middleware d'authentification JWT — access token
 * Extrait le payload et l'attache à req.user
 */
export function authenticate(req: AuthRequest, _res: Response, next: NextFunction): void {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    return next(AppError.unauthorized('Token d\'authentification requis'));
  }

  const token = header.split(' ')[1];
  try {
    const payload = jwt.verify(token, config.jwt.accessSecret) as JwtPayload;
    req.user = payload;
    next();
  } catch {
    next(AppError.unauthorized('Token invalide ou expiré'));
  }
}

/**
 * Middleware de contrôle d'accès par rôle
 * Vérifie le rôle côté serveur depuis le JWT — jamais depuis le body mobile
 */
export function authorize(...roles: Role[]) {
  return (req: AuthRequest, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      return next(AppError.unauthorized());
    }
    if (!roles.includes(req.user.role as Role)) {
      return next(AppError.forbidden(`Rôle requis : ${roles.join(' ou ')}`));
    }
    next();
  };
}

/**
 * Middleware qui bloque l'accès si l'utilisateur doit changer son PIN.
 * Appliqué sur toutes les routes sauf /auth/change-pin et /auth/logout.
 */
export function requirePinChange(req: AuthRequest, _res: Response, next: NextFunction): void {
  // On vérifie en base si must_change_pin est true
  // Pour éviter un query à chaque requête, on pourrait mettre ce flag dans le JWT
  // mais ici on privilégie la sécurité (le flag est vérifié côté serveur)
  pool.query(`SELECT must_change_pin FROM users WHERE id = $1`, [req.user?.sub])
    .then(({ rows }) => {
      if (rows.length === 0) return next(AppError.unauthorized());
      if (rows[0].must_change_pin) {
        return next(new AppError(403, 'Vous devez changer votre PIN avant de continuer', 'MUST_CHANGE_PIN'));
      }
      next();
    })
    .catch(() => next(AppError.internal()));
}

/**
 * Middleware qui met à jour la dernière activité à chaque requête authentifiée.
 */
export function updateLastActivity(req: AuthRequest, _res: Response, next: NextFunction): void {
  if (req.user?.sub) {
    // Fire-and-forget : on n'attend pas la réponse
    pool.query(`UPDATE users SET derniere_activite = NOW() WHERE id = $1`, [req.user.sub]).catch(() => {});
  }
  next();
}

/**
 * Génère un access token + refresh token
 */
export function generateTokens(userId: string, role: string, telephone: string) {
  const accessToken = jwt.sign(
    { sub: userId, role, telephone },
    config.jwt.accessSecret,
    { expiresIn: config.jwt.accessExpiresIn } as jwt.SignOptions,
  );
  const refreshToken = jwt.sign(
    { sub: userId, role, telephone },
    config.jwt.refreshSecret,
    { expiresIn: config.jwt.refreshExpiresIn } as jwt.SignOptions,
  );
  return { accessToken, refreshToken };
}

/**
 * Vérifie et rafraîchit l'access token à partir du refresh token
 */
export function refreshAccessToken(refreshToken: string): string {
  try {
    const payload = jwt.verify(refreshToken, config.jwt.refreshSecret) as JwtPayload;
    return jwt.sign(
      { sub: payload.sub, role: payload.role, telephone: payload.telephone },
      config.jwt.accessSecret,
      { expiresIn: config.jwt.accessExpiresIn } as jwt.SignOptions,
    );
  } catch {
    throw AppError.unauthorized('Refresh token invalide ou expiré');
  }
}
