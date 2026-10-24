// Migration runner.
// Applies every .sql file in /migrations in filename order and records
// applied migrations in a schema_migrations table so each runs once.
require('dotenv').config();
const fs = require('fs');
const path = require('path');
const { pool } = require('../src/config/db');

async function migrate() {
  // Track which migrations already ran.
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
  `);

  const dir = path.join(__dirname, '..', 'migrations');
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();

  for (const file of files) {
    const { rowCount } = await pool.query(
      'SELECT 1 FROM schema_migrations WHERE name = $1',
      [file]
    );
    if (rowCount > 0) {
      console.log(`Skipping ${file} (already applied)`);
      continue;
    }
    const sql = fs.readFileSync(path.join(dir, file), 'utf8');
    console.log(`Applying ${file}...`);
    await pool.query(sql);
    await pool.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
  }

  console.log('Migrations complete.');
  await pool.end();
}

migrate().catch((err) => {
  console.error('Migration failed:', err.message);
  process.exit(1);
});
