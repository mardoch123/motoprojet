import pool from '../config/db.js';
import { logger } from '../utils/logger.js';
import { sendNotification, processRetryQueue, type NotificationChannel } from './notificationService.js';
import {
  rappelJ1, relanceJ2, alerteAdminJ5, defautJ10,
  transfertPropriete, achatPossible, type TemplateContext,
} from './notificationTemplates.js';

/**
 * Service de rappels automatiques — déclenché après le job des impayés.
 *
 * Règles (seuils paramétrables) :
 * - J+1 : SMS/WhatsApp poli au chauffeur
 * - J+2 : Relance ferme au chauffeur
 * - J+5 : Notification à l'administrateur
 * - J+10 : Notification admin pour décision + statut défaut
 * - Fin remboursement : Notification transfert de propriété
 * - Caisse cumulée ≥ prix véhicule : Notification achat possible
 *
 * Pour éviter les doublons, on vérifie qu'aucune notification du même type
 * n'a été envoyée pour le même chauffeur dans les dernières 24h.
 */

export interface ReminderResult {
  rappels_envoyes: number;
  admin_notifiees: number;
  transfert_notifies: number;
  achat_notifies: number;
}

/**
 * Exécute les rappels automatiques après le job des impayés.
 */
export async function executeRappels(): Promise<ReminderResult> {
  logger.info('[Rappels] Démarrage du service de rappels automatiques');

  const result: ReminderResult = {
    rappels_envoyes: 0,
    admin_notifiees: 0,
    transfert_notifies: 0,
    achat_notifies: 0,
  };

  // ── Lire les seuils configurables ─────────────────────────────────────
  const { rows: params } = await pool.query(
    `SELECT cle, valeur FROM parametres WHERE cle IN (
       'seuil_retard_jours', 'seuil_defaut_jours',
       'rappel_actif_sms', 'rappel_actif_whatsapp'
     )`,
  );
  const seuilRetard = parseInt(params.find(p => p.cle === 'seuil_retard_jours')?.valeur ?? '1', 10);
  const seuilDefaut = parseInt(params.find(p => p.cle === 'seuil_defaut_jours')?.valeur ?? '10', 10);
  const smsActif = params.find(p => p.cle === 'rappel_actif_sms')?.valeur !== 'false';
  const whatsappActif = params.find(p => p.cle === 'rappel_actif_whatsapp')?.valeur !== 'false';

  // ── Récupérer les chauffeurs avec leurs jours de retard ───────────────
  const { rows: chauffeurs } = await pool.query(`
    SELECT
      c.id AS chauffeur_id,
      c.nom,
      c.jours_impayes_cumules,
      c.statut,
      u.telephone,
      COALESCE(c.objectif_journalier, 5000) AS objectif_journalier,
      v.id AS vehicule_id,
      v.plaque,
      v.type AS vehicule_type,
      v.prix_achat,
      v.date_fin_remboursement,
      COALESCE(SUM(p.montant), 0) AS total_verse
    FROM chauffeurs c
    LEFT JOIN users u ON u.id = c.user_id
    LEFT JOIN affectations a ON a.chauffeur_id = c.id AND a.date_fin IS NULL
    LEFT JOIN vehicules v ON v.id = a.vehicule_id AND v.statut = 'en_remboursement'
    LEFT JOIN paiements p ON p.vehicule_id = v.id
    WHERE c.statut IN ('actif', 'retard', 'defaut')
      AND c.jours_impayes_cumules >= 1
    GROUP BY c.id, c.nom, c.jours_impayes_cumules, c.statut, u.telephone,
             c.objectif_journalier, v.id, v.plaque, v.type, v.prix_achat, v.date_fin_remboursement
  `);

  for (const c of chauffeurs) {
    const jours = c.jours_impayes_cumules;
    const objectif = parseFloat(c.objectif_journalier);
    const ctx: TemplateContext = {
      nom: c.nom,
      montant: objectif,
      plaque: c.plaque ?? '—',
      jours,
      vehicule_type: c.vehicule_type,
    };

    const canal: NotificationChannel = whatsappActif ? 'whatsapp' : smsActif ? 'sms' : 'in_app';

    // ── Règle J+1 : Rappel poli ─────────────────────────────────────────
    if (jours >= 1 && jours < 2) {
      const alreadySent = await wasNotificationSentToday(c.chauffeur_id, 'rappel_j1');
      if (!alreadySent) {
        const tpl = rappelJ1(ctx);
        await sendNotification({
          type: 'rappel_j1',
          channel: canal,
          destinataireId: c.chauffeur_id,
          destinataireTelephone: c.telephone,
          titre: tpl.titre,
          message: canal === 'whatsapp' ? tpl.whatsapp : tpl.sms,
          metadata: { jours, montant: objectif, plaque: c.plaque },
        });
        result.rappels_envoyes++;
      }
    }

    // ── Règle J+2 : Relance ferme ───────────────────────────────────────
    if (jours >= 2 && jours < 5) {
      const alreadySent = await wasNotificationSentToday(c.chauffeur_id, 'relance_j2');
      if (!alreadySent) {
        const tpl = relanceJ2(ctx);
        await sendNotification({
          type: 'relance_j2',
          channel: canal,
          destinataireId: c.chauffeur_id,
          destinataireTelephone: c.telephone,
          titre: tpl.titre,
          message: canal === 'whatsapp' ? tpl.whatsapp : tpl.sms,
          metadata: { jours, montant: objectif * jours, plaque: c.plaque },
        });
        result.rappels_envoyes++;
      }
    }

    // ── Règle J+5 : Alerte admin ────────────────────────────────────────
    if (jours >= 5 && jours < seuilDefaut) {
      const alreadySent = await wasNotificationSentToday(c.chauffeur_id, 'alerte_admin_j5');
      if (!alreadySent) {
        const tpl = alerteAdminJ5(ctx);
        await sendNotificationAdmin(tpl.titre, tpl.message, 'alerte_admin_j5', {
          chauffeur_id: c.chauffeur_id,
          chauffeur_nom: c.nom,
          jours,
          montant: objectif * jours,
          plaque: c.plaque,
        });
        result.admin_notifiees++;
      }
    }

    // ── Règle J+10 : Défaut + notification admin ────────────────────────
    if (jours >= seuilDefaut) {
      const alreadySent = await wasNotificationSentToday(c.chauffeur_id, 'defaut_j10');
      if (!alreadySent) {
        const tpl = defautJ10(ctx);
        await sendNotificationAdmin(tpl.titre, tpl.message, 'defaut_j10', {
          chauffeur_id: c.chauffeur_id,
          chauffeur_nom: c.nom,
          jours,
          montant: objectif * jours,
          plaque: c.plaque,
        });
        result.admin_notifiees++;
      }
    }
  }

  // ── Règle : Fin de remboursement atteinte ─────────────────────────────
  const { rows: finsRemboursement } = await pool.query(`
    SELECT
      v.id AS vehicule_id, v.plaque, v.type, v.date_fin_remboursement,
      c.id AS chauffeur_id, c.nom AS chauffeur_nom,
      u.telephone,
      COALESCE(SUM(p.montant), 0) AS total_verse,
      v.prix_achat
    FROM vehicules v
    LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
    LEFT JOIN chauffeurs c ON c.id = a.chauffeur_id
    LEFT JOIN users u ON u.id = c.user_id
    LEFT JOIN paiements p ON p.vehicule_id = v.id
    WHERE v.statut = 'en_remboursement'
      AND v.date_fin_remboursement IS NOT NULL
      AND v.date_fin_remboursement <= CURRENT_DATE
      AND COALESCE(SUM(p.montant), 0) >= v.prix_achat * 0.95
    GROUP BY v.id, v.plaque, v.type, v.date_fin_remboursement,
             c.id, c.nom, u.telephone, v.prix_achat
  `);

  for (const v of finsRemboursement) {
    const alreadySent = await wasNotificationSentToday(v.chauffeur_id, 'transfert_propriete');
    if (!alreadySent) {
      const ctx: TemplateContext = {
        nom: v.chauffeur_nom ?? 'Chauffeur',
        montant: 0,
        plaque: v.plaque,
        jours: 0,
        date_fin: v.date_fin_remboursement?.toISOString().split('T')[0],
        vehicule_type: v.type,
      };
      const tpl = transfertPropriete(ctx);

      // Notification au chauffeur
      if (v.telephone) {
        await sendNotification({
          type: 'transfert_propriete',
          channel: whatsappActif ? 'whatsapp' : 'sms',
          destinataireId: v.chauffeur_id,
          destinataireTelephone: v.telephone,
          titre: tpl.titre,
          message: whatsappActif ? tpl.whatsapp : tpl.sms,
          metadata: { vehicule_id: v.vehicule_id, plaque: v.plaque },
        });
      }

      // Notification à l'admin
      await sendNotificationAdmin(tpl.titre, tpl.adminMessage, 'transfert_propriete', {
        vehicule_id: v.vehicule_id,
        plaque: v.plaque,
        chauffeur: v.chauffeur_nom,
      });

      result.transfert_notifies++;
    }
  }

  // ── Règle : Caisse cumulée ≥ prix véhicule ────────────────────────────
  const { rows: achatsPossibles } = await pool.query(`
    SELECT v.id, v.plaque, v.type, v.prix_achat,
           COALESCE(SUM(p.montant), 0) AS total_verse
    FROM vehicules v
    LEFT JOIN paiements p ON p.vehicule_id = v.id
    WHERE v.statut = 'en_remboursement'
    GROUP BY v.id, v.plaque, v.type, v.prix_achat
    HAVING COALESCE(SUM(p.montant), 0) >= v.prix_achat
  `);

  // Vérifier si la caisse globale permet d'acheter un nouveau véhicule
  const { rows: caisseRows } = await pool.query(
    `SELECT COALESCE(SUM(montant), 0) AS total FROM paiements WHERE date >= CURRENT_DATE - INTERVAL '30 days'`,
  );
  const caisseMensuelle = parseFloat(caisseRows[0]?.total ?? '0');

  for (const v of achatsPossibles) {
    // Chercher un véhicule non encore acheté dont le prix <= prix du véhicule remboursé
    const { rows: nouveauxVehicules } = await pool.query(`
      SELECT id, plaque, type, prix_achat FROM vehicules
      WHERE statut = 'en_remboursement' AND id != $1 AND prix_achat <= $2
      ORDER BY prix_achat ASC LIMIT 1
    `, [v.id, v.prix_achat]);

    if (nouveauxVehicules.length > 0) {
      const nouveau = nouveauxVehicules[0];
      const alreadySent = await wasNotificationSentToday(null, 'achat_possible', v.plaque);
      if (!alreadySent) {
        const ctx: TemplateContext = {
          nom: 'Admin',
          montant: 0,
          plaque: nouveau.plaque,
          jours: 0,
          vehicule_type: nouveau.type,
          prix_vehicule: parseFloat(nouveau.prix_achat),
        };
        const tpl = achatPossible(ctx);
        await sendNotificationAdmin(tpl.titre, tpl.message, 'achat_possible', {
          vehicule_rembourse: v.plaque,
          vehicule_cible: nouveau.plaque,
          prix: parseFloat(nouveau.prix_achat),
        });
        result.achat_notifies++;
      }
    }
  }

  // ── Traiter la file de retry ──────────────────────────────────────────
  await processRetryQueue();

  logger.info(`[Rappels] Terminé — ${result.rappels_envoyes} rappels, ${result.admin_notifiees} alertes admin, ${result.transfert_notifies} transferts, ${result.achat_notifies} achats`);
  return result;
}

/**
 * Vérifie si une notification du même type a déjà été envoyée aujourd'hui
 * pour éviter les doublons.
 */
async function wasNotificationSentToday(
  chauffeurId: string | null,
  type: string,
  plaqueRef?: string,
): Promise<boolean> {
  const { rows } = await pool.query(
    `SELECT COUNT(*) AS nb FROM notifications_log
     WHERE type = $1
       AND date_creation >= CURRENT_DATE
       AND statut IN ('envoye', 'en_attente')
       ${chauffeurId ? 'AND user_id = $2' : ''}`,
    chauffeurId ? [type, chauffeurId] : [type],
  );
  return parseInt(rows[0].nb, 10) > 0;
}

/**
 * Envoie une notification à tous les administrateurs.
 */
async function sendNotificationAdmin(
  titre: string,
  message: string,
  type: string,
  metadata: Record<string, unknown>,
): Promise<void> {
  // Récupérer les user_ids des super_admin et gestionnaire
  const { rows: admins } = await pool.query(
    `SELECT id FROM users WHERE role IN ('super_admin', 'gestionnaire') AND statut = 'actif'`,
  );

  for (const admin of admins) {
    await sendNotification({
      type: type as any,
      channel: 'in_app',
      destinataireId: admin.id,
      titre,
      message,
      metadata,
    });
  }
}
