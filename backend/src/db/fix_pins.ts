/**
 * Script de correction des PINs de test.
 * 
 * Le hash bcrypt dans migration.sql était un faux placeholder.
 * Ce script :
 * 1. Génère un vrai hash bcrypt pour le PIN "1234"
 * 2. Met à jour les utilisateurs de test en base de production
 * 3. Met à jour migration.sql et corrections_migration.sql
 */
import bcrypt from 'bcryptjs';
import { writeFileSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { config } from '../config/env.js';
import { Pool } from '@neondatabase/serverless';

const __dirname = dirname(fileURLToPath(import.meta.url));

async function main() {
  // 1. Générer le vrai hash
  const pin = '1234';
  const realHash = await bcrypt.hash(pin, 10);
  
  // Vérifier que le hash fonctionne
  const ok = await bcrypt.compare(pin, realHash);
  if (!ok) {
    console.error('ERREUR: Le hash généré ne fonctionne pas!');
    process.exit(1);
  }
  console.log(`[OK] Hash bcrypt généré pour PIN "${pin}": ${realHash}`);

  // 2. Mettre à jour la base de données
  console.log('[DB] Connexion à la base de données...');
  const pool = new Pool({ connectionString: config.db.url });
  
  try {
    // Mettre à jour tous les utilisateurs de test
    const { rows } = await pool.query(`
      UPDATE users 
      SET pin_hash = $1 
      WHERE telephone IN ('+22912345678', '+22923456789', '+22934567890', '+22945678901')
      RETURNING telephone, role
    `, [realHash]);
    
    if (rows.length === 0) {
      console.log('[WARN] Aucun utilisateur de test trouvé en base. Les utilisateurs seront créés avec le bon hash à la prochaine migration.');
    } else {
      console.log(`[OK] ${rows.length} utilisateurs mis à jour :`);
      for (const r of rows) {
        console.log(`  - ${r.telephone} (${r.role})`);
      }
    }

    // Aussi mettre à jour onboarding_completed à false pour pouvoir tester l'onboarding
    await pool.query(`
      UPDATE users 
      SET onboarding_completed = FALSE 
      WHERE telephone IN ('+22912345678', '+22923456789', '+22934567890', '+22945678901')
    `);
    console.log('[OK] onboarding_completed réinitialisé pour les users de test');
  } finally {
    await pool.end();
  }

  // 3. Mettre à jour migration.sql
  const migrationPath = join(__dirname, 'migration.sql');
  let migrationSQL = readFileSync(migrationPath, 'utf-8');
  
  // Remplacer l'ancien hash par le nouveau
  const oldHash = '$2a$10$rZG2Ql6G1Y0vGKJXmZCnAeN5R6tL8V9wX2yH4fK6jM8nO0pQ2rS4t';
  migrationSQL = migrationSQL.replaceAll(oldHash, realHash);
  writeFileSync(migrationPath, migrationSQL, 'utf-8');
  console.log('[OK] migration.sql mis à jour');

  // 4. Mettre à jour corrections_migration.sql
  const correctionsPath = join(__dirname, 'corrections_migration.sql');
  let correctionsSQL = readFileSync(correctionsPath, 'utf-8');
  correctionsSQL = correctionsSQL.replaceAll(oldHash, realHash);
  writeFileSync(correctionsPath, correctionsSQL, 'utf-8');
  console.log('[OK] corrections_migration.sql mis à jour');

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
}

main().catch(err => {
  console.error('Erreur:', err.message);
  process.exit(1);
});
