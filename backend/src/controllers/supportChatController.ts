import { Request, Response, NextFunction } from 'express';
import { logger } from '../utils/logger.js';
import { getSupportReponse } from '../services/supportChatService.js';

/**
 * Contrôleur du chatbot d'aide fonctionnelle.
 *
 * Accessible à TOUS les rôles (chauffeur, gestionnaire, super_admin).
 * Répond aux questions d'usage de l'app, PAS aux questions métier.
 */

/**
 * POST /support/chat
 * Envoie une question au chatbot d'aide.
 *
 * Body : { question: string, historique?: { role: string, contenu: string }[] }
 * Response : { reponse, hors_perimetre, suggestions, modele_utilise }
 */
export async function chat(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { question, historique } = req.body;

    if (!question || typeof question !== 'string' || question.trim().length === 0) {
      res.status(400).json({ error: 'La question est requise.' });
      return;
    }

    if (question.trim().length > 500) {
      res.status(400).json({ error: 'Question trop longue (max 500 caractères).' });
      return;
    }

    // Valider l'historique optionnel
    let histValide: { role: 'user' | 'assistant'; contenu: string }[] = [];
    if (Array.isArray(historique)) {
      histValide = historique
        .filter((m: any) => m && typeof m === 'object' && m.role && m.contenu)
        .slice(-10) // Max 10 messages d'historique
        .map((m: any) => ({
          role: m.role === 'user' ? 'user' as const : 'assistant' as const,
          contenu: String(m.contenu).substring(0, 500),
        }));
    }

    const userId = (req as any).user?.id;
    const userRole = (req as any).user?.role;
    logger.info(`[Support-Chat] Question de ${userId} (${userRole}): ${question.substring(0, 80)}...`);

    const result = await getSupportReponse(question.trim(), histValide);

    if (result.hors_perimetre) {
      logger.info(`[Support-Chat] Question hors périmètre détectée pour ${userId}`);
    }

    res.json({ data: result });
  } catch (err: any) {
    logger.error(`[Support-Chat] Erreur: ${err.message}`);
    next(err);
  }
}
