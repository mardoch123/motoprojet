import { Router } from 'express';
import {
  login, refresh, getProfile, changePin, resetPin,
  requestPinReset, listChauffeursForReset, updateActivity,
  completeOnboarding,
} from '../../controllers/authController.js';
import { authenticate, authorize, requirePinChange, updateLastActivity } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import {
  loginSchema, refreshSchema, changePinSchema,
  resetPinSchema, requestPinResetSchema,
} from '../../validators/schemas.js';
import { authRateLimiter, checkAccountLock, sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

// ─── Public (pas d'auth requise) ─────────────────────────────────────────────
router.post('/login', authRateLimiter, checkAccountLock, validate(loginSchema), login);
router.post('/refresh', validate(refreshSchema), refresh);
router.post('/request-pin-reset', authRateLimiter, validate(requestPinResetSchema), requestPinReset);

// ─── Authentifié (tous rôles) ────────────────────────────────────────────────
router.get('/me', authenticate, updateLastActivity, getProfile);
router.post('/change-pin', authenticate, sensitiveRateLimiter, validate(changePinSchema), changePin);
router.post('/onboarding/complete', authenticate, completeOnboarding);
router.patch('/activity', authenticate, updateActivity);

// ─── Super Admin uniquement ──────────────────────────────────────────────────
router.post('/reset-pin', authenticate, authorize('super_admin'), sensitiveRateLimiter, validate(resetPinSchema), resetPin);
router.get('/chauffeurs-for-reset', authenticate, authorize('super_admin'), listChauffeursForReset);

export default router;
