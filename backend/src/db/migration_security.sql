-- ============================================================================
-- Migration Sécurité — MotoProjet (Prompt 5)
-- Audit enrichi, chiffrement, verrouillage compte, RGPD
-- ============================================================================

-- ─── 1. Enrichissement journal_audit (valeurs avant/après, contexte) ─────────
ALTER TABLE journal_audit ADD COLUMN IF NOT EXISTS valeur_avant JSONB;
ALTER TABLE journal_audit ADD COLUMN IF NOT EXISTS valeur_apres JSONB;
ALTER TABLE journal_audit ADD COLUMN IF NOT EXISTS ip_address VARCHAR(45);
ALTER TABLE journal_audit ADD COLUMN IF NOT EXISTS user_agent TEXT;
ALTER TABLE journal_audit ADD COLUMN IF NOT EXISTS resource_type VARCHAR(50);
ALTER TABLE journal_audit ADD COLUMN IF NOT EXISTS resource_id UUID;

CREATE INDEX IF NOT EXISTS idx_audit_resource ON journal_audit(resource_type, resource_id);

-- ─── 2. Trigger append-only : empêcher UPDATE/DELETE sur journal_audit ───────
CREATE OR REPLACE FUNCTION prevent_audit_modification()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Modification du journal audit interdite (append-only)';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_append_only ON journal_audit;
CREATE TRIGGER trg_audit_append_only
  BEFORE UPDATE OR DELETE ON journal_audit
  FOR EACH ROW EXECUTE FUNCTION prevent_audit_modification();

-- ─── 3. Verrouillage de compte (tentatives PIN + lockout) ───────────────────
ALTER TABLE users ADD COLUMN IF NOT EXISTS login_attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS locked_until TIMESTAMPTZ;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_login_attempt TIMESTAMPTZ;

-- ─── 4. Table security_events (journal des événements de sécurité) ──────────
CREATE TABLE IF NOT EXISTS security_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  type VARCHAR(50) NOT NULL
    CHECK (type IN (
      'login_success', 'login_failure', 'pin_change', 'pin_reset',
      'account_locked', 'account_unlocked', 'role_change',
      'sensitive_data_access', 'rate_limit_exceeded', 'token_refresh',
      'ip_change', 'suspicious_activity'
    )),
  ip_address VARCHAR(45),
  user_agent TEXT,
  details JSONB DEFAULT '{}',
  severity VARCHAR(15) NOT NULL DEFAULT 'info'
    CHECK (severity IN ('info', 'warning', 'critical')),
  date_event TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_security_events_user ON security_events(user_id);
CREATE INDEX IF NOT EXISTS idx_security_events_type ON security_events(type);
CREATE INDEX IF NOT EXISTS idx_security_events_date ON security_events(date_event DESC);
CREATE INDEX IF NOT EXISTS idx_security_events_severity ON security_events(severity);

-- ─── 5. Chiffrement des données sensibles (pièce d'identité) ────────────────
-- Les colonnes piece_identite et numero_cni contiennent désormais des données
-- chiffrées avec AES-256-GCM. Le chiffrement est géré côté application.
-- On ajoute un marqueur pour savoir si la donnée est chiffrée.
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS piece_identite_chiffre BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS numero_cni_chiffre BOOLEAN NOT NULL DEFAULT FALSE;

-- Même chose pour les garants
ALTER TABLE garants ADD COLUMN IF NOT EXISTS piece_identite_numero_chiffre BOOLEAN NOT NULL DEFAULT FALSE;

-- ─── 6. Table consentements RGPD ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rgpd_consentements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type VARCHAR(50) NOT NULL
    CHECK (type IN (
      'collecte_donnees', 'photos', 'localisation', 'notifications',
      'conservation_pieces_identite', 'suppression_compte'
    )),
  accepte BOOLEAN NOT NULL DEFAULT FALSE,
  date_consentement TIMESTAMPTZ DEFAULT NOW(),
  date_retrait TIMESTAMPTZ,
  UNIQUE(user_id, type)
);

CREATE INDEX IF NOT EXISTS idx_rgpd_user ON rgpd_consentements(user_id);

-- ─── 7. Table demandes de suppression de données (droit à l'oubli) ──────────
CREATE TABLE IF NOT EXISTS rgpd_demandes_suppression (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  telephone VARCHAR(20),
  motif TEXT NOT NULL,
  statut VARCHAR(20) NOT NULL DEFAULT 'en_attente'
    CHECK (statut IN ('en_attente', 'traitee', 'refusee')),
  traite_par UUID REFERENCES users(id),
  traite_le TIMESTAMPTZ,
  anonymise BOOLEAN NOT NULL DEFAULT FALSE,
  date_demande TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rgpd_demandes_statut ON rgpd_demandes_suppression(statut);

-- ─── 8. Politique de rétention (paramètres) ─────────────────────────────────
INSERT INTO parametres (cle, valeur, description) VALUES
  ('rgpd_retention_pieces_annees', '5', 'Durée de conservation des pièces d''identité (années)'),
  ('rgpd_retention_photos_annees', '3', 'Durée de conservation des photos après fin contrat (années)'),
  ('rgpd_retention_audit_annees', '7', 'Durée de conservation du journal d''audit (années, non modifiable)'),
  ('rgpd_retention_security_events_annees', '3', 'Durée de conservation des événements de sécurité (années)'),
  ('security_max_login_attempts', '5', 'Nombre max de tentatives PIN avant verrouillage'),
  ('security_lockout_duration_minutes', '15', 'Durée du verrouillage de compte (minutes)'),
  ('security_pin_min_length', '4', 'Longueur minimum du PIN'),
  ('rate_limit_global_per_minute', '120', 'Rate limiting global : max requêtes par minute et par IP'),
  ('rate_limit_auth_per_minute', '5', 'Rate limiting authentification : max tentatives par minute et par IP'),
  ('rate_limit_sensitive_per_minute', '30', 'Rate limiting endpoints sensibles (écriture) par minute')
ON CONFLICT (cle) DO NOTHING;

-- ─── 9. Clé de chiffrement (référence — la vraie clé est en variable env) ───
-- Note : la clé AES-256 doit être stockée en variable d'environnement
-- ENCRYPTION_KEY (32 bytes = 64 caractères hex).
-- Ne JAMAIS écrire la clé ici.

-- ─── 10. Index pour les requêtes d'audit Super Admin ────────────────────────
CREATE INDEX IF NOT EXISTS idx_audit_date_action_desc ON journal_audit(date_action DESC);
CREATE INDEX IF NOT EXISTS idx_audit_action_date ON journal_audit(action, date_action DESC);

-- ─── 11. Vue : statistiques de sécurité (comptes verrouillés, etc.) ─────────
CREATE OR REPLACE VIEW vue_security_stats AS
SELECT
  COUNT(*) FILTER (WHERE locked_until > NOW()) AS comptes_verrouilles,
  COUNT(*) FILTER (WHERE login_attempts >= 3 AND locked_until IS NULL) AS comptes_a_risque,
  COUNT(*) FILTER (WHERE type = 'login_failure' AND date_event > NOW() - INTERVAL '24 hours')
    AS tentatives_24h,
  COUNT(*) FILTER (WHERE type = 'account_locked' AND date_event > NOW() - INTERVAL '7 days')
    AS verrouillages_7j
FROM security_events
CROSS JOIN users;
