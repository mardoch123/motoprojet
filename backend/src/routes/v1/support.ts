import { Router } from 'express';
import { authenticate } from '../../middleware/auth.js';
import { chat } from '../../controllers/supportChatController.js';

const router = Router();

// Accessible à tous les utilisateurs authentifiés (tous rôles)
router.use(authenticate);

/**
 * @swagger
 * /api/v1/support/chat:
 *   post:
 *     summary: Chatbot d'aide fonctionnelle
 *     description: |
 *       Répond aux questions d'utilisation de l'application.
 *       Ne répond PAS aux questions financières/métier (redirige vers l'admin).
 *       Accessible à tous les rôles.
 *     tags: [Support]
 *     security:
 *       - bearerAuth: []
 *     requestBody:
 *       content:
 *         application/json:
 *           schema:
 *             type: object
 *             required: [question]
 *             properties:
 *               question:
 *                 type: string
 *                 maxLength: 500
 *               historique:
 *                 type: array
 *                 items:
 *                   type: object
 *                   properties:
 *                     role:
 *                       type: string
 *                       enum: [user, assistant]
 *                     contenu:
 *                       type: string
 *     responses:
 *       200:
 *         description: Réponse du chatbot
 *         content:
 *           application/json:
 *             schema:
 *               type: object
 *               properties:
 *                 data:
 *                   type: object
 *                   properties:
 *                     reponse:
 *                       type: string
 *                     hors_perimetre:
 *                       type: boolean
 *                     suggestions:
 *                       type: array
 *                       items:
 *                         type: string
 *                     modele_utilise:
 *                       type: string
 */
router.post('/chat', chat);

export default router;
