import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';
import { auditAction } from '../../middleware/audit.js';
import {
  webhook,
  getStatutTransaction,
  listTransactions,
  initierPaiement,
  verifierPaiement,
  getPublicConfig,
} from '../../controllers/kkiapayController.js';

const router = Router();

// Webhook public (pas d'auth JWT) — KKiaPay envoie les notifications ici
router.post('/webhook', webhook);

// Routes authentifiées — tous les rôles peuvent initier/vérifier leurs paiements
router.use(authenticate);

// Configuration publique KKiaPay (clé publique pour le widget Flutter)
router.get('/config', getPublicConfig);

// Paiements KKiaPay (chauffeurs + gestionnaire + super_admin)
router.post('/paiements/initier',
  authorize('super_admin', 'gestionnaire', 'chauffeur'),
  sensitiveRateLimiter,
  initierPaiement,
);

router.post('/paiements/verifier',
  authorize('super_admin', 'gestionnaire', 'chauffeur'),
  sensitiveRateLimiter,
  auditAction('CREATE', 'paiement_kkiapay'),
  verifierPaiement,
);

// Administration — consultation des transactions (admin/gestionnaire uniquement)
router.use(authorize('super_admin', 'gestionnaire'));

router.get('/transactions', listTransactions);
router.get('/transaction/:transactionId/statut', getStatutTransaction);

export default router;
