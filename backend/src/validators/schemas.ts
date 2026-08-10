import { z } from 'zod';

// ─── Auth ────────────────────────────────────────────────────────────────────
export const loginSchema = z.object({
  telephone: z.string().min(8, 'Numéro trop court'),
  pin: z.string().min(4, 'PIN trop court').max(6, 'PIN trop long'),
});

export const refreshSchema = z.object({
  refresh_token: z.string().min(10, 'Refresh token invalide'),
});

// ─── Changement de PIN ──────────────────────────────────────────────────────
export const changePinSchema = z.object({
  old_pin: z.string().min(4).max(6),
  new_pin: z.string().min(4).max(6),
  confirm_pin: z.string().min(4).max(6),
}).refine(d => d.new_pin === d.confirm_pin, {
  message: 'Les PINs ne correspondent pas',
  path: ['confirm_pin'],
}).refine(d => d.old_pin !== d.new_pin, {
  message: 'Le nouveau PIN doit être différent de l\'ancien',
  path: ['new_pin'],
});

// ─── Réinitialisation PIN par admin ─────────────────────────────────────────
export const resetPinSchema = z.object({
  user_id: z.string().uuid('ID utilisateur invalide'),
});

// ─── Demande de réinitialisation PIN (chauffeur) ────────────────────────────
export const requestPinResetSchema = z.object({
  telephone: z.string().min(8, 'Numéro trop court'),
});

// ─── Chauffeurs ──────────────────────────────────────────────────────────────
export const createChauffeurSchema = z.object({
  telephone: z.string().min(8),
  pin: z.string().min(4).max(6),
  nom: z.string().min(2, 'Nom requis'),
  piece_identite: z.string().optional(),
  photo_url: z.string().url().optional(),
  adresse: z.string().optional(),
  contact_urgence: z.string().optional(),
  objectif_journalier: z.number().min(0).optional(),
});

export const updateChauffeurSchema = z.object({
  nom: z.string().min(2).optional(),
  piece_identite: z.string().optional(),
  photo_url: z.string().url().nullable().optional(),
  adresse: z.string().nullable().optional(),
  contact_urgence: z.string().nullable().optional(),
  objectif_journalier: z.number().min(0).nullable().optional(),
  statut: z.enum(['actif', 'retard', 'defaut', 'termine']).optional(),
});

export const createAffectationNestedSchema = z.object({
  vehicule_id: z.string().uuid(),
  date_debut: z.string().date().optional(),
});

export const terminerAffectationSchema = z.object({
  date_fin: z.string().date().optional(),
});

// ─── Véhicules ───────────────────────────────────────────────────────────────
export const createVehiculeSchema = z.object({
  type: z.enum(['moto', 'voiture']),
  plaque: z.string().min(3).max(20),
  prix_achat: z.number().positive('Le prix doit être positif'),
  date_achat: z.string().date().optional(),
  date_mise_circulation: z.string().date().optional(),
  marque: z.string().optional(),
  immatriculation: z.string().optional(),
});

export const updateVehiculeSchema = z.object({
  type: z.enum(['moto', 'voiture']).optional(),
  plaque: z.string().min(3).max(20).optional(),
  prix_achat: z.number().positive().optional(),
  date_achat: z.string().date().optional(),
  date_mise_circulation: z.string().date().nullable().optional(),
  date_fin_remboursement: z.string().date().nullable().optional(),
  marque: z.string().nullable().optional(),
  immatriculation: z.string().nullable().optional(),
});

export const changeStatutVehiculeSchema = z.object({
  statut: z.enum(['en_remboursement', 'rembourse', 'en_panne', 'accidente', 'recupere']),
  commentaire: z.string().optional(),
});

// ─── Paiements ───────────────────────────────────────────────────────────────
export const createPaiementSchema = z.object({
  vehicule_id: z.string().uuid('ID véhicule invalide'),
  montant: z.number().positive('Le montant doit être positif'),
  date: z.string().date().optional(),
  mode: z.enum(['cash', 'mobile_money']).default('cash'),
  synchronise_offline: z.boolean().default(false),
});

// ─── Sync batch ──────────────────────────────────────────────────────────────
export const syncBatchSchema = z.object({
  paiements: z.array(z.object({
    id: z.string().uuid('ID mobile invalide'),
    vehicule_id: z.string().uuid(),
    montant: z.number().positive(),
    date: z.string().date(),
    mode: z.enum(['cash', 'mobile_money']),
    synchronise_offline: z.boolean().default(true),
  })).min(1, 'Au moins un paiement requis').max(100, 'Max 100 paiements par lot'),
});

// ─── Incidents ───────────────────────────────────────────────────────────────
export const createIncidentSchema = z.object({
  vehicule_id: z.string().uuid(),
  type: z.enum(['panne', 'accident', 'vol']),
  description: z.string().min(10, 'Description trop courte (min 10 caractères)').optional(),
  photo_url: z.string().url().optional(),
  photo_urls: z.array(z.string().url()).optional(),
  severity: z.enum(['legere', 'moyenne', 'grave']).default('moyenne'),
  lieu: z.string().optional(),
  cout: z.number().min(0).default(0),
  date: z.string().date().optional(),
});

export const updateIncidentSchema = z.object({
  statut: z.enum(['signale', 'en_cours', 'resolu', 'classe_sans_suite']).optional(),
  statut_reparation: z.enum(['en_attente', 'en_cours', 'termine']).optional(),
  cout_reparation: z.number().min(0).optional(),
  date_remise_en_service: z.string().date().nullable().optional(),
  description: z.string().optional(),
  photo_urls: z.array(z.string().url()).optional(),
});

// ─── Affectations ────────────────────────────────────────────────────────────
export const createAffectationSchema = z.object({
  chauffeur_id: z.string().uuid(),
  vehicule_id: z.string().uuid(),
  date_debut: z.string().date().optional(),
  date_fin: z.string().date().optional(),
});

// ─── Salaires ────────────────────────────────────────────────────────────────
export const createSalaireSchema = z.object({
  profil: z.enum(['proprietaire', 'employe']),
  mois: z.string().regex(/^\d{4}-\d{2}$/, 'Format YYYY-MM requis'),
  montant: z.number().min(0),
  date_versement: z.string().date().optional(),
});

// ─── IA ──────────────────────────────────────────────────────────────────────
export const iaRecommandationSchema = z.object({
  revenu_jour: z.number().min(0, 'Le revenu ne peut pas être négatif'),
  km_jour: z.number().min(0, 'Le kilométrage ne peut pas être négatif'),
  zones: z.array(z.string().max(100)).max(10).optional(),
});

export const iaObjectifSchema = z.object({
  objectif_journalier: z.number().positive('L\'objectif doit être supérieur à 0'),
});
