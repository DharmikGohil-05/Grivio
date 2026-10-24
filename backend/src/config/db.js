// Database connection module.
// Reads DATABASE_URL from the environment and exposes a reusable
// connection pool plus small helpers the rest of the backend uses.
const { Pool } = require('pg');
const config = require('./env');

// A single pool is shared across the app. Render/Postgres work best with
// pooled connections instead of opening a new client per request.
const pool = new Pool({
  connectionString: config.databaseUrl || undefined,
  // Render managed Postgres requires SSL; local dev does not.
  ssl: config.databaseUrl && config.databaseUrl.includes('render.com')
    ? { rejectUnauthorized: false }
    : undefined,
});

// Run a single SQL query against the pool (parameterized: $1, $2, ...).
async function query(text, params) {
  return pool.query(text, params);
}

// Throws if the database is unreachable. Used by the health endpoint
// and during server startup checks.
async function checkConnection() {
  await pool.query('SELECT 1');
  return true;
}

module.exports = { pool, query, checkConnection };
