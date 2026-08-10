import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import {
  createVehiculeSchema, updateVehiculeSchema, changeStatutVehiculeSchema,
} from '../../validators/schemas.js';
import {
  listVehicules, getVehicule, createVehicule, updateVehicule,
  changeStatut, checkTransfertEligibilite,
} from '../../controllers/vehiculeController.js';
import { executeTransfert } from '../../controllers/transfertController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

router.use(authenticate);

// ─── Véhicules ───────────────────────────────────────────────────────────────
// GET : accessible à tous les rôles authentifiés (chauffeur voit ses véhicules affectés)
router.get('/', authorize('super_admin', 'gestionnaire', 'chauffeur'), listVehicules);
router.get('/:id', authorize('super_admin', 'gestionnaire', 'chauffeur'), getVehicule);

// Écriture : admin + gestionnaire uniquement, avec audit + rate limiting
router.post('/', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('CREATE', 'vehicule'), validate(createVehiculeSchema), createVehicule);
router.put('/:id', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('UPDATE', 'vehicule'), validate(updateVehiculeSchema), updateVehicule);

// ─── Statut ──────────────────────────────────────────────────────────────────
router.put('/:id/statut', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('UPDATE', 'vehicule_statut'), validate(changeStatutVehiculeSchema), changeStatut);

// ─── Transfert de propriété ─────────────────────────────────────────────────
router.get('/:id/transfert-eligibilite', authorize('super_admin', 'gestionnaire'), checkTransfertEligibilite);
router.post('/:id/transfert', authorize('super_admin'), sensitiveRateLimiter, auditAction('UPDATE', 'vehicule_transfert'), executeTransfert);

export default router;
