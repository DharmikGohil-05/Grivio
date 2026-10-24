require('dotenv').config();
const { pool } = require('../src/config/db');
async function describe(table) {
  const r = await pool.query(
    'select column_name,data_type from information_schema.columns where table_name=$1 order by ordinal_position',
    [table]
  );
  console.log(table.toUpperCase() + ':', r.rows.map((x) => `${x.column_name}:${x.data_type}`).join(', '));
}
(async () => {
  await describe('weekly_reviews');
  await describe('reflections');
  const c = await pool.query("select conname from pg_constraint where conrelid='weekly_reviews'::regclass");
  console.log('WR CONSTRAINTS:', c.rows.map((r) => r.conname).join(', '));
  await pool.end();
})().catch((e) => { console.error(e.message); process.exit(1); });
