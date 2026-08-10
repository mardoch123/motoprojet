import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import { getDashboard } from '../../controllers/dashboardController.js';
import { getDashboardRetards, getDashboardRecuperation, triggerImpayesJob } from '../../controllers/dashboardRetardsController.js';
import { getProchainAchat } from '../../controllers/dashboardProchainAchatController.js';

const router = Router();

router.use(authenticate);

router.get('/', authorize('super_admin', 'gestionnaire'), getDashboard);
router.get('/prochain-achat', authorize('super_admin'), getProchainAchat);
router.get('/retards', authorize('super_admin', 'gestionnaire'), getDashboardRetards);
router.get('/recuperation', authorize('super_admin', 'gestionnaire'), getDashboardRecuperation);
router.post('/jobs/impayes', authorize('super_admin'), triggerImpayesJob);

export default router;
