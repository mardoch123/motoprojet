import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import * as fleetCtrl from '../../controllers/fleetTrackingController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

// ─── Webhook (pas d'auth JWT, vérification par signature HMAC) ───────────────
router.post('/webhook', fleetCtrl.webhook);

// ─── Véhicules & Télémétrie ──────────────────────────────────────────────────
// Toutes les routes nécessitent authenticate + authorize
router.use(authenticate);

router.get('/vehicules', authorize('super_admin', 'gestionnaire'), fleetCtrl.listVehicules);
router.get('/vehicules/:id/telemetrie', authorize('super_admin', 'gestionnaire'), fleetCtrl.getTelemetrie);
router.get('/vehicules/:id/commandes', authorize('super_admin', 'gestionnaire'), fleetCtrl.getCommandes);

// ─── Commandes (avec audit) ─────────────────────────────────────────────────
router.post('/vehicules/:id/immobiliser', authorize('super_admin'), sensitiveRateLimiter, auditAction('CREATE', 'immobilisation'), fleetCtrl.immobiliser);
router.post('/vehicules/:id/reactiver', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('CREATE', 'reactivation'), fleetCtrl.reactiver);

// ─── Configuration boîtier (avec audit) ─────────────────────────────────────
router.put('/vehicules/:id/boitier', authorize('super_admin'), sensitiveRateLimiter, auditAction('UPDATE', 'boitier'), fleetCtrl.configurerBoitier);

// ─── Audit (super_admin uniquement — journal d'immobilisation) ──────────────
router.get('/audit', authorize('super_admin'), fleetCtrl.getAudit);

// ─── Paramètres (avec audit) ────────────────────────────────────────────────
router.get('/parametres', authorize('super_admin'), fleetCtrl.getParametres);
router.put('/parametres', authorize('super_admin'), sensitiveRateLimiter, auditAction('UPDATE', 'parametre_fleet'), fleetCtrl.updateParametres);

export default router;
