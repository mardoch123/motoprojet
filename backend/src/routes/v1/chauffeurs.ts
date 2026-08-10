import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import {
  createChauffeurSchema, updateChauffeurSchema,
  createAffectationNestedSchema, terminerAffectationSchema,
} from '../../validators/schemas.js';
import {
  listChauffeurs, getChauffeur, createChauffeur, updateChauffeur,
} from '../../controllers/chauffeurController.js';
import {
  listAffectations, createAffectation, terminerAffectation,
} from '../../controllers/affectationController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

router.use(authenticate);

// ─── Chauffeurs ──────────────────────────────────────────────────────────────
router.get('/', authorize('super_admin', 'gestionnaire'), listChauffeurs);
router.get('/:id', authorize('super_admin', 'gestionnaire'), getChauffeur);
router.post('/', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('CREATE', 'chauffeur'), validate(createChauffeurSchema), createChauffeur);
router.put('/:id', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('UPDATE', 'chauffeur'), validate(updateChauffeurSchema), updateChauffeur);

// ─── Affectations (sous chauffeur) ──────────────────────────────────────────
router.get('/:chauffeurId/affectations', authorize('super_admin', 'gestionnaire'), listAffectations);
router.post('/:chauffeurId/affectations', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('CREATE', 'affectation'), validate(createAffectationNestedSchema), createAffectation);

// ─── Affectations (terminer) ─────────────────────────────────────────────────
router.put('/affectations/:id/terminer', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('UPDATE', 'affectation'), validate(terminerAffectationSchema), terminerAffectation);

export default router;
