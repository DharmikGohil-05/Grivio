require('dotenv').config();
const { pool } = require('../src/config/db');
pool
  .query("select table_name from information_schema.tables where table_schema='public' order by 1")
  .then((r) => {
    console.log(r.rows.map((x) => x.table_name).join(', '));
    return pool.end();
  })
  .catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
