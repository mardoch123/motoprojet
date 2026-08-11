/**
 * Script de seed des utilisateurs de test.
 * Crée les utilisateurs avec le bon hash bcrypt pour PIN "1234".
 */
import bcrypt from 'bcryptjs';
import { config } from '../config/env.js';
import { Pool } from '@neondatabase/serverless';

async function main() {
  const pin = '1234';
  const realHash = await bcrypt.hash(pin, 10);
  const ok = await bcrypt.compare(pin, realHash);
  if (!ok) { console.error('ERREUR: hash invalide'); process.exit(1); }
  console.log(`[OK] Hash bcrypt vérifié pour PIN "${pin}"`);

  const pool = new Pool({ connectionString: config.db.url });

  try {
    // Vérifier les tables existantes
    const { rows: tables } = await pool.query(
      `SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename`
    );
    console.log('[DB] Tables:', tables.map((t: any) => t.tablename).join(', '));

    if (!tables.find((t: any) => t.tablename === 'users')) {
      console.error('[ERREUR] La table users n\'existe pas. Exécutez migration.sql d\'abord.');
      process.exit(1);
    }

    // Insérer les utilisateurs de test
    const users = [
      { tel: '+22912345678', role: 'super_admin', mustChangePin: false },
      { tel: '+22923456789', role: 'gestionnaire', mustChangePin: false },
      { tel: '+22934567890', role: 'chauffeur', mustChangePin: true },
      { tel: '+22945678901', role: 'chauffeur', mustChangePin: true },
    ];

    for (const u of users) {
      const { rows } = await pool.query(`
        INSERT INTO users (telephone, pin_hash, role, must_change_pin, statut, onboarding_completed)
        VALUES ($1, $2, $3, $4, 'actif', FALSE)
        ON CONFLICT (telephone) DO UPDATE SET pin_hash = $2, statut = 'actif', onboarding_completed = FALSE
        RETURNING id, telephone, role
      `, [u.tel, realHash, u.role, u.mustChangePin]);
      console.log(`  [OK] ${rows[0].telephone} (${rows[0].role}) — id: ${rows[0].id}`);
    }

    // Insérer les chauffeurs liés (si pas déjà existants)
    const chauffeurs = [
      { tel: '+22934567890', nom: 'Koffi AGBANLON', piece: 'CNI-BJ-123456' },
      { tel: '+22945678901', nom: 'Mensah TOSSOU', piece: 'CNI-BJ-789012' },
    ];

    for (const c of chauffeurs) {
      const { rows } = await pool.query(`
        INSERT INTO chauffeurs (user_id, nom, piece_identite, statut)
        VALUES (
          (SELECT id FROM users WHERE telephone = $1),
          $2, $3, 'actif'
        )
        ON CONFLICT DO NOTHING
        RETURNING id, nom
      `, [c.tel, c.nom, c.piece]);
      if (rows.length > 0) {
        console.log(`  [OK] Chauffeur ${rows[0].nom} créé`);
      } else {
        console.log(`  [INFO] Chauffeur ${c.nom} déjà existant`);
      }
    }

    // Insérer des véhicules de test
    const vehicules = [
      { type: 'moto', plaque: 'MOTO-001-BJ', prix: 450000 },
      { type: 'moto', plaque: 'MOTO-002-BJ', prix: 500000 },
    ];

    for (const v of vehicules) {
      const { rows } = await pool.query(`
        INSERT INTO vehicules (type, plaque, prix_achat, date_achat, statut)
        VALUES ($1, $2, $3, '2025-01-15', 'en_remboursement')
        ON CONFLICT (plaque) DO NOTHING
        RETURNING id, plaque
      `, [v.type, v.plaque, v.prix]);
      if (rows.length > 0) {
        console.log(`  [OK] Véhicule ${rows[0].plaque} créé`);
      } else {
        console.log(`  [INFO] Véhicule ${v.plaque} déjà existant`);
      }
    }

    // Affectations
    await pool.query(`
      INSERT INTO affectations (chauffeur_id, vehicule_id)
      SELECT c.id, v.id
      FROM chauffeurs c, vehicules v
      WHERE c.nom = 'Koffi AGBANLON' AND v.plaque = 'MOTO-001-BJ'
      AND NOT EXISTS (
        SELECT 1 FROM affectations a 
        WHERE a.chauffeur_id = c.id AND a.vehicule_id = v.id
      )
    `);
    await pool.query(`
      INSERT INTO affectations (chauffeur_id, vehicule_id)
      SELECT c.id, v.id
      FROM chauffeurs c, vehicules v
      WHERE c.nom = 'Mensah TOSSOU' AND v.plaque = 'MOTO-002-BJ'
      AND NOT EXISTS (
        SELECT 1 FROM affectations a 
        WHERE a.chauffeur_id = c.id AND a.vehicule_id = v.id
      )
    `);
    console.log('  [OK] Affectations vérifiées');

    console.log('\n═══════════════════════════════════════════════════');
    console.log('  IDENTIFIANTS DE CONNEXION');
    console.log('═══════════════════════════════════════════════════');
    console.log('  PIN commun : 1234');
    console.log('───────────────────────────────────────────────────');
    console.log('  Super Admin  : +22912345678');
    console.log('  Gestionnaire : +22923456789');
    console.log('  Chauffeur 1  : +22934567890 (Koffi AGBANLON)');
    console.log('  Chauffeur 2  : +22945678901 (Mensah TOSSOU)');
    console.log('═══════════════════════════════════════════════════');
  } finally {
    await pool.end();
  }
}

main().catch(err => {
  console.error('Erreur:', err.message);
  process.exit(1);
});
