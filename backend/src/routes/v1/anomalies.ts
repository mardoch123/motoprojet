import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import {
  getAnomalies,
  getAnomaliesStats,
  getAnomalieById,
  updateAnomalieStatut,
  forceScan,
} from '../../controllers/anomaliesController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

// Toutes les routes nécessitent l'authentification + rôle admin/gestionnaire
router.use(authenticate);
router.use(authorize('super_admin', 'gestionnaire'));

/**
 * GET /api/v1/anomalies
 * Liste des anomalies détectées par l'IA
 */
router.get('/', getAnomalies);

/**
 * GET /api/v1/anomalies/stats
 * Statistiques globales sur les anomalies
 */
router.get('/stats', getAnomaliesStats);

/**
 * POST /api/v1/anomalies/scan
 * Force un scan manuel des anomalies (super_admin uniquement)
 */
router.post('/scan', authorize('super_admin'), sensitiveRateLimiter, forceScan);

/**
 * GET /api/v1/anomalies/:id
 * Détail d'une anomalie
 */
router.get('/:id', getAnomalieById);

/**
 * PUT /api/v1/anomalies/:id/statut
 * Change le statut d'une anomalie (avec audit)
 */
router.put('/:id/statut', sensitiveRateLimiter, auditAction('UPDATE', 'anomalie'), updateAnomalieStatut);

export default router;
