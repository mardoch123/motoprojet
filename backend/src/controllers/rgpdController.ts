import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import { AppError } from '../utils/errors.js';
import { writeAuditLog } from '../services/audit.js';
import type { AuthRequest } from '../types/index.js';

/**
 * GET /api/v1/rgpd/mes-donnees
 * Retourne toutes les données personnelles de l'utilisateur connecté.
 * Droit d'accès RGPD (Article 15).
 */
export async function getMesDonnees(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const userId = req.user!.sub;

    // Données utilisateur
    const { rows: user } = await pool.query(
      `SELECT id, telephone, role, statut, date_creation, derniere_activite
       FROM users WHERE id = $1`,
      [userId],
    );
    if (user.length === 0) throw AppError.notFound('Utilisateur non trouvé');

    // Données chauffeur (si applicable)
    let chauffeur = null;
    let affectations: any[] = [];
    let paiements: any[] = [];

    const { rows: chauffeurs } = await pool.query(
      `SELECT id, nom, adresse, contact_urgence, objectif_journalier, statut, date_creation
       FROM chauffeurs WHERE user_id = $1`,
      [userId],
    );
    if (chauffeurs.length > 0) {
      chauffeur = chauffeurs[0];

      // Affectations
      const { rows: affs } = await pool.query(
        `SELECT a.id, v.plaque, v.type, a.date_debut, a.date_fin
         FROM affectations a
         JOIN vehicules v ON v.id = a.vehicule_id
         WHERE a.chauffeur_id = $1
         ORDER BY a.date_debut DESC`,
        [chauffeur.id],
      );
      affectations = affs;

      // Paiements
      const { rows: pays } = await pool.query(
        `SELECT id, montant, date, mode, date_enregistrement
         FROM paiements WHERE chauffeur_id = $1
         ORDER BY date DESC LIMIT 100`,
        [chauffeur.id],
      );
      paiements = pays;
    }

    // Consentements
    const { rows: consentements } = await pool.query(
      `SELECT type, accepte, date_consentement, date_retrait
       FROM rgpd_consentements WHERE user_id = $1`,
      [userId],
    );

    // Événements de sécurité (derniers 90 jours)
    const { rows: securityEvents } = await pool.query(
      `SELECT type, severity, date_event, ip_address
       FROM security_events WHERE user_id = $1
       AND date_event > NOW() - INTERVAL '90 days'
       ORDER BY date_event DESC LIMIT 50`,
      [userId],
    );

    res.json({
      success: true,
      data: {
        utilisateur: user[0],
        chauffeur,
        affectations,
        paiements: { total: paiements.length, derniers: paiements },
        consentements,
        evenements_securite: securityEvents,
      },
    });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/rgpd/suppression
 * Demande de suppression de compte (droit à l'oubli — Article 17).
 * La demande est mise en attente pour traitement par le Super Admin.
 */
export async function demanderSuppression(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const userId = req.user!.sub;
    const { motif } = req.body;

    if (!motif || motif.length < 10) {
      throw AppError.badRequest('Veuillez fournir un motif (min 10 caractères)');
    }

    // Vérifier qu'il n'y a pas déjà une demande en attente
    const { rows: existing } = await pool.query(
      `SELECT id FROM rgpd_demandes_suppression
       WHERE user_id = $1 AND statut = 'en_attente'`,
      [userId],
    );
    if (existing.length > 0) {
      throw AppError.conflict('Une demande de suppression est déjà en cours');
    }

    // Récupérer le téléphone pour la demande
    const { rows: users } = await pool.query(
      `SELECT telephone FROM users WHERE id = $1`,
      [userId],
    );

    await pool.query(
      `INSERT INTO rgpd_demandes_suppression (user_id, telephone, motif)
       VALUES ($1, $2, $3)`,
      [userId, users[0]?.telephone, motif],
    );

    await writeAuditLog(userId, 'DEMANDE_SUPPRESSION_RGPD', userId, { motif });

    res.json({
      success: true,
      data: {
        message: 'Votre demande de suppression a été enregistrée. Elle sera traitée dans les 30 jours.',
      },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/rgpd/demandes
 * Liste des demandes de suppression (Super Admin uniquement).
 */
export async function listDemandes(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { rows } = await pool.query(`
      SELECT d.id, d.user_id, d.telephone, d.motif, d.statut,
             d.date_demande, d.traite_le, d.anonymise,
             u.role AS user_role
      FROM rgpd_demandes_suppression d
      LEFT JOIN users u ON u.id = d.user_id
      ORDER BY d.date_demande DESC
    `);

    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/rgpd/demandes/:id/anonymiser
 * Anonymise les données d'un utilisateur (Super Admin).
 * Remplace les données personnelles par des valeurs anonymes.
 */
export async function anonymiserDonnees(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const adminId = req.user!.sub;
    const { id: demandeId } = req.params;

    // Récupérer la demande
    const { rows: demandes } = await pool.query(
      `SELECT * FROM rgpd_demandes_suppression WHERE id = $1`,
      [demandeId],
    );
    if (demandes.length === 0) throw AppError.notFound('Demande non trouvée');

    const demande = demandes[0];
    if (demande.statut === 'traitee') {
      throw AppError.badRequest('Cette demande a déjà été traitée');
    }

    if (!demande.user_id) {
      throw AppError.badRequest('Utilisateur associé introuvable');
    }

    // Anonymiser les données
    await pool.query('BEGIN');

    // 1. Anonymiser l'utilisateur
    await pool.query(
      `UPDATE users SET
         telephone = 'ANONYMISE_' || id::text,
         pin_hash = 'anonyme',
         statut = 'desactive',
         derniere_activite = NULL
       WHERE id = $1`,
      [demande.user_id],
    );

    // 2. Anonymiser le chauffeur (si existe)
    await pool.query(
      `UPDATE chauffeurs SET
         nom = 'ANONYMISE',
         piece_identite = NULL,
         photo_url = NULL,
         adresse = NULL,
         contact_urgence = NULL,
         numero_cni = NULL,
         email = NULL,
         date_naissance = NULL,
         lieu_naissance = NULL,
         profession = NULL
       WHERE user_id = $1`,
      [demande.user_id],
    );

    // 3. Anonymiser les garants associés
    await pool.query(
      `UPDATE garants SET
         nom = 'ANONYMISE',
         prenom = '',
         telephone = 'ANONYMISE',
         email = NULL,
         adresse = NULL,
         piece_identite_numero = NULL,
         photo_url = NULL
       WHERE user_id = $1`,
      [demande.user_id],
    );

    // 4. Marquer la demande comme traitée
    await pool.query(
      `UPDATE rgpd_demandes_suppression SET
         statut = 'traitee',
         traite_par = $1,
         traite_le = NOW(),
         anonymise = TRUE
       WHERE id = $2`,
      [adminId, demandeId],
    );

    await pool.query('COMMIT');

    await writeAuditLog(adminId, 'ANONYMISATION_RGPD', demande.user_id, {
      demande_id: demandeId,
      motif: demande.motif,
    });

    res.json({
      success: true,
      data: { message: 'Données anonymisées avec succès' },
    });
  } catch (err) {
    await pool.query('ROLLBACK').catch(() => {});
    next(err);
  }
}

/**
 * PUT /api/v1/rgpd/consentement
 * Met à jour un consentement de l'utilisateur.
 */
export async function updateConsentement(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const userId = req.user!.sub;
    const { type, accepte } = req.body;

    const typesValides = [
      'collecte_donnees', 'photos', 'localisation',
      'notifications', 'conservation_pieces_identite',
    ];

    if (!typesValides.includes(type)) {
      throw AppError.badRequest(`Type de consentement invalide. Valeurs : ${typesValides.join(', ')}`);
    }

    if (accepte) {
      await pool.query(
        `INSERT INTO rgpd_consentements (user_id, type, accepte, date_consentement)
         VALUES ($1, $2, TRUE, NOW())
         ON CONFLICT (user_id, type) DO UPDATE SET
           accepte = TRUE, date_consentement = NOW(), date_retrait = NULL`,
        [userId, type],
      );
    } else {
      await pool.query(
        `INSERT INTO rgpd_consentements (user_id, type, accepte, date_retrait)
         VALUES ($1, $2, FALSE, NOW())
         ON CONFLICT (user_id, type) DO UPDATE SET
           accepte = FALSE, date_retrait = NOW()`,
        [userId, type],
      );
    }

    res.json({ success: true, data: { message: 'Consentement mis à jour' } });
  } catch (err) { next(err); }
}
