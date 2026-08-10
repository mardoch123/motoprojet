import { logger } from '../utils/logger.js';
import { executeAnomalyScan, type AnomalyJobResult } from '../services/anomalyDetectionService.js';

/**
 * Job de détection d'anomalies — Prévention proactive.
 *
 * Exécution : toutes les N heures (configurable via anomalie_frequence_verification).
 * Peut aussi être déclenché manuellement via POST /api/v1/jobs/anomalies.
 *
 * Analyse les indicateurs clés et détecte :
 * 1. Chute soudaine du taux de recouvrement
 * 2. Chauffeur régulier qui ne paie plus
 * 3. Remboursements groupés (trou de trésorerie)
 * 4. Incidents multiples
 * 5. Cash anormalement bas
 * 6. Retards groupés
 *
 * Envoie une notification push admin immédiate pour chaque anomalie détectée.
 */

export async function executeAnomalyJob(): Promise<AnomalyJobResult> {
  logger.info('[JobAnomalies] Démarrage du scan de détection d\'anomalies');

  try {
    const result = await executeAnomalyScan();
    logger.info(
      `[JobAnomalies] Terminé — ${result.anomalies_detectees} anomalies détectées, ` +
      `${result.alertes_envoyees} alertes envoyées en ${result.duree_ms}ms`
    );
    return result;
  } catch (err: any) {
    logger.error(`[JobAnomalies] Erreur: ${err.message}`);
    throw err;
  }
}
