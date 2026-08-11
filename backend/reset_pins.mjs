import { Pool } from '@neondatabase/serverless';
import bcrypt from 'bcryptjs';

const pool = new Pool({
  connectionString: 'postgresql://neondb_owner:npg_69BaskTIOrfR@ep-shy-glade-aykmz324-pooler.c-5.us-east-2.aws.neon.tech/neondb',
});

const pin = '1234';
const hash = await bcrypt.hash(pin, 10);

// Réinitialiser tous les utilisateurs à PIN 1234
const users = [
  { tel: '+22912345678', role: 'super_admin' },
  { tel: '+22923456789', role: 'gestionnaire' },
  { tel: '+22934567890', role: 'chauffeur' },
  { tel: '+22945678901', role: 'chauffeur' },
];

for (const u of users) {
  await pool.query(
    "UPDATE users SET pin_hash = $1, must_change_pin = FALSE, onboarding_completed = TRUE WHERE telephone = $2",
    [hash, u.tel]
  );
  console.log(`OK: ${u.tel} (${u.role}) → PIN ${pin}`);
}

// Vérifier le login
const { rows } = await pool.query("SELECT telephone, pin_hash FROM users WHERE telephone = '+22934567890'");
const valid = await bcrypt.compare(pin, rows[0].pin_hash);
console.log(`\nVérification bcrypt: ${valid ? 'OK' : 'ÉCHOUÉ'}`);

await pool.end();
