import { Response, NextFunction } from 'express';
import type { AuthRequest } from '../types/index.js';
import * as contratsService from '../services/contratsService.js';
import { writeAuditLog } from '../services/audit.js';

// ─── Garants ─────────────────────────────────────────────────────────────────

export async function listGarants(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const actifsOnly = req.query.actifs !== 'false';
    const garants = await contratsService.listerGarants(actifsOnly);
    res.json({ success: true, data: garants });
  } catch (err) { next(err); }
}

export async function createGarant(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const garant = await contratsService.creerGarant(req.body);
    await writeAuditLog(req.user!.sub, 'CREATE_GARANT', garant.id, { nom: garant.nom });
    res.status(201).json({ success: true, data: garant });
  } catch (err) { next(err); }
}

export async function getGarant(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const garant = await contratsService.getGarant(id);
    if (!garant) {
      res.status(404).json({ success: false, message: 'Garant introuvable' });
      return;
    }
    res.json({ success: true, data: garant });
  } catch (err) { next(err); }
}

export async function updateGarant(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const garant = await contratsService.updateGarant(id, req.body);
    if (!garant) {
      res.status(404).json({ success: false, message: 'Garant introuvable' });
      return;
    }
    await writeAuditLog(req.user!.sub, 'UPDATE_GARANT', id, { fields: Object.keys(req.body) });
    res.json({ success: true, data: garant });
  } catch (err) { next(err); }
}

// ─── Paramètres ──────────────────────────────────────────────────────────────

export async function listParametres(_req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const parametres = await contratsService.listerParametres();
    res.json({ success: true, data: parametres });
  } catch (err) { next(err); }
}

export async function updateParametre(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const cle = req.params.cle as string;
    const { valeur } = req.body;
    if (!valeur) {
      res.status(400).json({ success: false, message: 'valeur requise' });
      return;
    }
    await contratsService.updateParametre(cle, valeur, req.user!.sub);
    await writeAuditLog(req.user!.sub, 'UPDATE_PARAM_CONTRAT', cle, { valeur });
    res.json({ success: true, message: 'Paramètre mis à jour' });
  } catch (err) { next(err); }
}

// ─── Contrats ────────────────────────────────────────────────────────────────

export async function listContrats(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const user = req.user!;
    let chauffeurId: string | undefined;
    let garantId: string | undefined;

    // Un chauffeur ne voit que ses contrats
    if (user.role === 'chauffeur') {
      const { rows } = await (await import('../config/db.js')).default.query(
        `SELECT id FROM chauffeurs WHERE user_id = $1`, [user.sub],
      );
      if (rows.length > 0) chauffeurId = rows[0].id;
    } else {
      chauffeurId = req.query.chauffeurId as string | undefined;
      garantId = req.query.garantId as string | undefined;
    }

    const contrats = await contratsService.listerContrats({
      chauffeurId,
      garantId,
      statut: req.query.statut as string | undefined,
      vehiculeId: req.query.vehiculeId as string | undefined,
    });
    res.json({ success: true, data: contrats });
  } catch (err) { next(err); }
}

export async function getContrat(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const contrat = await contratsService.getContratComplet(id);
    if (!contrat) {
      res.status(404).json({ success: false, message: 'Contrat introuvable' });
      return;
    }
    res.json({ success: true, data: contrat });
  } catch (err) { next(err); }
}

export async function createContrat(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const { chauffeurId, vehiculeId, garantId, prixAchat, apportInitial,
      frequencePaiement, montantEcheance, nombreEcheances, tauxInteret,
      datePremierPaiement, dateDebut, dateFinPrevue, notes } = req.body;

    if (!chauffeurId || !vehiculeId || !prixAchat || !frequencePaiement || !montantEcheance || !dateDebut) {
      res.status(400).json({
        success: false,
        message: 'Champs requis : chauffeurId, vehiculeId, prixAchat, frequencePaiement, montantEcheance, dateDebut',
      });
      return;
    }

    const contrat = await contratsService.creerContrat({
      chauffeurId, vehiculeId, garantId, prixAchat, apportInitial,
      frequencePaiement, montantEcheance, nombreEcheances, tauxInteret,
      datePremierPaiement, dateDebut, dateFinPrevue, notes,
      userId: req.user!.sub,
    });

    await writeAuditLog(req.user!.sub, 'CREATE_CONTRAT', contrat.id, {
      numero: contrat.numero, chauffeurId, vehiculeId,
    });

    res.status(201).json({ success: true, data: contrat });
  } catch (err) { next(err); }
}

export async function updateContrat(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const contrat = await contratsService.updateContrat(id, req.body);
    if (!contrat) {
      res.status(404).json({ success: false, message: 'Contrat introuvable' });
      return;
    }
    await writeAuditLog(req.user!.sub, 'UPDATE_CONTRAT', id, { fields: Object.keys(req.body) });
    res.json({ success: true, data: contrat });
  } catch (err) { next(err); }
}

export async function deleteContrat(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const id = req.params.id as string;
    const deleted = await contratsService.supprimerContrat(id);
    if (!deleted) {
      res.status(404).json({ success: false, message: 'Contrat introuvable' });
      return;
    }
    await writeAuditLog(req.user!.sub, 'DELETE_CONTRAT', id, {});
    res.json({ success: true, message: 'Contrat supprimé' });
  } catch (err) { next(err); }
}

// ─── Signatures ──────────────────────────────────────────────────────────────

export async function signerContrat(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const contratId = req.params.id as string;
    const user = req.user!;
    const { signataireType, signataireNom, signatureImageUrl } = req.body;

    if (!signataireType || !signataireNom) {
      res.status(400).json({ success: false, message: 'signataireType et signataireNom requis' });
      return;
    }

    const signature = await contratsService.signerContrat({
      contratId,
      signataireType,
      signataireId: user.sub,
      signataireNom,
      signatureImageUrl,
      ipAddress: req.ip ?? req.socket.remoteAddress,
      userAgent: req.headers['user-agent'],
    });

    res.status(201).json({ success: true, data: signature });
  } catch (err) { next(err); }
}

export async function listSignatures(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const contratId = req.params.id as string;
    const signatures = await contratsService.listerSignatures(contratId);
    res.json({ success: true, data: signatures });
  } catch (err) { next(err); }
}

// ─── Contenu contrat (pour génération PDF) ──────────────────────────────────

export async function getContenuContrat(req: AuthRequest, res: Response, next: NextFunction) {
  try {
    const contratId = req.params.id as string;
    const contenu = await contratsService.genererContenuContrat(contratId);
    res.json({ success: true, data: contenu });
  } catch (err) { next(err); }
}
