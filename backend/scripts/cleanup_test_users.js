require('dotenv').config();
const { pool } = require('../src/config/db');
pool
  .query("delete from users where email like 'test_%@example.com'")
  .then((r) => {
    console.log('deleted', r.rowCount);
    return pool.end();
  })
  .catch((e) => { console.error(e.message); process.exit(1); });
