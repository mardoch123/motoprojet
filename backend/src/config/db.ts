import { neon, Pool } from '@neondatabase/serverless';
import { config } from './env.js';

/**
 * Pool Neon serverless avec gestion du cold start.
 * Le pool serverless de Neon maintient les connexions chaudes
 * et les recycle automatiquement après inactivité.
 */
const pool = new Pool({
  connectionString: config.db.url,
  max: 10,                    // connexions max dans le pool
  idleTimeoutMillis: 30_000,  // recycle après 30s d'inactivité
  connectionTimeoutMillis: 10_000, // timeout de connexion : 10s
});

// Requêtes simples via l'API HTTP Neon (sans pool)
export const sql = neon(config.db.url);

// Pool pour les transactions et requêtes complexes
export default pool;

// Warm-up : garde le pool prêt dès le démarrage
pool.on('error', (err: Error) => {
  console.error('[DB] Erreur pool Neon :', err.message);
});

// Test de connexion au démarrage
export async function testConnection(): Promise<void> {
  try {
    const client = await pool.connect();
    await client.query('SELECT 1');
    client.release();
    console.log('[DB] Connexion Neon OK');
  } catch (err: any) {
    console.error('[DB] Échec connexion Neon :', err.message);
  }
}
