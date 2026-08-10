import type { Request, Response } from 'express';
import * as penalitesService from '../services/penalitesService.js';
import { logger } from '../utils/logger.js';

/**
 * GET /penalites
 * Liste les pénalités (filtres optionnels)
 */
export async function listPenalites(req: Request, res: Response): Promise<void> {
  const { vehicule_id, chauffeur_id, statut } = req.query;
  
  const penalites = await penalitesService.listerPenalites(
    vehicule_id as string | undefined,
    chauffeur_id as string | undefined,
    statut as string | undefined
  );
  
  res.json({ penalites });
}

/**
 * GET /penalites/:vehiculeId/total
 * Total des pénalités par véhicule
 */
export async function getTotalPenalites(req: Request, res: Response): Promise<void> {
  const vehiculeId = req.params.vehiculeId as string;
  const total = await penalitesService.getTotalPenalites(vehiculeId);
  res.json(total);
}

/**
 * POST /penalites/:id/annuler
 * Annule une pénalité (geste commercial)
 */
export async function annulerPenalite(req: Request, res: Response): Promise<void> {
  const id = req.params.id as string;
  const { motif } = req.body;
  const userId = req.user!.sub;
  
  if (!motif) {
    res.status(400).json({ error: 'Motif obligatoire' });
    return;
  }
  
  const penalite = await penalitesService.annulerPenalite(id, userId, motif);
  
  if (!penalite) {
    res.status(404).json({ error: 'Pénalité non trouvée ou déjà traitée' });
    return;
  }
  
  logger.info(`Pénalité annulée: ${id}`, { userId, motif });
  res.json({ penalite, message: 'Pénalité annulée avec succès' });
}

/**
 * GET /penalites/parametres
 * Liste les paramètres de pénalité
 */
export async function listParametres(req: Request, res: Response): Promise<void> {
  const parametres = await penalitesService.listerParametres();
  res.json({ parametres });
}

/**
 * PUT /penalites/parametres/:type
 * Met à jour les paramètres pour un type de véhicule
 */
export async function updateParametres(req: Request, res: Response): Promise<void> {
  const type = req.params.type as string;
  const data = req.body;
  
  const parametre = await penalitesService.updateParametres(type, data);
  
  if (!parametre) {
    res.status(404).json({ error: 'Paramètre non trouvé' });
    return;
  }
  
  logger.info(`Paramètres pénalité mis à jour: ${type}`, { userId: req.user!.sub, data });
  res.json({ parametre, message: 'Paramètres mis à jour' });
}

/**
 * GET /penalites/exemptions
 * Liste les exemptions
 */
export async function listExemptions(req: Request, res: Response): Promise<void> {
  const exemptions = await penalitesService.listerExemptions();
  res.json({ exemptions });
}

/**
 * POST /penalites/exemptions
 * Ajoute une exemption
 */
export async function ajouterExemption(req: Request, res: Response): Promise<void> {
  const { vehicule_id, chauffeur_id, motif, date_debut, date_fin } = req.body;
  const userId = req.user!.sub;
  
  if (!vehicule_id && !chauffeur_id) {
    res.status(400).json({ error: 'vehicule_id ou chauffeur_id requis' });
    return;
  }
  if (!motif || !date_debut) {
    res.status(400).json({ error: 'motif et date_debut requis' });
    return;
  }
  
  const exemption = await penalitesService.ajouterExemption(
    vehicule_id || null,
    chauffeur_id || null,
    motif,
    date_debut,
    date_fin || null,
    userId
  );
  
  res.json({ exemption, message: 'Exemption ajoutée' });
}

/**
 * DELETE /penalites/exemptions/:id
 * Supprime une exemption
 */
export async function supprimerExemption(req: Request, res: Response): Promise<void> {
  const id = req.params.id as string;
  const userId = req.user!.sub;
  
  const exemption = await penalitesService.supprimerExemption(id, userId);
  
  if (!exemption) {
    res.status(404).json({ error: 'Exemption non trouvée' });
    return;
  }
  
  res.json({ message: 'Exemption supprimée' });
}

/**
 * POST /penalites/paiement-anticipe
 * Enregistre un paiement anticipé
 */
export async function enregistrerPaiementAnticipe(req: Request, res: Response): Promise<void> {
  const { vehicule_id, chauffeur_id, montant, jours_couverts, mode, raccourcit_duree, paiement_id, note } = req.body;
  
  if (!vehicule_id || !chauffeur_id || !montant || !jours_couverts) {
    res.status(400).json({ error: 'Paramètres requis manquants' });
    return;
  }
  
  const paiement = await penalitesService.enregistrerPaiementAnticipe(
    vehicule_id,
    chauffeur_id,
    montant,
    jours_couverts,
    mode || 'cash',
    raccourcit_duree || false,
    paiement_id || null,
    note
  );
  
  res.json({ paiement, message: 'Paiement anticipé enregistré' });
}

/**
 * POST /penalites/job/force
 * Force l'exécution du job de calcul des pénalités
 */
export async function forceJob(req: Request, res: Response): Promise<void> {
  const { forcePenalitesJob } = await import('../jobs/scheduler.js');
  const result = await forcePenalitesJob();
  res.json(result);
}
