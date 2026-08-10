import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { createPaiementSchema, syncBatchSchema } from '../../validators/schemas.js';
import {
  createPaiement,
  listPaiements,
  syncBatch,
  getFinanceDashboard,
  listPendingSync,
} from '../../controllers/paiementController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

router.use(authenticate);

router.get('/finance/dashboard', authorize('super_admin', 'gestionnaire'), getFinanceDashboard);
router.get('/pending-sync', authorize('super_admin', 'gestionnaire'), listPendingSync);
router.post('/sync-batch', authorize('super_admin', 'gestionnaire', 'chauffeur'), sensitiveRateLimiter, validate(syncBatchSchema), syncBatch);

// LISTE : tous les rôles authentifiés (le contrôleur filtre par périmètre)
router.get('/', authorize('super_admin', 'gestionnaire', 'chauffeur'), listPaiements);

// CRÉATION : avec audit logging
router.post('/', authorize('super_admin', 'gestionnaire', 'chauffeur'), sensitiveRateLimiter, auditAction('CREATE', 'paiement'), validate(createPaiementSchema), createPaiement);

export default router;
