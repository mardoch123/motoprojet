import { Response, NextFunction } from 'express';
import { writeAuditLog, writeMutationAudit, type AuditContext } from '../services/audit.js';
import type { AuthRequest } from '../types/index.js';

/**
 * Middleware d'audit logging automatique.
 *
 * Capture les mutations (POST/PUT/PATCH/DELETE) et les enregistre dans le
 * journal d'audit avec les valeurs avant/après, l'IP, le user-agent et le rôle.
 *
 * Usage :
 *   router.post('/', auditAction('CREATE', 'chauffeur'), createChauffeur);
 *   router.put('/:id', auditAction('UPDATE', 'vehicule'), updateVehicule);
 *   router.delete('/:id', auditAction('DELETE', 'contrat'), deleteContrat);
 */
export function auditAction(action: 'CREATE' | 'UPDATE' | 'DELETE', resourceType: string) {
  return (req: AuthRequest, res: Response, next: NextFunction): void => {
    // Intercepter la réponse après envoi pour capturer le résultat
    const originalJson = res.json.bind(res);
    const ctx: AuditContext = {
      ip: req.ip ?? req.socket.remoteAddress,
      userAgent: req.headers['user-agent'],
      resourceType,
    };

    res.json = function (body: any) {
      // Ne logger que les réponses réussies (2xx)
      if (res.statusCode >= 200 && res.statusCode < 300) {
        const userId = req.user?.sub ?? null;
        const resourceId = body?.data?.id ?? req.params?.id ?? req.params?.chauffeurId ?? '';
        const resourceLabel = body?.data?.nom ?? body?.data?.plaque ?? body?.data?.numero ?? resourceId;

        // Pour UPDATE, on essaie de capturer avant/après depuis le body
        const avant = req.body?._audit_avant ?? null;
        const apres = body?.data ?? req.body ?? null;

        // Nettoyer les champs sensibles avant de logger
        const sanitizedAvant = sanitizeForAudit(avant);
        const sanitizedApres = sanitizeForAudit(apres);

        // Fire-and-forget : on n'attend pas l'écriture audit
        writeMutationAudit(
          userId,
          action,
          resourceType,
          String(resourceId),
          String(resourceLabel),
          sanitizedAvant,
          sanitizedApres,
          ctx,
        ).catch(() => {});
      }
      return originalJson(body);
    };

    next();
  };
}

/**
 * Middleware d'audit pour actions spécifiques (login, changement rôle, etc.)
 * Ne capture pas avant/après — juste l'action et le contexte.
 */
export function auditEvent(eventName: string, severity: 'info' | 'warning' | 'critical' = 'info') {
  return (req: AuthRequest, _res: Response, next: NextFunction): void => {
    const userId = req.user?.sub ?? null;
    const ctx: AuditContext = {
      ip: req.ip ?? req.socket.remoteAddress,
      userAgent: req.headers['user-agent'],
    };

    writeAuditLog(userId, eventName, req.path, {
      role: req.user?.role,
      telephone: req.user?.telephone,
      body_keys: Object.keys(req.body ?? {}),
    }, ctx).catch(() => {});

    next();
  };
}

/**
 * Supprime les champs sensibles des données avant écriture dans l'audit.
 */
function sanitizeForAudit(data: any): Record<string, unknown> | null {
  if (!data || typeof data !== 'object') return null;

  const sanitized = { ...data };
  const sensitiveFields = [
    'pin_hash', 'pin', 'old_pin', 'new_pin', 'temporary_pin',
    'access_token', 'refresh_token', 'access_secret',
    'piece_identite', 'numero_cni', 'piece_identite_numero',
    'password', 'secret', 'api_key', 'apiKey',
  ];

  for (const field of sensitiveFields) {
    if (field in sanitized) {
      sanitized[field] = '[CENSURÉ]';
    }
  }

  return sanitized;
}
