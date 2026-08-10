import { Request, Response, NextFunction } from 'express';
import { ZodSchema, ZodError } from 'zod';
import { AppError } from '../utils/errors.js';

/**
 * Middleware de validation stricte des entrées via Zod.
 * Valide req.body, req.query ou req.params selon le schéma fourni.
 */
export function validate(schema: ZodSchema, source: 'body' | 'query' | 'params' = 'body') {
  return (req: Request, _res: Response, next: NextFunction): void => {
    try {
      const parsed = schema.parse(req[source]);
      req[source] = parsed; // remplace par les données validées + coercées
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        const messages = err.errors.map(e => `${e.path.join('.')}: ${e.message}`);
        return next(AppError.badRequest(`Validation échouée — ${messages.join(', ')}`));
      }
      next(err);
    }
  };
}
