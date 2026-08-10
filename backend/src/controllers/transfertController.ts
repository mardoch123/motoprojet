import { Response, NextFunction } from 'express';
import pool from '../config/db.js';
import { AppError } from '../utils/errors.js';
import { writeAuditLog } from '../services/audit.js';
import type { AuthRequest } from '../types/index.js';

/**
 * POST /api/v1/vehicules/:id/transfert
 * Workflow de transfert de propriété :
 * 1. Vérifie éligibilité (remboursé OU date atteinte)
 * 2. Met à jour le statut → 'rembourse'
 * 3. Génère les données pour l'attestation PDF
 * 4. Enregistre dans l'historique
 *
 * Le PDF est généré côté client (Flutter) à partir des données retournées.
 */
export async function executeTransfert(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const vehiculeId = req.params.id as string;

    // Récupérer toutes les infos nécessaires
    const { rows } = await pool.query(`
      SELECT v.*,
        COALESCE(SUM(p.montant), 0) AS total_verse,
        v.prix_achat - COALESCE(SUM(p.montant), 0) AS solde_restant,
        a.chauffeur_id, c.nom AS chauffeur_nom, c.piece_identite,
        COUNT(p.id) AS nb_paiements,
        MIN(p.date) AS premier_paiement,
        MAX(p.date) AS dernier_paiement
      FROM vehicules v
      LEFT JOIN paiements p ON p.vehicule_id = v.id
      LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
      LEFT JOIN chauffeurs c ON a.chauffeur_id = c.id
      WHERE v.id = $1
      GROUP BY v.id, a.chauffeur_id, c.nom, c.piece_identite`,
      [vehiculeId],
    );

    if (rows.length === 0) throw AppError.notFound('Véhicule non trouvé');

    const vehicule = rows[0];
    const totalVerse = parseFloat(vehicule.total_verse);
    const prixAchat = parseFloat(vehicule.prix_achat);

    // Vérifier l'éligibilité
    const estRembourse = totalVerse >= prixAchat;
    const dateAtteinte = vehicule.date_fin_remboursement
      ? new Date() >= new Date(vehicule.date_fin_remboursement)
      : false;

    if (!estRembourse && !dateAtteinte) {
      throw AppError.unprocessable(
        'Le véhicule n\'est pas encore éligible au transfert. ' +
        `Solde restant : ${(prixAchat - totalVerse).toFixed(0)} FCFA`,
      );
    }

    const client = await pool.connect();
    try {
      await client.query('BEGIN');

      const ancienStatut = vehicule.statut;

      // Mettre à jour le statut
      await client.query(
        `UPDATE vehicules SET statut = 'rembourse' WHERE id = $1`,
        [vehiculeId],
      );

      // Historique statut
      await client.query(`
        INSERT INTO vehicule_statut_historique (vehicule_id, ancien_statut, nouveau_statut, user_id, commentaire)
        VALUES ($1, $2, 'rembourse', $3, 'Transfert de propriété — remboursement terminé')`,
        [vehiculeId, ancienStatut, req.user!.sub],
      );

      await client.query('COMMIT');

      // Données pour l'attestation PDF
      const attestationData = {
        type: 'transfert_propriete',
        date: new Date().toISOString().split('T')[0],
        vehicule: {
          id: vehicule.id,
          type: vehicule.type,
          plaque: vehicule.plaque,
          marque: vehicule.marque ?? '',
          prix_achat: prixAchat,
          date_achat: vehicule.date_achat,
          date_mise_circulation: vehicule.date_mise_circulation,
          date_fin_remboursement: vehicule.date_fin_remboursement,
        },
        chauffeur: {
          id: vehicule.chauffeur_id,
          nom: vehicule.chauffeur_nom ?? 'Non assigné',
          piece_identite: vehicule.piece_identite ?? '',
        },
        financier: {
          total_verse: totalVerse,
          prix_achat: prixAchat,
          nb_paiements: parseInt(vehicule.nb_paiements, 10),
          premier_paiement: vehicule.premier_paiement,
          dernier_paiement: vehicule.dernier_paiement,
        },
      };

      await writeAuditLog(req.user!.sub, 'TRANSFERT_PROPRIETE', vehiculeId, {
        ancien_statut: ancienStatut,
        chauffeur: vehicule.chauffeur_nom,
        total_verse: totalVerse,
      });

      res.json({ success: true, data: { vehicule: vehicule, attestation: attestationData } });
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }
  } catch (err) { next(err); }
}
