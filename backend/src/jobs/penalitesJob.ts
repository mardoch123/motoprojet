import { calculerPenalitesJour, verifierImmobilisation, verifierReactivation } from '../services/penalitesService.js';
import { creerCommandeImmobilisation, creerCommandeReactivation, getVehiculesAvecTelemetrie } from '../services/fleetTrackingService.js';
import { logger } from '../utils/logger.js';
import pool from '../config/db.js';

/**
 * Job quotidien de calcul des pénalités de retard
 * Vérifie aussi si des véhicules doivent être immobilisés ou réactivés
 */
export async function runPenalitesJob() {
  logger.info('Démarrage du job de calcul des pénalités');
  
  try {
    // 1. Calculer les pénalités du jour
    const result = await calculerPenalitesJour();
    logger.info('Job pénalités terminé', { 
      creees: result.creees, 
      ignorees: result.ignorees 
    });
    
    // 2. Vérifier les véhicules à immobiliser
    const immobilisations = await verifierVehiculesImmobiliser();
    
    // 3. Vérifier les véhicules à réactiver
    const reactivations = await verifierVehiculesReacter();
    
    return { 
      ...result, 
      immobilisations,
      reactivations
    };
  } catch (err) {
    logger.error('Erreur job pénalités', { 
      error: err instanceof Error ? err.message : String(err) 
    });
    throw err;
  }
}

/**
 * Vérifie tous les véhicules et immobilise ceux qui ont dépassé le seuil
 */
async function verifierVehiculesImmobiliser(): Promise<{ demandes: number; auto: number; manuelles: number }> {
  // Récupérer les véhicules avec des pénalités actives
  const { rows: vehicules } = await pool.query(`
    SELECT DISTINCT v.id, v.immatriculation, v.chauffeur_id, v.coupure_auto
    FROM vehicules v
    JOIN penalites p ON p.vehicule_id = v.id AND p.statut = 'active'
    WHERE v.statut = 'actif' AND v.imei_boitier IS NOT NULL
  `);
  
  let demandes = 0;
  let auto = 0;
  let manuelles = 0;
  
  for (const vehicule of vehicules) {
    const check = await verifierImmobilisation(vehicule.id);
    
    if (check.shouldImmobilize) {
      demandes++;
      
      // Créer la commande d'immobilisation
      await creerCommandeImmobilisation(
        vehicule.id,
        null, // Système
        `Immobilisation automatique après ${check.daysLate} jours de retard`,
        'penalite'
      );
      
      if (vehicule.coupure_auto) {
        auto++;
        logger.info('Immobilisation automatique déclenchée', { 
          vehiculeId: vehicule.id, 
          jours: check.daysLate 
        });
      } else {
        manuelles++;
        logger.info('Immobilisation en attente validation manuelle', { 
          vehiculeId: vehicule.id, 
          jours: check.daysLate 
        });
      }
      
      // TODO: Envoyer notification au chauffeur avec préavis
    }
  }
  
  return { demandes, auto, manuelles };
}

/**
 * Vérifie les véhicules coupés et les réactive si les paiements sont à jour
 */
async function verifierVehiculesReacter(): Promise<{ reactivees: number }> {
  // Récupérer les véhicules avec moteur coupé
  const { rows: vehicules } = await pool.query(`
    SELECT id, immatriculation
    FROM vehicules
    WHERE statut_moteur = 'coupe' AND statut = 'actif'
  `);
  
  let reactivees = 0;
  
  for (const vehicule of vehicules) {
    const check = await verifierReactivation(vehicule.id);
    
    if (check.shouldReactivate) {
      // Créer la commande de réactivation
      await creerCommandeReactivation(
        vehicule.id,
        null as unknown as string, // Système
        `Réactivation automatique : ${check.reason}`,
        false // Pas prioritaire
      );
      
      reactivees++;
      logger.info('Réactivation automatique déclenchée', { vehiculeId: vehicule.id });
    }
  }
  
  return { reactivees };
}
