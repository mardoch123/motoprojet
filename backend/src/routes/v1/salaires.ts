import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import {
  listSalaires,
  getCumuls,
  getParametres,
  updateParametres,
  calculer,
  valider,
  annuler,
  simuler,
  createSalaire,
} from '../../controllers/salaireController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

// Toutes les routes salaires sont strictement réservées au Super Admin
router.use(authenticate);
router.use(authorize('super_admin'));

// Paramètres (avec audit)
router.get('/parametres', getParametres);
router.put('/parametres', sensitiveRateLimiter, auditAction('UPDATE', 'parametre_salaire'), updateParametres);

// Cumuls par profil
router.get('/cumuls', getCumuls);

// Simulation d'impact
router.post('/simuler', simuler);

// Calcul des salaires (avec audit)
router.post('/calculer', sensitiveRateLimiter, auditAction('CREATE', 'salaire'), calculer);

// Validation / annulation (avec audit)
router.post('/:id/valider', sensitiveRateLimiter, auditAction('UPDATE', 'salaire'), valider);
router.post('/:id/annuler', sensitiveRateLimiter, auditAction('UPDATE', 'salaire'), annuler);

// Liste + création manuelle (legacy)
router.get('/', listSalaires);
router.post('/', sensitiveRateLimiter, auditAction('CREATE', 'salaire'), createSalaire);

export default router;
