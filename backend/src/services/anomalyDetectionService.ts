import pool from '../config/db.js';
import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';
import { sendNotification } from './notificationService.js';

/**
 * Service de détection d'anomalies — Prévention proactive.
 *
 * Analyse les indicateurs clés et détecte les écarts significatifs
 * par rapport à la tendance historique. Génère des alertes immédiates
 * avec résumé en langage clair via l'IA.
 *
 * Règles implémentées :
 * 1. chute_recouvrement      — Baisse soudaine du taux vs moyenne 7j
 * 2. chauffeur_arret_paiement — Chauffeur régulier qui ne paie plus
 * 3. remboursements_simultanes — Plusieurs véhicules finissent ensemble
 * 4. incidents_multiples      — Plusieurs véhicules en panne simultanément
 * 5. cash_anormalement_bas    — Cash journalier sous la moyenne
 * 6. retards_ensemble         — Plusieurs chauffeurs passent en retard d'un coup
 */

// ─── Types ──────────────────────────────────────────────────────────────────

export type TypeAnomalie =
  | 'chute_recouvrement'
  | 'chauffeur_arret_paiement'
  | 'remboursements_simultanes'
  | 'incidents_multiples'
  | 'cash_anormalement_bas'
  | 'retards_ensemble'
  | 'autre';

export type Severite = 'critique' | 'haute' | 'moyenne' | 'basse';

export interface AnomalieDetectee {
  type_anomalie: TypeAnomalie;
  severite: Severite;
  titre: string;
  description: string;
  cause_probable?: string;
  actions_suggerees: string[];
  contexte: Record<string, unknown>;
}

export interface AnomalyJobResult {
  date: string;
  anomalies_detectees: number;
  alertes_envoyees: number;
  duree_ms: number;
  details: string[];
}

// ─── Paramètres ──────────────────────────────────────────────────────────────

interface AnomalyParams {
  frequenceVerification: number;  // heures
  seuilChuteRecouvrement: number; // % de baisse
  seuilCashBasPct: number;       // % sous la moyenne
  fenetreGroupeJours: number;    // jours pour groupe
  actif: boolean;
}

async function getParams(): Promise<AnomalyParams> {
  const { rows } = await pool.query(
    `SELECT cle, valeur FROM parametres WHERE cle LIKE 'anomalie_%'`,
  );
  const get = (cle: string, def: string): string =>
    rows.find(r => r.cle === cle)?.valeur ?? def;

  return {
    frequenceVerification: parseInt(get('anomalie_frequence_verification', '4'), 10),
    seuilChuteRecouvrement: parseInt(get('anomalie_seuil_chute_recouvrement', '15'), 10),
    seuilCashBasPct: parseInt(get('anomalie_seuil_cash_bas_pct', '40'), 10),
    fenetreGroupeJours: parseInt(get('anomalie_fenetre_groupe_jours', '30'), 10),
    actif: get('anomalie_actif', 'true') === 'true',
  };
}

// ─── Point d'entrée principal ────────────────────────────────────────────────

/**
 * Exécute le scan complet des anomalies.
 * Appelé par le scheduler toutes les N heures.
 */
export async function executeAnomalyScan(): Promise<AnomalyJobResult> {
  const startTime = Date.now();
  const today = new Date().toISOString().split('T')[0];
  const details: string[] = [];

  logger.info('[Anomalies] Démarrage du scan');

  const params = await getParams();
  if (!params.actif) {
    logger.info('[Anomalies] Détection désactivée — skip');
    return { date: today, anomalies_detectees: 0, alertes_envoyees: 0, duree_ms: 0, details: ['Désactivé'] };
  }

  const anomalies: AnomalieDetectee[] = [];

  // Exécuter toutes les règles en parallèle
  const results = await Promise.allSettled([
    detecterChuteRecouvrement(params),
    detecterChauffeurArretPaiement(),
    detecterRemboursementsSimultanes(params),
    detecterIncidentsMultiples(),
    detecterCashAnormalementBas(params),
    detecterRetardsEnsemble(),
  ]);

  for (const r of results) {
    if (r.status === 'fulfilled' && r.value) {
      anomalies.push(r.value);
      details.push(`${r.value.type_anomalie}: ${r.value.titre}`);
    } else if (r.status === 'rejected') {
      logger.error(`[Anomalies] Erreur règle: ${r.reason?.message}`);
    }
  }

  // Filtrer les anomalies déjà détectées récemment (même type, < 24h)
  const anomaliesNouvelles = await filtrerDoublons(anomalies);

  // Stocker et notifier
  let alertesEnvoyees = 0;
  for (const anomalie of anomaliesNouvelles) {
    const id = await stockerAnomalie(anomalie);

    // Enrichir via l'IA (mise en langage clair)
    const enrichi = await enrichirViaIA(anomalie);

    // Mettre à jour avec l'enrichissement
    await pool.query(
      `UPDATE anomalies_detectees SET
         cause_probable = $1,
         actions_suggerees = $2,
         description = COALESCE(NULLIF(description, ''), $3)
       WHERE id = $4`,
      [enrichi.cause_probable, JSON.stringify(enrichi.actions_suggerees), enrichi.description, id],
    );

    // Envoyer la notification push admin
    await envoyerAlerteAdmin(id, anomalie, enrichi);
    alertesEnvoyees++;
  }

  const duree_ms = Date.now() - startTime;
  logger.info(`[Anomalies] Scan terminé en ${duree_ms}ms — ${anomaliesNouvelles.length} nouvelles anomalies, ${alertesEnvoyees} alertes`);

  return {
    date: today,
    anomalies_detectees: anomaliesNouvelles.length,
    alertes_envoyees: alertesEnvoyees,
    duree_ms,
    details,
  };
}

// ─── Règle 1 : Chute du taux de recouvrement ────────────────────────────────

async function detecterChuteRecouvrement(params: AnomalyParams): Promise<AnomalieDetectee | null> {
  // Comparer le taux actuel vs la moyenne des 7 derniers jours
  const { rows } = await pool.query(`
    SELECT
      date,
      taux_recouvrement,
      AVG(taux_recouvrement) OVER (
        ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
      ) AS moyenne_7j,
      AVG(taux_recouvrement) OVER (
        ORDER BY date ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
      ) - taux_recouvrement AS ecart
    FROM historique_taux_recouvrement
    WHERE date >= CURRENT_DATE - INTERVAL '14 days'
    ORDER BY date DESC
    LIMIT 1
  `);

  if (rows.length === 0) return null;

  const tauxActuel = parseFloat(rows[0].taux_recouvrement);
  const moyenne7j = parseFloat(rows[0].moyenne_7j) || tauxActuel;
  const ecart = moyenne7j - tauxActuel;

  if (ecart < params.seuilChuteRecouvrement) return null;

  const severite: Severite = ecart > 30 ? 'critique' : ecart > 20 ? 'haute' : 'moyenne';

  return {
    type_anomalie: 'chute_recouvrement',
    severite,
    titre: `Chute du taux de recouvrement : ${tauxActuel.toFixed(1)}%`,
    description: `Le taux de recouvrement est passé à ${tauxActuel.toFixed(1)}%, soit une baisse de ${ecart.toFixed(1)} points par rapport à la moyenne de 7 jours (${moyenne7j.toFixed(1)}%).`,
    contexte: { taux_actuel: tauxActuel, moyenne_7j: moyenne7j, ecart: ecart },
    actions_suggerees: [],
  };
}

// ─── Règle 2 : Chauffeur régulier qui ne paie plus ──────────────────────────

async function detecterChauffeurArretPaiement(): Promise<AnomalieDetectee | null> {
  // Chauffeurs qui payaient régulièrement et ont subitement arrêté (3+ jours)
  const { rows } = await pool.query(`
    SELECT
      c.id AS chauffeur_id,
      c.nom,
      c.statut,
      c.jours_impayes_cumules,
      c.dernier_paiement_date,
      v.plaque,
      v.id AS vehicule_id,
      -- Vérifier qu'il payait bien avant (au moins 10 paiements dans les 30 derniers jours)
      COUNT(p.id) FILTER (WHERE p.date >= CURRENT_DATE - INTERVAL '30 days'
                          AND p.date < CURRENT_DATE - INTERVAL '3 days') AS paiements_recents_avant,
      -- Moyenne des paiements sur les 30 derniers jours (avant l'arrêt)
      COALESCE(AVG(p.montant) FILTER (WHERE p.date >= CURRENT_DATE - INTERVAL '30 days'
                          AND p.date < CURRENT_DATE - INTERVAL '3 days'), 0) AS moy_paiement
    FROM chauffeurs c
    JOIN affectations a ON a.chauffeur_id = c.id AND a.date_fin IS NULL
    JOIN vehicules v ON v.id = a.vehicule_id
    LEFT JOIN paiements p ON p.chauffeur_id = c.id
    WHERE c.statut IN ('retard', 'defaut')
      AND c.jours_impayes_cumules >= 3
      AND c.dernier_paiement_date IS NOT NULL
      AND c.dernier_paiement_date < CURRENT_DATE - INTERVAL '2 days'
    GROUP BY c.id, c.nom, c.statut, c.jours_impayes_cumules,
             c.dernier_paiement_date, v.plaque, v.id
    HAVING COUNT(p.id) FILTER (WHERE p.date >= CURRENT_DATE - INTERVAL '30 days'
                          AND p.date < CURRENT_DATE - INTERVAL '3 days') >= 10
  `);

  if (rows.length === 0) return null;

  // Prendre le cas le plus significatif
  const pire = rows[0];
  const severite: Severite = rows.length > 3 ? 'haute' : rows.length > 1 ? 'moyenne' : 'basse';

  const nomListe = rows.length === 1
    ? pire.nom
    : `${rows.length} chauffeurs`;

  return {
    type_anomalie: 'chauffeur_arret_paiement',
    severite,
    titre: `Arrêt de paiement — ${nomListe}`,
    description: rows.length === 1
      ? `${pire.nom} (véhicule ${pire.plaque}) ne paie plus depuis ${pire.jours_impayes_cumules} jours alors qu'il était régulier (${parseInt(pire.paiements_recents_avant)} paiements sur les 30 derniers jours).`
      : `${rows.length} chauffeurs réguliers ont arrêté de payer simultanément : ${rows.map((r: any) => r.nom).join(', ')}.`,
    contexte: { chauffeurs: rows.map(r => ({ id: r.chauffeur_id, nom: r.nom, jours: r.jours_impayes_cumules, plaque: r.plaque })) },
    actions_suggerees: [],
  };
}

// ─── Règle 3 : Remboursements simultanés (trou de trésorerie) ───────────────

async function detecterRemboursementsSimultanes(params: AnomalyParams): Promise<AnomalieDetectee | null> {
  // Détecter les groupes de véhicules dont la date de fin de remboursement
  // tombe dans la même fenêtre de N jours
  const { rows } = await pool.query(`
    SELECT
      DATE_TRUNC('month', v.date_fin_remboursement) AS fin_groupe,
      COUNT(*) AS nb_vehicules,
      SUM(v.prix_achat) AS montant_total,
      ARRAY_AGG(v.plaque) AS plaques
    FROM vehicules v
    WHERE v.statut = 'en_remboursement'
      AND v.date_fin_remboursement IS NOT NULL
    GROUP BY DATE_TRUNC('month', v.date_fin_remboursement)
    HAVING COUNT(*) >= 3
    ORDER BY fin_groupe ASC
    LIMIT 5
  `);

  if (rows.length === 0) return null;

  // Vérifier si le premier groupe est dans les 60 prochains jours (risque imminent)
  const prochain = rows[0];
  const dateFin = new Date(prochain.fin_groupe);
  const joursRestants = Math.ceil((dateFin.getTime() - Date.now()) / (1000 * 60 * 60 * 24));

  if (joursRestants > 60) return null; // Pas encore imminent

  const severite: Severite = joursRestants <= 15 ? 'critique' : joursRestants <= 30 ? 'haute' : 'moyenne';
  const nbVehicules = parseInt(prochain.nb_vehicules, 10);

  return {
    type_anomalie: 'remboursements_simultanes',
    severite,
    titre: `${nbVehicules} véhicules finissent leur remboursement en même temps`,
    description: `${nbVehicules} véhicules (${prochain.plaques.join(', ')}) atteindront leur fin de remboursement vers le ${dateFin.toLocaleDateString('fr-FR')}, soit dans ${joursRestants} jours. Cela créera un trou de trésorerie de ${parseInt(prochain.montant_total).toLocaleString('fr-FR')} FCFA de revenus perdus, et les salaires pourraient tomber à 0 F si aucun nouveau véhicule n'est démarré entre-temps.`,
    contexte: {
      nb_vehicules: nbVehicules,
      date_fin: dateFin.toISOString().split('T')[0],
      jours_restants: joursRestants,
      montant_total: parseInt(prochain.montant_total),
      plaques: prochain.plaques,
    },
    actions_suggerees: [],
  };
}

// ─── Règle 4 : Incidents multiples ──────────────────────────────────────────

async function detecterIncidentsMultiples(): Promise<AnomalieDetectee | null> {
  const { rows } = await pool.query(`
    SELECT
      COUNT(*) AS nb_incidents,
      COUNT(DISTINCT i.vehicule_id) AS nb_vehicules,
      ARRAY_AGG(DISTINCT v.plaque) AS plaques,
      ARRAY_AGG(DISTINCT i.type) AS types
    FROM incidents i
    JOIN vehicules v ON v.id = i.vehicule_id
    WHERE i.statut != 'resolu'
      AND i.date >= CURRENT_DATE - INTERVAL '7 days'
  `);

  if (rows.length === 0 || parseInt(rows[0].nb_vehicules) < 3) return null;

  const nbVehicules = parseInt(rows[0].nb_vehicules, 10);
  const severite: Severite = nbVehicules >= 5 ? 'haute' : 'moyenne';

  return {
    type_anomalie: 'incidents_multiples',
    severite,
    titre: `${nbVehicules} véhicules en incident simultanément`,
    description: `${nbVehicules} véhicules sont immobilisés pour incident (${rows[0].types.join(', ')}). Plaques : ${rows[0].plaques.join(', ')}. Cela réduit la capacité de remboursement de ${Math.round(nbVehicules * 5000).toLocaleString('fr-FR')} FCFA/jour.`,
    contexte: { nb_vehicules: nbVehicules, plaques: rows[0].plaques, types: rows[0].types },
    actions_suggerees: [],
  };
}

// ─── Règle 5 : Cash anormalement bas ────────────────────────────────────────

async function detecterCashAnormalementBas(params: AnomalyParams): Promise<AnomalieDetectee | null> {
  // Comparer le cash d'aujourd'hui vs la moyenne des 7 derniers jours
  const { rows } = await pool.query(`
    WITH cash_par_jour AS (
      SELECT
        date AS jour,
        SUM(montant) AS cash_jour
      FROM paiements
      WHERE date >= CURRENT_DATE - INTERVAL '14 days'
      GROUP BY date
    )
    SELECT
      jour,
      cash_jour,
      AVG(cash_jour) OVER (
        ORDER BY jour ROWS BETWEEN 7 PRECEDING AND 1 PRECEDING
      ) AS moyenne_7j
    FROM cash_par_jour
    WHERE jour = CURRENT_DATE
    LIMIT 1
  `);

  if (rows.length === 0) return null;

  const cashJour = parseFloat(rows[0].cash_jour);
  const moyenne7j = parseFloat(rows[0].moyenne_7j) || cashJour;

  if (moyenne7j === 0) return null;

  const pctActuel = (cashJour / moyenne7j) * 100;

  if (pctActuel >= params.seuilCashBasPct) return null;

  const severite: Severite = pctActuel < 20 ? 'critique' : pctActuel < 30 ? 'haute' : 'moyenne';

  return {
    type_anomalie: 'cash_anormalement_bas',
    severite,
    titre: `Cash journalier anormalement bas : ${cashJour.toLocaleString('fr-FR')} FCFA`,
    description: `Le cash du jour (${cashJour.toLocaleString('fr-FR')} FCFA) est à ${pctActuel.toFixed(0)}% de la moyenne des 7 derniers jours (${Math.round(moyenne7j).toLocaleString('fr-FR')} FCFA). Baisse de ${(100 - pctActuel).toFixed(0)}%.`,
    contexte: { cash_jour: cashJour, moyenne_7j: Math.round(moyenne7j), pct: pctActuel.toFixed(0) },
    actions_suggerees: [],
  };
}

// ─── Règle 6 : Plusieurs chauffeurs passent en retard ensemble ──────────────

async function detecterRetardsEnsemble(): Promise<AnomalieDetectee | null> {
  const { rows } = await pool.query(`
    SELECT
      COUNT(*) AS nb_retards,
      ARRAY_AGG(c.nom) AS noms
    FROM chauffeurs c
    WHERE c.statut = 'retard'
      AND c.jours_impayes_cumules BETWEEN 1 AND 3
      AND c.dernier_paiement_date = CURRENT_DATE - INTERVAL '1 day'
  `);

  if (rows.length === 0 || parseInt(rows[0].nb_retards) < 3) return null;

  const nbRetards = parseInt(rows[0].nb_retards, 10);
  const severite: Severite = nbRetards >= 6 ? 'haute' : 'moyenne';

  return {
    type_anomalie: 'retards_ensemble',
    severite,
    titre: `${nbRetards} chauffeurs passent en retard simultanément`,
    description: `${nbRetards} chauffeurs sont passés en retard aujourd'hui même : ${rows[0].noms.slice(0, 5).join(', ')}${rows[0].noms.length > 5 ? '...' : ''}. Un tel regroupement peut indiquer un problème systémique (jour de paie, événement local, problème de collecte).`,
    contexte: { nb_retards: nbRetards, noms: rows[0].noms },
    actions_suggerees: [],
  };
}

// ─── Filtrage des doublons ───────────────────────────────────────────────────

async function filtrerDoublons(anomalies: AnomalieDetectee[]): Promise<AnomalieDetectee[]> {
  if (anomalies.length === 0) return [];

  // Vérifier les anomalies des dernières 24h
  const { rows: recentes } = await pool.query(`
    SELECT type_anomalie, date_detection
    FROM anomalies_detectees
    WHERE date_detection >= NOW() - INTERVAL '24 hours'
      AND statut != 'ignore'
  `);

  const typesRecents = new Set(recentes.map(r => r.type_anomalie));

  return anomalies.filter(a => !typesRecents.has(a.type_anomalie));
}

// ─── Stockage ────────────────────────────────────────────────────────────────

async function stockerAnomalie(anomalie: AnomalieDetectee): Promise<string> {
  const { rows } = await pool.query(
    `INSERT INTO anomalies_detectees
       (type_anomalie, severite, titre, description, cause_probable,
        actions_suggerees, contexte_json, statut)
     VALUES ($1, $2, $3, $4, $5, $6, $7, 'nouveau')
     RETURNING id`,
    [
      anomalie.type_anomalie,
      anomalie.severite,
      anomalie.titre,
      anomalie.description,
      anomalie.cause_probable ?? null,
      JSON.stringify(anomalie.actions_suggerees),
      JSON.stringify(anomalie.contexte),
    ],
  );
  return rows[0].id;
}

// ─── Appel IA (Claude priorité, Deepseek fallback) ──────────────────────────

async function callClaude(systemPrompt: string, userPrompt: string, maxTokens = 500): Promise<string> {
  const { claudeApiKey, claudeModel } = config.ia;
  if (!claudeApiKey) throw new Error('Clé API Claude non configurée');

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': claudeApiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: claudeModel,
      max_tokens: maxTokens,
      system: systemPrompt,
      messages: [{ role: 'user', content: userPrompt }],
    }),
  });

  if (!response.ok) throw new Error(`Claude API error: ${response.status}`);
  const data = await response.json() as { content: { text: string }[] };
  return data.content[0].text;
}

async function callDeepseek(systemPrompt: string, userPrompt: string, maxTokens = 500): Promise<string> {
  const { deepseekApiKey, deepseekBaseUrl, deepseekModel } = config.ia;
  if (!deepseekApiKey) throw new Error('Clé API Deepseek non configurée');

  const response = await fetch(`${deepseekBaseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${deepseekApiKey}`,
    },
    body: JSON.stringify({
      model: deepseekModel,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.5,
      max_tokens: maxTokens,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) throw new Error(`Deepseek API error: ${response.status}`);
  const data = await response.json() as { choices: { message: { content: string } }[] };
  return data.choices[0].message.content;
}

async function getAppelAnomalie(systemPrompt: string, userPrompt: string): Promise<string> {
  try {
    return await callClaude(systemPrompt, userPrompt);
  } catch (err: any) {
    logger.warn(`[Anomalies] Claude échoué, fallback Deepseek: ${err.message}`);
    try {
      return await callDeepseek(systemPrompt, userPrompt);
    } catch (err2: any) {
      logger.error(`[Anomalies] Deepseek aussi échoué: ${err2.message}`);
      throw err2;
    }
  }
}

// ─── Enrichissement via IA ───────────────────────────────────────────────────

const SYSTEM_PROMPT_ANOMALIE = `Tu es un analyste business pour une société de financement de véhicules (taxis/motos) au Bénin.
Tu reçois une anomalie détectée automatiquement et tu dois l'expliquer en langage clair.

RÈGES STRICTES :
- Réponds en français simple et professionnel.
- Ne JAMAIS inventer de chiffres — utilise uniquement les données fournies.
- Les actions doivent être concrètes et actionnables immédiatement.
- Pas de jargon technique.
- Monnaie : FCFA (1€ ≈ 655 FCFA).

FORMAT DE RÉPONSE ATTENDU (JSON strict) :
{
  "cause_probable": "Explication en 1-2 phrases simples de la cause la plus probable",
  "actions_suggerees": ["Action concrète 1", "Action concrète 2", "Action concrète 3"],
  "description_claire": "Résumé en langage clair pour un administrateur non-technique (2-3 phrases max)"
}`;

async function enrichirViaIA(anomalie: AnomalieDetectee): Promise<{
  cause_probable: string;
  actions_suggerees: string[];
  description: string;
}> {
  const userPrompt = `ANOMALIE DÉTECTÉE :
- Type : ${anomalie.type_anomalie}
- Sévérité : ${anomalie.severite}
- Titre : ${anomalie.titre}
- Description technique : ${anomalie.description}
- Contexte chiffré : ${JSON.stringify(anomalie.contexte)}

Analyse cette anomalie et propose des actions concrètes.`;

  try {
    const reponse = await getAppelAnomalie(SYSTEM_PROMPT_ANOMALIE, userPrompt);
    const parsed = JSON.parse(reponse);
    return {
      cause_probable: parsed.cause_probable ?? 'Non identifiée',
      actions_suggerees: Array.isArray(parsed.actions_suggerees) ? parsed.actions_suggerees : [],
      description: parsed.description_claire ?? anomalie.description,
    };
  } catch (err: any) {
    logger.warn(`[Anomalies] Échec enrichissement IA: ${err.message}`);
    // Fallback : actions génériques selon le type
    return {
      cause_probable: 'Analyse IA indisponible — voir le contexte chiffré',
      actions_suggerees: getActionsFallback(anomalie.type_anomalie),
      description: anomalie.description,
    };
  }
}

function getActionsFallback(type: TypeAnomalie): string[] {
  switch (type) {
    case 'chute_recouvrement':
      return [
        'Contacter les chauffeurs en retard pour comprendre la situation',
        'Vérifier si un événement local explique la baisse',
        'Envisager un plan de rattrapage échelonné',
      ];
    case 'chauffeur_arret_paiement':
      return [
        'Appeler le chauffeur immédiatement',
        'Programmer une visite terrain si pas de réponse sous 24h',
        'Préparer un plan de restructuration de la dette',
      ];
    case 'remboursements_simultanes':
      return [
        'Décaler le démarrage de nouveaux véhicules pour lisser les rentrées',
        'Constituer une réserve de trésorerie dès maintenant',
        'Anticiper le renouvellement avec de nouveaux contrats décalés',
      ];
    case 'incidents_multiples':
      return [
        'Faire le point avec le mécanicien sur les réparations en cours',
        'Évaluer si des véhicules de remplacement sont disponibles',
        'Vérifier les assurances et les responsabilités',
      ];
    case 'cash_anormalement_bas':
      return [
        'Vérifier si des paiements ont été encaissés mais non enregistrés',
        'Contacter les chauffeurs qui n\'ont pas payé aujourd\'hui',
        'Comparer avec les jours similaires (même jour de la semaine)',
      ];
    case 'retards_ensemble':
      return [
        'Identifier si un événement commun explique les retards groupés',
        'Renforcer la communication avec les chauffeurs concernés',
        'Envisager un ajustement des horaires ou des modalités de collecte',
      ];
    default:
      return ['Investiguer la situation', 'Consulter le tableau de bord détaillé'];
  }
}

// ─── Notification admin ──────────────────────────────────────────────────────

async function envoyerAlerteAdmin(
  anomalieId: string,
  anomalie: AnomalieDetectee,
  enrichi: { cause_probable: string; actions_suggerees: string[]; description: string },
): Promise<void> {
  const emojiSeverite = anomalie.severite === 'critique' ? '🚨' : anomalie.severite === 'haute' ? '⚠️' : '📊';

  // Notification in-app pour le super admin
  await sendNotification({
    type: 'rappel_j1', // Réutilisation — pas de type dédié dans le schema actuel
    channel: 'in_app',
    titre: `${emojiSeverite} ${anomalie.titre}`,
    message: `${enrichi.description}\n\nCause probable : ${enrichi.cause_probable}\n\nActions recommandées :\n${enrichi.actions_suggerees.map((a, i) => `${i + 1}. ${a}`).join('\n')}`,
    metadata: {
      anomalie_id: anomalieId,
      type_anomalie: anomalie.type_anomalie,
      severite: anomalie.severite,
    },
  });

  // Marquer comme notifiée
  await pool.query(
    `UPDATE anomalies_detectees SET notif_envoyee = TRUE WHERE id = $1`,
    [anomalieId],
  );
}
