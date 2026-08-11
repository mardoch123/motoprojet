-- ============================================================================
-- Fichier de corrections — migration.sql (appliquer APRÈS migration.sql)
-- ============================================================================
-- Ce fichier corrige 4 problèmes dans migration.sql :
--   1. INSERT chauffeur sans user_id (viole NOT NULL)
--   2. CASE type mismatch (date vs integer) dans vue_retards_chauffeurs
--   3. Conversion des paiements 'cash' → 'mobile_money'
--   4. Contrainte paiements_mode_check mise à jour
--
-- Utiliser ce fichier si migration.sql a déjà été exécuté sur la base
-- (via init.ts avec l'ancien driver HTTP qui a tronqué le script).
-- ============================================================================

-- ─── 1. Corriger l'INSERT chauffeur sans user_id ─────────────────────────────
-- Ajouter l'utilisateur manquant pour Mensah TOSSOU
INSERT INTO users (telephone, pin_hash, role, must_change_pin)
VALUES ('+22945678901', '$2b$10$O7X5JeV20ndlZmKAIrcTTOoXCjYBff7BcScnSfCEf2O1J.TmC7YKa', 'chauffeur', TRUE)
ON CONFLICT (telephone) DO NOTHING;

-- Mettre à jour le chauffeur existant pour lier son user_id
UPDATE chauffeurs
SET user_id = (SELECT id FROM users WHERE telephone = '+22945678901')
WHERE nom = 'Mensah TOSSOU' AND user_id IS NULL;

-- ─── 2. Corriger la vue vue_retards_chauffeurs (CASE type mismatch) ──────────
-- La vue originale mélangeait DATE et INTEGER dans un CASE.
-- Recréer la vue avec les types corrects.
CREATE OR REPLACE VIEW vue_retards_chauffeurs AS
SELECT
  c.id AS chauffeur_id,
  c.nom,
  c.statut AS statut_chauffeur,
  c.jours_impayes_cumules,
  c.dernier_paiement_date,
  COALESCE(c.objectif_journalier, 5000) AS objectif_journalier,
  COUNT(DISTINCT a.vehicule_id) AS nb_vehicules,
  COALESCE(SUM(v.prix_achat), 0) AS valeur_totale,
  COALESCE(SUM(v.prix_achat - sub.total_verse), 0) AS montant_du_global,
  CASE
    WHEN c.dernier_paiement_date IS NULL THEN 999
    ELSE (CURRENT_DATE - c.dernier_paiement_date)
  END AS jours_depuis_dernier_paiement
FROM chauffeurs c
LEFT JOIN affectations a ON a.chauffeur_id = c.id AND a.date_fin IS NULL
LEFT JOIN vehicules v ON v.id = a.vehicule_id AND v.statut = 'en_remboursement'
LEFT JOIN LATERAL (
  SELECT COALESCE(SUM(p.montant), 0) AS total_verse
  FROM paiements p
  WHERE p.vehicule_id = v.id
) sub ON true
WHERE c.statut IN ('actif', 'retard', 'defaut')
GROUP BY c.id, c.nom, c.statut, c.jours_impayes_cumules, c.dernier_paiement_date, c.objectif_journalier;

-- ─── 3. Convertir les paiements 'cash' en 'mobile_money' ─────────────────────
-- La section 39 de migration.sql supprime le mode 'cash'.
-- Si des paiements 'cash' existent déjà, les convertir.
UPDATE paiements SET mode = 'mobile_money' WHERE mode = 'cash';

-- ─── 4. Mettre à jour la contrainte du mode de paiement ──────────────────────
ALTER TABLE paiements DROP CONSTRAINT IF EXISTS paiements_mode_check;
ALTER TABLE paiements ADD CONSTRAINT paiements_mode_check
  CHECK (mode IN ('mobile_money', 'kkiapay', 'mobile_money_kkiapay'));
ALTER TABLE paiements ALTER COLUMN mode SET DEFAULT 'kkiapay';
