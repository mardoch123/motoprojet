import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import {
  listNotifications,
  getNotificationStats,
  markAsRead,
  retryFailedNotifications,
} from '../../controllers/notificationsController.js';

const router = Router();

router.use(authenticate);

// Stats : admin + gestionnaire
router.get('/stats', authorize('super_admin', 'gestionnaire'), getNotificationStats);
router.post('/retry', authorize('super_admin'), retryFailedNotifications);

// Liste : tous les rôles authentifiés (le contrôleur filtre par user_id)
router.get('/', listNotifications);
router.put('/:id/lu', markAsRead);

export default router;
