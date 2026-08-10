import crypto from 'node:crypto';
import pool from '../config/db.js';
import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';

// ─── Types ───────────────────────────────────────────────────────────────────

export interface TransactionKKiaPay {
  id: string;
  transactionId: string;
  type: string;
  referenceId: string;
  montant: number;
  telephone: string;
  statut: string;
  montantRecu: number | null;
  frais: number | null;
  creeLe: string;
  confirmeLe: string | null;
  expireLe: string;
}

export interface InitierPaiementResult {
  transactionId: string;
  statut: string;
  urlPaiement?: string;
  message: string;
}

// ─── Service KKiaPay ─────────────────────────────────────────────────────────

/**
 * Génère un identifiant de transaction unique
 */
function genererTransactionId(): string {
  const timestamp = Date.now().toString(36);
  const random = crypto.randomBytes(8).toString('hex');
  return `MP-${timestamp}-${random}`;
}

/**
 * Vérifie la signature HMAC d'un webhook KKiaPay
 */
export function verifierSignatureWebhook(payload: string, signature: string): boolean {
  const secret = config.kkiapay.webhookSecret;
  if (!secret) {
    logger.warn('KKiaPay webhook_secret non configuré, vérification ignorée');
    return true; // En dev, on accepte sans vérification
  }
  const expected = crypto.createHmac('sha256', secret).update(payload).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(signature), Buffer.from(expected));
}

/**
 * Initie un paiement KKiaPay pour un versement d'apport
 */
export async function initierPaiementApport(data: {
  apportId: string;
  montant: number;
  telephone: string;
  dateVersement: string;
  note?: string;
}): Promise<InitierPaiementResult> {
  const { apportId, montant, telephone, dateVersement, note } = data;

  // Vérifier que le téléphone est valide (format béninois)
  if (!/^(229)?\d{8}$/.test(telephone.replace(/\s/g, ''))) {
    throw new Error('Numéro de téléphone invalide. Format attendu : 229XXXXXXXX ou XXXXXXXX');
  }

  // Créer d'abord le versement en statut "en_attente"
  const { rows: versementRows } = await pool.query(`
    INSERT INTO apports_versements (apport_id, date_versement, montant, note, mode, telephone, statut_paiement)
    VALUES ($1, $2, $3, $4, 'kkiapay', $5, 'en_attente')
    RETURNING id
  `, [apportId, dateVersement, montant, note, telephone]);

  const versementId = versementRows[0].id;
  const transactionId = genererTransactionId();

  // Créer la transaction KKiaPay
  await pool.query(`
    INSERT INTO transactions_kkiapay (transaction_id, type, reference_id, montant, telephone)
    VALUES ($1, 'apport_versement', $2, $3, $4)
  `, [transactionId, versementId, montant, telephone]);

  // Appeler l'API KKiaPay pour initier le paiement
  try {
    const resultat = await appelerKKiaPayAPI({
      transactionId,
      montant,
      telephone: telephone.replace(/\s/g, ''),
      motif: `Apport personnel - ${montant} FCFA`,
    });

    // Mettre à jour la transaction avec la réponse
    await pool.query(`
      UPDATE transactions_kkiapay
      SET reponse_kkiapay = $1, statut = 'pending'
      WHERE transaction_id = $2
    `, [JSON.stringify(resultat), transactionId]);

    logger.info('Paiement KKiaPay initié', { transactionId, montant, telephone });

    return {
      transactionId,
      statut: 'pending',
      urlPaiement: resultat.url as string | undefined,
      message: 'Demande de paiement envoyée. Le client va recevoir une notification USSD.',
    };
  } catch (error: unknown) {
    const errorMessage = error instanceof Error ? error.message : String(error);
    // En cas d'échec API, marquer la transaction comme échouée
    await pool.query(`
      UPDATE transactions_kkiapay
      SET statut = 'failed', reponse_kkiapay = $1
      WHERE transaction_id = $2
    `, [JSON.stringify({ error: errorMessage }), transactionId]);

    // Mettre à jour le versement
    await pool.query(`
      UPDATE apports_versements SET statut_paiement = 'echoue' WHERE id = $1
    `, [versementId]);

    logger.error('Erreur initiation paiement KKiaPay', { transactionId, error: errorMessage });
    throw new Error(`Impossible d'initier le paiement : ${errorMessage}`);
  }
}

/**
 * Appelle l'API KKiaPay pour initier un paiement
 * En mode sandbox/dev, simule l'appel
 */
async function appelerKKiaPayAPI(data: {
  transactionId: string;
  montant: number;
  telephone: string;
  motif: string;
}): Promise<Record<string, unknown>> {
  const { apiKey, apiUrl, sandbox } = config.kkiapay;

  // Mode développement : simuler le paiement
  if (sandbox || !apiKey) {
    logger.info('KKiaPay SANDBOX : paiement simulé', { transactionId: data.transactionId });
    return {
      success: true,
      transaction_id: data.transactionId,
      status: 'pending',
      url: `https://sandbox.kkiapay.io/pay/${data.transactionId}`,
      message: 'Mode sandbox : paiement simulé',
    };
  }

  // Appel API réel
  const response = await fetch(`${apiUrl}/api/v1/payments/initiate`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`,
      'X-Kkiapay-Key': apiKey,
    },
    body: JSON.stringify({
      amount: data.montant,
      phone: data.telephone,
      reason: data.motif,
      callback_url: `${apiUrl}/api/v1/kkiapay/webhook`,
      transaction_id: data.transactionId,
    }),
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`KKiaPay API error ${response.status}: ${text}`);
  }

  return response.json() as Promise<Record<string, unknown>>;
}

/**
 * Traite le webhook de confirmation KKiaPay
 */
export async function traiterWebhook(data: {
  transactionId: string;
  status: string;
  amount?: number;
  fees?: number;
  rawData: Record<string, unknown>;
}): Promise<{ success: boolean; message: string }> {
  const { transactionId, status, amount, fees, rawData } = data;

  // Trouver la transaction
  const { rows } = await pool.query(`
    SELECT * FROM transactions_kkiapay WHERE transaction_id = $1
  `, [transactionId]);

  if (rows.length === 0) {
    logger.warn('Webhook KKiaPay : transaction introuvable', { transactionId });
    return { success: false, message: 'Transaction introuvable' };
  }

  const transaction = rows[0];
  const referenceId = transaction.reference_id;
  const type = transaction.type;

  // Déterminer le nouveau statut
  let nouveauStatut: string;
  let statutPaiement: string;

  switch (status) {
    case 'success':
    case 'completed':
      nouveauStatut = 'confirmed';
      statutPaiement = 'confirme';
      break;
    case 'failed':
    case 'rejected':
      nouveauStatut = 'failed';
      statutPaiement = 'echoue';
      break;
    case 'expired':
    case 'timeout':
      nouveauStatut = 'expired';
      statutPaiement = 'expire';
      break;
    default:
      nouveauStatut = 'pending';
      statutPaiement = 'en_attente';
  }

  // Mettre à jour la transaction
  await pool.query(`
    UPDATE transactions_kkiapay
    SET statut = $1, montant_recu = $2, frais = $3,
        webhook_recu = $4, confirme_le = NOW()
    WHERE transaction_id = $5
  `, [nouveauStatut, amount || null, fees || null, JSON.stringify(rawData), transactionId]);

  // Mettre à jour l'entité liée
  if (type === 'apport_versement') {
    await pool.query(`
      UPDATE apports_versements
      SET statut_paiement = $1,
          kkiapay_transaction_id = $2,
          montant = COALESCE($3, montant)
      WHERE id = $4
    `, [statutPaiement, transactionId, amount || null, referenceId]);
  }

  // Pour les paiements chauffeur, le webhook ne crée PAS directement le paiement.
  // Il marque la transaction comme confirmée. La création du paiement se fait
  // via verifierEtCreerPaiement() (appelé soit par le client après le widget,
  // soit par ce webhook si le client n'a pas pu vérifier).
  if (type === 'paiement_chauffeur' && (status === 'success' || status === 'completed')) {
    // Idempotence : vérifier que le paiement n'a pas déjà été créé
    const { rows: existingPaiement } = await pool.query(`
      SELECT id FROM paiements WHERE transaction_kkiapay_id = $1
    `, [transactionId]);

    if (existingPaiement.length === 0 && !transaction.webhook_processed) {
      // Le webhook crée le paiement si le client ne l'a pas encore fait
      const [chauffeurId, vehiculeId, date] = referenceId.split('|');

      try {
        const client = await pool.connect();
        try {
          await client.query('BEGIN');

          // Double-check sous transaction
          const { rows: doubleCheck } = await client.query(`
            SELECT id FROM paiements WHERE transaction_kkiapay_id = $1
          `, [transactionId]);

          if (doubleCheck.length === 0) {
            const { rows: paiementRows } = await client.query(`
              INSERT INTO paiements (chauffeur_id, vehicule_id, montant, date, mode, transaction_kkiapay_id, kkiapay_frais)
              VALUES ($1, $2, $3, COALESCE($4, CURRENT_DATE), 'mobile_money_kkiapay', $5, $6)
              RETURNING id
            `, [chauffeurId, vehiculeId, amount || transaction.montant, date || null, transactionId, fees || null]);

            await client.query(`
              UPDATE transactions_kkiapay
              SET paiement_id = $1, webhook_processed = TRUE
              WHERE transaction_id = $2
            `, [paiementRows[0].id, transactionId]);

            logger.info('Paiement créé par webhook KKiaPay', { transactionId, paiementId: paiementRows[0].id });
          }

          await client.query('COMMIT');
        } catch (err) {
          await client.query('ROLLBACK');
          throw err;
        } finally {
          client.release();
        }
      } catch (err: unknown) {
        const errorMessage = err instanceof Error ? err.message : String(err);
        logger.error('Erreur création paiement par webhook', { transactionId, error: errorMessage });
      }
    }
  }

  logger.info('Webhook KKiaPay traité', { transactionId, statut: nouveauStatut });

  return { success: true, message: `Transaction ${nouveauStatut}` };
}

/**
 * Vérifie le statut d'une transaction KKiaPay (polling)
 */
export async function verifierStatutTransaction(transactionId: string): Promise<TransactionKKiaPay | null> {
  const { rows } = await pool.query(`
    SELECT * FROM transactions_kkiapay WHERE transaction_id = $1
  `, [transactionId]);

  if (rows.length === 0) return null;

  const r = rows[0];

  // Si encore en attente et API configurée, faire un polling
  if (r.statut === 'pending' && config.kkiapay.apiKey && !config.kkiapay.sandbox) {
    try {
      const response = await fetch(
        `${config.kkiapay.apiUrl}/api/v1/transactions/${transactionId}/status`,
        {
          headers: {
            'Authorization': `Bearer ${config.kkiapay.apiKey}`,
            'X-Kkiapay-Key': config.kkiapay.apiKey,
          },
        },
      );

      if (response.ok) {
        const data = await response.json() as Record<string, unknown>;
        const status = data.status as string;

        if (status === 'success' || status === 'completed') {
          await pool.query(`
            UPDATE transactions_kkiapay
            SET statut = 'confirmed', montant_recu = $1, confirme_le = NOW()
            WHERE transaction_id = $2
          `, [data.amount, transactionId]);

          await pool.query(`
            UPDATE apports_versements
            SET statut_paiement = 'confirme', kkiapay_transaction_id = $1
            WHERE kkiapay_transaction_id = $1
          `, [transactionId]);

          r.statut = 'confirmed';
        } else if (status === 'failed' || status === 'expired') {
          await pool.query(`
            UPDATE transactions_kkiapay SET statut = $1 WHERE transaction_id = $2
          `, [status, transactionId]);

          await pool.query(`
            UPDATE apports_versements SET statut_paiement = $1
            WHERE kkiapay_transaction_id = $2
          `, [status === 'failed' ? 'echoue' : 'expire', transactionId]);

          r.statut = status;
        }
      }
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      logger.error('Erreur polling KKiaPay', { transactionId, error: errorMessage });
    }
  }

  return {
    id: r.id,
    transactionId: r.transaction_id,
    type: r.type,
    referenceId: r.reference_id,
    montant: parseFloat(r.montant),
    telephone: r.telephone,
    statut: r.statut,
    montantRecu: r.montant_recu ? parseFloat(r.montant_recu) : null,
    frais: r.frais ? parseFloat(r.frais) : null,
    creeLe: r.cree_le,
    confirmeLe: r.confirme_le,
    expireLe: r.expire_le,
  };
}

/**
 * Annule un versement en attente (timeout ou annulation manuelle)
 */
export async function annulerVersementEnAttente(versementId: string): Promise<void> {
  await pool.query(`
    UPDATE apports_versements SET statut_paiement = 'annule' WHERE id = $1 AND statut_paiement = 'en_attente'
  `, [versementId]);

  await pool.query(`
    UPDATE transactions_kkiapay SET statut = 'expired'
    WHERE reference_id = $1 AND type = 'apport_versement' AND statut = 'pending'
  `, [versementId]);
}

/**
 * Liste les transactions KKiaPay récentes
 */
export async function listerTransactions(options?: {
  statut?: string;
  type?: string;
  limit?: number;
}): Promise<TransactionKKiaPay[]> {
  let query = 'SELECT * FROM transactions_kkiapay';
  const conditions: string[] = [];
  const params: unknown[] = [];
  let idx = 1;

  if (options?.statut) {
    conditions.push(`statut = $${idx}`);
    params.push(options.statut);
    idx++;
  }
  if (options?.type) {
    conditions.push(`type = $${idx}`);
    params.push(options.type);
    idx++;
  }

  if (conditions.length > 0) query += ' WHERE ' + conditions.join(' AND ');
  query += ' ORDER BY cree_le DESC';

  const limit = options?.limit || 50;
  query += ` LIMIT $${idx}`;
  params.push(limit);

  const { rows } = await pool.query(query, params);

  return rows.map((r: Record<string, unknown>) => ({
    id: r.id as string,
    transactionId: r.transaction_id as string,
    type: r.type as string,
    referenceId: r.reference_id as string,
    montant: parseFloat(r.montant as string),
    telephone: r.telephone as string,
    statut: r.statut as string,
    montantRecu: r.montant_recu ? parseFloat(r.montant_recu as string) : null,
    frais: r.frais ? parseFloat(r.frais as string) : null,
    creeLe: r.cree_le as string,
    confirmeLe: r.confirme_le as string | null,
    expireLe: r.expire_le as string,
  }));
}

// ═════════════════════════════════════════════════════════════════════════
// PAIEMENT CHAUFFEUR — Vérification serveur + création paiement
// ═════════════════════════════════════════════════════════════════════════

export interface PaiementChauffeurInitResult {
  transactionId: string;
  statut: string;
  message: string;
}

/**
 * Initie une transaction KKiaPay pour un paiement chauffeur.
 * Crée un enregistrement dans transactions_kkiapay avec type='paiement_chauffeur'.
 * Le paiement n'est PAS encore créé dans la table paiements — il le sera
 * uniquement après vérification serveur (voir verifierEtCreerPaiement).
 */
export async function initierPaiementChauffeur(data: {
  chauffeurId: string;
  vehiculeId: string;
  montant: number;
  telephone: string;
  date: string;
  plaque?: string;
}): Promise<PaiementChauffeurInitResult> {
  const { chauffeurId, vehiculeId, montant, telephone, date, plaque } = data;

  // Générer un identifiant de transaction unique
  const transactionId = genererTransactionId();

  // Créer la transaction KKiaPay en statut 'initiated'
  // reference_id = concatenation chauffeurId|vehiculeId|date pour traçabilité
  const referenceId = `${chauffeurId}|${vehiculeId}|${date}`;

  await pool.query(`
    INSERT INTO transactions_kkiapay (transaction_id, type, reference_id, montant, telephone)
    VALUES ($1, 'paiement_chauffeur', $2, $3, $4)
  `, [transactionId, referenceId, montant, telephone]);

  logger.info('Transaction KKiaPay initiée pour paiement chauffeur', {
    transactionId, chauffeurId, vehiculeId, montant, telephone,
  });

  return {
    transactionId,
    statut: 'initiated',
    message: 'Transaction initiée. Ouvrez le widget KKiaPay pour compléter le paiement.',
  };
}

/**
 * Vérifie le statut réel d'une transaction KKiaPay auprès de l'API serveur
 * et crée le paiement en base UNIQUEMENT si la transaction est confirmée.
 *
 * SÉCURITÉ : Cette fonction appelle l'API KKiaPay avec la clé PRIVÉE
 * pour vérifier le statut côté serveur. Le statut renvoyé par le client
 * mobile n'est JAMAIS utilisé directement.
 *
 * IDempotence : si le transactionId a déjà créé un paiement, retourne
 * le paiement existant sans en créer un nouveau.
 */
export async function verifierEtCreerPaiement(data: {
  transactionId: string;
  chauffeurId: string;
  vehiculeId: string;
  montant: number;
  date: string;
}): Promise<{
  success: boolean;
  paiement?: Record<string, unknown>;
  solde?: Record<string, unknown>;
  message: string;
}> {
  const { transactionId, chauffeurId, vehiculeId, montant, date } = data;

  // ── 1. Vérifier l'idempotence : ce transactionId a-t-il déjà créé un paiement ? ─
  const { rows: existingPaiement } = await pool.query(`
    SELECT p.*, tk.statut AS kkiapay_statut
    FROM paiements p
    JOIN transactions_kkiapay tk ON p.transaction_kkiapay_id = tk.transaction_id
    WHERE p.transaction_kkiapay_id = $1
  `, [transactionId]);

  if (existingPaiement.length > 0) {
    const p = existingPaiement[0];
    logger.info('Paiement KKiaPay déjà existant (idempotence)', { transactionId, paiementId: p.id });

    // Recalculer le solde pour la réponse
    const { rows: soldeRows } = await pool.query(
      `SELECT COALESCE(SUM(montant), 0) AS total_verse FROM paiements WHERE vehicule_id = $1`,
      [p.vehicule_id],
    );
    const { rows: vehicules } = await pool.query(
      `SELECT prix_achat FROM vehicules WHERE id = $1`, [p.vehicule_id],
    );

    const totalVerse = parseFloat(soldeRows[0].total_verse);
    const prixAchat = parseFloat(vehicules[0].prix_achat);

    return {
      success: true,
      paiement: p,
      solde: {
        total_verse_avant: totalVerse - parseFloat(p.montant),
        montant_paye: parseFloat(p.montant),
        nouveau_solde: Math.max(0, prixAchat - totalVerse),
        pourcentage_rembourse: Math.min(100, (totalVerse / prixAchat) * 100),
      },
      message: 'Paiement déjà confirmé (transaction existante)',
    };
  }

  // ── 2. Vérifier la transaction dans notre base ─
  const { rows: txRows } = await pool.query(`
    SELECT * FROM transactions_kkiapay WHERE transaction_id = $1
  `, [transactionId]);

  if (txRows.length === 0) {
    return { success: false, message: 'Transaction introuvable' };
  }

  const transaction = txRows[0];

  // Si déjà confirmée mais pas de paiement créé (incohérence), bloquer
  if (transaction.statut === 'confirmed' && transaction.webhook_processed) {
    return { success: false, message: 'Transaction déjà traitée' };
  }

  // ── 3. Appel API KKiaPay pour vérifier le statut RÉEL (server-to-server) ─
  let kkiapayStatus = transaction.statut;
  let kkiapayAmount = parseFloat(transaction.montant);
  let kkiapayFees: number | null = null;

  if (config.kkiapay.apiKey && !config.kkiapay.sandbox) {
    try {
      const response = await fetch(
        `${config.kkiapay.apiUrl}/api/v1/transactions/${transactionId}/status`,
        {
          headers: {
            'Authorization': `Bearer ${config.kkiapay.apiKey}`,
            'X-Kkiapay-Key': config.kkiapay.apiKey,
          },
        },
      );

      if (response.ok) {
        const kkiapayData = await response.json() as Record<string, unknown>;
        kkiapayStatus = (kkiapayData.status as string) === 'success'
          || (kkiapayData.status as string) === 'completed'
          ? 'confirmed' : (kkiapayData.status as string);
        kkiapayAmount = (kkiapayData.amount as number) || kkiapayAmount;
        kkiapayFees = (kkiapayData.fees as number) || null;
      } else {
        logger.error('KKiaPay API error lors de la vérification', {
          transactionId, status: response.status,
        });
        return { success: false, message: 'Impossible de vérifier la transaction auprès de KKiaPay' };
      }
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : String(error);
      logger.error('Erreur vérification KKiaPay', { transactionId, error: errorMessage });
      return { success: false, message: 'Erreur de communication avec KKiaPay' };
    }
  } else {
    // Mode sandbox : accepter la transaction si elle existe dans notre base
    kkiapayStatus = 'confirmed';
    logger.info('KKiaPay SANDBOX : transaction simulée confirmée', { transactionId });
  }

  // ── 4. Si le statut n'est pas confirmed, refuser ─
  if (kkiapayStatus !== 'confirmed') {
    await pool.query(`
      UPDATE transactions_kkiapay SET statut = $1 WHERE transaction_id = $2
    `, [kkiapayStatus, transactionId]);

    return {
      success: false,
      message: `Transaction non confirmée (statut : ${kkiapayStatus})`,
    };
  }

  // ── 5. Créer le paiement en base (transaction DB atomique) ─
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    // Vérifier à nouveau l'idempotence sous lock (race condition)
    const { rows: doubleCheck } = await client.query(`
      SELECT id FROM paiements WHERE transaction_kkiapay_id = $1
    `, [transactionId]);

    if (doubleCheck.length > 0) {
      await client.query('COMMIT');
      return { success: false, message: 'Paiement déjà créé (concurrent)' };
    }

    // Calcul du solde
    const { rows: soldeRows } = await client.query(
      `SELECT COALESCE(SUM(montant), 0) AS total_verse FROM paiements WHERE vehicule_id = $1`,
      [vehiculeId],
    );
    const totalVerseAvant = parseFloat(soldeRows[0].total_verse);

    const { rows: vehicules } = await client.query(
      `SELECT prix_achat, plaque FROM vehicules WHERE id = $1`, [vehiculeId],
    );
    const prixAchat = parseFloat(vehicules[0].prix_achat);
    const nouveauSolde = prixAchat - (totalVerseAvant + montant);

    // Insérer le paiement
    const { rows: paiementRows } = await client.query(`
      INSERT INTO paiements (chauffeur_id, vehicule_id, montant, date, mode, transaction_kkiapay_id, kkiapay_frais)
      VALUES ($1, $2, $3, COALESCE($4, CURRENT_DATE), 'mobile_money_kkiapay', $5, $6)
      RETURNING *
    `, [chauffeurId, vehiculeId, montant, date || null, transactionId, kkiapayFees]);

    const paiementId = paiementRows[0].id;

    // Mettre à jour la transaction KKiaPay
    await client.query(`
      UPDATE transactions_kkiapay
      SET statut = 'confirmed', montant_recu = $1, frais = $2,
          paiement_id = $3, webhook_processed = TRUE, confirme_le = NOW()
      WHERE transaction_id = $4
    `, [kkiapayAmount, kkiapayFees, paiementId, transactionId]);

    await client.query('COMMIT');

    logger.info('Paiement KKiaPay créé avec succès', {
      transactionId, paiementId, montant, chauffeurId,
    });

    return {
      success: true,
      paiement: paiementRows[0],
      solde: {
        total_verse_avant: totalVerseAvant,
        montant_paye: montant,
        nouveau_solde: Math.max(0, nouveauSolde),
        pourcentage_rembourse: Math.min(100, ((totalVerseAvant + montant) / prixAchat) * 100),
      },
      message: 'Paiement confirmé et enregistré',
    };
  } catch (err) {
    await client.query('ROLLBACK');
    throw err;
  } finally {
    client.release();
  }
}
