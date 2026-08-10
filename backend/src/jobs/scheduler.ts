import { logger } from '../utils/logger.js';
import pool from '../config/db.js';
import { executeImpayesJob } from './impayesJob.js';
import { executeAnomalyJob } from './anomalyJob.js';
import { executeSalaireJob } from './salaireJob.js';
import { executeFinancesJob } from './financesJob.js';
import { runPenalitesJob } from './penalitesJob.js';
import { recordJobResult, setJobNextRun } from '../services/monitoringService.js';

/**
 * Scheduler interne — Exécute les jobs planifiés.
 *
 * Jobs :
 * 1. Job nocturne des impayés (quotidien)
 * 2. Rapport IA admin (hebdomadaire, le lundi)
 * 3. Détection d'anomalies (toutes les N heures)
 *
 * Deux modes de déclenchement :
 * 1. Interne : setInterval vérifie chaque heure
 * 2. Externe : POST /api/v1/jobs/impayes ou /api/v1/jobs/anomalies
 */

let schedulerInterval: NodeJS.Timeout | null = null;
let lastRunDate: string | null = null;
let lastRapportWeek: string | null = null;
let lastAnomalyScanKey: string | null = null;
let lastSalaireMonth: string | null = null;
let lastFinancesMonth: string | null = null;
let lastPenalitesDate: string | null = null;

/**
 * Démarre le scheduler interne.
 * Vérifie chaque heure si c'est l'heure d'exécution du job.
 */
export function startScheduler(): void {
  logger.info('[Scheduler] Démarrage du scheduler de jobs nocturnes');

  // Vérifier toutes les heures
  schedulerInterval = setInterval(async () => {
    try {
      await checkAndRun();
    } catch (err: any) {
      logger.error(`[Scheduler] Erreur: ${err.message}`);
    }
  }, 60 * 60 * 1000); // Toutes les heures

  // Vérification immédiate au démarrage (après 30s)
  setTimeout(async () => {
    try {
      await checkAndRun();
    } catch (err: any) {
      logger.error(`[Scheduler] Erreur démarrage: ${err.message}`);
    }
  }, 30_000);
}

/**
 * Arrête le scheduler.
 */
export function stopScheduler(): void {
  if (schedulerInterval) {
    clearInterval(schedulerInterval);
    schedulerInterval = null;
    logger.info('[Scheduler] Arrêté');
  }
}

/**
 * Vérifie si c'est l'heure d'exécution et lance les jobs si nécessaire.
 */
async function checkAndRun(): Promise<void> {
  const now = new Date();
  const today = now.toISOString().split('T')[0];
  const currentHour = now.getUTCHours();

  // Ne pas exécuter le job impayes deux fois le même jour
  if (lastRunDate === today) {
    // Vérifier quand même le rapport IA admin et les anomalies
    await checkRapportHebdo();
    await checkAnomalies();
    await checkSalaires();
    await checkFinances();
    await checkPenalites();
    return;
  }

  // Lire l'heure configurée
  const { rows } = await pool.query(
    `SELECT valeur FROM parametres WHERE cle = 'job_impayes_heure'`,
  );
  const heureConfig = parseInt(rows[0]?.valeur ?? '2', 10);

  // Vérifier si on est dans la fenêtre d'exécution (heure configurée ± 30 min)
  if (now.getUTCHours() === heureConfig) {
    logger.info(`[Scheduler] Heure atteinte (${heureConfig}h UTC) — lancement du job`);
    await runJob();
    // Lancer aussi le rapport IA admin si c'est le bon jour
    await checkRapportHebdo();
    // Et le scan d'anomalies
    await checkAnomalies();
    // Et les salaires de fin de mois
    await checkSalaires();
    // Et le job finances (snapshot + rapport)
    await checkFinances();
    // Et les pénalités de retard
    await checkPenalites();
  }

  // Vérifier le scan d'anomalies (indépendant du job impayes)
  await checkAnomalies();
  await checkSalaires();
  await checkFinances();
  await checkPenalites();
}

/**
 * Exécute le job (appelé par le scheduler ou manuellement).
 */
export async function runJob(): Promise<void> {
  const today = new Date().toISOString().split('T')[0];
  if (lastRunDate === today) {
    logger.info('[Scheduler] Job déjà exécuté aujourd\'hui — ignoré');
    return;
  }

  try {
    const start = Date.now();
    const result = await executeImpayesJob();
    lastRunDate = result.date;
    recordJobResult('impayes', true, Date.now() - start);
    logger.info(`[Scheduler] Job terminé — ${result.impayes_detectes} impayés détectés`);
  } catch (err: any) {
    recordJobResult('impayes', false, 0, err.message);
    logger.error(`[Scheduler] Échec du job: ${err.message}`);
    throw err;
  }
}

/**
 * Force l'exécution du job (ignore la vérification d'heure).
 * Utilisé pour les tests ou l'exécution manuelle via API.
 */
export async function forceRunJob(): Promise<void> {
  logger.info('[Scheduler] Exécution forcée du job impayés');
  const result = await executeImpayesJob();
  lastRunDate = result.date;
  logger.info(`[Scheduler] Job forcé terminé — taux: ${result.taux_recouvrement}%`);
}

/**
 * Vérifie si c'est le jour du rapport IA admin (lundi par défaut)
 * et le génère automatiquement.
 */
async function checkRapportHebdo(): Promise<void> {
  const now = new Date();
  const weekLabel = getWeekLabel(now);

  // Ne pas exécuter deux fois la même semaine
  if (lastRapportWeek === weekLabel) return;

  // Lire le jour configuré (1 = Lundi)
  const { rows } = await pool.query(
    `SELECT valeur FROM parametres WHERE cle = 'ia_admin_job_jour'`,
  );
  const jourConfig = parseInt(rows[0]?.valeur ?? '1', 10);

  // getUTCDay() : 0=Dimanche, 1=Lundi, ...
  if (now.getUTCDay() === jourConfig) {
    logger.info(`[Scheduler] Jour IA admin atteint (jour ${jourConfig}) — génération du rapport`);
    try {
      const { generateRapportHebdo } = await import('../controllers/iaAdminController.js');
      const result = await generateRapportHebdo();
      lastRapportWeek = weekLabel;
      logger.info(`[Scheduler] Rapport IA admin généré : ${result.id} (${result.trajectoire})`);
    } catch (err: any) {
      logger.error(`[Scheduler] Erreur rapport IA admin : ${err.message}`);
    }
  }
}

/**
 * Force la génération du rapport IA admin (pour test ou exécution manuelle).
 */
export async function forceRapportAdmin(): Promise<{ id: string; trajectoire: string }> {
  logger.info('[Scheduler] Génération forcée du rapport IA admin');
  const { generateRapportHebdo } = await import('../controllers/iaAdminController.js');
  const result = await generateRapportHebdo();
  lastRapportWeek = getWeekLabel(new Date());
  return result;
}

function getWeekLabel(date: Date): string {
  const startOfWeek = new Date(date);
  startOfWeek.setDate(date.getDate() - date.getDay() + 1);
  return startOfWeek.toISOString().split('T')[0];
}

/**
 * Vérifie si c'est l'heure du scan d'anomalies (toutes les N heures)
 * et le lance automatiquement.
 */
async function checkAnomalies(): Promise<void> {
  const now = new Date();
  const currentHour = now.getUTCHours();

  // Lire la fréquence configurée (en heures)
  const { rows } = await pool.query(
    `SELECT valeur FROM parametres WHERE cle = 'anomalie_frequence_verification'`,
  );
  const frequence = parseInt(rows[0]?.valeur ?? '4', 10);

  // Vérifier si on est dans une fenêtre d'exécution
  // Ex: si fréquence=4, exécuter à 0h, 4h, 8h, 12h, 16h, 20h
  const heureExecution = currentHour % frequence === 0;

  // Vérifier que le scan n'a pas déjà été fait cette heure-ci
  const todayHourKey = `${now.toISOString().split('T')[0]}_${currentHour}`;
  if (!heureExecution || lastAnomalyScanKey === todayHourKey) return;

  logger.info(`[Scheduler] Heure scan anomalies (${currentHour}h UTC, fréquence=${frequence}h)`);
  try {
    const start = Date.now();
    const result = await executeAnomalyJob();
    lastAnomalyScanKey = todayHourKey;
    recordJobResult('anomalies', true, Date.now() - start);
    logger.info(`[Scheduler] Scan anomalies terminé : ${result.anomalies_detectees} anomalies`);
  } catch (err: any) {
    recordJobResult('anomalies', false, 0, err.message);
    logger.error(`[Scheduler] Erreur scan anomalies : ${err.message}`);
  }
}

/**
 * Force l'exécution du scan d'anomalies (pour test ou exécution manuelle).
 */
export async function forceAnomalyScan(): Promise<{ anomalies_detectees: number; alertes_envoyees: number }> {
  logger.info('[Scheduler] Scan d\'anomalies forcé');
  const result = await executeAnomalyJob();
  const now = new Date();
  lastAnomalyScanKey = `${now.toISOString().split('T')[0]}_${now.getUTCHours()}`;
  return { anomalies_detectees: result.anomalies_detectees, alertes_envoyees: result.alertes_envoyees };
}

/**
 * Vérifie si c'est la fin du mois et lance le calcul des salaires.
 * Exécuté le dernier jour du mois (ou le 1er du mois suivant pour le mois précédent).
 */
async function checkSalaires(): Promise<void> {
  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

  // Ne pas exécuter deux fois le même mois
  if (lastSalaireMonth === currentMonth) return;

  // Vérifier si on est le dernier jour du mois ou le 1er du mois suivant
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const isLastDayOfMonth = tomorrow.getMonth() !== now.getMonth();
  const isFirstDayOfMonth = now.getDate() === 1;

  if (!isLastDayOfMonth && !isFirstDayOfMonth) return;

  // Le mois à calculer est le mois précédent si on est le 1er
  const moisACalculer = isFirstDayOfMonth
    ? `${now.getFullYear()}-${String(now.getMonth()).padStart(2, '0')}`
    : currentMonth;

  // Vérifier si le module est actif
  const { rows } = await pool.query(
    `SELECT valeur FROM parametres WHERE cle = 'salaire_actif'`,
  );
  if ((rows[0]?.valeur ?? 'true') !== 'true') return;

  logger.info(`[Scheduler] Fin de mois détectée — calcul salaires ${moisACalculer}`);
  try {
    const start = Date.now();
    const result = await executeSalaireJob();
    lastSalaireMonth = currentMonth;
    recordJobResult('salaires', true, Date.now() - start);
    logger.info(`[Scheduler] Salaires calculés : Prop ${result.proprietaire} F, Emp ${result.employe} F`);
  } catch (err: any) {
    recordJobResult('salaires', false, 0, err.message);
    logger.error(`[Scheduler] Erreur calcul salaires : ${err.message}`);
  }
}

/**
 * Force l'exécution du calcul des salaires (pour test ou exécution manuelle).
 */
export async function forceSalaireJob(): Promise<{
  mois: string;
  proprietaire: number;
  employe: number;
  seuil_atteint: boolean;
}> {
  logger.info('[Scheduler] Calcul forcé des salaires');
  const result = await executeSalaireJob();
  lastSalaireMonth = result.mois;
  return result;
}

/**
 * Vérifie si c'est la fin du mois et lance le job finances (snapshot + rapport).
 */
async function checkFinances(): Promise<void> {
  const now = new Date();
  const currentMonth = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}`;

  // Ne pas exécuter deux fois le même mois
  if (lastFinancesMonth === currentMonth) return;

  // Vérifier si on est le dernier jour du mois ou le 1er du mois suivant
  const tomorrow = new Date(now);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const isLastDayOfMonth = tomorrow.getMonth() !== now.getMonth();
  const isFirstDayOfMonth = now.getDate() === 1;

  if (!isLastDayOfMonth && !isFirstDayOfMonth) return;

  logger.info(`[Scheduler] Fin de mois détectée — exécution job finances`);
  try {
    const start = Date.now();
    const result = await executeFinancesJob();
    lastFinancesMonth = currentMonth;
    recordJobResult('finances', true, Date.now() - start);
    logger.info(`[Scheduler] Job finances terminé : snapshot=${result.snapshotOk}, rapport=${result.rapportId}`);
  } catch (err: any) {
    recordJobResult('finances', false, 0, err.message);
    logger.error(`[Scheduler] Erreur job finances : ${err.message}`);
  }
}

/**
 * Force l'exécution du job finances (pour test ou exécution manuelle).
 */
export async function forceFinancesJob(): Promise<{
  mois: string;
  snapshotOk: boolean;
  rapportId: string | null;
}> {
  logger.info('[Scheduler] Exécution forcée du job finances');
  const result = await executeFinancesJob();
  lastFinancesMonth = result.mois;
  return result;
}

/**
 * Vérifie si c'est le moment de calculer les pénalités de retard (quotidien).
 */
async function checkPenalites(): Promise<void> {
  const now = new Date();
  const today = now.toISOString().split('T')[0];

  // Ne pas exécuter deux fois le même jour
  if (lastPenalitesDate === today) return;

  // Lire l'heure configurée pour les pénalités (par défaut 3h UTC)
  const { rows } = await pool.query(
    `SELECT valeur FROM parametres WHERE cle = 'job_penalites_heure'`,
  );
  const heureConfig = parseInt(rows[0]?.valeur ?? '3', 10);

  // Vérifier si on est dans la fenêtre d'exécution
  if (now.getUTCHours() !== heureConfig) return;

  logger.info(`[Scheduler] Heure pénalités atteinte (${heureConfig}h UTC) — calcul des pénalités`);
  try {
    const start = Date.now();
    const result = await runPenalitesJob();
    lastPenalitesDate = today;
    recordJobResult('penalites', true, Date.now() - start);
    logger.info(`[Scheduler] Pénalités calculées : ${result.creees} créées, ${result.ignorees} ignorées`);
  } catch (err: any) {
    recordJobResult('penalites', false, 0, err.message);
    logger.error(`[Scheduler] Erreur job pénalités : ${err.message}`);
  }
}

/**
 * Force l'exécution du job de calcul des pénalités (pour test ou exécution manuelle).
 */
export async function forcePenalitesJob(): Promise<{ creees: number; ignorees: number }> {
  logger.info('[Scheduler] Exécution forcée du job pénalités');
  const result = await runPenalitesJob();
  lastPenalitesDate = new Date().toISOString().split('T')[0];
  return result;
}
