-- ============================================================================
-- Script de test : Création véhicule + affectation + paiements de test
-- ============================================================================
-- Ce script :
-- 1. Crée une nouvelle moto avec une plaque unique
-- 2. L'affecte au chauffeur dont le numéro se termine par "7890"
-- 3. Insère des paiements de test (cash / mobile_money / kkiapay)
-- 4. Vérifie les données insérées
-- ============================================================================

BEGIN;

-- ─── 0. NETTOYAGE (si le véhicule existe déjà) ─────────────────────────────
DELETE FROM paiements WHERE vehicule_id IN (SELECT id FROM vehicules WHERE plaque LIKE 'MOTO-TEST-%' OR plaque LIKE 'MT-TEST-%');
DELETE FROM affectations WHERE vehicule_id IN (SELECT id FROM vehicules WHERE plaque LIKE 'MOTO-TEST-%' OR plaque LIKE 'MT-TEST-%');
DELETE FROM vehicules WHERE plaque LIKE 'MOTO-TEST-%' OR plaque LIKE 'MT-TEST-%';

-- ─── 1. CRÉATION DU VÉHICULE ────────────────────────────────────────────────
INSERT INTO vehicules (type, plaque, marque, prix_achat, date_achat, statut)
VALUES (
  'moto',
  'MT-TEST-' || TO_CHAR(NOW(), 'HH24MI'),
  'Honda CG125',
  500000,
  CURRENT_DATE,
  'en_remboursement'
);

-- ─── 2. AFFECTATION AU CHAUFFEUR (numéro se terminant par "7890") ───────────
INSERT INTO affectations (chauffeur_id, vehicule_id, date_debut)
SELECT c.id, v.id, CURRENT_DATE
FROM chauffeurs c
JOIN users u ON u.id = c.user_id
CROSS JOIN vehicules v
WHERE u.telephone LIKE '%7890'
  AND v.plaque LIKE 'MT-TEST-%'
LIMIT 1;

-- ─── 3. PAIEMENTS DE TEST ───────────────────────────────────────────────────
-- 10 paiements avec dates et modes variés pour tester le flux de remboursement
INSERT INTO paiements (chauffeur_id, vehicule_id, montant, date, mode, synchronise_offline)
SELECT c.id, v.id, 5000, d, m, TRUE
FROM chauffeurs c
JOIN users u ON u.id = c.user_id
CROSS JOIN vehicules v
CROSS JOIN LATERAL (
  VALUES
    (CURRENT_DATE - INTERVAL '30 days', 'kkiapay'),
    (CURRENT_DATE - INTERVAL '27 days', 'mobile_money'),
    (CURRENT_DATE - INTERVAL '23 days', 'kkiapay'),
    (CURRENT_DATE - INTERVAL '20 days', 'kkiapay'),
    (CURRENT_DATE - INTERVAL '16 days', 'mobile_money'),
    (CURRENT_DATE - INTERVAL '13 days', 'kkiapay'),
    (CURRENT_DATE - INTERVAL '9 days',  'mobile_money'),
    (CURRENT_DATE - INTERVAL '6 days',  'kkiapay'),
    (CURRENT_DATE - INTERVAL '3 days',  'mobile_money'),
    (CURRENT_DATE - INTERVAL '1 day',   'kkiapay')
) AS payments(d, m)
WHERE u.telephone LIKE '%7890'
  AND v.plaque LIKE 'MT-TEST-%';

-- ─── 4. VÉRIFICATION ────────────────────────────────────────────────────────
-- Afficher le véhicule créé
SELECT '=== VÉHICULE CRÉÉ ===' AS info;
SELECT v.id, v.plaque, v.marque, v.type, v.prix_achat, v.statut, v.date_achat
FROM vehicules v
WHERE v.plaque LIKE 'MOTO-TEST-%';

-- Afficher l'affectation
SELECT '=== AFFECTATION ===' AS info;
SELECT a.id AS affectation_id, c.nom AS chauffeur, u.telephone, v.plaque, a.date_debut
FROM affectations a
JOIN chauffeurs c ON c.id = a.chauffeur_id
JOIN users u ON u.id = c.user_id
JOIN vehicules v ON v.id = a.vehicule_id
WHERE v.plaque LIKE 'MOTO-TEST-%';

-- Afficher les paiements
SELECT '=== PAIEMENTS DE TEST ===' AS info;
SELECT p.id, p.montant, p.date, p.mode, p.synchronise_offline
FROM paiements p
JOIN vehicules v ON v.id = p.vehicule_id
WHERE v.plaque LIKE 'MT-TEST-%'
ORDER BY p.date;

-- Afficher le résumé financier
SELECT '=== RÉSUMÉ FINANCIER ===' AS info;
SELECT
  v.plaque,
  v.prix_achat,
  COUNT(p.id) AS nb_paiements,
  COALESCE(SUM(p.montant), 0) AS total_verse,
  v.prix_achat - COALESCE(SUM(p.montant), 0) AS solde_restant,
  ROUND((COALESCE(SUM(p.montant), 0) / NULLIF(v.prix_achat, 0)) * 100, 2) AS pct_rembourse
FROM vehicules v
LEFT JOIN paiements p ON p.vehicule_id = v.id
WHERE v.plaque LIKE 'MT-TEST-%'
GROUP BY v.id, v.plaque, v.prix_achat;

COMMIT;
