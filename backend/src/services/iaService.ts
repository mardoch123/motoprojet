import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';

// ─── Types ────────────────────────────────────────────────────────────────────
export interface IaContexteChauffeur {
  chauffeur_nom: string;
  objectif_jour: number;
  revenu_jour: number;
  km_jour: number;
  km_7j: number;
  zones_frequentees: string[];
  historique_7j: {
    date: string;
    revenu: number;
    km: number;
    objectif_atteint: boolean;
  }[];
  performance_semaine: {
    jours_travailles: number;
    jours_objectif_atteint: number;
    revenu_total: number;
    objectif_total: number;
  };
}

export interface IaReponse {
  recommandation: string;
  objectif_atteint: boolean;
  modele_utilise: 'deepseek' | 'claude';
}

// ─── Prompt système ──────────────────────────────────────────────────────────
const SYSTEM_PROMPT = `Tu es un assistant IA intégré à une application mobile pour chauffeurs de taxis-motos au Bénin.
Ton rôle : aider le chauffeur à atteindre son objectif de revenu journalier.

RÈGES STRICTES :
- Réponds TOUJOURS en français simple et court (2-3 phrases maximum).
- Ne donne JAMAIS de conseils dangereux ou illégaux.
- Ne mentionne JAMAIS de coordonnées GPS précises — utilise des noms de zones génériques (quartiers, villes).
- Ne partage JAMAIS les données d'un chauffeur avec un autre.
- Si l'objectif est atteint ou dépassé : félicite et suggère de mettre de côté le surplus.
- Si l'objectif est en retard : suggère un rythme concret pour rattraper sur les jours restants.
- Si l'objectif semble irréaliste (ex: très supérieur à la moyenne historique) : alerte gentiment et propose un ajustement.
- Cite les zones/heures historiquement les plus rentables pour CE chauffeur (basé sur son historique).
- Utilise un ton bienveillant et motivant, comme un mentor.

FORMAT DE RÉPONSE ATTENDU (JSON strict) :
{
  "recommandation": "ton message court et concret ici",
  "zones_prioritaires": ["zone1", "zone2"],
  "heures_prioritaires": ["8h-10h", "17h-19h"],
  "rythme_cible": "ex: 2000 FCFA de plus par jour cette semaine",
  "alerte_objectif_irrealiste": false
}`;

// ─── Construction du prompt utilisateur ───────────────────────────────────────
function buildUserPrompt(ctx: IaContexteChauffeur): string {
  const {
    chauffeur_nom,
    objectif_jour,
    revenu_jour,
    km_jour,
    km_7j,
    zones_frequentees,
    historique_7j,
    performance_semaine,
  } = ctx;

  const ecart = revenu_jour - objectif_jour;
  const statut = ecart >= 0 ? 'ATTEINT' : 'EN RETARD';

  return `
Chauffeur : ${chauffeur_nom}
Objectif du jour : ${objectif_jour.toLocaleString('fr-FR')} FCFA
Revenu réalisé aujourd'hui : ${revenu_jour.toLocaleString('fr-FR')} FCFA
Statut : ${statut} (écart : ${ecart >= 0 ? '+' : ''}${ecart.toLocaleString('fr-FR')} FCFA)

Kilométrage du jour : ${km_jour.toFixed(1)} km
Kilométrage des 7 derniers jours : ${km_7j.toFixed(1)} km
Zones fréquentées aujourd'hui : ${zones_frequentees.join(', ') || 'non renseignées'}

Historique des 7 derniers jours :
${historique_7j.map(h =>
  `  - ${h.date} : ${h.revenu.toLocaleString('fr-FR')} FCFA, ${h.km.toFixed(1)} km, objectif ${h.objectif_atteint ? '✓ atteint' : '✗ non atteint'}`
).join('\n')}

Performance de la semaine :
  - Jours travaillés : ${performance_semaine.jours_travailles}/7
  - Jours avec objectif atteint : ${performance_semaine.jours_objectif_atteint}
  - Revenu total : ${performance_semaine.revenu_total.toLocaleString('fr-FR')} FCFA
  - Objectif total attendu : ${performance_semaine.objectif_total.toLocaleString('fr-FR')} FCFA

Analyse la situation et donne une recommandation courte et concrète.`.trim();
}

// ─── Appel Deepseek API ───────────────────────────────────────────────────────
async function callDeepseek(userPrompt: string): Promise<string> {
  const { deepseekApiKey, deepseekBaseUrl, deepseekModel } = config.ia;

  if (!deepseekApiKey) {
    throw new Error('Clé API Deepseek non configurée (DEEPSEEK_API_KEY)');
  }

  const response = await fetch(`${deepseekBaseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${deepseekApiKey}`,
    },
    body: JSON.stringify({
      model: deepseekModel,
      messages: [
        { role: 'system', content: SYSTEM_PROMPT },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.7,
      max_tokens: 300,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    logger.error('[IA] Erreur Deepseek', { status: response.status, body: errText });
    throw new Error(`Deepseek API error: ${response.status}`);
  }

  const data = await response.json() as {
    choices: { message: { content: string } }[];
  };
  return data.choices[0].message.content;
}

// ─── Appel Claude API (Anthropic) ────────────────────────────────────────────
async function callClaude(userPrompt: string): Promise<string> {
  const { claudeApiKey, claudeModel } = config.ia;

  if (!claudeApiKey) {
    throw new Error('Clé API Claude non configurée (CLAUDE_API_KEY)');
  }

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': claudeApiKey,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model: claudeModel,
      max_tokens: 300,
      system: SYSTEM_PROMPT,
      messages: [
        { role: 'user', content: userPrompt },
      ],
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    logger.error('[IA] Erreur Claude', { status: response.status, body: errText });
    throw new Error(`Claude API error: ${response.status}`);
  }

  const data = await response.json() as {
    content: { text: string }[];
  };
  return data.content[0].text;
}

// ─── Fonction principale : appelle le modèle configuré ────────────────────────
export async function getAppelIA(
  contexte: IaContexteChauffeur,
  provider?: 'deepseek' | 'claude',
): Promise<IaReponse> {
  const modele = provider ?? (config.ia.provider as 'deepseek' | 'claude');
  const userPrompt = buildUserPrompt(contexte);

  let rawResponse: string;
  let modeleUtilise: 'deepseek' | 'claude';

  try {
    if (modele === 'claude') {
      rawResponse = await callClaude(userPrompt);
      modeleUtilise = 'claude';
    } else {
      rawResponse = await callDeepseek(userPrompt);
      modeleUtilise = 'deepseek';
    }
  } catch (err) {
    // Fallback : si Deepseek échoue, essayer Claude (et inversement)
    logger.warn('[IA] Modèle principal en échec, tentative fallback', { modele });
    try {
      if (modele === 'deepseek') {
        rawResponse = await callClaude(userPrompt);
        modeleUtilise = 'claude';
      } else {
        rawResponse = await callDeepseek(userPrompt);
        modeleUtilise = 'deepseek';
      }
    } catch (fallbackErr) {
      logger.error('[IA] Les deux modèles IA ont échoué', { err, fallbackErr });
      // Réponse de secours sans appel IA
      return {
        recommandation: buildFallbackReponse(contexte),
        objectif_atteint: contexte.revenu_jour >= contexte.objectif_jour,
        modele_utilise: 'deepseek',
      };
    }
  }

  // Parser la réponse JSON
  try {
    const parsed = JSON.parse(rawResponse) as {
      recommandation?: string;
      zones_prioritaires?: string[];
      heures_prioritaires?: string[];
      rythme_cible?: string;
      alerte_objectif_irrealiste?: boolean;
    };

    const recommandation = parsed.recommandation ?? rawResponse;
    return {
      recommandation,
      objectif_atteint: contexte.revenu_jour >= contexte.objectif_jour,
      modele_utilise: modeleUtilise!,
    };
  } catch {
    // Si le parsing échoue, retourner le texte brut
    return {
      recommandation: rawResponse.substring(0, 300),
      objectif_atteint: contexte.revenu_jour >= contexte.objectif_jour,
      modele_utilise: modeleUtilise!,
    };
  }
}

// ─── Réponse de secours (pas d'IA disponible) ─────────────────────────────────
function buildFallbackReponse(ctx: IaContexteChauffeur): string {
  const ecart = ctx.revenu_jour - ctx.objectif_jour;

  if (ecart >= 0) {
    return `Bravo ${ctx.chauffeur_nom} ! Objectif atteint avec +${ecart.toLocaleString('fr-FR')} FCFA de surplus. Pense à mettre de côté au moins la moitié du surplus.`;
  }

  const joursRestants = 7 - ctx.performance_semaine.jours_travailles;
  const retardSemaine = ctx.performance_semaine.objectif_total - ctx.performance_semaine.revenu_total;
  const rattrapageParJour = joursRestants > 0 ? Math.ceil(retardSemaine / joursRestants) : 0;

  if (rattrapageParJour > 0) {
    return `Tu es en retard de ${Math.abs(ecart).toLocaleString('fr-FR')} FCFA aujourd'hui. Pour rattraper cette semaine, vise ${rattrapageParJour.toLocaleString('fr-FR')} FCFA de plus par jour pendant ${joursRestants} jours.`;
  }

  return `Continue comme ça, tu es sur la bonne voie. ${Math.abs(ecart).toLocaleString('fr-FR')} FCFA de retard aujourd'hui, mais la semaine reste jouable.`;
}
