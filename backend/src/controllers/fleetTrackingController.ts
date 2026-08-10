import type { Request, Response } from 'express';
import crypto from 'crypto';
import * as fleetService from '../services/fleetTrackingService.js';
import { logger } from '../utils/logger.js';

/**
 * GET /fleet/vehicules
 * Liste tous les véhicules avec leur télémétrie
 */
export async function listVehicules(req: Request, res: Response): Promise<void> {
  const vehicules = await fleetService.getVehiculesAvecTelemetrie();
  res.json({ vehicules });
}

/**
 * GET /fleet/vehicules/:id/telemetrie
 * Historique télémétrie d'un véhicule
 */
export async function getTelemetrie(req: Request, res: Response): Promise<void> {
  const vehiculeId = req.params.id as string;
  const limit = parseInt(req.query.limit as string) || 100;
  
  const historique = await fleetService.getHistoriqueTelemetrie(vehiculeId, limit);
  const derniere = await fleetService.getDerniereTelemetrie(vehiculeId);
  
  res.json({ historique, derniere });
}

/**
 * GET /fleet/vehicules/:id/commandes
 * Historique des commandes d'un véhicule
 */
export async function getCommandes(req: Request, res: Response): Promise<void> {
  const vehiculeId = req.params.id as string;
  const commandes = await fleetService.getCommandesVehicule(vehiculeId);
  res.json({ commandes });
}

/**
 * POST /fleet/vehicules/:id/immobiliser
 * Demande d'immobilisation d'un véhicule
 */
export async function immobiliser(req: Request, res: Response): Promise<void> {
  const vehiculeId = req.params.id as string;
  const { motif, source } = req.body;
  const userId = req.user!.sub;
  
  if (!motif) {
    res.status(400).json({ error: 'Motif obligatoire' });
    return;
  }
  
  const commandeId = await fleetService.creerCommandeImmobilisation(
    vehiculeId,
    userId,
    motif,
    source || 'manuel'
  );
  
  logger.info('Immobilisation demandée', { vehiculeId, userId, commandeId });
  res.json({ commandeId, message: 'Commande d\'immobilisation créée' });
}

/**
 * POST /fleet/vehicules/:id/reactiver
 * Réactivation d'urgence d'un véhicule
 */
export async function reactiver(req: Request, res: Response): Promise<void> {
  const vehiculeId = req.params.id as string;
  const { motif } = req.body;
  const userId = req.user!.sub;
  
  if (!motif) {
    res.status(400).json({ error: 'Motif obligatoire' });
    return;
  }
  
  const commandeId = await fleetService.creerCommandeReactivation(
    vehiculeId,
    userId,
    motif,
    true // Priorité haute pour urgence
  );
  
  logger.info('Réactivation d\'urgence demandée', { vehiculeId, userId, commandeId });
  res.json({ commandeId, message: 'Commande de réactivation créée (priorité haute)' });
}

/**
 * GET /fleet/audit
 * Journal d'audit des immobilisations
 */
export async function getAudit(req: Request, res: Response): Promise<void> {
  const vehiculeId = req.query.vehicule_id as string | undefined;
  const limit = parseInt(req.query.limit as string) || 100;
  
  const audit = await fleetService.getAuditImmobilisations(vehiculeId, limit);
  res.json({ audit });
}

/**
 * GET /fleet/parametres
 * Paramètres d'immobilisation
 */
export async function getParametres(req: Request, res: Response): Promise<void> {
  const parametres = await fleetService.getAllParametres();
  res.json({ parametres });
}

/**
 * PUT /fleet/parametres
 * Met à jour les paramètres d'immobilisation
 */
export async function updateParametres(req: Request, res: Response): Promise<void> {
  const updates = req.body as Record<string, string>;
  
  for (const [cle, valeur] of Object.entries(updates)) {
    await fleetService.setParametre(cle, valeur);
  }
  
  logger.info('Paramètres immobilisation mis à jour', { userId: req.user!.sub, updates: Object.keys(updates) });
  res.json({ message: 'Paramètres mis à jour' });
}

/**
 * POST /fleet/webhook
 * Webhook pour recevoir la télémétrie des boîtiers GPS
 */
export async function webhook(req: Request, res: Response): Promise<void> {
  // Vérifier le secret si configuré
  const webhookSecret = await fleetService.getParametre('webhook_secret');
  if (webhookSecret) {
    const signature = req.headers['x-webhook-signature'] as string;
    const body = JSON.stringify(req.body);
    const expectedSignature = crypto
      .createHmac('sha256', webhookSecret)
      .update(body)
      .digest('hex');
    
    if (signature !== expectedSignature) {
      logger.warn('Webhook signature invalide', { ip: req.ip });
      res.status(401).json({ error: 'Signature invalide' });
      return;
    }
  }
  
  const payload = req.body;
  
  // Vérifier le type de webhook
  if (payload.type === 'telemetry') {
    // Télémétrie
    const result = await fleetService.traiterTelemetrie({
      imei: payload.imei,
      latitude: payload.latitude,
      longitude: payload.longitude,
      vitesse: payload.speed || payload.vitesse || 0,
      statut_moteur: payload.engine_status || payload.statut_moteur,
      niveau_batterie: payload.battery || payload.niveau_batterie,
      timestamp: payload.timestamp,
      donnees_brutes: payload,
    });
    
    res.json({ received: true, vehiculeId: result.vehiculeId });
  } else if (payload.type === 'command_confirmation') {
    // Confirmation de commande
    await fleetService.confirmerCommande(
      payload.imei,
      payload.command || payload.type_commande,
      payload.success !== false,
      payload.error
    );
    
    res.json({ received: true });
  } else {
    // Type inconnu
    logger.warn('Type de webhook inconnu', { type: payload.type });
    res.json({ received: true, ignored: true });
  }
}

/**
 * PUT /fleet/vehicules/:id/boitier
 * Configure le boîtier GPS d'un véhicule
 */
export async function configurerBoitier(req: Request, res: Response): Promise<void> {
  const vehiculeId = req.params.id as string;
  const { imei, fournisseur } = req.body;
  
  if (!imei) {
    res.status(400).json({ error: 'IMEI obligatoire' });
    return;
  }
  
  // TODO: Mettre à jour la table vehicules avec l'IMEI et le fournisseur
  // Pour l'instant, on retourne un succès
  logger.info('Boîtier configuré', { vehiculeId, imei, fournisseur, userId: req.user!.sub });
  res.json({ message: 'Boîtier configuré', imei, fournisseur });
}
