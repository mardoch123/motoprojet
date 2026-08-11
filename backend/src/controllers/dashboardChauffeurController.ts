import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import type { AuthRequest } from '../types/index.js';

/**
 * GET /api/v1/dashboard/chauffeur
 * Dashboard personnalisé pour le chauffeur connecté.
 * Retourne : véhicule actif, progression paiements, derniers paiements, retards.
 */
export async function getDashboardChauffeur(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const userId = req.user?.sub;
    if (!userId) {
      return res.status(401).json({ success: false, error: 'Non authentifié' });
    }

    // 1. Trouver le chauffeur lié au user connecté
    const chauffeurRes = await pool.query(
      `SELECT c.id, c.nom, c.statut, c.objectif_journalier, c.user_id
       FROM chauffeurs c
       WHERE c.user_id = $1`,
      [userId]
    );

    if (chauffeurRes.rows.length === 0) {
      return res.json({ success: true, data: { message: 'Aucun profil chauffeur trouvé' } });
    }

    const chauffeur = chauffeurRes.rows[0];
    const chauffeurId = chauffeur.id;

    // 2. Véhicule actuellement affecté (affectation active = pas de date_fin)
    const vehiculeRes = await pool.query(
      `SELECT v.id, v.plaque, v.marque, v.type, v.prix_achat, v.statut,
              v.date_achat, v.date_fin_remboursement,
              a.date_debut AS affectation_depuis
       FROM vehicules v
       JOIN affectations a ON a.vehicule_id = v.id
       WHERE a.chauffeur_id = $1 AND a.date_fin IS NULL
       ORDER BY a.date_debut DESC
       LIMIT 1`,
      [chauffeurId]
    );

    // 3. Progression des paiements (total payé vs prix d'achat)
    const progressionRes = await pool.query(
      `SELECT
         COALESCE(SUM(p.montant), 0) AS total_paye,
         COUNT(*) AS nb_paiements
       FROM paiements p
       JOIN affectations a ON a.vehicule_id = p.vehicule_id AND a.chauffeur_id = p.chauffeur_id
       WHERE p.chauffeur_id = $1
         AND a.date_fin IS NULL`,
      [chauffeurId]
    );

    // 4. Derniers paiements (5 plus récents)
    const derniersPaiementsRes = await pool.query(
      `SELECT p.id, p.montant::float, p.date, p.mode,
              v.plaque AS vehicule_plaque
       FROM paiements p
       JOIN vehicules v ON v.id = p.vehicule_id
       WHERE p.chauffeur_id = $1
       ORDER BY p.date DESC, p.date_enregistrement DESC
       LIMIT 5`,
      [chauffeurId]
    );

    // 5. Paiements cette semaine et ce mois
    const periodesRes = await pool.query(
      `SELECT
         COALESCE(SUM(CASE WHEN p.date >= DATE_TRUNC('week', CURRENT_DATE) THEN p.montant END), 0)::float AS semaine,
         COALESCE(SUM(CASE WHEN p.date >= DATE_TRUNC('month', CURRENT_DATE) THEN p.montant END), 0)::float AS mois,
         COUNT(*) FILTER (WHERE p.date >= DATE_TRUNC('week', CURRENT_DATE))::int AS nb_semaine,
         COUNT(*) FILTER (WHERE p.date >= DATE_TRUNC('month', CURRENT_DATE))::int AS nb_mois
       FROM paiements p
       WHERE p.chauffeur_id = $1`,
      [chauffeurId]
    );

    // 6. Impayés (retards de paiement)
    const impayesRes = await pool.query(
      `SELECT vi.id, vi.date, vi.montant_attendu::float, vi.montant_verse::float,
              vi.ecart::float, vi.statut,
              v.plaque AS vehicule_plaque
       FROM vehicule_impayes vi
       JOIN vehicules v ON v.id = vi.vehicule_id
       WHERE vi.chauffeur_id = $1 AND vi.statut != 'paye'
       ORDER BY vi.date DESC
       LIMIT 10`,
      [chauffeurId]
    );

    // 7. Incidents ouverts sur le véhicule du chauffeur
    const incidentsRes = await pool.query(
      `SELECT i.id, i.type, i.statut, i.description, i.date, i.cout::float,
              v.plaque AS vehicule_plaque
       FROM incidents i
       JOIN vehicules v ON v.id = i.vehicule_id
       JOIN affectations a ON a.vehicule_id = i.vehicule_id
       WHERE a.chauffeur_id = $1 AND a.date_fin IS NULL AND i.statut != 'resolu'
       ORDER BY i.date_creation DESC`,
      [chauffeurId]
    );

    // Construire la réponse
    const vehicule = vehiculeRes.rows[0] || null;
    const totalPaye = parseFloat(progressionRes.rows[0].total_paye) || 0;
    const prixAchat = vehicule ? parseFloat(vehicule.prix_achat) : 0;
    const pourcentage = prixAchat > 0 ? Math.min(100, Math.round((totalPaye / prixAchat) * 100)) : 0;
    const soldeRestant = Math.max(0, prixAchat - totalPaye);

    res.json({
      success: true,
      data: {
        chauffeur: {
          id: chauffeur.id,
          nom: chauffeur.nom,
          statut: chauffeur.statut,
          objectif_journalier: parseFloat(chauffeur.objectif_journalier) || 0,
        },
        vehicule_actif: vehicule ? {
          id: vehicule.id,
          plaque: vehicule.plaque,
          marque: vehicule.marque,
          type: vehicule.type,
          statut: vehicule.statut,
          prix_achat: prixAchat,
          affectation_depuis: vehicule.affectation_depuis,
          date_fin_remboursement: vehicule.date_fin_remboursement,
        } : null,
        progression: {
          total_paye: totalPaye,
          prix_achat: prixAchat,
          solde_restant: soldeRestant,
          pourcentage,
          nb_paiements: parseInt(progressionRes.rows[0].nb_paiements) || 0,
        },
        derniers_paiements: derniersPaiementsRes.rows.map((p: any) => ({
          id: p.id,
          montant: p.montant,
          date: p.date,
          mode: p.mode,
          vehicule_plaque: p.vehicule_plaque,
        })),
        periodes: {
          semaine: periodesRes.rows[0].semaine,
          mois: periodesRes.rows[0].mois,
          nb_paiements_semaine: periodesRes.rows[0].nb_semaine,
          nb_paiements_mois: periodesRes.rows[0].nb_mois,
        },
        impayes: impayesRes.rows.map((i: any) => ({
          id: i.id,
          date: i.date,
          montant_attendu: i.montant_attendu,
          montant_verse: i.montant_verse,
          ecart: i.ecart,
          statut: i.statut,
          vehicule_plaque: i.vehicule_plaque,
        })),
        incidents_ouverts: incidentsRes.rows.map((i: any) => ({
          id: i.id,
          type: i.type,
          statut: i.statut,
          description: i.description,
          date: i.date,
          cout: i.cout,
          vehicule_plaque: i.vehicule_plaque,
        })),
      },
    });
  } catch (err) {
    next(err);
  }
}
