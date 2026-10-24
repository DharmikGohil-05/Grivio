// Database connection module.
// Reads DATABASE_URL from the environment and exposes a reusable
// connection pool plus small helpers the rest of the backend uses.
const { Pool } = require('pg');
const config = require('./env');

// A single pool is shared across the app. Render/Postgres work best with
// pooled connections instead of opening a new client per request.
// The pool is also lazy: constructing it does NOT contact the database,
// so a down DB only fails when a query runs (or checkConnection is used),
// never when this module is imported.
const pool = new Pool({
  // `undefined` (not an empty string) lets the pg driver fall back to its
  // own defaults when DATABASE_URL is unset; an empty string is invalid.
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
