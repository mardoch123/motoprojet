import { logger } from '../utils/logger.js';
import { calculerSalairesMois, enregistrerSalaires, verifierAnomalieSalaire } from '../services/salaireService.js';

/**
 * Job de fin de mois — Calcul automatique des salaires.
 *
 * Exécuté le dernier jour du mois (ou manuellement via API).
 * Calcule les salaires propriétaire + employé selon les paramètres,
 * les enregistre en base, et vérifie les anomalies.
 */
export async function executeSalaireJob(): Promise<{
  mois: string;
  proprietaire: number;
  employe: number;
  seuil_atteint: boolean;
  anomalies: boolean;
}> {
  const now = new Date();
  const mois = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

  logger.info(`[SalaireJob] Calcul des salaires pour ${mois}`);

  try {
    const calcul = await calculerSalairesMois(mois);
    const saved = await enregistrerSalaires(calcul);

    // Vérifier les anomalies
    let anomalies = false;
    try {
      await verifierAnomalieSalaire(mois);
    } catch (err: any) {
      logger.error(`[SalaireJob] Erreur vérification anomalie: ${err.message}`);
      anomalies = true;
    }

    const proprietaire = parseFloat(saved.proprietaire?.montant ?? '0');
    const employe = parseFloat(saved.employe?.montant ?? '0');
    const seuilAtteint = calcul.proprietaire.seuilAtteint;

    logger.info(`[SalaireJob] Terminé — Prop: ${proprietaire} F, Emp: ${employe} F, Seuil: ${seuilAtteint}`);

    return {
      mois,
      proprietaire,
      employe,
      seuil_atteint: seuilAtteint,
      anomalies,
    };
  } catch (err: any) {
    logger.error(`[SalaireJob] Échec: ${err.message}`);
    throw err;
  }
}
