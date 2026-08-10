import { config } from '../config/env.js';
import { logger } from '../utils/logger.js';

/**
 * Service de chatbot d'aide fonctionnelle — Support utilisateur.
 *
 * Ce chatbot répond aux questions d'USAGE de l'application
 * (comment enregistrer un paiement, comment signaler une panne, etc.)
 * Il ne répond PAS aux questions métier/financières (combien je dois, quel solde…).
 *
 * Le contexte fonctionnel de l'app est injecté dans le prompt système.
 * Pas de fine-tuning nécessaire.
 */

// ─── Types ────────────────────────────────────────────────────────────────────

export interface SupportReponse {
  reponse: string;
  hors_perimetre: boolean;  // true si la question dépasse le scope support
  suggestions: string[];    // questions de suivi suggérées
  modele_utilise: 'deepseek' | 'claude';
}

// ─── Prompt système : documentation fonctionnelle de l'app ────────────────────

const SYSTEM_PROMPT = `Tu es l'assistant d'aide de l'application MotoProjet, une application mobile de financement de taxis (motos et voitures) au Bénin.

TON RÔLE UNIQUE : aider les utilisateurs à comprendre comment utiliser l'application. Tu réponds UNIQUEMENT aux questions d'usage/fonctionnement de l'app.

═══════════════════════════════════════════════════
DOCUMENTATION FONCTIONNELLE DE L'APPLICATION
═══════════════════════════════════════════════════

## RÔLES UTILISATEURS
L'app a 3 rôles :
- **Super Admin** : voit tout (dashboard global, tous les chauffeurs, véhicules, paiements, IA, anomalies)
- **Gestionnaire** : gère les opérations quotidiennes (chauffeurs, véhicules, paiements, incidents)
- **Chauffeur** : consulte ses paiements, signale des incidents, suit son objectif

## COMMENT ENREGISTRER UN PAIEMENT
1. Aller dans l'onglet "Paiements"
2. Appuyer sur le bouton "+" ou "Saisie rapide"
3. Sélectionner le chauffeur (ou scanner le QR code)
4. Saisir le montant (ex: 5000 FCFA)
5. Choisir le mode : Cash ou Mobile Money
6. Confirmer
→ Le paiement est enregistré instantanément. Si hors-ligne, il sera synchronisé automatiquement.

## COMMENT AJOUTER UN CHAUFFEUR
1. Aller dans "Chauffeurs" (Super Admin ou Gestionnaire)
2. Appuyer sur "+"
3. Remplir : nom, téléphone, permis, caution
4. Sauvegarder
→ Le chauffeur apparaît dans la liste et peut se connecter.

## COMMENT AFFECTER UN VÉHICULE À UN CHAUFFEUR
1. Aller dans "Véhicules"
2. Sélectionner le véhicule
3. Appuyer sur "Affecter"
4. Choisir le chauffeur dans la liste
5. Définir la durée de remboursement et l'objectif journalier
→ Le véhicule passe en statut "en_rem boursement" et le chauffeur commence à rembourser.

## COMMENT SIGNALER UNE PANNE / INCIDENT
1. Aller dans "Incidents" ou depuis le détail du véhicule
2. Appuyer sur "Signaler un incident"
3. Choisir le type : Panne ou Accident
4. Décrire l'incident et prendre une photo (optionnel)
5. Soumettre
→ L'admin est notifié. Le véhicule peut être mis hors service le temps de la réparation.

## COMMENT VOIR LE TABLEAU DE BORD
- Super Admin : onglet "Dashboard" → vue complète (cash, véhicules, recouvrement, retards, IA)
- Gestionnaire : onglet "Opérations" → vue opérationnelle
- Les données se rafraîchissent automatiquement toutes les 5 minutes
- Tirer vers le bas pour rafraîchir manuellement

## COMMENT FONCTIONNE LE SUIVI GPS (CHAUFFEUR)
1. L'assistant IA (onglet "IA") propose un suivi GPS
2. Le chauffeur définit son objectif de revenu journalier
3. L'app suit les kilomètres parcourus pendant les heures d'activité (6h-22h)
4. En fin de journée, l'IA donne des recommandations personnalisées
→ Les données GPS sont anonymisées et propres à chaque chauffeur.

## COMMENT FONCTIONNE L'ASSISTANT IA
- Côté chauffeur : recommandations personnalisées (revenu, km, zones)
- Côté admin : rapport hebdomadaire (trajectoire, objectifs, actions)
- Pour les questions financières, l'admin peut interroger l'IA librement

## COMMENT GÉRER LES RETARDS
- Le système calcule automatiquement les impayés chaque nuit
- J+1 : rappel automatique au chauffeur
- J+2 : relance ferme
- J+5 : alerte admin
- J+10 : défaut de paiement → décision admin (visite, récupération, restructuration)

## COMMENT FONCTIONNE LE HORS-LIGNE
- Les paiements peuvent être saisis sans connexion internet
- Ils sont stockés localement et marqués "En attente de sync"
- La synchronisation se fait automatiquement quand la connexion revient
- Icône de sync dans la barre de navigation pour voir les éléments en attente

## COMMENT CHANGER SON PIN
- Super Admin peut réinitialiser le PIN d'un chauffeur (menu "Reset PIN")
- Chaque utilisateur peut changer son PIN dans les paramètres

## MONNAIE
- Tous les montants sont en FCFA (Franc CFA ouest-africain)
- 1 € ≈ 655 FCFA

═══════════════════════════════════════════════════
RÈGES STRICTES DE RÉPONSE
═══════════════════════════════════════════════════

1. Réponds UNIQUEMENT aux questions sur l'utilisation de l'application.
2. Si la question porte sur un MONTANT PRÉCIS, un SOLDE, un RETARD spécifique, ou une donnée financière personnelle → réponds que tu ne peux pas accéder aux données du compte et suggère de contacter l'administrateur.
3. Si la question est hors sujet (météo, politique, cuisine…) → redirige gentiment vers le sujet (l'app).
4. Réponds en français simple, en 2-4 phrases maximum.
5. Si pertinent, donne les étapes numérotées (1. 2. 3.).
6. Propose 2-3 questions de suivi pertinentes.
7. Ne JAMAIS inventer une fonctionnalité qui n'existe pas dans la documentation ci-dessus.

FORMAT DE RÉPONSE ATTENDU (JSON strict, pas de markdown) :
{
  "reponse": "Ta réponse ici",
  "hors_perimetre": false,
  "suggestions": ["Question de suivi 1 ?", "Question de suivi 2 ?"]
}

Le champ "hors_perimetre" doit être true UNIQUEMENT si la question concerne des données financières personnelles ou sort complètement du cadre de l'application.`;

// ─── Appel IA ─────────────────────────────────────────────────────────────────

async function callClaude(systemPrompt: string, userPrompt: string, maxTokens = 400): Promise<string> {
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

async function callDeepseek(systemPrompt: string, userPrompt: string, maxTokens = 400): Promise<string> {
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

// ─── Fonction principale ──────────────────────────────────────────────────────

export async function getSupportReponse(
  question: string,
  historique: { role: 'user' | 'assistant'; contenu: string }[] = [],
): Promise<SupportReponse> {
  // Construire le prompt utilisateur avec l'historique
  let userPrompt = '';

  if (historique.length > 0) {
    const lastMessages = historique.slice(-6); // Garder les 3 derniers échanges (6 messages)
    userPrompt += 'CONVERSATION PRÉCÉDENTE :\n';
    for (const msg of lastMessages) {
      userPrompt += `${msg.role === 'user' ? 'Utilisateur' : 'Assistant'} : ${msg.contenu}\n`;
    }
    userPrompt += '\n';
  }

  userPrompt += `NOUVELLE QUESTION DE L'UTILISATEUR : ${question}`;

  // Appeler l'IA (Claude priorité, Deepseek fallback)
  let rawResponse: string;
  let modele: 'claude' | 'deepseek';

  try {
    rawResponse = await callClaude(SYSTEM_PROMPT, userPrompt);
    modele = 'claude';
  } catch (err: any) {
    logger.warn(`[Support-IA] Claude échoué, fallback Deepseek: ${err.message}`);
    try {
      rawResponse = await callDeepseek(SYSTEM_PROMPT, userPrompt);
      modele = 'deepseek';
    } catch (err2: any) {
      logger.error(`[Support-IA] Deepseek aussi échoué: ${err2.message}`);
      // Fallback de secours
      return {
        reponse: 'Désolé, je ne peux pas répondre pour le moment. Vous pouvez contacter l\'administrateur pour obtenir de l\'aide.',
        hors_perimetre: false,
        suggestions: ['Comment contacter l\'administrateur ?', 'Comment signaler un incident ?'],
        modele_utilise: 'claude',
      };
    }
  }

  // Parser la réponse JSON
  try {
    const parsed = JSON.parse(rawResponse);
    return {
      reponse: parsed.reponse ?? 'Je n\'ai pas compris votre question.',
      hors_perimetre: parsed.hors_perimetre === true,
      suggestions: Array.isArray(parsed.suggestions) ? parsed.suggestions.slice(0, 3) : [],
      modele_utilise: modele,
    };
  } catch {
    // Si le parsing échoue, retourner la réponse brute
    return {
      reponse: rawResponse.substring(0, 300),
      hors_perimetre: false,
      suggestions: [],
      modele_utilise: modele,
    };
  }
}
