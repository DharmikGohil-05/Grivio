// Phase 4 profile API smoke test — verifies auth protection, validation,
// ownership rules, and setup_completed persistence against the real DB.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5056;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'Profile Test', email, password: 'passw0rd123' }),
  });
  return (await r.json()).token;
}

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`p1_${Date.now()}@example.com`);
  const t2 = await register(`p2_${Date.now()}@example.com`);

  // No token
  let r = await fetch(`${BASE}/profile`);
  check('GET /profile without token → 401', r.status === 401);

  // Get own profile
  r = await fetch(`${BASE}/profile`, { headers: { Authorization: `Bearer ${t1}` } });
  let j = await r.json();
  check('GET /profile returns own profile', r.status === 200 && j.profile.name === 'Profile Test' && j.profile.setup_completed === false);

  // Update
  r = await fetch(`${BASE}/profile`, {
    method: 'PUT', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${t1}` },
    body: JSON.stringify({ name: 'Alex Vance', growthAreas: ['Career', 'Learning'], mainGoal: 'Master Flutter', dailyAvailableTime: '1 hour', setupCompleted: true }),
  });
  j = await r.json();
  check('PUT /profile updates fields', r.status === 200 && j.profile.name === 'Alex Vance' && j.profile.setup_completed === true && j.profile.growth_areas.length === 2);

  // Another user cannot see it
  r = await fetch(`${BASE}/profile`, { headers: { Authorization: `Bearer ${t2}` } });
  j = await r.json();
  check('User 2 sees own (default) profile, not user 1', r.status === 200 && j.profile.name === 'Profile Test');

  // Invalid growth area
  r = await fetch(`${BASE}/profile`, {
    method: 'PUT', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${t1}` },
    body: JSON.stringify({ name: 'Alex', growthAreas: ['Hacking'] }),
  });
  check('Invalid growth area → 400', r.status === 400);

  // Invalid daily time
  r = await fetch(`${BASE}/profile`, {
    method: 'PUT', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${t1}` },
    body: JSON.stringify({ name: 'Alex', dailyAvailableTime: 'whenever' }),
  });
  check('Invalid daily time → 400', r.status === 400);

  // Missing name
  r = await fetch(`${BASE}/profile`, {
    method: 'PUT', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${t1}` },
    body: JSON.stringify({ name: '   ' }),
  });
  check('Empty name → 400', r.status === 400);

  // Persistence check
  r = await fetch(`${BASE}/profile`, { headers: { Authorization: `Bearer ${t1}` } });
  j = await r.json();
  check('setup_completed persisted', j.profile.setup_completed === true);

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();

  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'p1_%' or email like 'p2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); process.exit(1); });
