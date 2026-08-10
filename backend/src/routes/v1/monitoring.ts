import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import {
  getDashboard,
  getApiMetricsEndpoint,
  getDbMetricsEndpoint,
  getJobsEndpoint,
  getDetailedHealth,
} from '../../controllers/monitoringController.js';

const router = Router();

/**
 * Routes de monitoring.
 *
 * - /health est public (utilisé par les load balancers)
 * - Les autres routes nécessitent une authentification super_admin
 */

// Health check détaillé (public — utilisé par uptime monitors)
router.get('/health', getDetailedHealth);

// Dashboard complet (super_admin uniquement)
router.get('/', authenticate, authorize('super_admin'), getDashboard);

// Métriques API (super_admin)
router.get('/api', authenticate, authorize('super_admin'), getApiMetricsEndpoint);

// Métriques DB (super_admin)
router.get('/db', authenticate, authorize('super_admin'), getDbMetricsEndpoint);

// État des jobs (super_admin)
router.get('/jobs', authenticate, authorize('super_admin'), getJobsEndpoint);

export default router;
