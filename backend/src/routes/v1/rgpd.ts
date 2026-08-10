import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import {
  getMesDonnees, demanderSuppression,
  listDemandes, anonymiserDonnees,
  updateConsentement,
} from '../../controllers/rgpdController.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

router.use(authenticate);

// ─── Droits de l'utilisateur (tous rôles authentifiés) ──────────────────────
router.get('/mes-donnees', getMesDonnees);
router.post('/suppression', sensitiveRateLimiter, demanderSuppression);
router.put('/consentement', sensitiveRateLimiter, updateConsentement);

// ─── Gestion Super Admin ────────────────────────────────────────────────────
router.get('/demandes', authorize('super_admin'), listDemandes);
router.post('/demandes/:id/anonymiser', authorize('super_admin'), sensitiveRateLimiter, anonymiserDonnees);

export default router;
