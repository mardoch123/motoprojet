import { Pool } from '@neondatabase/serverless';

const pool = new Pool({
  connectionString: 'postgresql://neondb_owner:npg_69BaskTIOrfR@ep-shy-glade-aykmz324-pooler.c-5.us-east-2.aws.neon.tech/neondb',
});

try {
  const { rows } = await pool.query(
    'SELECT id, telephone, role, statut, must_change_pin, onboarding_completed FROM users'
  );
  console.log(JSON.stringify(rows, null, 2));
  console.log(`\nTotal: ${rows.length} users`);
} catch (e) {
  console.error(e.message);
} finally {
  await pool.end();
}
