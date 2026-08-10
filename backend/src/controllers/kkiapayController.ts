import { Request, Response, NextFunction } from 'express';
import type { AuthRequest } from '../types/index.js';
import { logger } from '../utils/logger.js';
import { writeAuditLog } from '../services/audit.js';
import { config } from '../config/env.js';
import * as kkiapayService from '../services/kkiapayService.js';

/**
 * GET /api/v1/kkiapay/config
 * Retourne la configuration publique KKiaPay pour le widget Flutter.
 * NE retourne JAMAIS la clé privée.
 */
export async function getPublicConfig(_req: AuthRequest, res: Response) {
  res.json({
    success: true,
    data: {
      publicKey: config.kkiapay.publicKey,
      sandbox: config.kkiapay.sandbox,
      apiUrl: config.kkiapay.apiUrl,
    },
  });
}

/**
 * POST /api/v1/kkiapay/webhook
 * Webhook public (pas d'auth JWT) — vérification par signature HMAC
 */
export async function webhook(req: Request, res: Response, next: NextFunction) {
  try {
    const rawBody = JSON.stringify(req.body);
    const signature = req.headers['x-kkiapay-signature'] as string | undefined;

    // Vérifier la signature si un secret est configuré
    if (signature) {
      const valid = kkiapayService.verifierSignatureWebhook(rawBody, signature);
      if (!valid) {
        logger.warn('Webhook KKiaPay : signature invalide');
        res.status(401).json({ success: false, message: 'Signature invalide' });
        return;
      }
    }

    const { transaction_id, status, amount, fees } = req.body;

    if (!transaction_id || !status) {
      res.status(400).json({ success: false, message: 'Champs requis : transaction_id, status' });
      return;
    }

    const result = await kkiapayService.traiterWebhook({
      transactionId: transaction_id,
      status,
      amount,
      fees,
      rawData: req.body,
    });

    res.json(result);
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/kkiapay/transaction/:transactionId/statut
 * Vérifie le statut d'une transaction (polling côté client)
 */
export async function getStatutTransaction(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const transactionId = req.params.transactionId as string;
    const transaction = await kkiapayService.verifierStatutTransaction(transactionId);

    if (!transaction) {
      res.status(404).json({ success: false, message: 'Transaction introuvable' });
      return;
    }

    res.json({ success: true, data: transaction });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/kkiapay/transactions
 * Liste les transactions KKiaPay récentes
 */
export async function listTransactions(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const statut = req.query.statut as string | undefined;
    const type = req.query.type as string | undefined;
    const limit = parseInt(req.query.limit as string) || 50;

    const transactions = await kkiapayService.listerTransactions({ statut, type, limit });
    res.json({ success: true, data: transactions });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/kkiapay/paiements/initier
 * Initie une transaction KKiaPay pour un paiement chauffeur.
 * Le client reçoit un transactionId qu'il passera au widget KKiaPay.
 */
export async function initierPaiement(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { vehicule_id, montant, date } = req.body;
    const user = req.user!;

    // Résoudre le chauffeur_id depuis le JWT
    let chauffeurId: string;
    let telephone: string;
    if (user.role === 'chauffeur') {
      const { rows } = await (await import('../config/db.js')).default.query(
        `SELECT c.id, u.telephone FROM chauffeurs c JOIN users u ON c.user_id = u.id WHERE c.user_id = $1`,
        [user.sub],
      );
      if (rows.length === 0) {
        res.status(400).json({ success: false, message: 'Profil chauffeur non trouvé' });
        return;
      }
      chauffeurId = rows[0].id;
      telephone = rows[0].telephone;
    } else {
      chauffeurId = req.body.chauffeur_id;
      telephone = req.body.telephone;
      if (!chauffeurId || !telephone) {
        res.status(400).json({ success: false, message: 'chauffeur_id et telephone requis pour ce rôle' });
        return;
      }
    }

    // Récupérer la plaque pour le motif
    const { rows: vehicules } = await (await import('../config/db.js')).default.query(
      `SELECT plaque FROM vehicules WHERE id = $1`, [vehicule_id],
    );
    const plaque = vehicules[0]?.plaque;

    const result = await kkiapayService.initierPaiementChauffeur({
      chauffeurId,
      vehiculeId: vehicule_id,
      montant,
      telephone,
      date: date || new Date().toISOString().split('T')[0],
      plaque,
    });

    await writeAuditLog(user.sub, 'INITIATE_KKIAPAY_PAIEMENT', result.transactionId, {
      montant, vehicule_id, chauffeurId,
    });

    res.status(201).json({ success: true, data: result });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/kkiapay/paiements/verifier
 * Vérifie le statut RÉEL d'une transaction KKiaPay (server-to-server)
 * et crée le paiement en base si confirmé.
 *
 * SÉCURITÉ : L'appel est fait avec la clé PRIVÉE côté serveur.
 * Le statut renvoyé par le client mobile n'est JAMAIS utilisé.
 */
export async function verifierPaiement(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { transaction_id, vehicule_id, montant, date } = req.body;
    const user = req.user!;

    if (!transaction_id || !vehicule_id || !montant) {
      res.status(400).json({ success: false, message: 'transaction_id, vehicule_id et montant requis' });
      return;
    }

    // Résoudre le chauffeur_id
    let chauffeurId: string;
    if (user.role === 'chauffeur') {
      const { rows } = await (await import('../config/db.js')).default.query(
        `SELECT id FROM chauffeurs WHERE user_id = $1`, [user.sub],
      );
      if (rows.length === 0) {
        res.status(400).json({ success: false, message: 'Profil chauffeur non trouvé' });
        return;
      }
      chauffeurId = rows[0].id;
    } else {
      chauffeurId = req.body.chauffeur_id;
      if (!chauffeurId) {
        res.status(400).json({ success: false, message: 'chauffeur_id requis pour ce rôle' });
        return;
      }
    }

    const result = await kkiapayService.verifierEtCreerPaiement({
      transactionId: transaction_id,
      chauffeurId,
      vehiculeId: vehicule_id,
      montant,
      date: date || new Date().toISOString().split('T')[0],
    });

    if (result.success) {
      await writeAuditLog(user.sub, 'VERIFY_KKIAPAY_PAIEMENT', transaction_id, {
        montant, vehicule_id, chauffeurId, statut: 'confirmed',
      });
    }

    res.status(result.success ? 201 : 400).json({
      success: result.success,
      data: result.success ? { paiement: result.paiement, solde: result.solde } : undefined,
      message: result.message,
    });
  } catch (err) { next(err); }
}
