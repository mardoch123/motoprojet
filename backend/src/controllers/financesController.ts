import { Response, NextFunction } from 'express';
import type { AuthRequest } from '../types/index.js';
import * as financesService from '../services/financesService.js';
import * as kkiapayService from '../services/kkiapayService.js';

/**
 * GET /api/v1/finances/patrimoine
 */
export async function getPatrimoine(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const patrimoine = await financesService.calculerPatrimoine();
    res.json({ success: true, data: patrimoine });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/finances/patrimoine/snapshot
 */
export async function createSnapshot(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    await financesService.enregistrerSnapshotPatrimoine();
    res.json({ success: true, message: 'Snapshot enregistré' });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/finances/depots
 */
export async function listDepots(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const depots = await financesService.listerDepots({
      dateDebut: req.query.dateDebut as string,
      dateFin: req.query.dateFin as string,
      rapproche: req.query.rapproche === 'true' ? true : req.query.rapproche === 'false' ? false : undefined,
    });
    res.json({ success: true, data: depots });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/finances/depots
 */
export async function createDepot(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { dateDepot, montantTheorique, montantReel, banque, reference, note } = req.body;
    const depot = await financesService.enregistrerDepot({
      dateDepot,
      montantTheorique,
      montantReel,
      banque,
      reference,
      note,
      userId: req.user!.sub,
    });
    res.status(201).json({ success: true, data: depot });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/finances/depots/:id/rapprocher
 */
export async function rapprocherDepot(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    await financesService.rapprocherDepot(id, req.user!.sub);
    res.json({ success: true, message: 'Dépôt rapproché' });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/finances/export
 */
export async function exportComptable(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { dateDebut, dateFin } = req.query;
    if (!dateDebut || !dateFin) {
      res.status(400).json({ success: false, message: 'Paramètres dateDebut et dateFin requis' });
      return;
    }
    const data = await financesService.genererExportComptable(dateDebut as string, dateFin as string);
    res.json({ success: true, data });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/finances/rapport/:mois
 */
export async function getRapportMensuel(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { mois } = req.params;
    if (!mois || !/^\d{4}-\d{2}$/.test(mois as string)) {
      res.status(400).json({ success: false, message: 'Paramètre mois invalide (format YYYY-MM)' });
      return;
    }
    const rapport = await financesService.genererRapportMensuel(mois as string);
    res.json({ success: true, data: rapport });
  } catch (err) { next(err); }
}

// ─── APPORTS PERSONNELS ─────────────────────────────────────────────────────

/**
 * GET /api/v1/finances/apports
 */
export async function listApports(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const actifsOnly = req.query.actifs !== 'false';
    const apports = await financesService.listerApports(actifsOnly);
    res.json({ success: true, data: apports });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/finances/apports
 */
export async function createApport(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { libelle, montant, frequence, jourPrealable, dateDebut, dateFin, objectif, note } = req.body;
    if (!libelle || !montant || !frequence || !dateDebut) {
      res.status(400).json({ success: false, message: 'Champs requis : libelle, montant, frequence, dateDebut' });
      return;
    }
    const apport = await financesService.creerApport({
      libelle,
      montant,
      frequence,
      jourPrealable,
      dateDebut,
      dateFin,
      objectif: objectif || 'moto',
      note,
      userId: req.user!.sub,
    });
    res.status(201).json({ success: true, data: apport });
  } catch (err) { next(err); }
}

/**
 * PUT /api/v1/finances/apports/:id
 */
export async function updateApport(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const apport = await financesService.updateApport(id, req.body);
    if (!apport) {
      res.status(404).json({ success: false, message: 'Apport introuvable' });
      return;
    }
    res.json({ success: true, data: apport });
  } catch (err) { next(err); }
}

/**
 * DELETE /api/v1/finances/apports/:id
 */
export async function deleteApport(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const deleted = await financesService.supprimerApport(id);
    if (!deleted) {
      res.status(404).json({ success: false, message: 'Apport introuvable' });
      return;
    }
    res.json({ success: true, message: 'Apport supprimé' });
  } catch (err) { next(err); }
}

/**
 * POST /api/v1/finances/apports/:id/versement
 * Versement via KKiaPay (mobile money)
 */
export async function enregistrerVersement(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const apportId = req.params.id as string;
    const { dateVersement, montant, note, telephone } = req.body;
    if (!dateVersement || !montant || !telephone) {
      res.status(400).json({ success: false, message: 'Champs requis : dateVersement, montant, telephone' });
      return;
    }

    // Initier le paiement KKiaPay
    const resultat = await kkiapayService.initierPaiementApport({
      apportId,
      montant,
      telephone,
      dateVersement,
      note,
    });

    res.status(201).json({
      success: true,
      data: {
        transaction_id: resultat.transactionId,
        statut: resultat.statut,
        url_paiement: resultat.urlPaiement,
        message: resultat.message,
      },
    });
  } catch (err) { next(err); }
}

/**
 * GET /api/v1/finances/apports/versements
 */
export async function listVersements(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const apportId = req.query.apportId as string | undefined;
    const versements = await financesService.listerVersements(apportId);
    res.json({ success: true, data: versements });
  } catch (err) { next(err); }
}
