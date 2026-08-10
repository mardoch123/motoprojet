import { Router } from 'express';
import { authenticate, authorize } from '../../middleware/auth.js';
import {
  listGarants, createGarant, getGarant, updateGarant,
  listParametres, updateParametre,
  listContrats, getContrat, createContrat, updateContrat, deleteContrat,
  signerContrat, listSignatures, getContenuContrat,
} from '../../controllers/contratsController.js';
import { auditAction } from '../../middleware/audit.js';
import { sensitiveRateLimiter } from '../../middleware/security.js';

const router = Router();

router.use(authenticate);

// ─── Garants (tous rôles authentifiés peuvent voir, admin/gestionnaire créent)
router.get('/garants', authorize('super_admin', 'gestionnaire', 'chauffeur'), listGarants);
router.get('/garants/:id', authorize('super_admin', 'gestionnaire', 'chauffeur'), getGarant);
router.post('/garants', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('CREATE', 'garant'), createGarant);
router.put('/garants/:id', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('UPDATE', 'garant'), updateGarant);

// ─── Paramètres des contrats (admin voit, admin modifie avec audit)
router.get('/parametres', authorize('super_admin', 'gestionnaire'), listParametres);
router.put('/parametres/:cle', authorize('super_admin'), sensitiveRateLimiter, auditAction('UPDATE', 'parametre_contrat'), updateParametre);

// ─── Contrats (tous rôles authentifiés voient la liste, écriture restreinte)
router.get('/', authorize('super_admin', 'gestionnaire', 'chauffeur'), listContrats);
router.get('/:id', authorize('super_admin', 'gestionnaire', 'chauffeur'), getContrat);
router.post('/', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('CREATE', 'contrat'), createContrat);
router.put('/:id', authorize('super_admin', 'gestionnaire'), sensitiveRateLimiter, auditAction('UPDATE', 'contrat'), updateContrat);
router.delete('/:id', authorize('super_admin'), sensitiveRateLimiter, auditAction('DELETE', 'contrat'), deleteContrat);

// ─── Signatures (avec audit)
router.post('/:id/signer', sensitiveRateLimiter, auditAction('UPDATE', 'signature_contrat'), signerContrat);
router.get('/:id/signatures', authorize('super_admin', 'gestionnaire', 'chauffeur'), listSignatures);

// ─── Contenu contrat (pour génération PDF côté client)
router.get('/:id/contenu', authorize('super_admin', 'gestionnaire', 'chauffeur'), getContenuContrat);

export default router;
