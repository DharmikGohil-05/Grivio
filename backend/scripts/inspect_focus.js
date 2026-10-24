require('dotenv').config();
const { pool } = require('../src/config/db');
Promise.all([
  pool.query("select column_name,data_type from information_schema.columns where table_name='focus_sessions' order by ordinal_position"),
  pool.query("select conname from pg_constraint where conrelid='focus_sessions'::regclass"),
])
  .then(([a, b]) => {
    console.log('COLUMNS:', a.rows.map((r) => `${r.column_name}:${r.data_type}`).join(', '));
    console.log('CONSTRAINTS:', b.rows.map((r) => r.conname).join(', '));
    return pool.end();
  })
  .catch((e) => { console.error(e.message); process.exit(1); });
