import pool from '../config/db.js';
import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';

/**
 * Service d'envoi de notifications — SMS + WhatsApp Business.
 *
 * Architecture :
 * 1. notificationService.send() → tente l'envoi réel (SMS/WhatsApp)
 * 2. Si échec → écrit dans notifications_log avec statut 'echec'
 * 3. File de retry : processRetryQueue() relance les échecs (max 3 tentatives)
 * 4. Mode 'log' (développement) : écrit uniquement en base sans appel externe
 *
 * Les clés API ne sont JAMAIS exposées côté Flutter — tout passe par ce service.
 */

export type NotificationType =
  | 'rappel_j1'           // J+1 sans paiement — rappel poli
  | 'relance_j2'          // 2 jours cumulés — relance ferme
  | 'alerte_admin_j5'     // 5 jours — notification admin
  | 'defaut_j10'          // 10 jours — défaut + décision admin
  | 'transfert_propriete' // Fin de remboursement atteinte
  | 'achat_possible';     // Caisse cumulée ≥ prix véhicule

export type NotificationChannel = 'sms' | 'whatsapp' | 'in_app';

export interface SendNotificationParams {
  type: NotificationType;
  channel: NotificationChannel;
  destinataireId?: string;      // user_id ou chauffeur_id
  destinataireTelephone?: string; // numéro au format international
  titre: string;
  message: string;
  metadata?: Record<string, unknown>; // données contextuelles (montant, plaque, etc.)
}

const MAX_RETRIES = 3;

/**
 * Envoie une notification et journalise dans notifications_log.
 */
export async function sendNotification(params: SendNotificationParams): Promise<string | null> {
  // 1. Écrire dans notifications_log (statut initial: 'en_attente')
  const { rows } = await pool.query(
    `INSERT INTO notifications_log (user_id, titre, message, type, canal, destinataire_telephone, metadata, statut, tentatives)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'en_attente', 0)
     RETURNING id`,
    [
      params.destinataireId ?? null,
      params.titre,
      params.message,
      params.type,
      params.channel,
      params.destinataireTelephone ?? null,
      JSON.stringify(params.metadata ?? {}),
    ],
  );
  const notifId = rows[0].id as string;

  // 2. Tenter l'envoi réel
  try {
    await dispatchNotification(params);
    await pool.query(
      `UPDATE notifications_log SET statut = 'envoye', date_envoi = NOW() WHERE id = $1`,
      [notifId],
    );
    logger.info(`[Notification] Envoyée: ${params.type} → ${params.destinataireTelephone ?? 'in-app'}`);
    return notifId;
  } catch (err: any) {
    logger.error(`[Notification] Échec envoi: ${params.type} — ${err.message}`);
    await pool.query(
      `UPDATE notifications_log SET statut = 'echec', erreur = $1, tentatives = tentatives + 1 WHERE id = $2`,
      [err.message, notifId],
    );
    return notifId;
  }
}

/**
 * Dispatch vers le canal approprié.
 */
async function dispatchNotification(params: SendNotificationParams): Promise<void> {
  if (params.channel === 'in_app') {
    // Notification in-app : juste le log en base, pas d'envoi externe
    return;
  }

  if (params.channel === 'whatsapp' && config.whatsapp.enabled) {
    await sendWhatsApp(params);
    return;
  }

  if (params.channel === 'sms') {
    await sendSMS(params);
    return;
  }

  // Fallback : mode log (développement ou canal non configuré)
  logger.info(`[Notification][LOG] ${params.channel} → ${params.destinataireTelephone}: ${params.message}`);
}

/**
 * Envoi SMS via Twilio (ou fallback log).
 */
async function sendSMS(params: SendNotificationParams): Promise<void> {
  if (config.sms.provider !== 'twilio' || !config.sms.twilioAccountSid) {
    // Mode log — pas de vrai envoi
    logger.info(`[SMS][LOG] → ${params.destinataireTelephone}: ${params.message.substring(0, 80)}...`);
    return;
  }

  const url = `https://api.twilio.com/2010-04-01/Accounts/${config.sms.twilioAccountSid}/Messages.json`;
  const auth = Buffer.from(`${config.sms.twilioAccountSid}:${config.sms.twilioAuthToken}`).toString('base64');

  const body = new URLSearchParams({
    From: config.sms.twilioPhoneNumber,
    To: params.destinataireTelephone ?? '',
    Body: params.message,
  });

  const response = await fetch(url, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: body.toString(),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`Twilio SMS échoué (HTTP ${response.status}): ${errorBody.substring(0, 200)}`);
  }
}

/**
 * Envoi WhatsApp via l'API WhatsApp Business Cloud.
 */
async function sendWhatsApp(params: SendNotificationParams): Promise<void> {
  if (!config.whatsapp.baseUrl || !config.whatsapp.token) {
    logger.info(`[WhatsApp][LOG] → ${params.destinataireTelephone}: ${params.message.substring(0, 80)}...`);
    return;
  }

  const response = await fetch(`${config.whatsapp.baseUrl}/messages`, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${config.whatsapp.token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      messaging_product: 'whatsapp',
      to: params.destinataireTelephone?.replace('+', ''),
      type: 'text',
      text: { body: params.message },
    }),
  });

  if (!response.ok) {
    const errorBody = await response.text();
    throw new Error(`WhatsApp échoué (HTTP ${response.status}): ${errorBody.substring(0, 200)}`);
  }
}

/**
 * Traite la file de retry pour les notifications en échec.
 * Appelé périodiquement par le scheduler.
 */
export async function processRetryQueue(): Promise<{ retried: number; success: number; failed: number }> {
  const { rows } = await pool.query(`
    SELECT id, type, canal, destinataire_telephone, titre, message, metadata, tentatives
    FROM notifications_log
    WHERE statut = 'echec' AND tentatives < $1
    ORDER BY date_creation ASC
    LIMIT 50
  `, [MAX_RETRIES]);

  let success = 0;
  let failed = 0;

  for (const notif of rows) {
    try {
      const metadata = typeof notif.metadata === 'string' ? JSON.parse(notif.metadata) : notif.metadata;
      await dispatchNotification({
        type: notif.type,
        channel: notif.canal,
        destinataireTelephone: notif.destinataire_telephone,
        titre: notif.titre,
        message: notif.message,
        metadata,
      });

      await pool.query(
        `UPDATE notifications_log SET statut = 'envoye', date_envoi = NOW(), tentatives = tentatives + 1 WHERE id = $1`,
        [notif.id],
      );
      success++;
    } catch (err: any) {
      await pool.query(
        `UPDATE notifications_log SET tentatives = tentatives + 1, erreur = $1 WHERE id = $2`,
        [err.message, notif.id],
      );
      failed++;
    }
  }

  if (rows.length > 0) {
    logger.info(`[RetryQueue] ${success} succès, ${failed} échecs sur ${rows.length} tentatives`);
  }

  return { retried: rows.length, success, failed };
}
