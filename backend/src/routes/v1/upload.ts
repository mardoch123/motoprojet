import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { presignUpload } from '../../controllers/uploadController.js';

const router = Router();

router.use(authenticate);
router.post('/presign', presignUpload);

export default router;
