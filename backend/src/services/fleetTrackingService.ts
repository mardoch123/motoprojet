import pool from '../config/db.js';
import { logger } from '../utils/logger.js';
import { writeAuditLog } from '../services/audit.js';

/**
 * Service Fleet Tracking
 * Gère la communication avec les boîtiers GPS/IoT et l'immobilisation des véhicules
 */

// ─── Types ───────────────────────────────────────────────────────────────────

export interface TelemetriePayload {
  imei: string;
  latitude: number;
  longitude: number;
  vitesse: number;
  statut_moteur?: string;
  niveau_batterie?: number;
  timestamp?: string;
  donnees_brutes?: Record<string, unknown>;
}

export interface CommandeBoitier {
  id: string;
  vehicule_id: string;
  type_commande: 'immobiliser' | 'reactiver';
  statut: string;
  priorite: boolean;
}

// ─── Paramètres ──────────────────────────────────────────────────────────────

export async function getParametre(cle: string): Promise<string | null> {
  const { rows } = await pool.query(
    `SELECT valeur FROM parametres_immobilisation WHERE cle = $1`,
    [cle]
  );
  return rows[0]?.valeur ?? null;
}

export async function setParametre(cle: string, valeur: string): Promise<void> {
  await pool.query(
    `UPDATE parametres_immobilisation SET valeur = $2, modifie_le = NOW() WHERE cle = $1`,
    [cle, valeur]
  );
}

export async function getAllParametres(): Promise<Record<string, string>> {
  const { rows } = await pool.query(`SELECT cle, valeur FROM parametres_immobilisation`);
  const result: Record<string, string> = {};
  for (const row of rows) {
    result[row.cle] = row.valeur;
  }
  return result;
}

// ─── Télémétrie ──────────────────────────────────────────────────────────────

/**
 * Traite un payload de télémétrie reçu d'un boîtier GPS
 */
export async function traiterTelemetrie(payload: TelemetriePayload): Promise<{ vehiculeId: string | null; updated: boolean }> {
  // Trouver le véhicule par IMEI
  const { rows: vehicules } = await pool.query(
    `SELECT id, chauffeur_id, statut_moteur FROM vehicules WHERE imei_boitier = $1`,
    [payload.imei]
  );

  if (vehicules.length === 0) {
    logger.warn('Télémétrie reçue pour IMEI inconnu', { imei: payload.imei });
    return { vehiculeId: null, updated: false };
  }

  const vehicule = vehicules[0];

  // Mettre à jour la table vehicules (dernière position)
  await pool.query(
    `UPDATE vehicules SET 
       derniere_latitude = $2,
       derniere_longitude = $3,
       derniere_vitesse = $4,
       derniere_maj_telemetrie = NOW(),
       statut_moteur = COALESCE($5, statut_moteur)
     WHERE id = $1`,
    [
      vehicule.id,
      payload.latitude,
      payload.longitude,
      payload.vitesse,
      payload.statut_moteur || null,
    ]
  );

  // Insérer dans l'historique télémétrie
  await pool.query(
    `INSERT INTO telemetrie_vehicules 
     (vehicule_id, latitude, longitude, vitesse, statut_moteur, niveau_batterie, donnees_brutes)
     VALUES ($1, $2, $3, $4, $5, $6, $7)`,
    [
      vehicule.id,
      payload.latitude,
      payload.longitude,
      payload.vitesse,
      payload.statut_moteur || null,
      payload.niveau_batterie || null,
      payload.donnees_brutes ? JSON.stringify(payload.donnees_brutes) : null,
    ]
  );

  // Vérifier s'il y a des commandes en attente qui peuvent être exécutées
  await verifierCommandesEnAttente(vehicule.id, payload.vitesse);

  return { vehiculeId: vehicule.id, updated: true };
}

/**
 * Récupère la dernière télémétrie d'un véhicule
 */
export async function getDerniereTelemetrie(vehiculeId: string) {
  const { rows } = await pool.query(
    `SELECT * FROM telemetrie_vehicules 
     WHERE vehicule_id = $1 
     ORDER BY received_at DESC 
     LIMIT 1`,
    [vehiculeId]
  );
  return rows[0] || null;
}

/**
 * Récupère l'historique de télémétrie d'un véhicule
 */
export async function getHistoriqueTelemetrie(vehiculeId: string, limit = 100) {
  const { rows } = await pool.query(
    `SELECT * FROM telemetrie_vehicules 
     WHERE vehicule_id = $1 
     ORDER BY received_at DESC 
     LIMIT $2`,
    [vehiculeId, limit]
  );
  return rows;
}

// ─── Commandes ───────────────────────────────────────────────────────────────

/**
 * Vérifie les commandes en attente et les exécute si les conditions de sécurité sont remplies
 */
async function verifierCommandesEnAttente(vehiculeId: string, vitesseActuelle: number): Promise<void> {
  const vitesseMax = parseFloat(await getParametre('vitesse_max_coupe') || '0');
  
  if (vitesseActuelle > vitesseMax) {
    // Véhicule en mouvement, ne pas exécuter les commandes d'immobilisation
    return;
  }

  // Récupérer les commandes en attente
  const { rows: commandes } = await pool.query(
    `SELECT * FROM commandes_boitier 
     WHERE vehicule_id = $1 
     AND statut = 'en_attente'
     AND (expire_le IS NULL OR expire_le > NOW())
     ORDER BY priorite DESC, cree_le ASC`,
    [vehiculeId]
  );

  for (const commande of commandes) {
    // Pour immobiliser, vérifier double confirmation d'arrêt
    if (commande.type_commande === 'immobiliser') {
      const arretConfirme = await verifierArretConfirme(vehiculeId);
      if (!arretConfirme) {
        continue; // Pas encore confirmé, attendre
      }
    }

    // Exécuter la commande
    await executerCommande(commande);
  }
}

/**
 * Vérifie que le véhicule est à l'arrêt depuis suffisamment longtemps
 */
async function verifierArretConfirme(vehiculeId: string): Promise<boolean> {
  const dureeRequired = parseInt(await getParametre('duree_arret_confirme_secondes') || '30', 10);
  const vitesseMax = parseFloat(await getParametre('vitesse_max_coupe') || '0');

  // Récupérer les dernières télémétries
  const { rows } = await pool.query(
    `SELECT vitesse, received_at FROM telemetrie_vehicules 
     WHERE vehicule_id = $1 
     ORDER BY received_at DESC 
     LIMIT 10`,
    [vehiculeId]
  );

  if (rows.length < 2) return false;

  // Vérifier que les 2 dernières lectures sont à vitesse <= max
  const [recent, previous] = rows;
  if (recent.vitesse > vitesseMax || previous.vitesse > vitesseMax) {
    return false;
  }

  // Vérifier l'intervalle de temps entre les deux lectures
  const timeDiff = (new Date(recent.received_at).getTime() - new Date(previous.received_at).getTime()) / 1000;
  return timeDiff >= dureeRequired;
}

/**
 * Crée une commande d'immobilisation
 */
export async function creerCommandeImmobilisation(
  vehiculeId: string,
  userId: string | null,
  motif: string,
  source: 'manuel' | 'automatique' | 'penalite' = 'manuel',
  priorite = false
): Promise<string> {
  // Récupérer la position actuelle
  const { rows: vehicules } = await pool.query(
    `SELECT derniere_vitesse, derniere_latitude, derniere_longitude, chauffeur_id 
     FROM vehicules WHERE id = $1`,
    [vehiculeId]
  );

  const vehicule = vehicules[0];
  const vitesse = vehicule?.derniere_vitesse || 0;

  // Insérer la commande
  const { rows } = await pool.query(
    `INSERT INTO commandes_boitier 
     (vehicule_id, type_commande, declenche_par, motif, vitesse_au_declenchement, position_au_declenchement, priorite, expire_le)
     VALUES ($1, 'immobiliser', $2, $3, $4, point($5, $6), $7, NOW() + INTERVAL '24 hours')
     RETURNING id`,
    [
      vehiculeId,
      userId,
      motif,
      vitesse,
      vehicule?.derniere_longitude || 0,
      vehicule?.derniere_latitude || 0,
      priorite,
    ]
  );

  const commandeId = rows[0].id;

  // Journal d'audit
  await pool.query(
    `INSERT INTO audit_immobilisations 
     (vehicule_id, chauffeur_id, action, declenche_par, source, vitesse_au_moment, latitude, longitude, details)
     VALUES ($1, $2, 'coupure_demandee', $3, $4, $5, $6, $7, $8)`,
    [
      vehiculeId,
      vehicule?.chauffeur_id || null,
      userId,
      source,
      vitesse,
      vehicule?.derniere_latitude || null,
      vehicule?.derniere_longitude || null,
      JSON.stringify({ commandeId, motif }),
    ]
  );

  // Log
  logger.info('Commande immobilisation créée', { vehiculeId, commandeId, source, vitesse });

  // Si véhicule déjà à l'arrêt, essayer d'exécuter immédiatement
  if (vitesse <= 0) {
    await verifierCommandesEnAttente(vehiculeId, vitesse);
  }

  return commandeId;
}

/**
 * Crée une commande de réactivation (urgence)
 */
export async function creerCommandeReactivation(
  vehiculeId: string,
  userId: string,
  motif: string,
  priorite = true
): Promise<string> {
  const { rows: vehicules } = await pool.query(
    `SELECT chauffeur_id, derniere_latitude, derniere_longitude FROM vehicules WHERE id = $1`,
    [vehiculeId]
  );

  const vehicule = vehicules[0];

  const { rows } = await pool.query(
    `INSERT INTO commandes_boitier 
     (vehicule_id, type_commande, declenche_par, motif, priorite, expire_le)
     VALUES ($1, 'reactiver', $2, $3, $4, NOW() + INTERVAL '1 hour')
     RETURNING id`,
    [vehiculeId, userId, motif, priorite]
  );

  const commandeId = rows[0].id;

  // Journal d'audit
  await pool.query(
    `INSERT INTO audit_immobilisations 
     (vehicule_id, chauffeur_id, action, declenche_par, source, latitude, longitude, details)
     VALUES ($1, $2, 'reactivation', $3, 'urgence', $4, $5, $6)`,
    [
      vehiculeId,
      vehicule?.chauffeur_id || null,
      userId,
      vehicule?.derniere_latitude || null,
      vehicule?.derniere_longitude || null,
      JSON.stringify({ commandeId, motif }),
    ]
  );

  // Exécuter immédiatement (pas de vérification de vitesse pour réactivation)
  await executerCommande({ id: commandeId, vehicule_id: vehiculeId, type_commande: 'reactiver', statut: 'en_attente', priorite });

  logger.info('Commande réactivation créée', { vehiculeId, commandeId, userId });

  return commandeId;
}

/**
 * Exécute une commande (envoi au boîtier via API du fournisseur)
 */
async function executerCommande(commande: CommandeBoitier): Promise<void> {
  const apiUrl = await getParametre('fournisseur_api_url');
  const apiKey = await getParametre('fournisseur_api_key');

  if (!apiUrl || !apiKey) {
    logger.warn('API fournisseur non configurée, commande simulée', { commandeId: commande.id });
    // En mode dev, on simule l'exécution
    await simulerExecutionCommande(commande);
    return;
  }

  // Récupérer l'IMEI du véhicule
  const { rows: vehicules } = await pool.query(
    `SELECT imei_boitier FROM vehicules WHERE id = $1`,
    [commande.vehicule_id]
  );

  const imei = vehicules[0]?.imei_boitier;
  if (!imei) {
    await pool.query(
      `UPDATE commandes_boitier SET statut = 'echouee', erreur = 'IMEI non configuré' WHERE id = $1`,
      [commande.id]
    );
    return;
  }

  try {
    // Mettre à jour le statut
    await pool.query(
      `UPDATE commandes_boitier SET statut = 'envoyee', envoye_le = NOW(), tentatives = tentatives + 1 WHERE id = $1`,
      [commande.id]
    );

    // Appel API fournisseur (à adapter selon le fournisseur choisi)
    const endpoint = commande.type_commande === 'immobiliser' ? '/immobilize' : '/reactivate';
    const response = await fetch(`${apiUrl}${endpoint}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
      },
      body: JSON.stringify({ imei, command: commande.type_commande }),
    });

    if (response.ok) {
      // Commande acceptée, en attente de confirmation du boîtier
      logger.info('Commande envoyée au boîtier', { commandeId: commande.id, imei });
    } else {
      const error = await response.text();
      await pool.query(
        `UPDATE commandes_boitier SET statut = 'echouee', erreur = $2 WHERE id = $1`,
        [commande.id, error]
      );
    }
  } catch (err) {
    const errorMessage = err instanceof Error ? err.message : String(err);
    logger.error('Erreur envoi commande', { commandeId: commande.id, error: errorMessage });
    
    // Vérifier si on peut retry
    const { rows: updated } = await pool.query(
      `UPDATE commandes_boitier 
       SET tentatives = tentatives + 1, 
           statut = CASE WHEN tentatives + 1 >= max_tentatives THEN 'echouee' ELSE 'en_attente' END,
           erreur = $2
       WHERE id = $1
       RETURNING tentatives, max_tentatives`,
      [commande.id, errorMessage]
    );

    if (updated[0]?.tentatives >= updated[0]?.max_tentatives) {
      logger.error('Commande échouée après max tentatives', { commandeId: commande.id });
    }
  }
}

/**
 * Simule l'exécution d'une commande (mode dev sans boîtier réel)
 */
async function simulerExecutionCommande(commande: CommandeBoitier): Promise<void> {
  const nouveauStatut = commande.type_commande === 'immobiliser' ? 'coupe' : 'actif';
  
  await pool.query(
    `UPDATE vehicules SET statut_moteur = $2 WHERE id = $1`,
    [commande.vehicule_id, nouveauStatut]
  );

  await pool.query(
    `UPDATE commandes_boitier SET statut = 'confirmee', confirme_le = NOW() WHERE id = $1`,
    [commande.id]
  );

  // Audit
  await pool.query(
    `INSERT INTO audit_immobilisations (vehicule_id, action, source, details)
     VALUES ($1, $2, 'simulation', $3)`,
    [commande.vehicule_id, nouveauStatut === 'coupe' ? 'coupure_confirmee' : 'reactivation', JSON.stringify({ commandeId: commande.id })]
  );

  logger.info('Commande simulée (mode dev)', { commandeId: commande.id, nouveauStatut });
}

/**
 * Confirme l'exécution d'une commande (appelé par webhook du boîtier)
 */
export async function confirmerCommande(imei: string, typeCommande: string, success: boolean, error?: string): Promise<void> {
  const { rows: vehicules } = await pool.query(
    `SELECT id FROM vehicules WHERE imei_boitier = $1`,
    [imei]
  );

  if (vehicules.length === 0) return;

  const vehiculeId = vehicules[0].id;
  const nouveauStatutMoteur = typeCommande === 'immobiliser' ? 'coupe' : 'actif';

  if (success) {
    // Mettre à jour le véhicule
    await pool.query(
      `UPDATE vehicules SET statut_moteur = $2 WHERE id = $1`,
      [vehiculeId, nouveauStatutMoteur]
    );

    // Confirmer la commande
    await pool.query(
      `UPDATE commandes_boitier SET statut = 'confirmee', confirme_le = NOW() 
       WHERE vehicule_id = $1 AND type_commande = $2 AND statut IN ('en_attente', 'envoyee')
       ORDER BY cree_le DESC LIMIT 1`,
      [vehiculeId, typeCommande]
    );

    // Audit
    await pool.query(
      `INSERT INTO audit_immobilisations (vehicule_id, action, source)
       VALUES ($1, $2, 'boitier')`,
      [vehiculeId, typeCommande === 'immobiliser' ? 'coupure_confirmee' : 'reactivation']
    );

    logger.info('Commande confirmée par le boîtier', { vehiculeId, typeCommande });
  } else {
    // Échec
    await pool.query(
      `UPDATE commandes_boitier SET statut = 'echouee', erreur = $2 
       WHERE vehicule_id = $1 AND type_commande = $2 AND statut IN ('en_attente', 'envoyee')`,
      [vehiculeId, error || 'Erreur inconnue']
    );
  }
}

// ─── Liste véhicules / commandes ─────────────────────────────────────────────

export async function getVehiculesAvecTelemetrie() {
  const { rows } = await pool.query(`
    SELECT 
      v.id, v.immatriculation, v.type, v.statut_moteur,
      v.imei_boitier, v.fournisseur_boitier,
      v.derniere_latitude, v.derniere_longitude, 
      v.derniere_vitesse, v.derniere_maj_telemetrie,
      v.coupure_auto, v.seuil_coupure_jours,
      c.id as chauffeur_id, c.nom as chauffeur_nom, c.telephone as chauffeur_telephone,
      (SELECT COUNT(*) FROM commandes_boitier cb 
       WHERE cb.vehicule_id = v.id AND cb.statut IN ('en_attente', 'envoyee')) as commandes_en_cours
    FROM vehicules v
    LEFT JOIN chauffeurs c ON c.id = v.chauffeur_id
    WHERE v.statut = 'actif'
    ORDER BY v.derniere_maj_telemetrie DESC NULLS LAST
  `);
  return rows;
}

export async function getCommandesVehicule(vehiculeId: string, limit = 50) {
  const { rows } = await pool.query(
    `SELECT cb.*, u.nom as declencheur_nom
     FROM commandes_boitier cb
     LEFT JOIN users u ON u.id = cb.declenche_par
     WHERE cb.vehicule_id = $1
     ORDER BY cb.cree_le DESC
     LIMIT $2`,
    [vehiculeId, limit]
  );
  return rows;
}

export async function getAuditImmobilisations(vehiculeId?: string, limit = 100) {
  let query = `
    SELECT a.*, v.immatriculation, c.nom as chauffeur_nom, u.nom as declencheur_nom
    FROM audit_immobilisations a
    JOIN vehicules v ON v.id = a.vehicule_id
    LEFT JOIN chauffeurs c ON c.id = a.chauffeur_id
    LEFT JOIN users u ON u.id = a.declenche_par
  `;
  const params: unknown[] = [];

  if (vehiculeId) {
    params.push(vehiculeId);
    query += ` WHERE a.vehicule_id = $1`;
  }

  query += ` ORDER BY a.horodatage DESC`;
  
  params.push(limit);
  query += ` LIMIT $${params.length}`;

  const { rows } = await pool.query(query, params);
  return rows;
}
