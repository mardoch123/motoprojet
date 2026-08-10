import { Response, NextFunction } from 'express';
import bcrypt from 'bcryptjs';
import pool from '../config/db.js';
import { AppError } from '../utils/errors.js';
import { writeAuditLog } from '../services/audit.js';
import type { AuthRequest, ApiResponse } from '../types/index.js';

/**
 * GET /api/v1/chauffeurs
 * Liste avec recherche (nom, téléphone) et filtre par statut.
 */
export async function listChauffeurs(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const search = (req.query.search as string) ?? '';
    const statut = (req.query.statut as string) ?? '';

    let query = `
      SELECT c.*, u.telephone, u.must_change_pin, u.derniere_activite,
             COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0) AS total_verse
      FROM chauffeurs c
      JOIN users u ON c.user_id = u.id
      LEFT JOIN paiements p ON p.chauffeur_id = c.id`;

    const conditions: string[] = [];
    const params: unknown[] = [];
    let paramIdx = 1;

    if (search) {
      conditions.push(`(c.nom ILIKE $${paramIdx} OR u.telephone ILIKE $${paramIdx})`);
      params.push(`%${search}%`);
      paramIdx++;
    }
    if (statut) {
      conditions.push(`c.statut = $${paramIdx}`);
      params.push(statut);
      paramIdx++;
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }
    query += ' GROUP BY c.id, u.telephone, u.must_change_pin, u.derniere_activite ORDER BY c.nom';

    const { rows } = await pool.query(query, params);
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/chauffeurs/:id
 * Fiche complète : infos + véhicule actuel + historique paiements + affectations.
 */
export async function getChauffeur(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const chauffeurId = req.params.id as string;

    // Infos chauffeur + user
    const { rows: chauffeurs } = await pool.query(`
      SELECT c.*, u.telephone, u.must_change_pin, u.derniere_activite, u.statut AS user_statut
      FROM chauffeurs c JOIN users u ON c.user_id = u.id
      WHERE c.id = $1`,
      [chauffeurId],
    );
    if (chauffeurs.length === 0) throw AppError.notFound('Chauffeur non trouvé');

    const chauffeur = chauffeurs[0];

    // Véhicule actuel (affectation active)
    const { rows: vehicules } = await pool.query(`
      SELECT v.id, v.plaque, v.type, v.statut AS vehicule_statut, a.date_debut
      FROM affectations a JOIN vehicules v ON a.vehicule_id = v.id
      WHERE a.chauffeur_id = $1 AND a.date_fin IS NULL`,
      [chauffeurId],
    );
    chauffeur.vehicule_actuel = vehicules[0] ?? null;

    // Historique affectations
    const { rows: affectations } = await pool.query(`
      SELECT a.*, v.plaque, v.type
      FROM affectations a JOIN vehicules v ON a.vehicule_id = v.id
      WHERE a.chauffeur_id = $1
      ORDER BY a.date_debut DESC`,
      [chauffeurId],
    );
    chauffeur.historique_affectations = affectations;

    // Derniers paiements (50 max)
    const { rows: paiements } = await pool.query(`
      SELECT p.*, v.plaque AS vehicule_plaque
      FROM paiements p LEFT JOIN vehicules v ON p.vehicule_id = v.id
      WHERE p.chauffeur_id = $1
      ORDER BY p.date DESC LIMIT 50`,
      [chauffeurId],
    );
    chauffeur.historique_paiements = paiements;

    // Stats
    const { rows: stats } = await pool.query(`
      SELECT
        COUNT(*) AS nb_paiements,
        COALESCE(SUM(montant), 0) AS total_verse,
        MAX(date) AS dernier_paiement,
        MIN(date) AS premier_paiement
      FROM paiements WHERE chauffeur_id = $1`,
      [chauffeurId],
    );
    chauffeur.stats = stats[0];

    res.json({ success: true, data: chauffeur });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/chauffeurs
 * Création : user + chauffeur en transaction. PIN temporaire, must_change_pin = TRUE.
 */
export async function createChauffeur(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { telephone, pin, nom, piece_identite, photo_url, adresse, contact_urgence, objectif_journalier } = req.body;

    const { rows: existing } = await pool.query(`SELECT id FROM users WHERE telephone = $1`, [telephone]);
    if (existing.length > 0) throw AppError.conflict('Ce numéro est déjà enregistré');

    const pinHash = await bcrypt.hash(pin, 10);

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const { rows: users } = await client.query(
        `INSERT INTO users (telephone, pin_hash, role, statut, must_change_pin) VALUES ($1, $2, 'chauffeur', 'actif', TRUE) RETURNING id`,
        [telephone, pinHash],
      );
      const userId = users[0].id;

      const { rows: chauffeurs } = await client.query(
        `INSERT INTO chauffeurs (user_id, nom, piece_identite, photo_url, adresse, contact_urgence, objectif_journalier)
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [userId, nom, piece_identite ?? null, photo_url ?? null, adresse ?? null, contact_urgence ?? null, objectif_journalier ?? 0],
      );

      await client.query('COMMIT');
      await writeAuditLog(req.user!.sub, 'CREATE_CHAUFFEUR', chauffeurs[0].id, { nom, telephone });

      res.status(201).json({ success: true, data: chauffeurs[0] });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/chauffeurs/:id
 * Mise à jour des infos chauffeur (pas le téléphone — celui-ci est dans users).
 */
export async function updateChauffeur(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const chauffeurId = req.params.id as string;
    const { nom, piece_identite, photo_url, adresse, contact_urgence, objectif_journalier, statut } = req.body;

    const { rows } = await pool.query(`
      UPDATE chauffeurs
      SET nom = COALESCE($2, nom),
          piece_identite = COALESCE($3, piece_identite),
          photo_url = COALESCE($4, photo_url),
          adresse = COALESCE($5, adresse),
          contact_urgence = COALESCE($6, contact_urgence),
          objectif_journalier = COALESCE($7, objectif_journalier),
          statut = COALESCE($8, statut)
      WHERE id = $1
      RETURNING *`,
      [chauffeurId, nom ?? null, piece_identite ?? null, photo_url ?? null, adresse ?? null, contact_urgence ?? null, objectif_journalier ?? null, statut ?? null],
    );

    if (rows.length === 0) throw AppError.notFound('Chauffeur non trouvé');

    await writeAuditLog(req.user!.sub, 'UPDATE_CHAUFFEUR', chauffeurId, {
      fields: Object.keys(req.body),
    });

    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
}
