import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import {
  getPatrimoine,
  createSnapshot,
  listDepots,
  createDepot,
  rapprocherDepot,
  exportComptable,
  getRapportMensuel,
  listApports,
  createApport,
  updateApport,
  deleteApport,
  enregistrerVersement,
  listVersements,
} from '../../controllers/financesController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

router.use(authenticate);
router.use(authorize('super_admin'));

// Patrimoine
router.get('/patrimoine', getPatrimoine);
router.post('/patrimoine/snapshot', sensitiveRateLimiter, auditAction('CREATE', 'patrimoine_snapshot'), createSnapshot);

// Dépôts banque (avec audit)
router.get('/depots', listDepots);
router.post('/depots', sensitiveRateLimiter, auditAction('CREATE', 'depot'), createDepot);
router.post('/depots/:id/rapprocher', sensitiveRateLimiter, auditAction('UPDATE', 'depot'), rapprocherDepot);

// Export comptable
router.get('/export', exportComptable);

// Rapport mensuel
router.get('/rapport/:mois', getRapportMensuel);

// Apports personnels (avec audit)
router.get('/apports', listApports);
router.post('/apports', sensitiveRateLimiter, auditAction('CREATE', 'apport'), createApport);
router.put('/apports/:id', sensitiveRateLimiter, auditAction('UPDATE', 'apport'), updateApport);
router.delete('/apports/:id', sensitiveRateLimiter, auditAction('DELETE', 'apport'), deleteApport);
router.post('/apports/:id/versement', sensitiveRateLimiter, auditAction('CREATE', 'versement'), enregistrerVersement);
router.get('/apports/versements', listVersements);

export default router;
