import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';

// ─── Types ────────────────────────────────────────────────────────────────────

export interface AdminObjectif {
  libelle: string;
  valeur_cible: number;
  unite: 'nb_vehicules' | 'taux_recouvrement' | 'revenu_mensuel' | 'delai_mois';
  delai_mois: number;
}

export interface AdminContexte {
  // Véhicules
  nb_vehicules_actifs: number;
  nb_vehicules_rembourses: number;
  nb_motos: number;
  nb_voitures: number;
  prix_moyen_moto: number;
  prix_moyen_voiture: number;
  valeur_totale_parc: number;

  // Paiements & cash
  total_paiements_mois: number;
  total_paiements_semaine: number;
  total_paiements_jour: number;
  cash_cumule_total: number;
  cash_disponible_achat: number;

  // Recouvrement
  taux_recouvrement: number;
  montant_reel: number;
  montant_theorique: number;

  // Chauffeurs
  nb_chauffeurs_actifs: number;
  nb_chauffeurs_retard: number;
  nb_chauffeurs_defaut: number;
  nb_chauffeurs_a_jour: number;
  montant_total_du: number;

  // Tendance (7 derniers jours)
  tendance_paiements: { date: string; montant: number }[];

  // Objectifs admin
  objectifs: AdminObjectif[];

  // Trajectoire calculée
  trajectoire: {
    vehicules_cible: number;
    vehicules_actuels: number;
    mois_restant: number;
    rythme_achat_necessaire: number; // véhicules par mois
    rythme_achat_reel: number;
    taux_recouvrement_cible: number;
    taux_recouvrement_actuel: number;
  };
}

export interface AdminReponseIA {
  rapport: string;
  actions_proposees: string[];
  trajectoire: 'en_avance' | 'a_temps' | 'en_retard' | 'non_evaluee';
  modele_utilise: 'claude' | 'deepseek';
}

// ─── Prompt système Admin ────────────────────────────────────────────────────
const SYSTEM_PROMPT_ADMIN = `Tu es un consultant IA spécialisé dans l'analyse de performance d'une entreprise de financement de taxis (motos et voitures) au Bénin.
Tu t'adresses au super administrateur qui gère le parc de véhicules, les chauffeurs et les remboursements.

CONTEXTE MÉTIER :
- L'entreprise achète des véhicules et les finance à des chauffeurs qui remboursent quotidiennement.
- L'objectif est double : maximiser le taux de recouvrement et agrandir le parc progressivement.
- Les paiements sont en FCFA (monnaie ouest-africaine, 1€ ≈ 655 FCFA).

RÈGES STRICTES :
- Réponds TOUJOURS en français clair et professionnel.
- Le rapport hebdomadaire doit tenir en 4-6 phrases maximum, dense et actionnable.
- Ne JAMAIS inventer de chiffres — utilise uniquement les données fournies.
- Ne JAMAIS mentionner de données personnelles (téléphone, adresse) des chauffeurs.
- Identifie les causes probables des écarts (retards, défauts, rythme d'achat).
- Propose des actions CONCRÈTES et PRIORISÉES (pas de conseils génériques).
- Si la trajectoire est en retard, quantifie l'effort nécessaire pour rattraper.
- Compare toujours la situation actuelle aux objectifs définis.
- Utilise un ton de consultant : factuel, direct, orienté résultats.

FORMAT DE RÉPONSE ATTENDU (JSON strict) :
{
  "rapport": "ton résumé hebdomadaire en 4-6 phrases",
  "actions_proposees": [
    "action prioritaire 1 — avec justification chiffrée",
    "action prioritaire 2",
    "action prioritaire 3"
  ],
  "trajectoire": "en_avance | a_temps | en_retard",
  "indicateurs_cles": {
    "taux_recouvrement_cible": 90,
    "taux_recouvrement_actuel": 67,
    "vehicules_cible": 20,
    "vehicules_actuels": 5,
    "mois_restant": 10,
    "rythme_achat_necessaire": 1.5
  }
}`;

// ─── Prompt système pour le chat libre ────────────────────────────────────────
const SYSTEM_PROMPT_CHAT = `Tu es un consultant IA pour une entreprise de financement de taxis au Bénin.
Tu réponds aux questions libres du super administrateur sur son business.
Tu as accès aux données agrégées de l'entreprise (paiements, recouvrement, véhicules, chauffeurs).

RÈGES :
- Réponds en français, de manière concise (3-5 phrases max).
- Ne JAMAIS inventer de chiffres — base-toi sur les données fournies.
- Ne JAMAIS divulguer de données personnelles de chauffeurs.
- Si la question sort du cadre métier, recentre poliment.
- Donne des conseils actionables et chiffrés quand possible.`;

// ─── Construction du prompt contexte business ─────────────────────────────────
function buildAdminUserPrompt(ctx: AdminContexte): string {
  const { objectifs, trajectoire } = ctx;

  const objectifsStr = objectifs.map(o =>
    `  - ${o.libelle} : cible ${o.valeur_cible} ${o.unite} sous ${o.delai_mois} mois`
  ).join('\n');

  return `
DONNÉES DE L'ENTREPRISE (semaine en cours) :

Véhicules en circulation :
  - Total actifs : ${ctx.nb_vehicules_actifs} (${ctx.nb_motos} motos, ${ctx.nb_voitures} voitures)
  - Remboursés : ${ctx.nb_vehicules_rembourses}
  - Valeur totale du parc : ${ctx.valeur_totale_parc.toLocaleString('fr-FR')} FCFA

Cash & Paiements :
  - Encaissé aujourd'hui : ${ctx.total_paiements_jour.toLocaleString('fr-FR')} FCFA
  - Cette semaine : ${ctx.total_paiements_semaine.toLocaleString('fr-FR')} FCFA
  - Ce mois : ${ctx.total_paiements_mois.toLocaleString('fr-FR')} FCFA
  - Cash cumulé disponible pour achat : ${ctx.cash_disponible_achat.toLocaleString('fr-FR')} FCFA

Recouvrement :
  - Taux actuel : ${ctx.taux_recouvrement.toFixed(1)}%
  - Montant reçu : ${ctx.montant_reel.toLocaleString('fr-FR')} FCFA
  - Montant attendu : ${ctx.montant_theorique.toLocaleString('fr-FR')} FCFA

Chauffeurs :
  - Actifs : ${ctx.nb_chauffeurs_actifs}
  - À jour : ${ctx.nb_chauffeurs_a_jour}
  - En retard : ${ctx.nb_chauffeurs_retard}
  - En défaut : ${ctx.nb_chauffeurs_defaut}
  - Montant total dû : ${ctx.montant_total_du.toLocaleString('fr-FR')} FCFA

Tendance 7 jours :
${ctx.tendance_paiements.map(t =>
  `  - ${t.date} : ${t.montant.toLocaleString('fr-FR')} FCFA`
).join('\n')}

OBJECTIFS DÉFINIS :
${objectifsStr}

TRAJECTOIRE :
  - Véhicules : ${trajectoire.vehicules_actuels} actuels / ${trajectoire.vehicules_cible} cible → ${trajectoire.mois_restant} mois restants
  - Rythme achat nécessaire : ${trajectoire.rythme_achat_necessaire} véh./mois
  - Rythme achat réel : ${trajectoire.rythme_achat_reel} véh./mois
  - Taux recouvrement : ${trajectoire.taux_recouvrement_actuel.toFixed(1)}% actuel / ${trajectoire.taux_recouvrement_cible}% cible

Génère le rapport hebdomadaire avec analyse et actions prioritaires.`.trim();
}

// ─── Appel Claude API (modèle principal pour admin) ──────────────────────────
async function callClaude(systemPrompt: string, userPrompt: string, maxTokens = 600): Promise<string> {
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
      max_tokens: maxTokens,
      system: systemPrompt,
      messages: [
        { role: 'user', content: userPrompt },
      ],
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    logger.error('[IA-Admin] Erreur Claude', { status: response.status, body: errText });
    throw new Error(`Claude API error: ${response.status}`);
  }

  const data = await response.json() as { content: { text: string }[] };
  return data.content[0].text;
}

// ─── Appel Deepseek API (fallback) ───────────────────────────────────────────
async function callDeepseek(systemPrompt: string, userPrompt: string, maxTokens = 600): Promise<string> {
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
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.5,
      max_tokens: maxTokens,
      response_format: { type: 'json_object' },
    }),
  });

  if (!response.ok) {
    const errText = await response.text();
    logger.error('[IA-Admin] Erreur Deepseek', { status: response.status, body: errText });
    throw new Error(`Deepseek API error: ${response.status}`);
  }

  const data = await response.json() as { choices: { message: { content: string } }[] };
  return data.choices[0].message.content;
}

// ─── Fonction principale : rapport hebdomadaire admin ─────────────────────────
export async function getRapportAdmin(
  contexte: AdminContexte,
): Promise<AdminReponseIA> {
  const userPrompt = buildAdminUserPrompt(contexte);
  let rawResponse: string;
  let modeleUtilise: 'claude' | 'deepseek';

  try {
    // Claude en priorité pour l'admin (meilleure analyse)
    rawResponse = await callClaude(SYSTEM_PROMPT_ADMIN, userPrompt);
    modeleUtilise = 'claude';
  } catch (err) {
    logger.warn('[IA-Admin] Claude en échec, tentative Deepseek');
    try {
      rawResponse = await callDeepseek(SYSTEM_PROMPT_ADMIN, userPrompt);
      modeleUtilise = 'deepseek';
    } catch (fallbackErr) {
      logger.error('[IA-Admin] Les deux modèles ont échoué', { err, fallbackErr });
      return buildFallbackRapport(contexte);
    }
  }

  return parseReponseAdmin(rawResponse, modeleUtilise, contexte);
}

// ─── Chat libre admin ─────────────────────────────────────────────────────────
export async function getChatAdmin(
  question: string,
  contexte: AdminContexte,
): Promise<AdminReponseIA> {
  const contexteResume = `
Données actuelles :
- Véhicules actifs : ${contexte.nb_vehicules_actifs} (${contexte.nb_motos} motos, ${contexte.nb_voitures} voitures)
- Taux recouvrement : ${contexte.taux_recouvrement.toFixed(1)}%
- Chauffeurs : ${contexte.nb_chauffeurs_actifs} actifs, ${contexte.nb_chauffeurs_retard} retard, ${contexte.nb_chauffeurs_defaut} défaut
- Cash disponible : ${contexte.cash_disponible_achat.toLocaleString('fr-FR')} FCFA
- Paiements ce mois : ${contexte.total_paiements_mois.toLocaleString('fr-FR')} FCFA
- Montant total dû : ${contexte.montant_total_du.toLocaleString('fr-FR')} FCFA`.trim();

  const userPrompt = `${contexteResume}\n\nQuestion de l'administrateur : ${question}`;

  let rawResponse: string;
  let modeleUtilise: 'claude' | 'deepseek';

  try {
    rawResponse = await callClaude(SYSTEM_PROMPT_CHAT, userPrompt, 400);
    modeleUtilise = 'claude';
  } catch {
    try {
      rawResponse = await callDeepseek(SYSTEM_PROMPT_CHAT, userPrompt, 400);
      modeleUtilise = 'deepseek';
    } catch {
      return {
        rapport: 'Impossible de traiter votre question pour le moment. Vérifiez la connexion et réessayez.',
        actions_proposees: [],
        trajectoire: 'non_evaluee',
        modele_utilise: 'claude',
      };
    }
  }

  return parseReponseAdmin(rawResponse, modeleUtilise, contexte);
}

// ─── Parser la réponse IA ─────────────────────────────────────────────────────
function parseReponseAdmin(
  raw: string,
  modele: 'claude' | 'deepseek',
  ctx: AdminContexte,
): AdminReponseIA {
  try {
    const parsed = JSON.parse(raw) as {
      rapport?: string;
      actions_proposees?: string[];
      trajectoire?: string;
    };

    return {
      rapport: parsed.rapport ?? raw.substring(0, 500),
      actions_proposees: Array.isArray(parsed.actions_proposees) ? parsed.actions_proposees : [],
      trajectoire: (['en_avance', 'a_temps', 'en_retard'].includes(parsed.trajectoire ?? '')
        ? parsed.trajectoire as 'en_avance' | 'a_temps' | 'en_retard'
        : evaluerTrajectoire(ctx)),
      modele_utilise: modele,
    };
  } catch {
    return {
      rapport: raw.substring(0, 500),
      actions_proposees: [],
      trajectoire: evaluerTrajectoire(ctx),
      modele_utilise: modele,
    };
  }
}

// ─── Évaluer la trajectoire sans IA ───────────────────────────────────────────
function evaluerTrajectoire(ctx: AdminContexte): 'en_avance' | 'a_temps' | 'en_retard' | 'non_evaluee' {
  const { trajectoire } = ctx;
  if (trajectoire.vehicules_cible === 0) return 'non_evaluee';

  const retardVehicules = trajectoire.vehicules_cible - trajectoire.vehicules_actuels;
  const moisRestants = trajectoire.mois_restant || 1;
  const rythmeNecessaire = retardVehicules / moisRestants;

  if (trajectoire.rythme_achat_reel >= rythmeNecessaire * 1.2) return 'en_avance';
  if (trajectoire.rythme_achat_reel >= rythmeNecessaire * 0.8) return 'a_temps';
  return 'en_retard';
}

// ─── Réponse de secours ───────────────────────────────────────────────────────
function buildFallbackRapport(ctx: AdminContexte): AdminReponseIA {
  const actions: string[] = [];
  const traj = ctx.trajectoire;

  if (ctx.nb_chauffeurs_retard + ctx.nb_chauffeurs_defaut > 0) {
    actions.push(`Relancer les ${ctx.nb_chauffeurs_retard + ctx.nb_chauffeurs_defaut} chauffeur(s) en retard/défaut — montant dû : ${ctx.montant_total_du.toLocaleString('fr-FR')} FCFA`);
  }

  if (ctx.taux_recouvrement < 75) {
    actions.push(`Taux de recouvrement à ${ctx.taux_recouvrement.toFixed(0)}% — intensifier les relances et envisager un ajustement des montants journaliers`);
  }

  if (traj.rythme_achat_reel < traj.rythme_achat_necessaire) {
    actions.push(`Rythme d'achat insuffisant (${traj.rythme_achat_reel}/mois vs ${traj.rythme_achat_necessaire} nécessaires) — accélérer la constitution de la caisse`);
  }

  const trajectoireLabel = evaluerTrajectoire(ctx);
  let rapport = '';

  switch (trajectoireLabel) {
    case 'en_avance':
      rapport = `Trajectoire en avance. ${ctx.nb_vehicules_actifs} véhicules actifs, taux de recouvrement à ${ctx.taux_recouvrement.toFixed(0)}%. Continuer la stratégie actuelle et envisager d'accélérer l'expansion.`;
      break;
    case 'a_temps':
      rapport = `Trajectoire conforme aux prévisions. ${ctx.nb_vehicules_actifs} véhicules actifs, taux de recouvrement à ${ctx.taux_recouvrement.toFixed(0)}%. Maintenir le rythme actuel.`;
      break;
    default:
      rapport = `Trajectoire en retard. ${ctx.nb_vehicules_actifs} véhicules actifs sur objectif, taux de recouvrement à ${ctx.taux_recouvrement.toFixed(0)}%. Des actions correctives sont nécessaires.`;
  }

  if (actions.length === 0) {
    actions.push('Aucune action urgente — le business est sur la bonne voie');
  }

  return {
    rapport,
    actions_proposees: actions.slice(0, 3),
    trajectoire: trajectoireLabel === 'non_evaluee' ? 'en_retard' : trajectoireLabel,
    modele_utilise: 'claude',
  };
}
