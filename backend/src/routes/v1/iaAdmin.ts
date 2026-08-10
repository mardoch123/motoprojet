import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import {
  getRapport,
  chat,
  getHistorique,
  setObjectif,
  getObjectifs,
} from '../../controllers/iaAdminController.js';

const router = Router();

// Toutes les routes IA admin nécessitent une authentification + rôle super_admin
router.use(authenticate);
router.use(authorize('super_admin'));

/**
 * GET /api/v1/ia/admin/rapport
 * Génère ou retourne le dernier rapport IA hebdomadaire.
 * Query : ?force=true pour forcer la régénération
 */
router.get('/rapport', getRapport);

/**
 * POST /api/v1/ia/admin/chat
 * Chat libre avec l'IA — question en langage naturel.
 * Body : { question: string }
 */
router.post('/chat', chat);

/**
 * GET /api/v1/ia/admin/historique
 * Liste des rapports et sessions de chat passés.
 * Query : ?type=hebdo|chat&limit=20
 */
router.get('/historique', getHistorique);

/**
 * GET /api/v1/ia/admin/objectifs
 * Liste des objectifs globaux actifs.
 */
router.get('/objectifs', getObjectifs);

/**
 * PUT /api/v1/ia/admin/objectif
 * Définir un nouvel objectif global.
 * Body : { libelle, valeur_cible, unite, delai_mois }
 */
router.put('/objectif', setObjectif);

export default router;
