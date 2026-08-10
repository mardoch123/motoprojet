-- ============================================================================
-- Migration complète — MotoProjet (Neon PostgreSQL)
-- 12 tables, index, vues SQL, données de test
-- ============================================================================

-- ─── 1. USERS ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  telephone VARCHAR(20) UNIQUE NOT NULL,
  pin_hash VARCHAR(255) NOT NULL,
  role VARCHAR(20) NOT NULL DEFAULT 'chauffeur' CHECK (role IN ('super_admin', 'gestionnaire', 'chauffeur')),
  statut VARCHAR(20) NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif', 'suspendu', 'desactive')),
  must_change_pin BOOLEAN NOT NULL DEFAULT FALSE,
  pin_changed_at TIMESTAMPTZ,
  derniere_activite TIMESTAMPTZ DEFAULT NOW(),
  date_creation TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_telephone ON users(telephone);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

-- ─── 2. CHAUFFEURS ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS chauffeurs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  nom VARCHAR(150) NOT NULL,
  piece_identite VARCHAR(100),
  photo_url TEXT,
  adresse TEXT,
  contact_urgence VARCHAR(30),
  objectif_journalier NUMERIC(12, 2) DEFAULT 0,
  statut VARCHAR(20) NOT NULL DEFAULT 'actif' CHECK (statut IN ('actif', 'retard', 'defaut', 'termine')),
  date_creation TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_chauffeurs_user_id ON chauffeurs(user_id);
CREATE INDEX IF NOT EXISTS idx_chauffeurs_statut ON chauffeurs(statut);

-- ─── 3. VEHICULES ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vehicules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type VARCHAR(20) NOT NULL CHECK (type IN ('moto', 'voiture')),
  plaque VARCHAR(20) UNIQUE NOT NULL,
  marque VARCHAR(100),
  immatriculation VARCHAR(50),
  prix_achat NUMERIC(12, 2) NOT NULL,
  date_achat DATE DEFAULT CURRENT_DATE,
  date_mise_circulation DATE,
  date_fin_remboursement DATE,
  statut VARCHAR(30) NOT NULL DEFAULT 'en_remboursement'
    CHECK (statut IN ('en_remboursement', 'rembourse', 'en_panne', 'accidente', 'recupere')),
  date_creation TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicules_plaque ON vehicules(plaque);
CREATE INDEX IF NOT EXISTS idx_vehicules_statut ON vehicules(statut);
CREATE INDEX IF NOT EXISTS idx_vehicules_type ON vehicules(type);

-- ─── 3b. VEHICULE_STATUT_HISTORIQUE ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS vehicule_statut_historique (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  ancien_statut VARCHAR(30),
  nouveau_statut VARCHAR(30) NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  commentaire TEXT,
  date_changement TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vehicule_statut_hist_vehicule ON vehicule_statut_historique(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_vehicule_statut_hist_date ON vehicule_statut_historique(date_changement DESC);

-- ─── 4. AFFECTATIONS ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS affectations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE CASCADE,
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  date_debut DATE DEFAULT CURRENT_DATE,
  date_fin DATE,
  date_creation TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_affectations_chauffeur ON affectations(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_affectations_vehicule ON affectations(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_affectations_active ON affectations(vehicule_id) WHERE date_fin IS NULL;

-- ─── 5. PAIEMENTS ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS paiements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE RESTRICT,
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE RESTRICT,
  montant NUMERIC(12, 2) NOT NULL CHECK (montant > 0),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  mode VARCHAR(20) NOT NULL DEFAULT 'cash' CHECK (mode IN ('cash', 'mobile_money')),
  synchronise_offline BOOLEAN DEFAULT FALSE,
  date_enregistrement TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_paiements_chauffeur ON paiements(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_paiements_vehicule ON paiements(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_paiements_date ON paiements(date DESC);
CREATE INDEX IF NOT EXISTS idx_paiements_mode ON paiements(mode);

-- ─── 6. PARAMETRES ──────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS parametres (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cle VARCHAR(100) UNIQUE NOT NULL,
  valeur TEXT NOT NULL,
  description TEXT,
  date_modification TIMESTAMPTZ DEFAULT NOW()
);

-- ─── 7. SALAIRES ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS salaires (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profil VARCHAR(20) NOT NULL CHECK (profil IN ('proprietaire', 'employe')),
  mois VARCHAR(7) NOT NULL,
  montant NUMERIC(12, 2) NOT NULL DEFAULT 0,
  date_versement DATE DEFAULT CURRENT_DATE,
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(profil, mois)
);

-- ─── 8. INCIDENTS ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS incidents (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  type VARCHAR(20) NOT NULL CHECK (type IN ('panne', 'accident')),
  description TEXT,
  photo_url TEXT,
  cout NUMERIC(12, 2) DEFAULT 0,
  date DATE DEFAULT CURRENT_DATE,
  statut VARCHAR(20) NOT NULL DEFAULT 'signale' CHECK (statut IN ('signale', 'en_cours', 'resolu')),
  date_creation TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_incidents_vehicule ON incidents(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_incidents_statut ON incidents(statut);

-- ─── 9. OBJECTIFS_CHAUFFEUR ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS objectifs_chauffeur (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE CASCADE,
  periode VARCHAR(20) NOT NULL,
  objectif_montant NUMERIC(12, 2) NOT NULL,
  montant_atteint NUMERIC(12, 2) DEFAULT 0,
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(chauffeur_id, periode)
);

-- ─── 10. TRAJETS ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS trajets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE CASCADE,
  date DATE DEFAULT CURRENT_DATE,
  km_parcourus NUMERIC(8, 2) DEFAULT 0,
  zones JSONB DEFAULT '[]',
  revenu_genere NUMERIC(12, 2) DEFAULT 0,
  date_creation TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_trajets_chauffeur ON trajets(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_trajets_date ON trajets(date DESC);

-- ─── 11. JOURNAL_AUDIT ──────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS journal_audit (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  action VARCHAR(100) NOT NULL,
  cible VARCHAR(200),
  details JSONB DEFAULT '{}',
  date_action TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_user ON journal_audit(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_action ON journal_audit(action);
CREATE INDEX IF NOT EXISTS idx_audit_date ON journal_audit(date_action DESC);

-- ─── 12. NOTIFICATIONS_LOG ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS notifications_log (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE CASCADE,
  titre VARCHAR(200) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(30) DEFAULT 'info',
  lu BOOLEAN DEFAULT FALSE,
  date_creation TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications_log(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_lu ON notifications_log(lu);

-- ============================================================================
-- VUES SQL
-- ============================================================================

-- Solde restant par véhicule
CREATE OR REPLACE VIEW vue_solde_par_vehicule AS
SELECT
  v.id AS vehicule_id,
  v.plaque,
  v.prix_achat,
  COALESCE(SUM(p.montant), 0) AS total_verse,
  v.prix_achat - COALESCE(SUM(p.montant), 0) AS solde_restant,
  ROUND((COALESCE(SUM(p.montant), 0) / NULLIF(v.prix_achat, 0)) * 100, 2) AS pourcentage_rembourse
FROM vehicules v
LEFT JOIN paiements p ON p.vehicule_id = v.id
GROUP BY v.id, v.plaque, v.prix_achat;

-- Taux de recouvrement global
CREATE OR REPLACE VIEW vue_taux_recouvrement_global AS
SELECT
  COUNT(DISTINCT v.id) AS nb_vehicules,
  SUM(v.prix_achat) AS prix_total,
  COALESCE(SUM(p.montant), 0) AS total_recouvre,
  ROUND((COALESCE(SUM(p.montant), 0) / NULLIF(SUM(v.prix_achat), 0)) * 100, 2) AS taux_recouvrement
FROM vehicules v
LEFT JOIN paiements p ON p.vehicule_id = v.id;

-- Cash cumulé par mode
CREATE OR REPLACE VIEW vue_cash_cumule AS
SELECT
  mode,
  SUM(montant) AS total,
  COUNT(*) AS nb_paiements,
  DATE_TRUNC('month', date) AS mois
FROM paiements
GROUP BY mode, DATE_TRUNC('month', date)
ORDER BY mois DESC;

-- Cash cumulé disponible (total + ventilation)
CREATE OR REPLACE VIEW vue_cash_cumule_disponible AS
SELECT
  SUM(montant) AS total_general,
  SUM(montant) FILTER (WHERE mode = 'cash') AS total_cash,
  SUM(montant) FILTER (WHERE mode = 'mobile_money') AS total_mobile,
  COUNT(*) AS nb_total,
  COUNT(*) FILTER (WHERE mode = 'cash') AS nb_cash,
  COUNT(*) FILTER (WHERE mode = 'mobile_money') AS nb_mobile
FROM paiements;

-- ============================================================================
-- DONNÉES DE TEST
-- ============================================================================

-- PIN "1234" hashé avec bcrypt (10 rounds)
INSERT INTO users (telephone, pin_hash, role, must_change_pin) VALUES
  ('+22912345678', '$2a$10$rZG2Ql6G1Y0vGKJXmZCnAeN5R6tL8V9wX2yH4fK6jM8nO0pQ2rS4t', 'super_admin', FALSE),
  ('+22923456789', '$2a$10$rZG2Ql6G1Y0vGKJXmZCnAeN5R6tL8V9wX2yH4fK6jM8nO0pQ2rS4t', 'gestionnaire', FALSE),
  ('+22934567890', '$2a$10$rZG2Ql6G1Y0vGKJXmZCnAeN5R6tL8V9wX2yH4fK6jM8nO0pQ2rS4t', 'chauffeur', TRUE),
  ('+22945678901', '$2a$10$rZG2Ql6G1Y0vGKJXmZCnAeN5R6tL8V9wX2yH4fK6jM8nO0pQ2rS4t', 'chauffeur', TRUE);

-- Chauffeurs de test
INSERT INTO chauffeurs (user_id, nom, piece_identite) VALUES
  ((SELECT id FROM users WHERE telephone = '+22934567890'), 'Koffi AGBANLON', 'CNI-BJ-123456');

INSERT INTO chauffeurs (user_id, nom, piece_identite) VALUES
  ((SELECT id FROM users WHERE telephone = '+22945678901'), 'Mensah TOSSOU', 'CNI-BJ-789012');

-- 2 motos
INSERT INTO vehicules (type, plaque, prix_achat, date_achat, statut) VALUES
  ('moto', 'MOTO-001-BJ', 450000, '2025-01-15', 'en_remboursement'),
  ('moto', 'MOTO-002-BJ', 500000, '2025-03-01', 'en_remboursement');

-- Affectations
INSERT INTO affectations (chauffeur_id, vehicule_id) VALUES
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'),
   (SELECT id FROM vehicules WHERE plaque = 'MOTO-001-BJ'));

-- Paiements de test
INSERT INTO paiements (chauffeur_id, vehicule_id, montant, date, mode) VALUES
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'),
   (SELECT id FROM vehicules WHERE plaque = 'MOTO-001-BJ'),
   5000, '2025-06-01', 'cash'),
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'),
   (SELECT id FROM vehicules WHERE plaque = 'MOTO-001-BJ'),
   5000, '2025-06-08', 'mobile_money'),
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'),
   (SELECT id FROM vehicules WHERE plaque = 'MOTO-001-BJ'),
   5000, '2025-06-15', 'cash'),
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'),
   (SELECT id FROM vehicules WHERE plaque = 'MOTO-001-BJ'),
   5000, '2025-06-22', 'cash'),
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'),
   (SELECT id FROM vehicules WHERE plaque = 'MOTO-001-BJ'),
   5000, '2025-07-01', 'cash'),
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'),
   (SELECT id FROM vehicules WHERE plaque = 'MOTO-001-BJ'),
   5000, '2025-07-08', 'mobile_money'),
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'),
   (SELECT id FROM vehicules WHERE plaque = 'MOTO-001-BJ'),
   5000, '2025-07-15', 'cash'),
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'),
   (SELECT id FROM vehicules WHERE plaque = 'MOTO-001-BJ'),
   5000, '2025-07-22', 'cash');

-- Trajets
INSERT INTO trajets (chauffeur_id, km_parcourus, zones, revenu_genere) VALUES
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'), 45.5, '["Cotonou", "Calavi"]', 15000),
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'), 30.0, '["Porto-Novo"]', 10000),
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'), 60.2, '["Cotonou", "Ouidah"]', 20000);

-- Incident
INSERT INTO incidents (vehicule_id, type, description, cout) VALUES
  ((SELECT id FROM vehicules WHERE plaque = 'MOTO-002-BJ'), 'panne', 'Panne moteur — réparation en cours', 35000);

-- Paramètres
INSERT INTO parametres (cle, valeur, description) VALUES
  ('taux_interet_mensuel', '2.5', 'Taux d''intérêt mensuel en pourcentage'),
  ('duree_max_financement_mois', '24', 'Durée maximale de financement en mois'),
  ('montant_min_paiement', '1000', 'Montant minimum d''un paiement en FCFA'),
  ('frequence_paiement', 'hebdomadaire', 'Fréquence de paiement attendue'),
  ('penalite_retard_jours', '7', 'Nombre de jours avant signalement retard'),
  ('notification_rappel_jours', '1', 'Rappel de paiement X jours avant échéance'),
  ('version_app_min', '1.0.0', 'Version minimum de l''application mobile'),
  ('maintenance_mode', 'false', 'Mode maintenance activé/désactivé'),
  ('max_paiements_offline', '50', 'Nombre max de paiements en cache hors-ligne'),
  ('inactivity_timeout_minutes', '30', 'Durée d''inactivité avant déconnexion automatique (minutes)'),
  ('duree_financement_mois', '14', 'Durée par défaut de remboursement en mois'),
  ('seuil_defaut_jours', '10', 'Nombre de jours impayés cumulés avant passage en défaut'),
  ('seuil_retard_jours', '1', 'Nombre de jours impayés avant passage en retard'),
  ('job_impayes_heure', '2', 'Heure d''exécution du job nocturne impayés (UTC)');

-- ─── 13. VEHICULE_IMPAYES (suivi quotidien des jours sans paiement) ─────────
CREATE TABLE IF NOT EXISTS vehicule_impayes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE CASCADE,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  montant_attendu NUMERIC(12, 2) NOT NULL DEFAULT 0,
  montant_verse NUMERIC(12, 2) NOT NULL DEFAULT 0,
  ecart NUMERIC(12, 2) NOT NULL DEFAULT 0,
  statut VARCHAR(20) NOT NULL DEFAULT 'impaye' CHECK (statut IN ('paye', 'impaye', 'partiel')),
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(vehicule_id, date)
);

CREATE INDEX IF NOT EXISTS idx_impayes_vehicule ON vehicule_impayes(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_impayes_chauffeur ON vehicule_impayes(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_impayes_date ON vehicule_impayes(date DESC);
CREATE INDEX IF NOT EXISTS idx_impayes_statut ON vehicule_impayes(statut);

-- ─── 14. HISTORIQUE_TAUX_RECOUVREMENT (snapshots quotidiens) ─────────────────
CREATE TABLE IF NOT EXISTS historique_taux_recouvrement (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  montant_reel NUMERIC(14, 2) NOT NULL DEFAULT 0,
  montant_theorique NUMERIC(14, 2) NOT NULL DEFAULT 0,
  taux_recouvrement NUMERIC(6, 2) NOT NULL DEFAULT 0,
  nb_vehicules_actifs INTEGER NOT NULL DEFAULT 0,
  nb_vehicules_a_jour INTEGER NOT NULL DEFAULT 0,
  nb_vehicules_en_retard INTEGER NOT NULL DEFAULT 0,
  nb_vehicules_en_defaut INTEGER NOT NULL DEFAULT 0,
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(date)
);

CREATE INDEX IF NOT EXISTS idx_hist_recouv_date ON historique_taux_recouvrement(date DESC);

-- ─── 15. Colonne jours_impayes_cumules sur chauffeurs ────────────────────────
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS jours_impayes_cumules INTEGER NOT NULL DEFAULT 0;
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS dernier_paiement_date DATE;

-- ─── Vue : retards par chauffeur (pour le dashboard) ───────────────────────
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

-- ─── Vue : taux de recouvrement par véhicule (attendu vs réel) ─────────────
CREATE OR REPLACE VIEW vue_recouvrement_par_vehicule AS
SELECT
  v.id AS vehicule_id,
  v.plaque,
  v.prix_achat,
  v.date_mise_circulation,
  COALESCE(c.nom, '—') AS chauffeur_nom,
  COALESCE(c.objectif_journalier, 5000) AS objectif_journalier,
  -- Montant théorique = nb_jours_depuis_circulation × objectif_journalier
  CASE
    WHEN v.date_mise_circulation IS NOT NULL THEN
      GREATEST(0, (CURRENT_DATE - v.date_mise_circulation)) * COALESCE(c.objectif_journalier, 5000)
    ELSE 0
  END AS montant_theorique,
  COALESCE(SUM(p.montant), 0) AS montant_reel,
  CASE
    WHEN v.date_mise_circulation IS NOT NULL AND COALESCE(c.objectif_journalier, 5000) > 0 THEN
      ROUND(
        (COALESCE(SUM(p.montant), 0) /
         NULLIF(GREATEST(0, (CURRENT_DATE - v.date_mise_circulation)) * COALESCE(c.objectif_journalier, 5000), 0)
        ) * 100, 2
      )
    ELSE 0
  END AS taux_recouvrement,
  v.statut AS statut_vehicule,
  CASE
    WHEN c.dernier_paiement_date IS NULL THEN 999
    ELSE (CURRENT_DATE - c.dernier_paiement_date)
  END AS jours_sans_paiement
FROM vehicules v
LEFT JOIN affectations a ON a.vehicule_id = v.id AND a.date_fin IS NULL
LEFT JOIN chauffeurs c ON c.id = a.chauffeur_id
LEFT JOIN paiements p ON p.vehicule_id = v.id
WHERE v.statut = 'en_remboursement'
GROUP BY v.id, v.plaque, v.prix_achat, v.date_mise_circulation, v.statut,
         c.nom, c.objectif_journalier, c.dernier_paiement_date;

-- Objectifs
INSERT INTO objectifs_chauffeur (chauffeur_id, periode, objectif_montant) VALUES
  ((SELECT id FROM chauffeurs WHERE nom = 'Koffi AGBANLON'), '2025-07', 20000),
  ((SELECT id FROM chauffeurs WHERE nom = 'Mensah TOSSOU'), '2025-07', 15000);

-- Audit
INSERT INTO journal_audit (action, cible, details) VALUES
  ('INIT_SYSTEM', 'database', '{"message": "Initialisation de la base de données"}'),
  ('CREATE_VEHICULE', 'MOTO-001-BJ', '{"prix": 450000}');

-- Notifications
INSERT INTO notifications_log (user_id, titre, message, type) VALUES
  ((SELECT id FROM users WHERE telephone = '+22912345678'),
   'Bienvenue', 'Système de financement MotoProjet initialisé', 'info'),
  ((SELECT id FROM users WHERE telephone = '+22934567890'),
   'Paiement enregistré', 'Votre paiement de 5000 FCFA a été enregistré', 'success');

-- ─── 16. Extension notifications_log pour rappels automatiques ─────────────
ALTER TABLE notifications_log ADD COLUMN IF NOT EXISTS canal VARCHAR(20) DEFAULT 'in_app'
  CHECK (canal IN ('sms', 'whatsapp', 'in_app'));
ALTER TABLE notifications_log ADD COLUMN IF NOT EXISTS destinataire_telephone VARCHAR(30);
ALTER TABLE notifications_log ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}';
ALTER TABLE notifications_log ADD COLUMN IF NOT EXISTS statut VARCHAR(20) DEFAULT 'envoye'
  CHECK (statut IN ('en_attente', 'envoye', 'echec', 'lu'));
ALTER TABLE notifications_log ADD COLUMN IF NOT EXISTS tentatives INTEGER DEFAULT 0;
ALTER TABLE notifications_log ADD COLUMN IF NOT EXISTS erreur TEXT;
ALTER TABLE notifications_log ADD COLUMN IF NOT EXISTS date_envoi TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications_log(type);
CREATE INDEX IF NOT EXISTS idx_notifications_statut ON notifications_log(statut);
CREATE INDEX IF NOT EXISTS idx_notifications_date ON notifications_log(date_creation DESC);

-- ─── 17. Paramètres rappels automatiques ─────────────────────────────────
INSERT INTO parametres (cle, valeur, description) VALUES
  ('rappel_actif_sms', 'true', 'Activer les rappels SMS automatiques'),
  ('rappel_actif_whatsapp', 'true', 'Activer les rappels WhatsApp automatiques'),
  ('rappel_delai_min_heures', '24', 'Délai minimum entre deux rappels du même type (heures)');

-- ─── 18. Extension table incidents (sévérité, lieu, photos, réparations) ─
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS severity VARCHAR(20) DEFAULT 'moyenne' CHECK (severity IN ('legere', 'moyenne', 'grave'));
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS lieu TEXT;
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS photo_urls TEXT[] DEFAULT '{}';
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS statut_reparation VARCHAR(20) DEFAULT 'en_attente' CHECK (statut_reparation IN ('en_attente', 'en_cours', 'termine'));
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS cout_reparation NUMERIC(12, 2) DEFAULT 0;
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS date_remise_en_service DATE;
ALTER TABLE incidents ADD COLUMN IF NOT EXISTS declared_by UUID REFERENCES users(id);

-- Index pour les véhicules en incident actif (exclusion calcul impayés)
CREATE INDEX IF NOT EXISTS idx_incidents_actifs ON incidents(vehicule_id) WHERE statut NOT IN ('resolu', 'classe_sans_suite');

-- Extension du check type pour inclure 'vol'
ALTER TABLE incidents DROP CONSTRAINT IF EXISTS incidents_type_check;
ALTER TABLE incidents ADD CONSTRAINT incidents_type_check CHECK (type IN ('panne', 'accident', 'vol'));

-- Extension du check statut pour inclure 'classe_sans_suite'
ALTER TABLE incidents DROP CONSTRAINT IF EXISTS incidents_statut_check;
ALTER TABLE incidents ADD CONSTRAINT incidents_statut_check CHECK (statut IN ('signale', 'en_cours', 'resolu', 'classe_sans_suite'));

-- ─── 19. IA_RECOMMANDATIONS (recommandations IA pour chauffeurs) ────────────
CREATE TABLE IF NOT EXISTS ia_recommendations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE CASCADE,
  modele_utilise VARCHAR(30) NOT NULL DEFAULT 'deepseek' CHECK (modele_utilise IN ('deepseek', 'claude')),
  revenu_jour NUMERIC(12, 2) NOT NULL DEFAULT 0,
  objectif_jour NUMERIC(12, 2) NOT NULL DEFAULT 0,
  km_jour NUMERIC(8, 2) NOT NULL DEFAULT 0,
  km_7j NUMERIC(8, 2) NOT NULL DEFAULT 0,
  zones_frequentees JSONB DEFAULT '[]',
  recommandation TEXT NOT NULL,
  objectif_atteint BOOLEAN NOT NULL DEFAULT FALSE,
  date_creation TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ia_reco_chauffeur ON ia_recommendations(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_ia_reco_date ON ia_recommendations(date_creation DESC);

-- ─── 20. HISTORIQUE_PERFORMANCE (suivi objectif atteint par jour/semaine) ───
CREATE TABLE IF NOT EXISTS historique_performance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE CASCADE,
  periode_type VARCHAR(10) NOT NULL CHECK (periode_type IN ('jour', 'semaine')),
  periode_label VARCHAR(20) NOT NULL,
  objectif NUMERIC(12, 2) NOT NULL DEFAULT 0,
  revenu_realise NUMERIC(12, 2) NOT NULL DEFAULT 0,
  ecart NUMERIC(12, 2) NOT NULL DEFAULT 0,
  objectif_atteint BOOLEAN NOT NULL DEFAULT FALSE,
  km_parcourus NUMERIC(8, 2) NOT NULL DEFAULT 0,
  nb_jours_activite INTEGER NOT NULL DEFAULT 0,
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(chauffeur_id, periode_type, periode_label)
);

CREATE INDEX IF NOT EXISTS idx_hist_perf_chauffeur ON historique_performance(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_hist_perf_periode ON historique_performance(periode_label DESC);

-- ─── 21. Paramètres IA ──────────────────────────────────────────────────────
INSERT INTO parametres (cle, valeur, description) VALUES
  ('ia_provider', 'deepseek', 'Fournisseur IA principal : deepseek ou claude'),
  ('ia_max_reponses', '3', 'Nombre max de recommandations par appel'),
  ('ia_tracking_actif', 'true', 'Suivi GPS actif pour l''IA (peut être désactivé par le chauffeur)');

-- ─── 22. IA_OBJECTIFS_ADMIN (objectifs globaux du super admin) ──────────────
CREATE TABLE IF NOT EXISTS ia_objectifs_admin (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  libelle VARCHAR(200) NOT NULL,
  valeur_cible NUMERIC(14, 2) NOT NULL,
  unite VARCHAR(50) NOT NULL DEFAULT 'nb_vehicules'
    CHECK (unite IN ('nb_vehicules', 'taux_recouvrement', 'revenu_mensuel', 'delai_mois')),
  delai_mois INTEGER NOT NULL DEFAULT 12,
  actif BOOLEAN NOT NULL DEFAULT TRUE,
  date_creation TIMESTAMPTZ DEFAULT NOW(),
  date_modification TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ia_objectifs_admin_actif ON ia_objectifs_admin(actif);

-- ─── 23. IA_RAPPORTS_ADMIN (rapports hebdomadaires générés par l'IA) ────────
CREATE TABLE IF NOT EXISTS ia_rapports_admin (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type VARCHAR(20) NOT NULL DEFAULT 'hebdo'
    CHECK (type IN ('hebdo', 'manuel', 'chat')),
  contexte_json JSONB NOT NULL DEFAULT '{}',
  rapport TEXT NOT NULL,
  actions_proposees JSONB DEFAULT '[]',
  trajectoire VARCHAR(20) DEFAULT 'non_evaluee'
    CHECK (trajectoire IN ('en_avance', 'a_temps', 'en_retard', 'non_evaluee')),
  objectifs_snapshot JSONB DEFAULT '{}',
  modele_utilise VARCHAR(30) NOT NULL DEFAULT 'claude',
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  date_creation TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ia_rapports_admin_date ON ia_rapports_admin(date_creation DESC);
CREATE INDEX IF NOT EXISTS idx_ia_rapports_admin_type ON ia_rapports_admin(type);

-- ─── 24. Paramètres IA admin ────────────────────────────────────────────────
INSERT INTO parametres (cle, valeur, description) VALUES
  ('ia_admin_frequence', 'hebdomadaire', 'Fréquence des rapports IA admin : quotidien ou hebdomadaire'),
  ('ia_admin_job_jour', '1', 'Jour d''exécution du rapport IA (1=Lundi)');

-- Objectif admin par défaut
INSERT INTO ia_objectifs_admin (libelle, valeur_cible, unite, delai_mois) VALUES
  ('Atteindre 20 véhicules en circulation', 20, 'nb_vehicules', 12),
  ('Maintenir un taux de recouvrement de 90%', 90, 'taux_recouvrement', 12);

-- ─── 25. ANOMALIES_DETECTEES (détection IA d'anomalies en temps réel) ───────
CREATE TABLE IF NOT EXISTS anomalies_detectees (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type_anomalie VARCHAR(40) NOT NULL
    CHECK (type_anomalie IN (
      'chute_recouvrement',       -- Baisse soudaine du taux de recouvrement
      'chauffeur_arret_paiement', -- Chauffeur régulier qui ne paie plus
      'remboursements_simultanes',-- Plusieurs véhicules finissent ensemble (trésorerie)
      'incidents_multiples',      -- Plusieurs véhicules en panne en même temps
      'cash_anormalement_bas',    -- Cash journalier très en dessous de la moyenne
      'retards_ensemble',         -- Plusieurs chauffeurs passent en retard simultanément
      'autre'
    )),
  severite VARCHAR(15) NOT NULL DEFAULT 'moyenne'
    CHECK (severite IN ('critique', 'haute', 'moyenne', 'basse')),
  titre VARCHAR(200) NOT NULL,
  description TEXT NOT NULL,
  cause_probable TEXT,
  actions_suggerees JSONB DEFAULT '[]',
  contexte_json JSONB NOT NULL DEFAULT '{}',
  statut VARCHAR(20) NOT NULL DEFAULT 'nouveau'
    CHECK (statut IN ('nouveau', 'vu', 'ignore', 'traite')),
  notif_envoyee BOOLEAN NOT NULL DEFAULT FALSE,
  date_detection TIMESTAMPTZ DEFAULT NOW(),
  date_traitement TIMESTAMPTZ,
  traite_par UUID REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_anomalies_date ON anomalies_detectees(date_detection DESC);
CREATE INDEX IF NOT EXISTS idx_anomalies_statut ON anomalies_detectees(statut);
CREATE INDEX IF NOT EXISTS idx_anomalies_severite ON anomalies_detectees(severite);
CREATE INDEX IF NOT EXISTS idx_anomalies_type ON anomalies_detectees(type_anomalie);

-- ─── 26. Paramètres détection anomalies ────────────────────────────────────
INSERT INTO parametres (cle, valeur, description) VALUES
  ('anomalie_frequence_verification', '4', 'Fréquence de vérification des anomalies (heures)'),
  ('anomalie_seuil_chute_recouvrement', '15', 'Baisse mininum du taux (%) pour alerter'),
  ('anomalie_seuil_cash_bas_pct', '40', 'Cash en dessous de X% de la moyenne pour alerter'),
  ('anomalie_fenetre_groupe_jours', '30', 'Jours max pour considérer des remboursements comme groupés'),
  ('anomalie_actif', 'true', 'Détection d''anomalies active');

-- ─── 27. Paramètres salaires ────────────────────────────────────────────────
INSERT INTO parametres (cle, valeur, description) VALUES
  ('salaire_pct_proprietaire', '8', 'Pourcentage du revenu mensuel encaissé pour le propriétaire'),
  ('salaire_pct_employe', '4', 'Pourcentage du revenu mensuel encaissé pour l''employé'),
  ('salaire_seuil_vehicules', '5', 'Nombre minimum de véhicules actifs pour déclencher les salaires'),
  ('salaire_actif', 'true', 'Module salaires actif');

-- ─── 28. Extension table salaires (revenu encaissé, véhicules actifs, statut) ─
ALTER TABLE salaires ADD COLUMN IF NOT EXISTS revenu_encaisse NUMERIC(14, 2) DEFAULT 0;
ALTER TABLE salaires ADD COLUMN IF NOT EXISTS vehicules_actifs INTEGER DEFAULT 0;
ALTER TABLE salaires ADD COLUMN IF NOT EXISTS pct_applique NUMERIC(5, 2) DEFAULT 0;
ALTER TABLE salaires ADD COLUMN IF NOT EXISTS statut VARCHAR(20) DEFAULT 'calcule'
  CHECK (statut IN ('calcule', 'valide', 'verse', 'annule'));
ALTER TABLE salaires ADD COLUMN IF NOT EXISTS verse_par UUID REFERENCES users(id);
ALTER TABLE salaires ADD COLUMN IF NOT EXISTS note TEXT;

-- ─── 29. Type anomalie : salaire_anormalement_bas ───────────────────────────
ALTER TABLE anomalies_detectees DROP CONSTRAINT IF EXISTS anomalies_detectees_type_anomalie_check;
ALTER TABLE anomalies_detectees ADD CONSTRAINT anomalies_detectees_type_anomalie_check
  CHECK (type_anomalie IN (
    'chute_recouvrement',
    'chauffeur_arret_paiement',
    'remboursements_simultanes',
    'incidents_multiples',
    'cash_anormalement_bas',
    'retards_ensemble',
    'salaire_anormalement_bas',
    'autre'
  ));

-- ─── 30. Paramètres prochain achat ─────────────────────────────────────────
INSERT INTO parametres (cle, valeur, description) VALUES
  ('prix_moto_defaut', '500000', 'Prix par défaut d''une moto (FCFA)'),
  ('prix_voiture_defaut', '2500000', 'Prix par défaut d''une voiture (FCFA)'),
  ('regle_reinvestissement', 'tout_moto', 'Règle de réinvestissement : tout_moto, tout_voiture, bascule, mixte');

-- ─── 31. Dépôts en banque ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS depots_banque (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date_depot DATE NOT NULL DEFAULT CURRENT_DATE,
  montant_theorique NUMERIC(15,2) NOT NULL,  -- Cash théorique à déposer
  montant_reel NUMERIC(15,2) NOT NULL,        -- Montant réellement déposé
  ecart NUMERIC(15,2) GENERATED ALWAYS AS (montant_reel - montant_theorique) STORED,
  banque VARCHAR(100),
  reference VARCHAR(100),
  note TEXT,
  rapproche BOOLEAN DEFAULT false,
  rapproche_par UUID REFERENCES users(id),
  rapproche_le TIMESTAMP WITH TIME ZONE,
  cree_par UUID REFERENCES users(id),
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_depots_date ON depots_banque(date_depot DESC);

-- ─── 32. Snapshots patrimoine ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS patrimoine_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  date_snapshot DATE NOT NULL DEFAULT CURRENT_DATE,
  cash_en_caisse NUMERIC(15,2) NOT NULL,
  valeur_vehicules_actifs NUMERIC(15,2) NOT NULL,  -- Restes dus
  patrimoine_total NUMERIC(15,2) GENERATED ALWAYS AS (cash_en_caisse + valeur_vehicules_actifs) STORED,
  nb_vehicules_actifs INTEGER NOT NULL,
  nb_vehicules_rembourses INTEGER NOT NULL,
  detail JSONB,  -- Détail par véhicule
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(date_snapshot)
);

CREATE INDEX IF NOT EXISTS idx_patrimoine_date ON patrimoine_snapshots(date_snapshot DESC);

-- ─── 33. Justificatifs d'achat ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS justificatifs_achat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  type_document VARCHAR(50) NOT NULL,  -- 'facture', 'recu', 'contrat', 'autre'
  url_fichier TEXT NOT NULL,
  nom_fichier VARCHAR(255),
  taille_fichier INTEGER,
  description TEXT,
  upload_par UUID REFERENCES users(id),
  upload_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_justif_vehicule ON justificatifs_achat(vehicule_id);

-- ─── 34. Rapports mensuels générés ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS rapports_mensuels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  mois VARCHAR(7) NOT NULL,  -- 'YYYY-MM'
  type_rapport VARCHAR(50) NOT NULL,  -- 'financier', 'activite'
  titre VARCHAR(255),
  contenu JSONB NOT NULL,  -- Données du rapport structurées
  url_pdf TEXT,
  envoye_par_email BOOLEAN DEFAULT false,
  envoye_a TEXT[],  -- Liste d'emails
  genere_par UUID REFERENCES users(id),
  genere_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(mois, type_rapport)
);

CREATE INDEX IF NOT EXISTS idx_rapports_mois ON rapports_mensuels(mois DESC);

-- ─── 35. Apports personnels (accélération achat) ──────────────────────────
CREATE TABLE IF NOT EXISTS apports_personnels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  libelle VARCHAR(255) NOT NULL,
  montant NUMERIC(15,2) NOT NULL,
  frequence VARCHAR(20) NOT NULL,  -- 'hebdomadaire', 'mensuel', 'trimestriel'
  jour_prealable INTEGER,  -- Pour hebdo: 0-6 (dim-sam), pour mensuel: 1-28, pour trimestriel: 1-90
  actif BOOLEAN DEFAULT true,
  date_debut DATE NOT NULL DEFAULT CURRENT_DATE,
  date_fin DATE,  -- Optionnel, si on veut arrêter à une date
  objectif VARCHAR(20) DEFAULT 'moto',  -- 'moto' ou 'voiture'
  note TEXT,
  cree_par UUID REFERENCES users(id),
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  modifie_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_apports_actif ON apports_personnels(actif);

-- Historique des apports réellement versés
CREATE TABLE IF NOT EXISTS apports_versements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  apport_id UUID NOT NULL REFERENCES apports_personnels(id) ON DELETE CASCADE,
  date_versement DATE NOT NULL,
  montant NUMERIC(15,2) NOT NULL,
  note TEXT,
  valide BOOLEAN DEFAULT true,
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_apports_versements_date ON apports_versements(date_versement DESC);

-- ─── 36. Pénalités de retard ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS penalites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE CASCADE,
  date_penalite DATE NOT NULL,
  montant NUMERIC(15,2) NOT NULL,
  motif VARCHAR(255) DEFAULT 'Retard de paiement',
  statut VARCHAR(20) NOT NULL DEFAULT 'active',  -- 'active', 'annulee', 'payee'
  annule_par UUID REFERENCES users(id),
  motif_annulation TEXT,
  paye_le TIMESTAMP WITH TIME ZONE,
  paiement_id UUID REFERENCES paiements(id),
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(vehicule_id, date_penalite)
);

CREATE INDEX IF NOT EXISTS idx_penalites_vehicule ON penalites(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_penalites_chauffeur ON penalites(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_penalites_date ON penalites(date_penalite DESC);
CREATE INDEX IF NOT EXISTS idx_penalites_statut ON penalites(statut);

-- Paramètres des pénalités
CREATE TABLE IF NOT EXISTS parametres_penalites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  type_vehicule VARCHAR(20) NOT NULL,  -- 'moto' ou 'voiture' ou 'general'
  type_calcul VARCHAR(20) NOT NULL DEFAULT 'fixe',  -- 'fixe' ou 'pourcentage'
  montant_fixe NUMERIC(15,2) DEFAULT 500,  -- Montant fixe par jour
  pourcentage NUMERIC(5,2) DEFAULT 10,  -- Pourcentage du montant journalier
  seuil_jours INTEGER DEFAULT 1,  -- Jour de déclenchement (0 = J+0, 1 = J+1, etc.)
  plafond NUMERIC(15,2),  -- Plafond max par véhicule (null = illimité)
  actif BOOLEAN DEFAULT true,
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  modifie_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(type_vehicule)
);

-- Insertion des paramètres par défaut
INSERT INTO parametres_penalites (type_vehicule, type_calcul, montant_fixe, pourcentage, seuil_jours, plafond)
VALUES 
  ('general', 'fixe', 500, 10, 1, NULL),
  ('moto', 'fixe', 500, 10, 1, 50000),
  ('voiture', 'fixe', 1000, 10, 1, 200000)
ON CONFLICT (type_vehicule) DO NOTHING;

-- Véhicules/chauffeurs exemptés de pénalités
CREATE TABLE IF NOT EXISTS exemptions_penalites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID REFERENCES vehicules(id) ON DELETE CASCADE,
  chauffeur_id UUID REFERENCES chauffeurs(id) ON DELETE CASCADE,
  motif TEXT NOT NULL,
  date_debut DATE NOT NULL,
  date_fin DATE,  -- NULL = indéterminée
  actif BOOLEAN DEFAULT true,
  cree_par UUID REFERENCES users(id),
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CHECK (vehicule_id IS NOT NULL OR chauffeur_id IS NOT NULL)
);

CREATE INDEX IF NOT EXISTS idx_exemptions_vehicule ON exemptions_penalites(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_exemptions_chauffeur ON exemptions_penalites(chauffeur_id);

-- Paiements anticipés (jours couverts à l'avance)
CREATE TABLE IF NOT EXISTS paiements_anticipes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE CASCADE,
  paiement_id UUID REFERENCES paiements(id) ON DELETE SET NULL,
  date_paiement DATE NOT NULL,
  jours_couverts INTEGER NOT NULL,
  date_fin_couverture DATE NOT NULL,
  montant NUMERIC(15,2) NOT NULL,
  mode VARCHAR(20) NOT NULL,  -- 'cash', 'mobile_money'
  raccourcit_duree BOOLEAN DEFAULT false,  -- Si true, avance la date de fin de remboursement
  note TEXT,
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_paiements_anticipes_vehicule ON paiements_anticipes(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_paiements_anticipes_date ON paiements_anticipes(date_fin_couverture);

-- ─── 37. Fleet Tracking & Immobilisation ─────────────────────────────────────
-- Enrichissement de la table vehicules (colonnes ajoutées si non existantes)
ALTER TABLE vehicules ADD COLUMN IF NOT EXISTS imei_boitier VARCHAR(50);
ALTER TABLE vehicules ADD COLUMN IF NOT EXISTS fournisseur_boitier VARCHAR(100);
ALTER TABLE vehicules ADD COLUMN IF NOT EXISTS statut_moteur VARCHAR(20) DEFAULT 'actif';
ALTER TABLE vehicules ADD COLUMN IF NOT EXISTS derniere_latitude NUMERIC(10, 7);
ALTER TABLE vehicules ADD COLUMN IF NOT EXISTS derniere_longitude NUMERIC(10, 7);
ALTER TABLE vehicules ADD COLUMN IF NOT EXISTS derniere_vitesse NUMERIC(5, 1) DEFAULT 0;
ALTER TABLE vehicules ADD COLUMN IF NOT EXISTS derniere_maj_telemetrie TIMESTAMP WITH TIME ZONE;
ALTER TABLE vehicules ADD COLUMN IF NOT EXISTS coupure_auto BOOLEAN DEFAULT true;
ALTER TABLE vehicules ADD COLUMN IF NOT EXISTS seuil_coupure_jours INTEGER DEFAULT 2;

CREATE INDEX IF NOT EXISTS idx_vehicules_imei ON vehicules(imei_boitier);
CREATE INDEX IF NOT EXISTS idx_vehicules_statut_moteur ON vehicules(statut_moteur);

-- Télémétrie reçue des boîtiers GPS (historique)
CREATE TABLE IF NOT EXISTS telemetrie_vehicules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  latitude NUMERIC(10, 7),
  longitude NUMERIC(10, 7),
  vitesse NUMERIC(5, 1),
  statut_moteur VARCHAR(20),
  niveau_batterie NUMERIC(5, 2),
  donnees_brutes JSONB,  -- Données complètes du boîtier
  received_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_telemetrie_vehicule ON telemetrie_vehicules(vehicule_id, received_at DESC);
CREATE INDEX IF NOT EXISTS idx_telemetrie_date ON telemetrie_vehicules(received_at DESC);

-- Commandes envoyées aux boîtiers (immobilisation/réactivation)
CREATE TABLE IF NOT EXISTS commandes_boitier (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  type_commande VARCHAR(20) NOT NULL,  -- 'immobiliser', 'reactiver'
  statut VARCHAR(20) NOT NULL DEFAULT 'en_attente',  -- 'en_attente', 'envoyee', 'confirmee', 'echouee', 'annulee'
  declenche_par UUID REFERENCES users(id),
  motif TEXT,
  vitesse_au_declenchement NUMERIC(5, 1),
  position_au_declenchement POINT,
  envoye_le TIMESTAMP WITH TIME ZONE,
  confirme_le TIMESTAMP WITH TIME ZONE,
  erreur TEXT,
  tentatives INTEGER DEFAULT 0,
  max_tentatives INTEGER DEFAULT 5,
  expire_le TIMESTAMP WITH TIME ZONE,
  priorite BOOLEAN DEFAULT false,  -- Urgence (réactivation manuelle)
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_commandes_vehicule ON commandes_boitier(vehicule_id, cree_le DESC);
CREATE INDEX IF NOT EXISTS idx_commandes_statut ON commandes_boitier(statut);
CREATE INDEX IF NOT EXISTS idx_commandes_type ON commandes_boitier(type_commande);

-- Journal d'audit des immobilisations (non modifiable)
CREATE TABLE IF NOT EXISTS audit_immobilisations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE CASCADE,
  chauffeur_id UUID REFERENCES chauffeurs(id),
  action VARCHAR(20) NOT NULL,  -- 'coupure_demandee', 'coupure_envoyee', 'coupure_confirmee', 'reactivation', 'urgence'
  declenche_par UUID REFERENCES users(id),
  source VARCHAR(20) NOT NULL DEFAULT 'manuel',  -- 'manuel', 'automatique', 'penalite', 'urgence'
  vitesse_au_moment NUMERIC(5, 1),
  latitude NUMERIC(10, 7),
  longitude NUMERIC(10, 7),
  details JSONB,
  horodatage TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_audit_immobilisations_vehicule ON audit_immobilisations(vehicule_id, horodatage DESC);
CREATE INDEX IF NOT EXISTS idx_audit_immobilisations_date ON audit_immobilisations(horodatage DESC);

-- Paramètres globaux d'immobilisation
CREATE TABLE IF NOT EXISTS parametres_immobilisation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cle VARCHAR(50) NOT NULL UNIQUE,
  valeur VARCHAR(255) NOT NULL,
  description TEXT,
  modifie_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Insertion des paramètres par défaut
INSERT INTO parametres_immobilisation (cle, valeur, description) VALUES
  ('immobilisation_active', 'true', 'Activer/désactiver globalement l''immobilisation'),
  ('delai_preavis_heures', '2', 'Heures de préavis avant coupure'),
  ('duree_arret_confirme_secondes', '30', 'Secondes d''arrêt continu pour confirmer'),
  ('vitesse_max_coupe', '0', 'Vitesse max pour autoriser coupure (km/h)'),
  ('fournisseur_api_url', '', 'URL API du fournisseur de boîtiers GPS'),
  ('fournisseur_api_key', '', 'Clé API du fournisseur'),
  ('webhook_secret', '', 'Secret pour vérifier les webhooks entrants')
ON CONFLICT (cle) DO NOTHING;

-- ─── 38. Intégration KKiaPay (Mobile Money) ─────────────────────────────────

-- Enrichissement de la table apports_versements avec mode de paiement et transaction KKiaPay
ALTER TABLE apports_versements ADD COLUMN IF NOT EXISTS mode VARCHAR(30) DEFAULT 'kkiapay';
ALTER TABLE apports_versements ADD COLUMN IF NOT EXISTS kkiapay_transaction_id VARCHAR(100);
ALTER TABLE apports_versements ADD COLUMN IF NOT EXISTS telephone VARCHAR(20);
ALTER TABLE apports_versements ADD COLUMN IF NOT EXISTS statut_paiement VARCHAR(20) DEFAULT 'confirme';

-- Table de suivi des transactions KKiaPay
CREATE TABLE IF NOT EXISTS transactions_kkiapay (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id VARCHAR(100) UNIQUE NOT NULL,
  type VARCHAR(30) NOT NULL,  -- 'apport_versement', 'paiement_chauffeur'
  reference_id UUID NOT NULL,  -- ID de l'entité liée (apport_versement ou paiement)
  montant NUMERIC(15,2) NOT NULL,
  telephone VARCHAR(20) NOT NULL,
  statut VARCHAR(20) NOT NULL DEFAULT 'pending',  -- 'pending', 'confirmed', 'failed', 'expired'
  montant_recu NUMERIC(15,2),
  frais NUMERIC(15,2),
  reponse_kkiapay JSONB,
  webhook_recu JSONB,
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  confirme_le TIMESTAMP WITH TIME ZONE,
  expire_le TIMESTAMP WITH TIME ZONE DEFAULT NOW() + INTERVAL '10 minutes'
);

CREATE INDEX IF NOT EXISTS idx_transactions_kkiapay_statut ON transactions_kkiapay(statut);
CREATE INDEX IF NOT EXISTS idx_transactions_kkiapay_type ON transactions_kkiapay(type);
CREATE INDEX IF NOT EXISTS idx_transactions_kkiapay_transaction_id ON transactions_kkiapay(transaction_id);

-- ─── 39. Contrats numérisés ───────────────────────────────────────────────

-- Enrichissement de la table chauffeurs pour les contrats
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS date_naissance DATE;
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS lieu_naissance VARCHAR(150);
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS nationalite VARCHAR(50) DEFAULT 'Béninoise';
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS profession VARCHAR(100);
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS numero_cni VARCHAR(50);
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS date_delivrance_cni DATE;
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS lieu_delivrance_cni VARCHAR(100);
ALTER TABLE chauffeurs ADD COLUMN IF NOT EXISTS email VARCHAR(150);

-- Table des garants
CREATE TABLE IF NOT EXISTS garants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  nom VARCHAR(150) NOT NULL,
  prenom VARCHAR(100),
  date_naissance DATE,
  lieu_naissance VARCHAR(150),
  nationalite VARCHAR(50) DEFAULT 'Béninoise',
  profession VARCHAR(100),
  telephone VARCHAR(20) NOT NULL,
  email VARCHAR(150),
  adresse TEXT,
  piece_identite_type VARCHAR(30),  -- 'cni', 'passeport', 'permis'
  piece_identite_numero VARCHAR(50),
  piece_identite_delivree_le DATE,
  piece_identite_lieu VARCHAR(100),
  lien_parente VARCHAR(50),  -- 'pere', 'mere', 'frere', 'oncle', 'ami', etc.
  situation_financiere VARCHAR(50),  -- 'salarie', 'commercant', 'fonctionnaire', etc.
  employeur VARCHAR(150),
  revenu_mensuel NUMERIC(12, 2),
  photo_url TEXT,
  actif BOOLEAN DEFAULT true,
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_garants_telephone ON garants(telephone);
CREATE INDEX IF NOT EXISTS idx_garants_user_id ON garants(user_id);

-- Table des contrats
CREATE TABLE IF NOT EXISTS contrats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  numero VARCHAR(50) UNIQUE NOT NULL,
  chauffeur_id UUID NOT NULL REFERENCES chauffeurs(id) ON DELETE RESTRICT,
  vehicule_id UUID NOT NULL REFERENCES vehicules(id) ON DELETE RESTRICT,
  garant_id UUID REFERENCES garants(id) ON DELETE SET NULL,
  
  -- Détails financiers
  prix_achat NUMERIC(12, 2) NOT NULL,
  apport_initial NUMERIC(12, 2) DEFAULT 0,
  montant_financ NUMERIC(12, 2) NOT NULL,
  frequence_paiement VARCHAR(20) NOT NULL DEFAULT 'journalier' CHECK (frequence_paiement IN ('journalier', 'hebdomadaire', 'mensuel')),
  montant_echeance NUMERIC(12, 2) NOT NULL,
  nombre_echeances INTEGER,
  taux_interet NUMERIC(5, 2) DEFAULT 0,
  date_premier_paiement DATE,
  
  -- Dates
  date_signature DATE,
  date_debut DATE NOT NULL,
  date_fin_prevue DATE,
  date_fin_reelle DATE,
  
  -- Statut
  statut VARCHAR(30) NOT NULL DEFAULT 'brouillon' CHECK (statut IN ('brouillon', 'en_cours', 'signe', 'resilie', 'termine')),
  
  -- Document
  pdf_url TEXT,
  pdf_hash VARCHAR(128),  -- SHA-256 du PDF pour intégrité
  
  -- Metadata
  cree_par UUID REFERENCES users(id),
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  modifie_le TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_contrats_chauffeur ON contrats(chauffeur_id);
CREATE INDEX IF NOT EXISTS idx_contrats_vehicule ON contrats(vehicule_id);
CREATE INDEX IF NOT EXISTS idx_contrats_garant ON contrats(garant_id);
CREATE INDEX IF NOT EXISTS idx_contrats_statut ON contrats(statut);
CREATE INDEX IF NOT EXISTS idx_contrats_numero ON contrats(numero);

-- Table des signatures
CREATE TABLE IF NOT EXISTS signatures_contrats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contrat_id UUID NOT NULL REFERENCES contrats(id) ON DELETE CASCADE,
  signataire_type VARCHAR(20) NOT NULL CHECK (signataire_type IN ('chauffeur', 'garant', 'admin')),
  signataire_id UUID NOT NULL,  -- user_id du signataire
  signataire_nom VARCHAR(150) NOT NULL,
  
  -- Signature
  signature_hash VARCHAR(128) NOT NULL,  -- Hash de la signature
  signature_image_url TEXT,
  
  -- Horodatage
  date_signature TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  ip_address VARCHAR(45),
  user_agent TEXT,
  
  -- Statut
  statut VARCHAR(20) NOT NULL DEFAULT 'signe' CHECK (statut IN ('signe', 'refuse', 'annule')),
  
  -- Metadata
  cree_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_signatures_contrat ON signatures_contrats(contrat_id);
CREATE INDEX IF NOT EXISTS idx_signatures_signataire ON signatures_contrats(signataire_id);

-- Paramètres des contrats (clauses, modèles)
CREATE TABLE IF NOT EXISTS parametres_contrats (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cle VARCHAR(50) NOT NULL UNIQUE,
  valeur TEXT NOT NULL,
  description TEXT,
  modifie_par UUID REFERENCES users(id),
  modifie_le TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Paramètres par défaut
INSERT INTO parametres_contrats (cle, valeur, description) VALUES
  ('titre_contrat', 'CONTRAT DE FINANCEMENT DE VÉHICULE', 'Titre du contrat'),
  ('clause_objet', 'Le présent contrat a pour objet le financement d''un véhicule par le système de paiement échelonné. Le bénéficiaire s''engage à rembourser le montant total selon la fréquence convenue.', 'Clause objet du contrat'),
  ('clause_obligations_beneficiaire', 'Le bénéficiaire s''engage à : 1) Effectuer les paiements selon la fréquence convenue ; 2) Entretenir le véhicule en bon état ; 3) Ne pas vendre ou céder le véhicule avant remboursement complet ; 4) Assurer le véhicule ; 5) Signaler tout incident dans les 48h.', 'Clause obligations bénéficiaire'),
  ('clause_obligations_financeur', 'Le financeur s''engage à : 1) Livrer le véhicule en bon état ; 2) Transférer la propriété après remboursement complet ; 3) Fournir un reçu pour chaque paiement ; 4) Respecter la confidentialité des données.', 'Clause obligations financeur'),
  ('clause_retard', 'En cas de retard de paiement supérieur à 7 jours, des pénalités seront appliquées conformément au règlement intérieur. Après 30 jours de retard sans justification, le contrat pourra être résilié et le véhicule récupéré.', 'Clause retard de paiement'),
  ('clause_resiliation', 'Le contrat peut être résilié : 1) Par remboursement anticipé total ; 2) Par accord mutuel ; 3) Pour non-respect des obligations ; 4) Pour décès du bénéficiaire (transmission au garant).', 'Clause résiliation'),
  ('clause_garant', 'Le garant s''engage solidairement avec le bénéficiaire au remboursement du montant restant dû en cas de défaillance de ce dernier. Cet engagement est valable pendant toute la durée du contrat et jusqu''au remboursement complet.', 'Clause garant'),
  ('clause_juridiction', 'Tout litige relatif à l''exécution du présent contrat sera soumis aux tribunaux compétents de la République du Bénin.', 'Clause juridiction'),
  ('prefixe_numero', 'MP', 'Préfixe du numéro de contrat'),
  ('delai_cool_down_heures', '24', 'Délai de rétractation en heures')
ON CONFLICT (cle) DO NOTHING;

-- Modification de la table paiements : modes de paiement
-- Convertir les anciens modes 'cash' vers 'mobile_money' puis appliquer la nouvelle contrainte
UPDATE paiements SET mode = 'mobile_money' WHERE mode = 'cash';
ALTER TABLE paiements DROP CONSTRAINT IF EXISTS paiements_mode_check;
ALTER TABLE paiements ADD CONSTRAINT paiements_mode_check CHECK (mode IN ('mobile_money', 'kkiapay', 'mobile_money_kkiapay'));
ALTER TABLE paiements ALTER COLUMN mode SET DEFAULT 'kkiapay';
