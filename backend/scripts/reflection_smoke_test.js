// Phase 10 reflection smoke test — daily reflection upsert on live Neon.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5073;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'R', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });
const today = new Date().toISOString().substring(0, 10);

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`r1_${Date.now()}@example.com`);
  const t2 = await register(`r2_${Date.now()}@example.com`);

  // no reflection yet
  let r = await fetch(`${BASE}/reflections?date=${today}`, { headers: H(t1) });
  let j = await r.json();
  check('no reflection → null', r.status === 200 && j.reflection === null);

  // create
  r = await fetch(`${BASE}/reflections`, { method: 'POST', headers: H(t1), body: JSON.stringify({ date: today, wentWell: 'Shipped feature', wasDifficult: 'Context switching', toImprove: 'Fewer meetings' }) });
  check('create reflection', r.status === 200);

  // read back
  r = await fetch(`${BASE}/reflections?date=${today}`, { headers: H(t1) });
  j = await r.json();
  check('read reflection back', j.reflection.went_well === 'Shipped feature');

  // upsert updates instead of duplicating
  r = await fetch(`${BASE}/reflections`, { method: 'POST', headers: H(t1), body: JSON.stringify({ date: today, wentWell: 'Shipped feature v2' }) });
  r = await fetch(`${BASE}/reflections?date=${today}`, { headers: H(t1) });
  j = await r.json();
  check('upsert updates', j.reflection.went_well === 'Shipped feature v2');

  // unauth
  r = await fetch(`${BASE}/reflections?date=${today}`);
  check('unauth → 401', r.status === 401);

  // cross-user cannot see
  r = await fetch(`${BASE}/reflections?date=${today}`, { headers: H(t2) });
  j = await r.json();
  check('other user sees null', j.reflection === null);

  // invalid date
  r = await fetch(`${BASE}/reflections?date=not-a-date`, { headers: H(t1) });
  check('invalid date → 400', r.status === 400);

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'r1_%' or email like 'r2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); process.exit(1); });
