/**
 * Templates de messages pour les notifications automatiques.
 *
 * Tous les messages sont en français, personnalisés avec :
 * - {{nom}} : nom du chauffeur
 * - {{montant}} : montant dû en FCFA
 * - {{plaque}} : plaque du véhicule
 * - {{jours}} : nombre de jours de retard
 * - {{date_fin}} : date de fin de remboursement
 *
 * Les messages SMS sont limités à 160 caractères quand possible.
 * Les messages WhatsApp peuvent être plus longs.
 */

export interface TemplateContext {
  nom: string;
  montant: number;
  plaque: string;
  jours: number;
  date_fin?: string;
  vehicule_type?: string;
  prix_vehicule?: number;
}

function formatMontant(n: number): string {
  return n.toLocaleString('fr-FR').replace(/,/g, ' ') + ' FCFA';
}

// ─── J+1 : Rappel poli ──────────────────────────────────────────────────────

export function rappelJ1(ctx: TemplateContext): { titre: string; sms: string; whatsapp: string } {
  const montant = formatMontant(ctx.montant);
  return {
    titre: 'Rappel de paiement',
    sms: `Bonjour ${ctx.nom}, votre paiement de ${montant} pour le véhicule ${ctx.plaque} est en attente. Merci de régulariser dès aujourd'hui. — MotoProjet`,
    whatsapp: `Bonjour ${ctx.nom} 👋\n\nNous n'avons pas encore reçu votre paiement du jour pour le véhicule *${ctx.plaque}*.\n\n💰 Montant attendu : *${montant}*\n\nMerci de faire le nécessaire dès aujourd'hui. Si vous avez déjà payé, ignorez ce message.\n\nBonne journée !\n— _MotoProjet_`,
  };
}

// ─── J+2 : Relance ferme ────────────────────────────────────────────────────

export function relanceJ2(ctx: TemplateContext): { titre: string; sms: string; whatsapp: string } {
  const montant = formatMontant(ctx.montant * ctx.jours);
  return {
    titre: 'Relance — paiement en retard',
    sms: `${ctx.nom}, vous avez ${ctx.jours} jours de retard sur le véhicule ${ctx.plaque}. Total dû : ${montant}. Régularisez-vous immédiatement. — MotoProjet`,
    whatsapp: `Bonjour ${ctx.nom},\n\n⚠️ *Relance de paiement*\n\nVotre véhicule *${ctx.plaque}* accuse un retard de *${ctx.jours} jours*.\n\n💰 Total dû : *${montant}*\n\nNous vous demandons de régulariser votre situation *dès aujourd'hui*. Un retard prolongé peut entraîner des conséquences sur votre statut.\n\nCordialement,\n— _MotoProjet_`,
  };
}

// ─── J+5 : Alerte administrateur ────────────────────────────────────────────

export function alerteAdminJ5(ctx: TemplateContext): { titre: string; message: string } {
  const montant = formatMontant(ctx.montant * ctx.jours);
  return {
    titre: `⚠️ Alerte retard — ${ctx.nom}`,
    message: `Le chauffeur ${ctx.nom} est en retard de ${ctx.jours} jours sur le véhicule ${ctx.plaque}.\n\nMontant total dû : ${montant}\n\nStatut actuel : retard\n\nAction recommandée : contacter le chauffeur pour comprendre la situation et définir un échéancier de rattrapage.`,
  };
}

// ─── J+10 : Défaut + décision admin ─────────────────────────────────────────

export function defautJ10(ctx: TemplateContext): { titre: string; message: string } {
  const montant = formatMontant(ctx.montant * ctx.jours);
  return {
    titre: `🚨 Défaut de paiement — ${ctx.nom}`,
    message: `Le chauffeur ${ctx.nom} est en défaut de paiement depuis ${ctx.jours} jours.\n\nVéhicule : ${ctx.plaque}\nMontant total dû : ${montant}\n\nLe statut du chauffeur est passé en "défaut".\n\nDécisions possibles :\n• Visite terrain pour évaluer la situation\n• Récupération du véhicule\n• Plan de restructuration de la dette\n\nAction requise de votre part.`,
  };
}

// ─── Fin de remboursement : Transfert de propriété ──────────────────────────

export function transfertPropriete(ctx: TemplateContext): { titre: string; sms: string; whatsapp: string; adminMessage: string } {
  return {
    titre: 'Fin de remboursement — Transfert de propriété',
    sms: `Félicitations ${ctx.nom} ! Le remboursement du véhicule ${ctx.plaque} est terminé. Contactez-nous pour organiser le transfert de propriété. — MotoProjet`,
    whatsapp: `Félicitations ${ctx.nom} 🎉\n\nLe remboursement du véhicule *${ctx.plaque}* est *terminé* !\n\nVous pouvez dès maintenant organiser le transfert de propriété. Contactez l'administration pour finaliser les démarches.\n\nBravo pour votre engagement !\n— _MotoProjet_`,
    adminMessage: `Le véhicule ${ctx.plaque} (${ctx.vehicule_type ?? 'véhicule'}) a atteint sa date de fin de remboursement (${ctx.date_fin ?? "aujourd'hui"}). Chauffeur : ${ctx.nom}.\n\nOrganiser le transfert de propriété : générer l'attestation PDF et mettre à jour le statut.`,
  };
}

// ─── Caisse cumulée ≥ prix véhicule : Achat possible ────────────────────────

export function achatPossible(ctx: TemplateContext): { titre: string; message: string } {
  const prix = formatMontant(ctx.prix_vehicule ?? 0);
  return {
    titre: `💰 Achat possible — ${ctx.plaque}`,
    message: `La caisse cumulée permet désormais l'achat d'un nouveau véhicule.\n\nVéhicule cible : ${ctx.plaque} (${ctx.vehicule_type ?? 'véhicule'})\nPrix : ${prix}\n\nVous pouvez lancer la procédure d'acquisition si vous le souhaitez.`,
  };
}
