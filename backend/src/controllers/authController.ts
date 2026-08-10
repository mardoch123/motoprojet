import { Request, Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/db.js';
import { generateTokens, refreshAccessToken } from '../middleware/auth.js';
import { AppError } from '../utils/errors.js';
import { writeAuditLog, writeSecurityEvent } from '../services/audit.js';
import { recordLoginFailure, resetLoginAttempts } from '../middleware/security.js';
import type { AuthRequest, ApiResponse } from '../types/index.js';

/**
 * POST /api/v1/auth/login
 */
export async function login(req: Request, res: Response, next: NextFunction) {
  try {
    const { telephone, pin } = req.body;

    const { rows: users } = await pool.query(
      `SELECT * FROM users WHERE telephone = $1 AND statut = 'actif'`,
      [telephone],
    );
    if (users.length === 0) {
      // Tenter d'enregistrer l'échec même si l'utilisateur n'est pas trouvé
      throw AppError.unauthorized('Identifiants incorrects');
    }

    const user = users[0];
    const valid = await bcrypt.compare(pin, user.pin_hash);
    if (!valid) {
      // Enregistrer l'échec de connexion + verrouillage progressif
      await recordLoginFailure(telephone, user.id, req.ip);
      throw AppError.unauthorized('Identifiants incorrects');
    }

    // Connexion réussie : réinitialiser les compteurs
    await resetLoginAttempts(user.id);

    const { accessToken, refreshToken } = generateTokens(user.id, user.role, user.telephone);

    // Mettre à jour la dernière activité
    await pool.query(`UPDATE users SET derniere_activite = NOW() WHERE id = $1`, [user.id]);

    // Logger l'événement de sécurité
    await writeSecurityEvent(
      user.id,
      'login_success',
      'info',
      { telephone: user.telephone, role: user.role },
      { ip: req.ip, userAgent: req.headers['user-agent'] },
    ).catch(() => {});

    await writeAuditLog(user.id, 'LOGIN', 'auth', { telephone: user.telephone, role: user.role });

    const body: ApiResponse = {
      success: true,
      data: {
        access_token: accessToken,
        refresh_token: refreshToken,
        user_id: user.id,
        role: user.role,
        statut: user.statut,
        must_change_pin: user.must_change_pin,
        onboarding_completed: user.onboarding_completed ?? false,
      },
    };
    res.json(body);
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/auth/refresh
 */
export async function refresh(req: Request, res: Response, next: NextFunction) {
  try {
    const { refresh_token } = req.body;
    const accessToken = refreshAccessToken(refresh_token);
    res.json({ success: true, data: { access_token: accessToken } });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/auth/me
 */
export async function getProfile(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const userId = req.user!.sub;
    const { rows } = await pool.query(
      `SELECT id, telephone, role, statut, must_change_pin, pin_changed_at, date_creation FROM users WHERE id = $1`,
      [userId],
    );
    if (rows.length === 0) throw AppError.notFound('Utilisateur non trouvé');

    const user = rows[0];
    if (user.role === 'chauffeur') {
      const { rows: chauffeurs } = await pool.query(
        `SELECT * FROM chauffeurs WHERE user_id = $1`,
        [userId],
      );
      user.chauffeur = chauffeurs[0] ?? null;
    }

    res.json({ success: true, data: user });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/auth/change-pin
 * L'utilisateur change son propre PIN (doit fournir l'ancien PIN).
 */
export async function changePin(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const userId = req.user!.sub;
    const { old_pin, new_pin } = req.body;

    // Récupérer le hash actuel
    const { rows } = await pool.query(`SELECT pin_hash FROM users WHERE id = $1`, [userId]);
    if (rows.length === 0) throw AppError.notFound('Utilisateur non trouvé');

    const valid = await bcrypt.compare(old_pin, rows[0].pin_hash);
    if (!valid) {
      throw AppError.badRequest('Ancien PIN incorrect');
    }

    // Hacher le nouveau PIN et mettre à jour
    const newHash = await bcrypt.hash(new_pin, 10);
    await pool.query(
      `UPDATE users SET pin_hash = $1, must_change_pin = FALSE, pin_changed_at = NOW() WHERE id = $2`,
      [newHash, userId],
    );

    await writeAuditLog(userId, 'CHANGE_PIN', 'auth', { user_id: userId });

    res.json({ success: true, data: { message: 'PIN modifié avec succès' } });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/auth/reset-pin
 * Super Admin réinitialise le PIN d'un chauffeur.
 * Génère un PIN temporaire à 4 chiffres et force le changement à la 1ère connexion.
 */
export async function resetPin(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const adminId = req.user!.sub;
    const { user_id } = req.body;

    // Vérifier que la cible existe
    const { rows: targets } = await pool.query(
      `SELECT id, telephone, role FROM users WHERE id = $1`,
      [user_id],
    );
    if (targets.length === 0) throw AppError.notFound('Utilisateur non trouvé');

    const target = targets[0];

    // Un admin ne peut réinitialiser que des chauffeurs (pas d'autres admins)
    if (target.role !== 'chauffeur') {
      throw AppError.forbidden('Seuls les PINs des chauffeurs peuvent être réinitialisés');
    }

    // Générer un PIN temporaire à 4 chiffres
    const tempPin = Math.floor(1000 + Math.random() * 9000).toString();
    const tempHash = await bcrypt.hash(tempPin, 10);

    await pool.query(
      `UPDATE users SET pin_hash = $1, must_change_pin = TRUE, pin_changed_at = NULL WHERE id = $2`,
      [tempHash, user_id],
    );

    await writeAuditLog(adminId, 'RESET_PIN', user_id, {
      cible_telephone: target.telephone,
    });

    res.json({
      success: true,
      data: {
        message: 'PIN réinitialisé avec succès',
        temporary_pin: tempPin,
        user_id: user_id,
        telephone: target.telephone,
      },
    });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/auth/request-pin-reset
 * Un chauffeur demande la réinitialisation de son PIN.
 * Crée une notification pour l'admin — pas de self-service.
 */
export async function requestPinReset(req: Request, res: Response, next: NextFunction) {
  try {
    const { telephone } = req.body;

    const { rows } = await pool.query(
      `SELECT id, telephone, role FROM users WHERE telephone = $1 AND statut = 'actif'`,
      [telephone],
    );
    if (rows.length === 0) {
      // Ne pas révéler si le numéro existe ou non (sécurité)
      res.json({
        success: true,
        data: { message: 'Si ce numéro existe, une demande a été envoyée à l\'administrateur.' },
      });
      return;
    }

    const user = rows[0];

    // Créer une notification pour les admins
    await pool.query(
      `INSERT INTO notifications_log (user_id, titre, message, type)
       VALUES (
         (SELECT id FROM users WHERE role = 'super_admin' LIMIT 1),
         $1, $2, 'warning'
       )`,
      [
        `Demande de réinitialisation PIN`,
        `L'utilisateur ${telephone} demande une réinitialisation de son PIN.`,
      ],
    );

    await writeAuditLog(user.id, 'REQUEST_PIN_RESET', 'auth', { telephone });

    res.json({
      success: true,
      data: { message: 'Si ce numéro existe, une demande a été envoyée à l\'administrateur.' },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/auth/chauffeurs-for-reset
 * Liste les chauffeurs avec leur statut PIN (pour l'écran admin reset).
 */
export async function listChauffeursForReset(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { rows } = await pool.query(`
      SELECT u.id, u.telephone, u.must_change_pin, u.pin_changed_at, u.derniere_activite,
             c.nom, c.statut AS chauffeur_statut
      FROM users u
      LEFT JOIN chauffeurs c ON c.user_id = u.id
      WHERE u.role = 'chauffeur' AND u.statut = 'actif'
      ORDER BY c.nom
    `);

    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

/**
 * PATCH /api/v1/auth/activity
 * Met à jour la dernière activité de l'utilisateur (heartbeat).
 */
export async function updateActivity(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const userId = req.user!.sub;
    await pool.query(`UPDATE users SET derniere_activite = NOW() WHERE id = $1`, [userId]);
    res.json({ success: true });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/auth/onboarding/complete
 * Marque l'onboarding comme complété pour l'utilisateur connecté.
 */
export async function completeOnboarding(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const userId = req.user!.sub;

    await pool.query(
      `UPDATE users SET onboarding_completed = TRUE WHERE id = $1`,
      [userId],
    );

    await writeAuditLog(userId, 'ONBOARDING_COMPLETE', 'auth', { user_id: userId });

    res.json({ success: true, data: { message: 'Onboarding terminé' } });
  } catch (err) { next(err); }
}
