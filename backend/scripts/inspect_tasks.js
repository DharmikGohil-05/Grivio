require('dotenv').config();
const { pool } = require('../src/config/db');
Promise.all([
  pool.query("select column_name from information_schema.columns where table_name='tasks' order by ordinal_position"),
  pool.query("select column_name from information_schema.columns where table_name='subtasks' order by ordinal_position"),
  pool.query("select conname from pg_constraint where conrelid='tasks'::regclass and contype='c'"),
])
  .then(([a, b, c]) => {
    console.log('TASKS:', a.rows.map((r) => r.column_name).join(','));
    console.log('SUBTASKS:', b.rows.map((r) => r.column_name).join(','));
    console.log('CHECKS:', c.rows.map((r) => r.conname).join(','));
    return pool.end();
  })
  .catch((e) => { console.error(e.message); process.exit(1); });
