-- ============================================================================
-- Migration Onboarding — Détection première connexion par utilisateur
-- ============================================================================
-- Ajoute le flag onboarding_completed sur la table users.
-- Chaque utilisateur passe par son parcours d'onboarding à la première
-- connexion, puis le flag est marqué à TRUE.
-- ============================================================================

-- ─── 1. Colonne onboarding_completed ────────────────────────────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;

-- ─── 2. Index pour la détection super_admin (premier lancement entreprise) ──
CREATE INDEX IF NOT EXISTS idx_users_super_admin_onboarding
  ON users(role, onboarding_completed)
  WHERE role = 'super_admin';

-- ─── 3. Vue : statut onboarding par rôle ────────────────────────────────────
CREATE OR REPLACE VIEW vue_onboarding_statut AS
SELECT
  role,
  COUNT(*) FILTER (WHERE onboarding_completed = FALSE) AS nb_a_onboarder,
  COUNT(*) FILTER (WHERE onboarding_completed = TRUE) AS nb_onboardes,
  COUNT(*) AS total
FROM users
WHERE statut = 'actif'
GROUP BY role;
