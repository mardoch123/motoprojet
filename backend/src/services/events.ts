import pool from '../config/db.js';
import { logger } from '../utils/logger.js';

/**
 * Service d'événements cross-module.
 * Permet à un module (ex: Paiements) de déclencher des actions
 * dans d'autres modules (ex: Chauffeurs → changement statut auto).
 *
 * Événements supportés :
 * - PAIEMENT_ENREGISTRE  → vérifie retards et met à jour statut chauffeur
 * - AFFECTATION_CREE     → met à jour le statut véhicule
 * - AFFECTATION_TERMINEE → libère le véhicule
 */

type EventHandler = (payload: Record<string, unknown>) => Promise<void>;

const handlers: Map<string, EventHandler[]> = new Map();

export function on(event: string, handler: EventHandler): void {
  const list = handlers.get(event) ?? [];
  list.push(handler);
  handlers.set(event, list);
}

export async function emit(event: string, payload: Record<string, unknown>): Promise<void> {
  const list = handlers.get(event);
  if (!list || list.length === 0) return;

  logger.info(`[Event] ${event}`, payload);

  for (const handler of list) {
    try {
      await handler(payload);
    } catch (err: any) {
      logger.error(`[Event] Erreur handler ${event}`, { error: err.message });
    }
  }
}

// ─── Handler : recalcul statut chauffeur après paiement ──────────────────────
on('PAIEMENT_ENREGISTRE', async (payload) => {
  const chauffeurId = payload['chauffeur_id'] as string;
  if (!chauffeurId) return;

  // Vérifier le dernier paiement du chauffeur
  const { rows } = await pool.query(
    `SELECT MAX(date) AS dernier_paiement
     FROM paiements WHERE chauffeur_id = $1`,
    [chauffeurId],
  );

  const dernierPaiement = rows[0]?.dernier_paiement;
  if (!dernierPaiement) return;

  const joursDepuis = Math.floor(
    (Date.now() - new Date(dernierPaiement).getTime()) / (1000 * 60 * 60 * 24),
  );

  let nouveauStatut: string;
  if (joursDepuis <= 7) {
    nouveauStatut = 'actif';
  } else if (joursDepuis <= 30) {
    nouveauStatut = 'retard';
  } else {
    nouveauStatut = 'defaut';
  }

  await pool.query(
    `UPDATE chauffeurs SET statut = $1 WHERE id = $2 AND statut NOT IN ('termine')`,
    [nouveauStatut, chauffeurId],
  );

  logger.info(`[Event] Chauffeur ${chauffeurId} → statut: ${nouveauStatut} (${joursDepuis}j depuis dernier paiement)`);
});

// ─── Handler : vérification périodique des retards (appelé par cron) ─────────
export async function checkRetards(): Promise<void> {
  const { rows } = await pool.query(`
    SELECT c.id, c.nom, MAX(p.date) AS dernier_paiement
    FROM chauffeurs c
    LEFT JOIN paiements p ON p.chauffeur_id = c.id
    WHERE c.statut IN ('actif', 'retard')
    GROUP BY c.id, c.nom
  `);

  for (const row of rows) {
    const jours = row.dernier_paiement
      ? Math.floor((Date.now() - new Date(row.dernier_paiement).getTime()) / (1000 * 60 * 60 * 24))
      : 999;

    let nouveauStatut: string;
    if (jours <= 7) {
      nouveauStatut = 'actif';
    } else if (jours <= 30) {
      nouveauStatut = 'retard';
    } else {
      nouveauStatut = 'defaut';
    }

    if (nouveauStatut !== row.statut) {
      await pool.query(
        `UPDATE chauffeurs SET statut = $1 WHERE id = $2`,
        [nouveauStatut, row.id],
      );
      logger.info(`[CheckRetards] ${row.nom} → ${nouveauStatut} (${jours}j)`);
    }
  }
}
