import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import { AppError } from '../utils/errors.js';
import { writeAuditLog } from '../services/audit.js';
import type { AuthRequest } from '../types/index.js';

/**
 * GET /api/v1/incidents
 * Liste tous les incidents (filtres: vehicule_id, statut, type).
 */
export async function listIncidents(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { vehicule_id, statut, type, limit } = req.query;
    const lim = parseInt(limit as string) || 100;

    let query = `
      SELECT i.*, v.plaque AS vehicule_plaque, v.type AS vehicule_type,
             c.nom AS chauffeur_nom
      FROM incidents i
      LEFT JOIN vehicules v ON i.vehicule_id = v.id
      LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
      LEFT JOIN chauffeurs c ON c.id = a.chauffeur_id
      WHERE 1=1
    `;
    const params: any[] = [];
    let idx = 1;

    if (vehicule_id) {
      query += ` AND i.vehicule_id = $${idx++}`;
      params.push(vehicule_id);
    }
    if (statut) {
      query += ` AND i.statut = $${idx++}`;
      params.push(statut);
    }
    if (type) {
      query += ` AND i.type = $${idx++}`;
      params.push(type);
    }

    query += ` ORDER BY i.date DESC LIMIT $${idx}`;
    params.push(lim);

    const { rows } = await pool.query(query, params);
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/incidents/actifs
 * Liste des véhicules avec un incident actif (pour exclusion du calcul impayés).
 */
export async function listActiveIncidents(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { rows } = await pool.query(`
      SELECT i.id, i.vehicule_id, i.type, i.severity, i.date, i.statut,
             i.statut_reparation, v.plaque AS vehicule_plaque
      FROM incidents i
      JOIN vehicules v ON v.id = i.vehicule_id
      WHERE i.statut NOT IN ('resolu', 'classe_sans_suite')
      ORDER BY i.date DESC
    `);
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/incidents
 * Crée un incident et met à jour le statut du véhicule.
 * GPS (latitude/longitude) et photos (photo_urls) obligatoires.
 */
export async function createIncident(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const {
      vehicule_id, type, description, photo_url, photo_urls,
      severity, lieu, date, latitude, longitude,
    } = req.body;

    // ── Validations obligatoires ──
    if (!photo_urls || (Array.isArray(photo_urls) && photo_urls.length === 0)) {
      throw AppError.badRequest('Au moins une photo est obligatoire pour signaler un incident');
    }
    if (latitude == null || longitude == null) {
      throw AppError.badRequest('Les coordonnées GPS sont obligatoires (détection automatique)');
    }

    // Vérifier le véhicule
    const { rows: vehicules } = await pool.query(`SELECT id, plaque, statut FROM vehicules WHERE id = $1`, [vehicule_id]);
    if (vehicules.length === 0) throw AppError.notFound('Véhicule non trouvé');

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      // Créer l'incident avec GPS et photos
      const { rows } = await client.query(`
        INSERT INTO incidents (vehicule_id, type, description, photo_url, photo_urls,
                               severity, lieu, date, declared_by, statut,
                               latitude, longitude)
        VALUES ($1, $2, $3, $4, $5, $6, $7, COALESCE($8, CURRENT_DATE), $9, 'signale',
                $10, $11)
        RETURNING *`,
        [
          vehicule_id, type, description ?? null, photo_url ?? null,
          photo_urls, severity ?? 'moyenne', lieu ?? null,
          date ?? null, req.user?.sub ?? null,
          latitude, longitude,
        ],
      );

      const incident = rows[0];

      // Mettre à jour le statut du véhicule si panne/accident
      let nouveauStatutVehicule: string | null = null;
      if (type === 'panne') {
        nouveauStatutVehicule = 'en_panne';
      } else if (type === 'accident') {
        nouveauStatutVehicule = 'accidente';
      }

      if (nouveauStatutVehicule) {
        await client.query(
          `UPDATE vehicules SET statut = $1 WHERE id = $2`,
          [nouveauStatutVehicule, vehicule_id],
        );
      }

      await client.query('COMMIT');

      await writeAuditLog(req.user!.sub, 'CREATE_INCIDENT', incident.id, {
        type, vehicule_id, severity,
      });

      res.status(201).json({ success: true, data: incident });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) { next(err); }
}

/**
 * PATCH /api/v1/incidents/:id
 * Met à jour un incident (suivi réparation, coût, statut).
 */
export async function updateIncident(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const {
      statut, statut_reparation, cout_reparation,
      date_remise_en_service, description, photo_urls,
    } = req.body;

    // Vérifier que l'incident existe
    const { rows: existing } = await pool.query(`SELECT * FROM incidents WHERE id = $1`, [id]);
    if (existing.length === 0) throw AppError.notFound('Incident non trouvé');

    const old = existing[0];
    const updates: string[] = [];
    const params: any[] = [];
    let idx = 1;

    if (statut !== undefined) {
      updates.push(`statut = $${idx++}`);
      params.push(statut);
    }
    if (statut_reparation !== undefined) {
      updates.push(`statut_reparation = $${idx++}`);
      params.push(statut_reparation);
    }
    if (cout_reparation !== undefined) {
      updates.push(`cout_reparation = $${idx++}`);
      params.push(cout_reparation);
    }
    if (date_remise_en_service !== undefined) {
      updates.push(`date_remise_en_service = $${idx++}`);
      params.push(date_remise_en_service);
    }
    if (description !== undefined) {
      updates.push(`description = $${idx++}`);
      params.push(description);
    }
    if (photo_urls !== undefined) {
      updates.push(`photo_urls = $${idx++}`);
      params.push(photo_urls);
    }

    if (updates.length === 0) {
      res.json({ success: true, data: old });
      return;
    }

    params.push(id);
    const { rows } = await pool.query(
      `UPDATE incidents SET ${updates.join(', ')} WHERE id = $${idx} RETURNING *`,
      params,
    );

    // Si l'incident est résolu et le véhicule était en panne/accidenté → remettre en_remboursement
    if (statut === 'resolu' && old.statut !== 'resolu') {
      const { rows: veh } = await pool.query(
        `SELECT statut FROM vehicules WHERE id = $1`,
        [old.vehicule_id],
      );
      if (veh.length > 0 && (veh[0].statut === 'en_panne' || veh[0].statut === 'accidente')) {
        await pool.query(
          `UPDATE vehicules SET statut = 'en_remboursement' WHERE id = $1`,
          [old.vehicule_id],
        );
      }
    }

    await writeAuditLog(req.user!.sub, 'UPDATE_INCIDENT', id, {
      statut, statut_reparation, cout_reparation,
    });

    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/incidents/vehicule/:vehiculeId
 * Historique des incidents d'un véhicule.
 */
export async function getIncidentsByVehicule(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { vehiculeId } = req.params;
    const { rows } = await pool.query(`
      SELECT i.*, v.plaque AS vehicule_plaque
      FROM incidents i
      LEFT JOIN vehicules v ON i.vehicule_id = v.id
      WHERE i.vehicule_id = $1
      ORDER BY i.date DESC
    `, [vehiculeId]);

    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}
