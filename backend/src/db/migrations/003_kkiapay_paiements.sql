-- ============================================================================
-- Migration KKiaPay Paiements — Intégration Mobile Money pour paiements
-- ============================================================================
-- Ajoute le support du paiement électronique via KKiaPay pour les chauffeurs.
-- Le mode 'mobile_money_kkiapay' est ajouté à la table paiements.
-- La colonne transaction_kkiapay_id lie le paiement à la transaction KKiaPay.
-- ============================================================================

-- ─── 1. Enrichir le mode de paiement ────────────────────────────────────────
-- Ajouter 'mobile_money_kkiapay' au CHECK de la colonne mode
ALTER TABLE paiements DROP CONSTRAINT IF EXISTS paiements_mode_check;
ALTER TABLE paiements ADD CONSTRAINT paiements_mode_check
  CHECK (mode IN ('cash', 'mobile_money', 'mobile_money_kkiapay'));

-- ─── 2. Colonne de liaison transaction KKiaPay ─────────────────────────────
ALTER TABLE paiements ADD COLUMN IF NOT EXISTS transaction_kkiapay_id VARCHAR(100);
ALTER TABLE paiements ADD COLUMN IF NOT EXISTS kkiapay_frais NUMERIC(12, 2);

-- Index unique pour empêcher la création de doublons (idempotence)
CREATE UNIQUE INDEX IF NOT EXISTS idx_paiements_transaction_kkiapay
  ON paiements(transaction_kkiapay_id)
  WHERE transaction_kkiapay_id IS NOT NULL;

-- Index pour les recherches par mode
CREATE INDEX IF NOT EXISTS idx_paiements_mode_kkiapay
  ON paiements(mode) WHERE mode = 'mobile_money_kkiapay';

-- ─── 3. Extension de la table transactions_kkiapay ─────────────────────────
-- Ajouter un champ pour l'idempotence webhook
ALTER TABLE transactions_kkiapay ADD COLUMN IF NOT EXISTS paiement_id UUID;
ALTER TABLE transactions_kkiapay ADD COLUMN IF NOT EXISTS webhook_processed BOOLEAN DEFAULT FALSE;

-- Contrainte : un transaction_id ne peut être traité qu'une fois
CREATE UNIQUE INDEX IF NOT EXISTS idx_transactions_kkiapay_paiement_id
  ON transactions_kkiapay(paiement_id)
  WHERE paiement_id IS NOT NULL AND type = 'paiement_chauffeur';

-- ─── 4. Vue des paiements KKiaPay ──────────────────────────────────────────
CREATE OR REPLACE VIEW vue_paiements_kkiapay AS
SELECT
  p.id AS paiement_id,
  p.chauffeur_id,
  p.vehicule_id,
  p.montant,
  p.date,
  p.mode,
  p.transaction_kkiapay_id,
  p.kkiapay_frais,
  c.nom AS chauffeur_nom,
  v.plaque AS vehicule_plaque,
  tk.statut AS kkiapay_statut,
  tk.telephone AS kkiapay_telephone,
  tk.confirme_le AS kkiapay_confirme_le,
  p.date_enregistrement
FROM paiements p
LEFT JOIN chauffeurs c ON p.chauffeur_id = c.id
LEFT JOIN vehicules v ON p.vehicule_id = v.id
LEFT JOIN transactions_kkiapay tk ON p.transaction_kkiapay_id = tk.transaction_id
WHERE p.mode = 'mobile_money_kkiapay';

-- ─── 5. Statistiques KKiaPay ───────────────────────────────────────────────
CREATE OR REPLACE VIEW vue_stats_kkiapay AS
SELECT
  COUNT(*) FILTER (WHERE mode = 'mobile_money_kkiapay') AS total_paiements_momo,
  COUNT(*) FILTER (WHERE mode = 'cash') AS total_paiements_cash,
  COUNT(*) FILTER (WHERE mode = 'mobile_money') AS total_paiements_momo_manuel,
  COALESCE(SUM(montant) FILTER (WHERE mode = 'mobile_money_kkiapay'), 0) AS montant_total_momo,
  COALESCE(SUM(kkiapay_frais) FILTER (WHERE mode = 'mobile_money_kkiapay'), 0) AS frais_total_momo,
  COALESCE(SUM(montant) FILTER (WHERE mode IN ('cash', 'mobile_money')), 0) AS montant_total_cash
FROM paiements;
