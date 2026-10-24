require('dotenv').config();
const { pool } = require('../src/config/db');
Promise.all([
  pool.query("select column_name,data_type from information_schema.columns where table_name='goals' order by ordinal_position"),
  pool.query("select column_name,data_type from information_schema.columns where table_name='milestones' order by ordinal_position"),
])
  .then(([a, b]) => {
    console.log('GOALS:', a.rows.map((r) => `${r.column_name}:${r.data_type}`).join(', '));
    console.log('MILESTONES:', b.rows.map((r) => `${r.column_name}:${r.data_type}`).join(', '));
    return pool.end();
  })
  .catch((e) => { console.error(e.message); process.exit(1); });
