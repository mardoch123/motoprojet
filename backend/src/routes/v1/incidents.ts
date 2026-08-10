import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import { validate } from '../../middleware/validate.js';
import { createIncidentSchema, updateIncidentSchema } from '../../validators/schemas.js';
import {
  listIncidents,
  listActiveIncidents,
  createIncident,
  updateIncident,
  getIncidentsByVehicule,
} from '../../controllers/incidentController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

router.use(authenticate);

// Liste des incidents (tous rôles authentifiés, avec contrôle de périmètre)
router.get('/', authorize('super_admin', 'gestionnaire', 'chauffeur'), listIncidents);

// Incidents actifs (pour exclusion calcul impayés)
router.get('/actifs', authorize('super_admin', 'gestionnaire'), listActiveIncidents);

// Historique par véhicule
router.get('/vehicule/:vehiculeId', authorize('super_admin', 'gestionnaire'), getIncidentsByVehicule);

// Création (tous rôles, avec audit)
router.post('/', authorize('super_admin', 'gestionnaire', 'chauffeur'), sensitiveRateLimiter, auditAction('CREATE', 'incident'), validate(createIncidentSchema), createIncident);

// Mise à jour (admin et gestionnaire uniquement, avec audit)
router.patch('/:id', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('UPDATE', 'incident'), validate(updateIncidentSchema), updateIncident);

export default router;
