import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import { AppError } from '../utils/errors.js';
import { writeAuditLog } from '../services/audit.js';
import { emit } from '../services/events.js';
import type { AuthRequest } from '../types/index.js';

/**
 * GET /api/v1/chauffeurs/:chauffeurId/affectations
 * Historique complet des affectations d'un chauffeur.
 */
export async function listAffectations(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const chauffeurId = req.params.chauffeurId as string;

    const { rows } = await pool.query(`
      SELECT a.*, v.plaque, v.type, v.marque, v.immatriculation,
             COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0) AS total_verse
      FROM affectations a
      JOIN vehicules v ON a.vehicule_id = v.id
      LEFT JOIN paiements p ON p.vehicule_id = v.id AND p.chauffeur_id = a.chauffeur_id
        AND p.date >= a.date_debut AND (a.date_fin IS NULL OR p.date <= a.date_fin)
      WHERE a.chauffeur_id = $1
      GROUP BY a.id, v.plaque, v.type, v.marque, v.immatriculation
      ORDER BY a.date_debut DESC`,
      [chauffeurId],
    );

    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/chauffeurs/:chauffeurId/affectations
 * Crée une affectation. Termine automatiquement l'affectation précédente si elle existe.
 */
export async function createAffectation(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const chauffeurId = req.params.chauffeurId as string;
    const { vehicule_id, date_debut } = req.body;

    // Vérifier que le chauffeur existe
    const { rows: chauffeurs } = await pool.query(`SELECT id FROM chauffeurs WHERE id = $1`, [chauffeurId]);
    if (chauffeurs.length === 0) throw AppError.notFound('Chauffeur non trouvé');

    // Vérifier que le véhicule est libre (pas d'affectation active)
    const { rows: conflits } = await pool.query(`
      SELECT a.id, c.nom, v.plaque
      FROM affectations a
      JOIN chauffeurs c ON a.chauffeur_id = c.id
      JOIN vehicules v ON a.vehicule_id = v.id
      WHERE a.vehicule_id = $1 AND a.date_fin IS NULL`,
      [vehicule_id],
    );
    if (conflits.length > 0) {
      throw AppError.conflict(
        `Le véhicule ${conflits[0].plaque} est déjà affecté à ${conflits[0].nom}`,
      );
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Terminer l'ancienne affectation active du chauffeur (s'il y en a une)
      await client.query(
        `UPDATE affectations SET date_fin = CURRENT_DATE WHERE chauffeur_id = $1 AND date_fin IS NULL`,
        [chauffeurId],
      );

      // Créer la nouvelle
      const { rows } = await client.query(
        `INSERT INTO affectations (chauffeur_id, vehicule_id, date_debut)
         VALUES ($1, $2, COALESCE($3, CURRENT_DATE))
         RETURNING *`,
        [chauffeurId, vehicule_id, date_debut ?? null],
      );

      await client.query('COMMIT');

      await writeAuditLog(req.user!.sub, 'CREATE_AFFECTATION', rows[0].id, {
        chauffeur_id: chauffeurId, vehicule_id,
      });

      // Événement cross-module
      await emit('AFFECTATION_CREE', { chauffeur_id: chauffeurId, vehicule_id });

      res.status(201).json({ success: true, data: rows[0] });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/affectations/:id/terminer
 * Termine une affectation (met date_fin).
 */
export async function terminerAffectation(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const affectationId = req.params.id as string;
    const { date_fin } = req.body;

    const { rows } = await pool.query(`
      UPDATE affectations
      SET date_fin = COALESCE($2, CURRENT_DATE)
      WHERE id = $1 AND date_fin IS NULL
      RETURNING *`,
      [affectationId, date_fin ?? null],
    );

    if (rows.length === 0) throw AppError.notFound('Affectation non trouvée ou déjà terminée');

    await writeAuditLog(req.user!.sub, 'END_AFFECTATION', affectationId, {});
    await emit('AFFECTATION_TERMINEE', { affectation_id: affectationId, chauffeur_id: rows[0].chauffeur_id });

    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
}
