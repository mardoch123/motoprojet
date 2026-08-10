import { readFileSync, readdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { Pool } from '@neondatabase/serverless';
import { config } from '../config/env.js';

const __dirname = dirname(fileURLToPath(import.meta.url));

/**
 * Runner de migrations versionnées pour Neon PostgreSQL.
 *
 * Utilise le Pool (WebSocket) au lieu du driver HTTP neon() car
 * ce dernier tronque les gros scripts SQL (> ~500 lignes).
 *
 * Fonctionnement :
 * 1. Lit les fichiers legacy (migration.sql, migration_security.sql)
 * 2. Lit les fichiers versionnés dans migrations/ (triés par nom)
 * 3. Vérifie lesquels ont déjà été exécutés (table _migrations)
 * 4. Exécute les nouveaux dans l'ordre
 * 5. Enregistre chaque migration dans _migrations
 */

interface MigrationRecord {
  name: string;
  executed_at: string;
  checksum: string;
}

async function ensureMigrationsTable(pool: Pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS _migrations (
      id SERIAL PRIMARY KEY,
      name VARCHAR(255) UNIQUE NOT NULL,
      checksum VARCHAR(64) NOT NULL,
      executed_at TIMESTAMPTZ DEFAULT NOW()
    )
  `);
}

async function getExecutedMigrations(pool: Pool): Promise<MigrationRecord[]> {
  const res = await pool.query('SELECT name, checksum, executed_at FROM _migrations ORDER BY name');
  return res.rows as unknown as MigrationRecord[];
}

/**
 * Calcule un hash simple du contenu SQL pour détecter les modifications.
 */
function computeChecksum(content: string): string {
  let hash = 0;
  for (let i = 0; i < content.length; i++) {
    const char = content.charCodeAt(i);
    hash = ((hash << 5) - hash) + char;
    hash |= 0;
  }
  return Math.abs(hash).toString(16).padStart(8, '0');
}

/**
 * Récupère les fichiers SQL à exécuter, dans l'ordre.
 *
 * Ordre garanti :
 *  1. Fichiers legacy (migration.sql → migration_security.sql) — fondations
 *  2. Fichiers versionnés dans migrations/ (001_xxx, 002_xxx, …) — incrémentaux
 *
 * Chaque fichier est enregistré dans _migrations, donc il n'est exécuté qu'une
 * seule fois même si le runner est relancé.
 */
function getMigrationFiles(): string[] {
  const result: string[] = [];

  // 1. Legacy : fichiers de fondation (toujours en premier)
  const legacyFiles = ['migration.sql', 'migration_security.sql'];
  for (const file of legacyFiles) {
    const path = join(__dirname, file);
    if (existsSync(path)) {
      result.push(path);
    }
  }

  // 2. Versionnés : dossier migrations/ (triés par nom de fichier)
  const migrationsDir = join(__dirname, 'migrations');
  if (existsSync(migrationsDir)) {
    const files = readdirSync(migrationsDir)
      .filter(f => f.endsWith('.sql'))
      .sort();
    for (const f of files) {
      result.push(join(migrationsDir, f));
    }
  }

  return result;
}

async function migrate() {
  const pool = new Pool({ connectionString: config.db.url });

  try {
    console.log('[Migrate] Démarrage des migrations...');

    // 1. Créer la table de suivi
    await ensureMigrationsTable(pool);
    console.log('[Migrate] Table _migrations vérifiée');

    // 2. Récupérer les migrations déjà exécutées
    const executed = await getExecutedMigrations(pool);
    const executedNames = new Set(executed.map(m => m.name));
    console.log(`[Migrate] ${executed.length} migration(s) déjà exécutée(s)`);

    // 2b. Auto-marquer les fichiers legacy si leurs tables existent déjà
    //     (cas où init.ts a déjà été exécuté avant migrate.ts)
    const legacyAutoMark: Record<string, string> = {
      'migration': 'users',             // table créée par migration.sql
      'migration_security': 'security_events', // table créée par migration_security.sql
    };
    for (const [name, table] of Object.entries(legacyAutoMark)) {
      if (!executedNames.has(name)) {
        const exists = await pool.query(
          `SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = $1`,
          [table]
        );
        if (exists.rows.length > 0) {
          await pool.query(
            `INSERT INTO _migrations (name, checksum) VALUES ($1, $2) ON CONFLICT (name) DO NOTHING`,
            [name, 'auto-marked']
          );
          executedNames.add(name);
          console.log(`[Migrate] ✓ ${name} (auto-marquée — table "${table}" existe déjà)`);
        }
      }
    }

    // 3. Lister les fichiers de migration
    const files = getMigrationFiles();
    if (files.length === 0) {
      console.log('[Migrate] Aucun fichier de migration trouvé');
      return;
    }

    console.log(`[Migrate] ${files.length} fichier(s) détecté(s)`);

    // 4. Exécuter les nouvelles migrations
    let count = 0;
    for (const filePath of files) {
      const name = filePath.split(/[/\\]/).pop()!.replace('.sql', '');

      if (executedNames.has(name)) {
        console.log(`[Migrate] ✓ ${name} (déjà exécutée)`);
        continue;
      }

      const content = readFileSync(filePath, 'utf-8');
      const checksum = computeChecksum(content);

      console.log(`[Migrate] ▶ Exécution de ${name}...`);

      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        await client.query(content);
        await client.query(`
          INSERT INTO _migrations (name, checksum)
          VALUES ($1, $2)
          ON CONFLICT (name) DO NOTHING
        `, [name, checksum]);
        await client.query('COMMIT');

        console.log(`[Migrate] ✓ ${name} — succès`);
        count++;
      } catch (err: any) {
        await client.query('ROLLBACK');
        console.error(`[Migrate] ✗ ${name} — échec :`, err.message);
        process.exit(1);
      } finally {
        client.release();
      }
    }

    // 5. Résumé
    const tables = await pool.query(
      `SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename`);
    console.log(`\n[Migrate] Terminé — ${count} nouvelle(s) migration(s)`);
    console.log(`[Migrate] ${tables.rows.length} tables en base`);
  } finally {
    await pool.end();
  }
}

migrate().catch(err => {
  console.error('[Migrate] Erreur fatale :', err);
  process.exit(1);
});
