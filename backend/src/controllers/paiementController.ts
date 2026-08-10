import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import { AppError } from '../utils/errors.js';
import { writeAuditLog } from '../services/audit.js';
import { emit } from '../services/events.js';
import type { AuthRequest, ApiResponse } from '../types/index.js';

/**
 * POST /api/v1/paiements
 * Création unitaire d'un paiement.
 * Résout le chauffeur_id depuis le JWT (ou depuis le body pour admin/gestionnaire).
 */
export async function createPaiement(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { vehicule_id, montant, date, synchronise_offline } = req.body;
    const mode = req.body.mode || 'kkiapay';
    const user = req.user!;

    // ── Résoudre le chauffeur_id depuis le JWT ──────────────────────────
    let chauffeurId: string;
    if (user.role === 'chauffeur') {
      const { rows } = await pool.query(
        `SELECT id FROM chauffeurs WHERE user_id = $1`, [user.sub],
      );
      if (rows.length === 0) throw AppError.badRequest('Profil chauffeur non trouvé');
      chauffeurId = rows[0].id;
    } else {
      chauffeurId = req.body.chauffeur_id;
      if (!chauffeurId) throw AppError.badRequest('chauffeur_id requis pour ce rôle');
    }

    // ── Vérifier que le véhicule existe ─────────────────────────────────
    const { rows: vehicules } = await pool.query(
      `SELECT id, plaque, prix_achat FROM vehicules WHERE id = $1`, [vehicule_id],
    );
    if (vehicules.length === 0) throw AppError.notFound('Véhicule non trouvé');

    // ── Calcul du solde restant AVANT ce paiement ───────────────────────
    const { rows: soldeRows } = await pool.query(
      `SELECT COALESCE(SUM(montant), 0) AS total_verse FROM paiements WHERE vehicule_id = $1`,
      [vehicule_id],
    );
    const totalVerseAvant = parseFloat(soldeRows[0].total_verse);
    const prixAchat = parseFloat(vehicules[0].prix_achat);
    const nouveauSolde = prixAchat - (totalVerseAvant + montant);

    // ── Écriture en base ────────────────────────────────────────────────
    const { rows } = await pool.query(
      `INSERT INTO paiements (chauffeur_id, vehicule_id, montant, date, mode, synchronise_offline)
       VALUES ($1, $2, $3, COALESCE($4, CURRENT_DATE), $5, $6)
       RETURNING *`,
      [chauffeurId, vehicule_id, montant, date ?? null, mode, synchronise_offline ?? false],
    );

    await writeAuditLog(user.sub, 'CREATE_PAIEMENT', rows[0].id, {
      montant, mode, vehicule: vehicules[0].plaque, synchronise_offline,
    });

    // ── Événement cross-module ──────────────────────────────────────────
    await emit('PAIEMENT_ENREGISTRE', { chauffeur_id: chauffeurId, montant, vehicule_id });

    res.status(201).json({
      success: true,
      data: {
        paiement: rows[0],
        solde: {
          total_verse_avant: totalVerseAvant,
          montant_paye: montant,
          nouveau_solde: Math.max(0, nouveauSolde),
          pourcentage_rembourse: Math.min(100, ((totalVerseAvant + montant) / prixAchat) * 100),
        },
      },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/paiements
 * Historique filtrable : chauffeur_id, vehicule_id, date_debut, date_fin, mode.
 * Le chauffeur ne voit que ses propres paiements.
 */
export async function listPaiements(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const user = req.user!;
    const chauffeurFilter = req.query.chauffeur_id as string;
    const vehiculeFilter = req.query.vehicule_id as string;
    const dateDebut = req.query.date_debut as string;
    const dateFin = req.query.date_fin as string;
    const modeFilter = req.query.mode as string;
    const limit = Math.min(parseInt(req.query.limit as string) || 200, 1000);

    let query = `
      SELECT p.*, c.nom AS chauffeur_nom, v.plaque AS vehicule_plaque, v.type AS vehicule_type
      FROM paiements p
      LEFT JOIN chauffeurs c ON p.chauffeur_id = c.id
      LEFT JOIN vehicules v ON p.vehicule_id = v.id`;

    const conditions: string[] = [];
    const params: unknown[] = [];
    let paramIdx = 1;

    // Un chauffeur ne voit QUE ses paiements
    if (user.role === 'chauffeur') {
      const { rows } = await pool.query(`SELECT id FROM chauffeurs WHERE user_id = $1`, [user.sub]);
      if (rows.length === 0) { res.json({ success: true, data: [] }); return; }
      conditions.push(`p.chauffeur_id = $${paramIdx}`);
      params.push(rows[0].id);
      paramIdx++;
    } else if (chauffeurFilter) {
      conditions.push(`p.chauffeur_id = $${paramIdx}`);
      params.push(chauffeurFilter);
      paramIdx++;
    }

    if (vehiculeFilter) {
      conditions.push(`p.vehicule_id = $${paramIdx}`);
      params.push(vehiculeFilter);
      paramIdx++;
    }
    if (dateDebut) {
      conditions.push(`p.date >= $${paramIdx}`);
      params.push(dateDebut);
      paramIdx++;
    }
    if (dateFin) {
      conditions.push(`p.date <= $${paramIdx}`);
      params.push(dateFin);
      paramIdx++;
    }
    if (modeFilter) {
      conditions.push(`p.mode = $${paramIdx}`);
      params.push(modeFilter);
      paramIdx++;
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }
    query += ` ORDER BY p.date DESC, p.date_enregistrement DESC LIMIT $${paramIdx}`;
    params.push(limit);

    const { rows } = await pool.query(query, params);

    // Stats pour les filtres actifs
    const { rows: stats } = await pool.query(`
      SELECT COUNT(*) AS total, COALESCE(SUM(p.montant), 0) AS total_montant
      FROM paiements p
      ${conditions.length > 0 ? 'WHERE ' + conditions.join(' AND ') : ''}`,
      params.slice(0, -1), // sans le LIMIT
    );

    res.json({
      success: true,
      data: rows,
      meta: {
        total: parseInt(stats[0]?.total ?? '0', 10),
        total_montant: parseFloat(stats[0]?.total_montant ?? '0'),
        limit,
      },
    });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/paiements/sync-batch
 * Synchronisation batch de paiements hors-ligne.
 * Déduplication par UUID (id) généré côté mobile.
 */
export async function syncBatch(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { paiements } = req.body;
    const user = req.user!;

    let chauffeurId: string;
    if (user.role === 'chauffeur') {
      const { rows } = await pool.query(`SELECT id FROM chauffeurs WHERE user_id = $1`, [user.sub]);
      if (rows.length === 0) throw AppError.badRequest('Profil chauffeur non trouvé');
      chauffeurId = rows[0].id;
    } else {
      chauffeurId = req.body.chauffeur_id;
      if (!chauffeurId) throw AppError.badRequest('chauffeur_id requis');
    }

    const created: string[] = [];
    const duplicates: string[] = [];
    const errors: Array<{ id: string; error: string }> = [];

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      for (const p of paiements) {
        try {
          const { rows: existing } = await client.query(
            `SELECT id FROM paiements WHERE id = $1`, [p.id],
          );
          if (existing.length > 0) {
            duplicates.push(p.id);
            continue;
          }

          const { rows } = await client.query(
            `INSERT INTO paiements (id, chauffeur_id, vehicule_id, montant, date, mode, synchronise_offline)
             VALUES ($1, $2, $3, $4, $5, $6, true) RETURNING id`,
            [p.id, chauffeurId, p.vehicule_id, p.montant, p.date, p.mode],
          );
          created.push(rows[0].id);
        } catch (err: any) {
          errors.push({ id: p.id, error: err.message });
        }
      }

      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    await writeAuditLog(user.sub, 'SYNC_BATCH', 'paiements', {
      total: paiements.length, created: created.length, duplicates: duplicates.length, errors: errors.length,
    });

    if (created.length > 0) {
      await emit('PAIEMENT_ENREGISTRE', { chauffeur_id: chauffeurId, batch: true, count: created.length });
    }

    res.json({
      success: true,
      data: { created, duplicates, errors },
      meta: { total: paiements.length },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/paiements/pending-sync
 * Liste les paiements en attente de synchronisation (admin/gestionnaire).
 * Utilise la table paiements avec synchronise_offline = true et date_enregistrement > now() - 24h.
 */
export async function listPendingSync(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    // Les paiements sync-batch sont marqués synchronise_offline = true
    // On retourne les paiements récents marqués offline pour vérification
    const { rows } = await pool.query(`
      SELECT p.*, c.nom AS chauffeur_nom, v.plaque AS vehicule_plaque
      FROM paiements p
      LEFT JOIN chauffeurs c ON p.chauffeur_id = c.id
      LEFT JOIN vehicules v ON p.vehicule_id = v.id
      WHERE p.synchronise_offline = TRUE
        AND p.date_enregistrement >= NOW() - INTERVAL '24 hours'
      ORDER BY p.date_enregistrement DESC
      LIMIT 100`,
    );

    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/paiements/finance/dashboard
 */
export async function getFinanceDashboard(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { rows: recouvrement } = await pool.query(`SELECT * FROM vue_taux_recouvrement_global`);
    const { rows: cash } = await pool.query(`SELECT * FROM vue_cash_cumule_disponible`);
    const { rows: soldes } = await pool.query(`SELECT * FROM vue_solde_par_vehicule LIMIT 10`);

    res.json({
      success: true,
      data: { recouvrement: recouvrement[0], cash_cumule: cash[0], soldes_vehicules: soldes },
    });
  } catch (err) { next(err); }
}
