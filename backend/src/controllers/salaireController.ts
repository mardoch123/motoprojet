import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import { AppError } from '../utils/errors.js';
import { writeAuditLog } from '../services/audit.js';
import {
  calculerSalairesMois,
  enregistrerSalaires,
  chargerParametresSalaire,
  updateParametreSalaire,
  validerSalaire,
  annulerSalaire,
  simulerImpact,
  verifierAnomalieSalaire,
} from '../services/salaireService.js';
import type { AuthRequest } from '../types/index.js';

/**
 * GET /api/v1/salaires
 * Liste des salaires avec filtres (profil, statut, mois).
 * Accès : super_admin uniquement.
 */
export async function listSalaires(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { profil, statut, mois, limit = '50' } = req.query;

    let query = `SELECT s.*, u.telephone AS verse_par_telephone
      FROM salaires s
      LEFT JOIN users u ON s.verse_par = u.id
      WHERE 1=1`;
    const params: any[] = [];
    let idx = 1;

    if (profil) {
      query += ` AND s.profil = $${idx++}`;
      params.push(profil);
    }
    if (statut) {
      query += ` AND s.statut = $${idx++}`;
      params.push(statut);
    }
    if (mois) {
      query += ` AND s.mois = $${idx++}`;
      params.push(mois);
    }

    query += ` ORDER BY s.mois DESC, s.profil ASC LIMIT $${idx}`;
    params.push(parseInt(limit as string, 10));

    const { rows } = await pool.query(query, params);
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/salaires/cumuls
 * Cumuls par profil (total versé, total calculé, nb mois).
 */
export async function getCumuls(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { rows } = await pool.query(`
      SELECT
        profil,
        COUNT(*)::int AS nb_mois,
        COALESCE(SUM(montant), 0)::float AS total_calcule,
        COALESCE(SUM(montant) FILTER (WHERE statut = 'verse'), 0)::float AS total_verse,
        COALESCE(AVG(montant) FILTER (WHERE montant > 0), 0)::float AS moyenne_mensuelle
      FROM salaires
      WHERE statut != 'annule'
      GROUP BY profil
    `);

    const cumuls: Record<string, any> = {};
    for (const r of rows) {
      cumuls[r.profil] = {
        nbMois: r.nb_mois,
        totalCalcule: r.total_calcule,
        totalVerse: r.total_verse,
        moyenneMensuelle: Math.round(r.moyenne_mensuelle),
      };
    }

    res.json({ success: true, data: cumuls });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/salaires/parametres
 * Paramètres salaires courants.
 */
export async function getParametres(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const params = await chargerParametresSalaire();
    res.json({ success: true, data: params });
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/salaires/parametres
 * Mise à jour des paramètres salaires.
 */
export async function updateParametres(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { pctProprietaire, pctEmploye, seuilVehicules, actif } = req.body;

    if (pctProprietaire !== undefined) {
      if (pctProprietaire < 0 || pctProprietaire > 50) throw AppError.badRequest('Pourcentage propriétaire invalide (0-50)');
      await updateParametreSalaire('pct_proprietaire', String(pctProprietaire));
    }
    if (pctEmploye !== undefined) {
      if (pctEmploye < 0 || pctEmploye > 50) throw AppError.badRequest('Pourcentage employé invalide (0-50)');
      await updateParametreSalaire('pct_employe', String(pctEmploye));
    }
    if (seuilVehicules !== undefined) {
      if (seuilVehicules < 0 || seuilVehicules > 100) throw AppError.badRequest('Seuil véhicules invalide (0-100)');
      await updateParametreSalaire('seuil_vehicules', String(seuilVehicules));
    }
    if (actif !== undefined) {
      await updateParametreSalaire('actif', String(actif));
    }

    await writeAuditLog(req.user!.sub, 'UPDATE_SALAIRE_PARAMS', '', req.body);

    const params = await chargerParametresSalaire();
    res.json({ success: true, data: params });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/salaires/calculer
 * Calcule les salaires pour un mois donné (ou le mois courant).
 */
export async function calculer(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const now = new Date();
    const mois = req.body.mois ?? `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

    // Vérifier si déjà calculé
    const { rows: existing } = await pool.query(
      `SELECT id, statut FROM salaires WHERE mois = $1`,
      [mois],
    );
    if (existing.length > 0 && existing[0].statut === 'verse') {
      throw AppError.conflict(`Salaires déjà versés pour ${mois}`);
    }

    const calcul = await calculerSalairesMois(mois);
    const saved = await enregistrerSalaires(calcul);

    // Vérifier anomalie
    await verifierAnomalieSalaire(mois);

    await writeAuditLog(req.user!.sub, 'CALCUL_SALAIRE', '', { mois, ...calcul });

    res.json({ success: true, data: saved });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/salaires/:id/valider
 * Valide et marque comme versé.
 */
export async function valider(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const result = await validerSalaire(id, req.user!.sub);
    if (!result) throw AppError.notFound('Salaire introuvable ou déjà versé');

    await writeAuditLog(req.user!.sub, 'VALIDER_SALAIRE', id, { montant: result.montant });

    res.json({ success: true, data: result });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/salaires/:id/annuler
 * Annule un salaire (pas encore versé).
 */
export async function annuler(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const result = await annulerSalaire(id);
    if (!result) throw AppError.notFound('Salaire introuvable ou déjà versé');

    await writeAuditLog(req.user!.sub, 'ANNULER_SALAIRE', id, { montant: result.montant });

    res.json({ success: true, data: result });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/salaires/simuler
 * Simule l'impact d'un changement de paramètres sur les N prochains mois.
 */
export async function simuler(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { pctProprietaire, pctEmploye, seuilVehicules, nbMois } = req.body;

    const result = await simulerImpact({
      pctProprietaire: pctProprietaire !== undefined ? parseFloat(pctProprietaire) : undefined,
      pctEmploye: pctEmploye !== undefined ? parseFloat(pctEmploye) : undefined,
      seuilVehicules: seuilVehicules !== undefined ? parseInt(seuilVehicules, 10) : undefined,
      nbMois: nbMois !== undefined ? parseInt(nbMois, 10) : undefined,
    });

    res.json({ success: true, data: result });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/salaires/create (legacy)
 * Création manuelle d'un salaire.
 */
export async function createSalaire(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { profil, mois, montant, date_versement } = req.body;

    const { rows: existing } = await pool.query(
      `SELECT id FROM salaires WHERE profil = $1 AND mois = $2`,
      [profil, mois],
    );
    if (existing.length > 0) throw AppError.conflict('Salaire déjà enregistré pour ce mois');

    const { rows } = await pool.query(`
      INSERT INTO salaires (profil, mois, montant, date_versement, statut)
      VALUES ($1, $2, $3, COALESCE($4, CURRENT_DATE), 'verse')
      RETURNING *`,
      [profil, mois, montant, date_versement ?? null],
    );

    await writeAuditLog(req.user!.sub, 'CREATE_SALAIRE', rows[0].id, { profil, mois, montant });

    res.status(201).json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
}
