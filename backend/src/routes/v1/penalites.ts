import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import * as penalitesCtrl from '../../controllers/penalitesController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

// ─── Authentification requise sur toutes les routes ─────────────────────────
router.use(authenticate);

// ─── Pénalités ──────────────────────────────────────────────────────────────
router.get('/', authorize('super_admin', 'gestionnaire'), penalitesCtrl.listPenalites);
router.get('/:vehiculeId/total', authorize('super_admin', 'gestionnaire'), penalitesCtrl.getTotalPenalites);
router.post('/:id/annuler', authorize('super_admin'), sensitiveRateLimiter, auditAction('UPDATE', 'penalite'), penalitesCtrl.annulerPenalite);

// ─── Paramètres ─────────────────────────────────────────────────────────────
router.get('/parametres', authorize('super_admin'), penalitesCtrl.listParametres);
router.put('/parametres/:type', authorize('super_admin'), sensitiveRateLimiter, auditAction('UPDATE', 'parametre_penalite'), penalitesCtrl.updateParametres);

// ─── Exemptions ─────────────────────────────────────────────────────────────
router.get('/exemptions', authorize('super_admin'), penalitesCtrl.listExemptions);
router.post('/exemptions', authorize('super_admin'), sensitiveRateLimiter, auditAction('CREATE', 'exemption'), penalitesCtrl.ajouterExemption);
router.delete('/exemptions/:id', authorize('super_admin'), sensitiveRateLimiter, auditAction('DELETE', 'exemption'), penalitesCtrl.supprimerExemption);

// ─── Paiements anticipés ────────────────────────────────────────────────────
router.post('/paiement-anticipe', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('CREATE', 'paiement_anticipe'), penalitesCtrl.enregistrerPaiementAnticipe);

// ─── Job ────────────────────────────────────────────────────────────────────
router.post('/job/force', authorize('super_admin'), sensitiveRateLimiter, penalitesCtrl.forceJob);

export default router;
