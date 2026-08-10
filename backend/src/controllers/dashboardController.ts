import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import type { AuthRequest } from '../types/index.js';

/**
 * GET /api/v1/dashboard
 */
export async function getDashboard(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const [chauffeurs, vehicules, paiements, recouvrement, cash, incidents] = await Promise.all([
      pool.query(`SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE statut = 'actif') AS actifs FROM chauffeurs`),
      pool.query(`SELECT COUNT(*) AS total, COUNT(*) FILTER (WHERE statut = 'en_remboursement') AS en_cours FROM vehicules`),
      pool.query(`SELECT COUNT(*) AS total, COALESCE(SUM(montant), 0) AS total_montant FROM paiements`),
      pool.query(`SELECT * FROM vue_taux_recouvrement_global`),
      pool.query(`SELECT * FROM vue_cash_cumule_disponible`),
      pool.query(`SELECT COUNT(*) AS total FROM incidents WHERE statut != 'resolu'`),
    ]);

    res.json({
      success: true,
      data: {
        chauffeurs: chauffeurs.rows[0],
        vehicules: vehicules.rows[0],
        paiements: paiements.rows[0],
        recouvrement: recouvrement.rows[0],
        cash: cash.rows[0],
        incidents_ouverts: incidents.rows[0].total,
      },
    });
  } catch (err) { next(err); }
}
