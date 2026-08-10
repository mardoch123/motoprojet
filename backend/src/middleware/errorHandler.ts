import { Request, Response, NextFunction } from 'express';
import { AppError } from '../utils/errors.js';
import { logger } from '../utils/logger.js';
import { captureException } from '../services/sentry.js';
import type { ApiResponse } from '../types/index.js';

/**
 * Middleware central de gestion des erreurs.
 * Convertit toute erreur en réponse JSON standardisée.
 */
export function errorHandler(err: Error, req: Request, res: Response, _next: NextFunction): void {
  // Erreur applicative connue
  if (err instanceof AppError) {
    logger.warn(`HTTP ${err.statusCode}`, {
      code: err.code,
      message: err.message,
      path: req.path,
      method: req.method,
    });

    const body: ApiResponse = {
      success: false,
      error: err.message,
    };
    res.status(err.statusCode).json(body);
    return;
  }

  // Erreur inattendue
  logger.error('Erreur non gérée', {
    message: err.message,
    stack: err.stack,
    path: req.path,
    method: req.method,
  });

  // Envoyer à Sentry
  captureException(err, { path: req.path, method: req.method });

  const body: ApiResponse = {
    success: false,
    error: 'Erreur interne du serveur',
  };
  res.status(500).json(body);
}
