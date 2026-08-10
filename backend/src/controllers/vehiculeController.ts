import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import { AppError } from '../utils/errors.js';
import { writeAuditLog } from '../services/audit.js';
import { emit } from '../services/events.js';
import type { AuthRequest } from '../types/index.js';

/**
 * GET /api/v1/vehicules
 * Liste avec filtres (type, statut, chauffeur) et recherche (plaque).
 * Calculs financiers temps réel via la vue SQL.
 */
export async function listVehicules(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const type = (req.query.type as string) ?? '';
    const statut = (req.query.statut as string) ?? '';
    const chauffeurId = (req.query.chauffeur_id as string) ?? '';
    const search = (req.query.search as string) ?? '';

    let query = `
      SELECT v.*,
        a.chauffeur_id, c.nom AS chauffeur_nom,
        COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0) AS total_verse,
        v.prix_achat - COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0) AS solde_restant,
        ROUND(
          (COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0)
          / NULLIF(v.prix_achat, 0)) * 100, 2
        ) AS pourcentage_rembourse,
        CASE
          WHEN v.statut = 'rembourse' THEN 'rembourse'
          WHEN v.statut IN ('en_panne', 'accidente') THEN 'probleme'
          WHEN COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0) >= v.prix_achat THEN 'a_jour'
          WHEN MAX(p.date) IS NOT NULL AND MAX(p.date) < CURRENT_DATE - INTERVAL '30 days' THEN 'defaut'
          WHEN MAX(p.date) IS NOT NULL AND MAX(p.date) < CURRENT_DATE - INTERVAL '7 days' THEN 'retard'
          WHEN MAX(p.date) IS NOT NULL THEN 'a_jour'
          ELSE 'en_attente'
        END AS couleur_flotte
      FROM vehicules v
      LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
      LEFT JOIN chauffeurs c ON a.chauffeur_id = c.id
      LEFT JOIN paiements p ON p.vehicule_id = v.id`;

    const conditions: string[] = [];
    const params: unknown[] = [];
    let paramIdx = 1;

    if (type) {
      conditions.push(`v.type = $${paramIdx}`);
      params.push(type);
      paramIdx++;
    }
    if (statut) {
      conditions.push(`v.statut = $${paramIdx}`);
      params.push(statut);
      paramIdx++;
    }
    if (chauffeurId) {
      conditions.push(`a.chauffeur_id = $${paramIdx}`);
      params.push(chauffeurId);
      paramIdx++;
    }
    if (search) {
      conditions.push(`v.plaque ILIKE $${paramIdx}`);
      params.push(`%${search}%`);
      paramIdx++;
    }

    if (conditions.length > 0) {
      query += ' WHERE ' + conditions.join(' AND ');
    }
    query += ' GROUP BY v.id, a.chauffeur_id, c.nom ORDER BY v.plaque';

    const { rows } = await pool.query(query, params);
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/vehicules/:id
 * Fiche complète : infos + calculs temps réel + historique paiements + affectations + statuts.
 */
export async function getVehicule(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const vehiculeId = req.params.id as string;

    // Infos véhicule + chauffeur actuel
    const { rows: vehicules } = await pool.query(`
      SELECT v.*,
        a.chauffeur_id, c.nom AS chauffeur_nom,
        COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0) AS total_verse,
        v.prix_achat - COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0) AS solde_restant,
        ROUND(
          (COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0)
          / NULLIF(v.prix_achat, 0)) * 100, 2
        ) AS pourcentage_rembourse,
        MAX(p.date) AS dernier_paiement,
        COUNT(p.id) AS nb_paiements
      FROM vehicules v
      LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
      LEFT JOIN chauffeurs c ON a.chauffeur_id = c.id
      LEFT JOIN paiements p ON p.vehicule_id = v.id
      WHERE v.id = $1
      GROUP BY v.id, a.chauffeur_id, c.nom`,
      [vehiculeId],
    );
    if (vehicules.length === 0) throw AppError.notFound('Véhicule non trouvé');

    const vehicule = vehicules[0];

    // Historique affectations (chauffeurs successifs)
    const { rows: affectations } = await pool.query(`
      SELECT a.*, c.nom AS chauffeur_nom,
        COALESCE(SUM(p.montant) FILTER (WHERE p.id IS NOT NULL), 0) AS total_verse_periode
      FROM affectations a
      JOIN chauffeurs c ON a.chauffeur_id = c.id
      LEFT JOIN paiements p ON p.vehicule_id = a.vehicule_id AND p.chauffeur_id = a.chauffeur_id
        AND p.date >= a.date_debut AND (a.date_fin IS NULL OR p.date <= a.date_fin)
      WHERE a.vehicule_id = $1
      GROUP BY a.id, c.nom
      ORDER BY a.date_debut DESC`,
      [vehiculeId],
    );
    vehicule.historique_affectations = affectations;

    // Historique statuts
    const { rows: statuts } = await pool.query(`
      SELECT h.*, u.telephone AS user_telephone
      FROM vehicule_statut_historique h
      LEFT JOIN users u ON h.user_id = u.id
      WHERE h.vehicule_id = $1
      ORDER BY h.date_changement DESC`,
      [vehiculeId],
    );
    vehicule.historique_statuts = statuts;

    // Derniers paiements (30 max)
    const { rows: paiements } = await pool.query(`
      SELECT p.*, c.nom AS chauffeur_nom
      FROM paiements p
      JOIN chauffeurs c ON p.chauffeur_id = c.id
      WHERE p.vehicule_id = $1
      ORDER BY p.date DESC LIMIT 30`,
      [vehiculeId],
    );
    vehicule.historique_paiements = paiements;

    // Incidents
    const { rows: incidents } = await pool.query(`
      SELECT * FROM incidents WHERE vehicule_id = $1 ORDER BY date DESC`,
      [vehiculeId],
    );
    vehicule.incidents = incidents;

    res.json({ success: true, data: vehicule });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/vehicules
 * Création : calcule auto date_fin_remboursement = date_mise_circulation + durée paramétrable.
 */
export async function createVehicule(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { type, plaque, prix_achat, date_achat, date_mise_circulation, marque, immatriculation } = req.body;

    // Récupérer la durée de remboursement par défaut
    const { rows: params } = await pool.query(
      `SELECT valeur FROM parametres WHERE cle = 'duree_financement_mois'`,
    );
    const dureeMois = parseInt(params[0]?.valeur ?? '14', 10);

    // Calculer date_fin_remboursement automatiquement
    let dateFinRemboursement: string | null = null;
    if (date_mise_circulation) {
      const dateMC = new Date(date_mise_circulation);
      dateMC.setMonth(dateMC.getMonth() + dureeMois);
      dateFinRemboursement = dateMC.toISOString().split('T')[0];
    }

    const { rows } = await pool.query(`
      INSERT INTO vehicules (type, plaque, prix_achat, date_achat, date_mise_circulation,
        date_fin_remboursement, marque, immatriculation)
      VALUES ($1, $2, $3, COALESCE($4, CURRENT_DATE), $5, $6, $7, $8)
      RETURNING *`,
      [type, plaque, prix_achat, date_achat ?? null, date_mise_circulation ?? null,
       dateFinRemboursement, marque ?? null, immatriculation ?? null],
    );

    // Enregistrer le statut initial dans l'historique
    await pool.query(`
      INSERT INTO vehicule_statut_historique (vehicule_id, nouveau_statut, user_id, commentaire)
      VALUES ($1, 'en_remboursement', $2, 'Création du véhicule')`,
      [rows[0].id, req.user!.sub],
    );

    await writeAuditLog(req.user!.sub, 'CREATE_VEHICULE', rows[0].id, { plaque, prix_achat });

    res.status(201).json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/vehicules/:id
 * Mise à jour des infos véhicule.
 */
export async function updateVehicule(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const vehiculeId = req.params.id as string;
    const { type, plaque, prix_achat, date_achat, date_mise_circulation, date_fin_remboursement, marque, immatriculation } = req.body;

    const { rows } = await pool.query(`
      UPDATE vehicules
      SET type = COALESCE($2, type),
          plaque = COALESCE($3, plaque),
          prix_achat = COALESCE($4, prix_achat),
          date_achat = COALESCE($5, date_achat),
          date_mise_circulation = COALESCE($6, date_mise_circulation),
          date_fin_remboursement = COALESCE($7, date_fin_remboursement),
          marque = COALESCE($8, marque),
          immatriculation = COALESCE($9, immatriculation)
      WHERE id = $1
      RETURNING *`,
      [vehiculeId, type ?? null, plaque ?? null, prix_achat ?? null,
       date_achat ?? null, date_mise_circulation ?? null, date_fin_remboursement ?? null,
       marque ?? null, immatriculation ?? null],
    );

    if (rows.length === 0) throw AppError.notFound('Véhicule non trouvé');

    await writeAuditLog(req.user!.sub, 'UPDATE_VEHICULE', vehiculeId, {
      fields: Object.keys(req.body),
    });

    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/vehicules/:id/statut
 * Changement de statut avec historique horodaté.
 */
export async function changeStatut(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const vehiculeId = req.params.id as string;
    const { statut, commentaire } = req.body;

    // Récupérer l'ancien statut
    const { rows: current } = await pool.query(
      `SELECT statut FROM vehicules WHERE id = $1`,
      [vehiculeId],
    );
    if (current.length === 0) throw AppError.notFound('Véhicule non trouvé');

    const ancienStatut = current[0].statut;

    // Mettre à jour le statut
    const { rows } = await pool.query(`
      UPDATE vehicules SET statut = $2 WHERE id = $1 RETURNING *`,
      [vehiculeId, statut],
    );

    // Enregistrer dans l'historique
    await pool.query(`
      INSERT INTO vehicule_statut_historique (vehicule_id, ancien_statut, nouveau_statut, user_id, commentaire)
      VALUES ($1, $2, $3, $4, $5)`,
      [vehiculeId, ancienStatut, statut, req.user!.sub, commentaire ?? null],
    );

    await writeAuditLog(req.user!.sub, 'CHANGE_STATUT_VEHICULE', vehiculeId, {
      ancien_statut: ancienStatut, nouveau_statut: statut,
    });

    res.json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/vehicules/:id/transfert-eligibilite
 * Vérifie si le véhicule est éligible au transfert de propriété.
 */
export async function checkTransfertEligibilite(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const vehiculeId = req.params.id as string;

    const { rows } = await pool.query(`
      SELECT v.id, v.plaque, v.prix_achat, v.statut, v.date_fin_remboursement,
        COALESCE(SUM(p.montant), 0) AS total_verse,
        v.prix_achat - COALESCE(SUM(p.montant), 0) AS solde_restant,
        CASE WHEN COALESCE(SUM(p.montant), 0) >= v.prix_achat THEN TRUE ELSE FALSE END AS est_rembourse,
        CASE WHEN v.date_fin_remboursement IS NOT NULL AND CURRENT_DATE >= v.date_fin_remboursement THEN TRUE ELSE FALSE END AS date_atteinte,
        a.chauffeur_id, c.nom AS chauffeur_nom
      FROM vehicules v
      LEFT JOIN paiements p ON p.vehicule_id = v.id
      LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
      LEFT JOIN chauffeurs c ON a.chauffeur_id = c.id
      WHERE v.id = $1
      GROUP BY v.id, a.chauffeur_id, c.nom`,
      [vehiculeId],
    );

    if (rows.length === 0) throw AppError.notFound('Véhicule non trouvé');

    const data = rows[0];
    const eligible = data.est_rembourse || data.date_atteinte;

    res.json({
      success: true,
      data: {
        ...data,
        eligible,
        reason: !eligible
          ? (data.solde_restant > 0 ? 'Solde restant dû' : 'Date de fin non atteinte')
          : null,
      },
    });
  } catch (err) { next(err); }
}
