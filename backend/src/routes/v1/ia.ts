import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import {
  getRecommandation,
  getHistorique,
  updateObjectif,
} from '../../controllers/iaController.js';

const router = Router();

// Toutes les routes IA nécessitent une authentification
router.use(authenticate);

/**
 * POST /api/v1/ia/recommandations
 * Demander une recommandation IA (chauffeur uniquement)
 */
router.post(
  '/recommandations',
  authorize('chauffeur'),
  getRecommandation,
);

/**
 * GET /api/v1/ia/historique
 * Historique des recommandations et performances (chauffeur)
 */
router.get(
  '/historique',
  authorize('chauffeur'),
  getHistorique,
);

/**
 * PUT /api/v1/ia/objectif
 * Mettre à jour l'objectif de revenu journalier (chauffeur)
 */
router.put(
  '/objectif',
  authorize('chauffeur'),
  updateObjectif,
);

export default router;
