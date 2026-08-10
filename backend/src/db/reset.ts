import { Pool } from '@neondatabase/serverless';
import { config } from '../config/env.js';

const pool = new Pool({ connectionString: config.db.url });

async function reset() {
  console.log('[Reset] Nettoyage de la base de données...');

  // Supprimer toutes les vues
  const views = await pool.query(
    "SELECT viewname FROM pg_views WHERE schemaname = 'public'"
  );
  if (views.rows.length > 0) {
    const dropViews = views.rows.map((r: any) => `"${r.viewname}"`).join(', ');
    await pool.query(`DROP VIEW IF EXISTS ${dropViews} CASCADE`);
    console.log(`[Reset] ${views.rows.length} vue(s) supprimée(s)`);
  }

  // Supprimer toutes les tables
  const tables = await pool.query(
    "SELECT tablename FROM pg_tables WHERE schemaname = 'public'"
  );
  if (tables.rows.length > 0) {
    const dropTables = tables.rows.map((r: any) => `"${r.tablename}"`).join(', ');
    await pool.query(`DROP TABLE IF EXISTS ${dropTables} CASCADE`);
    console.log(`[Reset] ${tables.rows.length} table(s) supprimée(s)`);
  }

  console.log('[Reset] Base nettoyée — prête pour initialisation');
  await pool.end();
}

reset();
