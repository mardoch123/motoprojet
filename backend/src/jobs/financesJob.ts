import { logger } from '../utils/logger.js';
import { enregistrerSnapshotPatrimoine, genererRapportMensuel } from '../services/financesService.js';

/**
 * Job de fin de mois : snapshot patrimoine + rapport mensuel
 */
export async function executeFinancesJob(): Promise<{
  mois: string;
  snapshotOk: boolean;
  rapportId: string | null;
}> {
  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

  logger.info(`[FinancesJob] Exécution du job finances pour ${currentMonth}`);

  // 1. Snapshot patrimoine
  let snapshotOk = false;
  try {
    await enregistrerSnapshotPatrimoine();
    snapshotOk = true;
    logger.info('[FinancesJob] Snapshot patrimoine enregistré');
  } catch (err: any) {
    logger.error(`[FinancesJob] Erreur snapshot: ${err.message}`);
  }

  // 2. Rapport mensuel (si on est le 1er du mois, pour le mois précédent)
  let rapportId: string | null = null;
  const isFirstDayOfMonth = now.getDate() === 1;
  if (isFirstDayOfMonth) {
    const moisRapport = `${now.getFullYear()}-${String(now.getMonth()).padStart(2, '0')}`;
    try {
      const rapport = await genererRapportMensuel(moisRapport);
      rapportId = rapport.id;
      logger.info(`[FinancesJob] Rapport mensuel ${moisRapport} généré : ${rapportId}`);
    } catch (err: any) {
      logger.error(`[FinancesJob] Erreur rapport mensuel: ${err.message}`);
    }
  }

  return { mois: currentMonth, snapshotOk, rapportId };
}
