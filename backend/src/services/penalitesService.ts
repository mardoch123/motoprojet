import pool from '../config/db.js';
import { writeAuditLog } from '../services/audit.js';
import { logger } from '../utils/logger.js';

/**
 * Récupère les paramètres de pénalité pour un type de véhicule
 */
export async function getParametresPenalite(typeVehicule: string) {
  // Cherche d'abord le paramètre spécifique au type
  const { rows } = await pool.query(
    `SELECT * FROM parametres_penalites WHERE type_vehicule = $1 AND actif = true`,
    [typeVehicule]
  );
  
  if (rows.length > 0) return rows[0];
  
  // Sinon, retourne le paramètre général
  const { rows: general } = await pool.query(
    `SELECT * FROM parametres_penalites WHERE type_vehicule = 'general' AND actif = true`
  );
  
  return general[0] || null;
}

/**
 * Vérifie si un véhicule est exempté de pénalités à une date donnée
 */
export async function estExempte(vehiculeId: string, chauffeurId: string, date: string): Promise<boolean> {
  const { rows } = await pool.query(
    `SELECT id FROM exemptions_penalites 
     WHERE actif = true 
     AND (vehicule_id = $1 OR chauffeur_id = $2)
     AND date_debut <= $3 
     AND (date_fin IS NULL OR date_fin >= $3)
     LIMIT 1`,
    [vehiculeId, chauffeurId, date]
  );
  return rows.length > 0;
}

/**
 * Vérifie si un véhicule a des jours couverts par un paiement anticipé
 */
export async function getJoursCouverts(vehiculeId: string, date: string): Promise<boolean> {
  const { rows } = await pool.query(
    `SELECT id FROM paiements_anticipes 
     WHERE vehicule_id = $1 
     AND date_paiement <= $2 
     AND date_fin_couverture >= $2`,
    [vehiculeId, date]
  );
  return rows.length > 0;
}

/**
 * Calcule le montant de pénalité pour un véhicule à une date donnée
 */
export async function calculerPenalite(vehiculeId: string, montantJournalier: number, typeVehicule: string): Promise<{ montant: number; params: any }> {
  const params = await getParametresPenalite(typeVehicule);
  
  if (!params || !params.actif) {
    return { montant: 0, params: null };
  }
  
  let montant: number;
  
  if (params.type_calcul === 'fixe') {
    montant = Number(params.montant_fixe) || 0;
  } else {
    // Pourcentage du montant journalier
    montant = (montantJournalier * (Number(params.pourcentage) || 0)) / 100;
  }
  
  return { montant, params };
}

/**
 * Vérifie si le plafond de pénalités est atteint pour un véhicule
 */
export async function plafondAtteint(vehiculeId: string, plafond: number | null): Promise<boolean> {
  if (!plafond || plafond <= 0) return false;
  
  const { rows } = await pool.query(
    `SELECT COALESCE(SUM(montant), 0) as total 
     FROM penalites 
     WHERE vehicule_id = $1 AND statut = 'active'`,
    [vehiculeId]
  );
  
  return Number(rows[0]?.total || 0) >= plafond;
}

/**
 * Récupère les véhicules en retard (dernier paiement > montant journalier attendu)
 */
export async function getVehiculesEnRetard() {
  const { rows } = await pool.query(`
    SELECT 
      v.id as vehicule_id,
      v.type,
      v.immatriculation,
      v.chauffeur_id,
      c.nom as chauffeur_nom,
      v.montant_journalier,
      v.date_fin_paiement,
      COALESCE(
        (SELECT MAX(date_paiement) FROM paiements p 
         WHERE p.vehicule_id = v.id AND p.statut = 'valide'),
        v.date_fin_paiement
      ) as dernier_paiement
    FROM vehicules v
    JOIN chauffeurs c ON c.id = v.chauffeur_id
    WHERE v.statut = 'actif'
    AND v.date_fin_paiement < CURRENT_DATE
  `);
  
  return rows;
}

/**
 * Job quotidien : calcule et enregistre les pénalités de retard
 */
export async function calculerPenalitesJour() {
  const today = new Date().toISOString().split('T')[0];
  const vehicules = await getVehiculesEnRetard();
  
  let penalitesCreees = 0;
  let penalitesIgnorees = 0;
  
  for (const vehicule of vehicules) {
    const vehiculeId = vehicule.vehicule_id;
    const chauffeurId = vehicule.chauffeur_id;
    const typeVehicule = vehicule.type || 'general';
    const montantJournalier = Number(vehicule.montant_journalier) || 0;
    
    // Vérifier exemption
    if (await estExempte(vehiculeId, chauffeurId, today)) {
      penalitesIgnorees++;
      continue;
    }
    
    // Vérifier jours couverts (paiement anticipé)
    if (await getJoursCouverts(vehiculeId, today)) {
      penalitesIgnorees++;
      continue;
    }
    
    // Calculer la pénalité
    const { montant, params } = await calculerPenalite(vehiculeId, montantJournalier, typeVehicule);
    
    if (!params || montant <= 0) {
      continue;
    }
    
    // Vérifier seuil de déclenchement
    const dernierPaiement = vehicule.dernier_paiement ? new Date(vehicule.dernier_paiement) : null;
    const joursRetard = dernierPaiement 
      ? Math.floor((new Date(today).getTime() - dernierPaiement.getTime()) / (1000 * 60 * 60 * 24))
      : 0;
    
    if (joursRetard < (params.seuil_jours || 1)) {
      continue;
    }
    
    // Vérifier plafond
    if (await plafondAtteint(vehiculeId, params.plafond)) {
      continue;
    }
    
    // Insérer la pénalité
    try {
      await pool.query(
        `INSERT INTO penalites (vehicule_id, chauffeur_id, date_penalite, montant, motif)
         VALUES ($1, $2, $3, $4, 'Retard de paiement')
         ON CONFLICT (vehicule_id, date_penalite) DO NOTHING`,
        [vehiculeId, chauffeurId, today, montant]
      );
      penalitesCreees++;
    } catch (err: unknown) {
      logger.error('Erreur insertion pénalité', { error: err instanceof Error ? err.message : String(err) });
    }
  }
  
  logger.info(`Pénalités: ${penalitesCreees} créées, ${penalitesIgnorees} ignorées`);
  return { creees: penalitesCreees, ignorees: penalitesIgnorees };
}

/**
 * Impute un paiement sur les pénalités puis le capital
 * Ordre : pénalités les plus anciennes d'abord, puis capital restant dû
 */
export async function imputerPaiement(
  vehiculeId: string,
  montantTotal: number,
  paiementId?: string
): Promise<{ imputationPenalites: number; imputationCapital: number; penalitesPayees: string[] }> {
  let reste = montantTotal;
  let imputationPenalites = 0;
  const penalitesPayees: string[] = [];
  
  // 1. Imputer sur les pénalités actives les plus anciennes
  const { rows: penalites } = await pool.query(
    `SELECT id, montant FROM penalites 
     WHERE vehicule_id = $1 AND statut = 'active' 
     ORDER BY date_penalite ASC`,
    [vehiculeId]
  );
  
  for (const penalite of penalites) {
    if (reste <= 0) break;
    
    const montantPenalite = Number(penalite.montant);
    const montantImpute = Math.min(reste, montantPenalite);
    
    await pool.query(
      `UPDATE penalites 
       SET statut = 'payee', paye_le = NOW(), paiement_id = $2
       WHERE id = $1`,
      [penalite.id, paiementId || null]
    );
    
    penalitesPayees.push(penalite.id);
    imputationPenalites += montantImpute;
    reste -= montantImpute;
  }
  
  // 2. Le reste va au capital
  const imputationCapital = reste;
  
  return { imputationPenalites, imputationCapital, penalitesPayees };
}

/**
 * Enregistre un paiement anticipé
 */
export async function enregistrerPaiementAnticipe(
  vehiculeId: string,
  chauffeurId: string,
  montant: number,
  joursCouverts: number,
  mode: string,
  raccourcitDuree: boolean,
  paiementId?: string,
  note?: string
) {
  const datePaiement = new Date().toISOString().split('T')[0];
  const dateFinCouverture = new Date();
  dateFinCouverture.setDate(dateFinCouverture.getDate() + joursCouverts);
  const dateFinStr = dateFinCouverture.toISOString().split('T')[0];
  
  const { rows } = await pool.query(
    `INSERT INTO paiements_anticipes 
     (vehicule_id, chauffeur_id, paiement_id, date_paiement, jours_couverts, date_fin_couverture, montant, mode, raccourcit_duree, note)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
     RETURNING *`,
    [vehiculeId, chauffeurId, paiementId || null, datePaiement, joursCouverts, dateFinStr, montant, mode, raccourcitDuree, note]
  );
  
  // Si raccourcit_duree = true, avancer la date de fin de remboursement
  if (raccourcitDuree) {
    await pool.query(
      `UPDATE vehicules 
       SET date_fin_paiement = date_fin_paiement + INTERVAL '$1 days'
       WHERE id = $2`,
      [joursCouverts, vehiculeId]
    );
  }
  
  return rows[0];
}

/**
 * Liste les pénalités d'un véhicule
 */
export async function listerPenalites(vehiculeId?: string, chauffeurId?: string, statut?: string) {
  let query = `
    SELECT p.*, v.immatriculation, c.nom as chauffeur_nom
    FROM penalites p
    JOIN vehicules v ON v.id = p.vehicule_id
    JOIN chauffeurs c ON c.id = p.chauffeur_id
    WHERE 1=1
  `;
  const params: any[] = [];
  
  if (vehiculeId) {
    params.push(vehiculeId);
    query += ` AND p.vehicule_id = $${params.length}`;
  }
  if (chauffeurId) {
    params.push(chauffeurId);
    query += ` AND p.chauffeur_id = $${params.length}`;
  }
  if (statut) {
    params.push(statut);
    query += ` AND p.statut = $${params.length}`;
  }
  
  query += ` ORDER BY p.date_penalite DESC`;
  
  const { rows } = await pool.query(query, params);
  return rows;
}

/**
 * Annule une pénalité (geste commercial, erreur, etc.)
 */
export async function annulerPenalite(
  penaliteId: string,
  userId: string,
  motif: string
) {
  const { rows } = await pool.query(
    `UPDATE penalites 
     SET statut = 'annulee', annule_par = $2, motif_annulation = $3
     WHERE id = $1 AND statut = 'active'
     RETURNING *`,
    [penaliteId, userId, motif]
  );
  
  if (rows.length > 0) {
    await writeAuditLog(userId, 'annulation_penalite', penaliteId, {
      motif,
      montant: rows[0].montant
    });
  }
  
  return rows[0];
}

/**
 * Récupère les paramètres de pénalité
 */
export async function listerParametres() {
  const { rows } = await pool.query(
    `SELECT * FROM parametres_penalites ORDER BY type_vehicule`
  );
  return rows;
}

/**
 * Met à jour les paramètres de pénalité
 */
export async function updateParametres(
  typeVehicule: string,
  data: {
    type_calcul?: string;
    montant_fixe?: number;
    pourcentage?: number;
    seuil_jours?: number;
    plafond?: number | null;
    actif?: boolean;
  }
) {
  const { rows } = await pool.query(
    `UPDATE parametres_penalites 
     SET type_calcul = COALESCE($2, type_calcul),
         montant_fixe = COALESCE($3, montant_fixe),
         pourcentage = COALESCE($4, pourcentage),
         seuil_jours = COALESCE($5, seuil_jours),
         plafond = $6,
         actif = COALESCE($7, actif),
         modifie_le = NOW()
     WHERE type_vehicule = $1
     RETURNING *`,
    [
      typeVehicule,
      data.type_calcul || null,
      data.montant_fixe || null,
      data.pourcentage || null,
      data.seuil_jours || null,
      data.plafond !== undefined ? data.plafond : null,
      data.actif !== undefined ? data.actif : null
    ]
  );
  return rows[0];
}

/**
 * Ajoute une exemption de pénalité
 */
export async function ajouterExemption(
  vehiculeId: string | null,
  chauffeurId: string | null,
  motif: string,
  dateDebut: string,
  dateFin: string | null,
  userId: string
) {
  const { rows } = await pool.query(
    `INSERT INTO exemptions_penalites 
     (vehicule_id, chauffeur_id, motif, date_debut, date_fin, cree_par)
     VALUES ($1, $2, $3, $4, $5, $6)
     RETURNING *`,
    [vehiculeId, chauffeurId, motif, dateDebut, dateFin, userId]
  );
  
  await writeAuditLog(userId, 'exemption_penalite', rows[0].id, {
    vehiculeId,
    chauffeurId,
    motif
  });
  
  return rows[0];
}

/**
 * Supprime une exemption
 */
export async function supprimerExemption(exemptionId: string, userId: string) {
  const { rows } = await pool.query(
    `UPDATE exemptions_penalites SET actif = false WHERE id = $1 RETURNING *`,
    [exemptionId]
  );
  
  if (rows.length > 0) {
    await writeAuditLog(userId, 'suppression_exemption', exemptionId);
  }
  
  return rows[0];
}

/**
 * Liste les exemptions
 */
export async function listerExemptions() {
  const { rows } = await pool.query(
    `SELECT e.*, v.immatriculation, c.nom as chauffeur_nom
     FROM exemptions_penalites e
     LEFT JOIN vehicules v ON v.id = e.vehicule_id
     LEFT JOIN chauffeurs c ON c.id = e.chauffeur_id
     WHERE e.actif = true
     ORDER BY e.cree_le DESC`
  );
  return rows;
}

/**
 * Récupère le total des pénalités par véhicule (pour affichage)
 */
export async function getTotalPenalites(vehiculeId: string) {
  const { rows } = await pool.query(
    `SELECT 
       COALESCE(SUM(CASE WHEN statut = 'active' THEN montant ELSE 0 END), 0) as total_actif,
       COALESCE(SUM(CASE WHEN statut = 'payee' THEN montant ELSE 0 END), 0) as total_paye,
       COALESCE(SUM(CASE WHEN statut = 'annulee' THEN montant ELSE 0 END), 0) as total_annule
     FROM penalites 
     WHERE vehicule_id = $1`,
    [vehiculeId]
  );
  
  return {
    totalActif: Number(rows[0]?.total_actif || 0),
    totalPaye: Number(rows[0]?.total_paye || 0),
    totalAnnule: Number(rows[0]?.total_annule || 0)
  };
}

/**
 * Vérifie si un véhicule doit être immobilisé selon le nombre de jours de retard cumulés
 * et déclenche la procédure si nécessaire
 */
export async function verifierImmobilisation(vehiculeId: string): Promise<{ shouldImmobilize: boolean; daysLate: number; reason: string }> {
  // Compter les jours de pénalités actives
  const { rows } = await pool.query(
    `SELECT COUNT(*) as jours_retard, MIN(date_penalite) as premiere_penalite
     FROM penalites 
     WHERE vehicule_id = $1 AND statut = 'active'`,
    [vehiculeId]
  );
  
  const joursRetard = parseInt(rows[0]?.jours_retard || '0', 10);
  
  if (joursRetard === 0) {
    return { shouldImmobilize: false, daysLate: 0, reason: 'Aucun jour de retard' };
  }
  
  // Récupérer le seuil de coupure du véhicule
  const { rows: vehicules } = await pool.query(
    `SELECT seuil_coupure_jours, coupure_auto, statut_moteur, imei_boitier
     FROM vehicules WHERE id = $1`,
    [vehiculeId]
  );
  
  const vehicule = vehicules[0];
  if (!vehicule) {
    return { shouldImmobilize: false, daysLate: joursRetard, reason: 'Véhicule non trouvé' };
  }
  
  // Vérifier si le véhicule a un boîtier configuré
  if (!vehicule.imei_boitier) {
    return { shouldImmobilize: false, daysLate: joursRetard, reason: 'Pas de boîtier configuré' };
  }
  
  // Vérifier si le seuil est atteint
  const seuil = vehicule.seuil_coupure_jours || 2;
  if (joursRetard < seuil) {
    return { shouldImmobilize: false, daysLate: joursRetard, reason: `Seuil non atteint (${joursRetard}/${seuil} jours)` };
  }
  
  // Vérifier si le moteur n'est pas déjà coupé
  if (vehicule.statut_moteur === 'coupe') {
    return { shouldImmobilize: false, daysLate: joursRetard, reason: 'Moteur déjà coupé' };
  }
  
  // Vérifier si la coupure auto est activée
  if (!vehicule.coupure_auto) {
    return { shouldImmobilize: true, daysLate: joursRetard, reason: 'Coupure manuelle requise (coupure_auto désactivée)' };
  }
  
  // Vérifier si l'immobilisation est activée globalement
  const { rows: params } = await pool.query(
    `SELECT valeur FROM parametres_immobilisation WHERE cle = 'immobilisation_active'`
  );
  
  if (params[0]?.valeur !== 'true') {
    return { shouldImmobilize: false, daysLate: joursRetard, reason: 'Immobilisation désactivée globalement' };
  }
  
  return { shouldImmobilize: true, daysLate: joursRetard, reason: `Seuil atteint (${joursRetard}/${seuil} jours)` };
}

/**
 * Réactive automatiquement un véhicule si tous les paiements sont à jour
 */
export async function verifierReactivation(vehiculeId: string): Promise<{ shouldReactivate: boolean; reason: string }> {
  // Vérifier s'il y a des pénalités actives
  const { rows } = await pool.query(
    `SELECT COUNT(*) as count FROM penalites WHERE vehicule_id = $1 AND statut = 'active'`,
    [vehiculeId]
  );
  
  const penalitesActives = parseInt(rows[0]?.count || '0', 10);
  
  if (penalitesActives === 0) {
    // Vérifier si le moteur est coupé
    const { rows: vehicules } = await pool.query(
      `SELECT statut_moteur FROM vehicules WHERE id = $1`,
      [vehiculeId]
    );
    
    if (vehicules[0]?.statut_moteur === 'coupe') {
      return { shouldReactivate: true, reason: 'Tous les paiements sont à jour' };
    }
  }
  
  return { shouldReactivate: false, reason: `${penalitesActives} pénalité(s) active(s)` };
}
