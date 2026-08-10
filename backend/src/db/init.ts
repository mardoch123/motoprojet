import { readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Pool } from '@neondatabase/serverless';
import { config } from '../config/env.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * Initialise la base de données en exécutant migration.sql via le Pool (WebSocket).
 * Le driver HTTP neon() tronque les gros scripts SQL — on utilise donc le Pool.
 */
async function init() {
  console.log('[DB] Initialisation de la base de données...');

  const pool = new Pool({ connectionString: config.db.url });
  const migrationPath = join(__dirname, 'migration.sql');
  const migrationSQL = readFileSync(migrationPath, 'utf-8');

  try {
    const client = await pool.connect();
    try {
      await client.query('BEGIN');
      await client.query(migrationSQL);
      await client.query('COMMIT');
    } catch (err) {
      await client.query('ROLLBACK');
      throw err;
    } finally {
      client.release();
    }

    console.log('[DB] Migration exécutée avec succès');

    // Vérification
    const tables = await pool.query(
      `SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename`);
    console.log(`[DB] ${tables.rows.length} tables créées :`, tables.rows.map((t: any) => t.tablename).join(', '));

    const views = await pool.query(
      `SELECT viewname FROM pg_views WHERE schemaname = 'public' ORDER BY viewname`);
    console.log(`[DB] ${views.rows.length} vues créées :`, views.rows.map((v: any) => v.viewname).join(', '));

    // Test des vues
    const recouvrement = await pool.query('SELECT * FROM vue_taux_recouvrement_global');
    console.log('[DB] Taux recouvrement :', recouvrement.rows[0]);

    const cash = await pool.query('SELECT * FROM vue_cash_cumule_disponible');
    console.log('[DB] Cash cumulé :', cash.rows[0]);

    console.log('[DB] Initialisation terminée !');
  } catch (err: any) {
    console.error('[DB] Erreur migration :', err.message);
    process.exit(1);
  } finally {
    await pool.end();
  }
}

init();
