import pool from '../config/db.js';
import { logger } from '../utils/logger.js';

/**
 * Service d'audit — écrit dans journal_audit et dans les logs structurés.
 * Append-only : les enregistrements ne peuvent ni être modifiés ni supprimés
 * (trigger PostgreSQL prevent_audit_modification).
 */
export interface AuditContext {
  ip?: string;
  userAgent?: string;
  resourceType?: string;
  resourceId?: string;
}

export async function writeAuditLog(
  userId: string | null,
  action: string,
  cible: string,
  details?: Record<string, unknown>,
  ctx?: AuditContext,
): Promise<void> {
  try {
    await pool.query(
      `INSERT INTO journal_audit
        (user_id, action, cible, details, valeur_avant, valeur_apres, ip_address, user_agent, resource_type, resource_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
      [
        userId,
        action,
        cible,
        JSON.stringify(details ?? {}),
        details?.valeur_avant ? JSON.stringify(details.valeur_avant) : null,
        details?.valeur_apres ? JSON.stringify(details.valeur_apres) : null,
        ctx?.ip ?? null,
        ctx?.userAgent ?? null,
        ctx?.resourceType ?? null,
        ctx?.resourceId ?? null,
      ],
    );
  } catch (err: any) {
    logger.error('Erreur écriture audit', { error: err.message, action, cible });
  }
  // Log structuré en parallèle
  logger.audit(userId ?? 'system', action, cible, details);
}

/**
 * Enregistre une action de modification avec avant/après.
 * Helper spécialisé pour les actions CREATE / UPDATE / DELETE.
 */
export async function writeMutationAudit(
  userId: string | null,
  action: 'CREATE' | 'UPDATE' | 'DELETE',
  resourceType: string,
  resourceId: string,
  resourceLabel: string,
  avant?: Record<string, unknown> | null,
  apres?: Record<string, unknown> | null,
  ctx?: AuditContext,
): Promise<void> {
  const actionName = `${action}_${resourceType.toUpperCase()}`;
  await writeAuditLog(
    userId,
    actionName,
    resourceLabel,
    { valeur_avant: avant ?? null, valeur_apres: apres ?? null },
    { ...ctx, resourceType, resourceId },
  );
}

/**
 * Enregistre un événement de sécurité dans security_events.
 */
export async function writeSecurityEvent(
  userId: string | null,
  type: string,
  severity: 'info' | 'warning' | 'critical',
  details?: Record<string, unknown>,
  ctx?: AuditContext,
): Promise<void> {
  try {
    await pool.query(
      `INSERT INTO security_events (user_id, type, ip_address, user_agent, details, severity)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [
        userId,
        type,
        ctx?.ip ?? null,
        ctx?.userAgent ?? null,
        JSON.stringify(details ?? {}),
        severity,
      ],
    );
  } catch (err: any) {
    logger.error('Erreur écriture security_event', { error: err.message, type });
  }
}
