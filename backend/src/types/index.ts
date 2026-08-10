import { Request } from 'express';

// ─── Payload JWT ─────────────────────────────────────────────────────────────
export interface JwtPayload {
  sub: string;       // user.id
  role: string;      // super_admin | gestionnaire | chauffeur
  telephone: string;
}

// ─── Declaration merging Express Request ─────────────────────────────────────
declare global {
  namespace Express {
    interface Request {
      user?: JwtPayload;
    }
  }
}

// ─── Alias pour les contrôleurs ──────────────────────────────────────────────
export type AuthRequest = Request;

// ─── Réponse API standardisée ────────────────────────────────────────────────
export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  meta?: Record<string, unknown>;
}

// ─── Rôles ───────────────────────────────────────────────────────────────────
export type Role = 'super_admin' | 'gestionnaire' | 'chauffeur';

// ─── Statuts chauffeur ───────────────────────────────────────────────────────
export type ChauffeurStatut = 'actif' | 'retard' | 'defaut' | 'termine';

// ─── Statuts véhicule ────────────────────────────────────────────────────────
export type VehiculeStatut = 'en_remboursement' | 'rembourse' | 'en_panne' | 'accidente' | 'recupere';

// ─── Sync batch ──────────────────────────────────────────────────────────────
export interface SyncPaiementPayload {
  id: string;            // UUID généré côté mobile
  chauffeur_id: string;
  vehicule_id: string;
  montant: number;
  date: string;
  mode: 'cash' | 'mobile_money';
  synchronise_offline: boolean;
}
