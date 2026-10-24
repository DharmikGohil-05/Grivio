require('dotenv').config();
const { pool } = require('../src/config/db');
pool
  .query("select column_name from information_schema.columns where table_name='profiles' order by ordinal_position")
  .then((r) => { console.log(r.rows.map((x) => x.column_name).join(', ')); return pool.end(); })
  .catch((e) => { console.error(e.message); process.exit(1); });
