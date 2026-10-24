// Phase 3 backend smoke test — hits every auth requirement over HTTP.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5055;
const BASE = `http://localhost:${PORT}/api`;
const email = `test_${Date.now()}@example.com`;
let token = '';
let passed = 0, failed = 0;

function check(name, cond) {
  console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`);
  cond ? passed++ : failed++;
}

async function run() {
  const server = app.listen(PORT);

  // 1. Health still works
  let r = await fetch(`${BASE}/health`);
  let j = await r.json();
  check('health endpoint ok', r.status === 200 && j.success && j.database === 'connected');

  // 2. Register valid
  r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'Test User', email, password: 'passw0rd123' }) });
  j = await r.json();
  check('register valid → 201 + token', r.status === 201 && j.token && j.user.email === email);
  token = j.token;

  // 3. Duplicate email
  r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'Dup', email, password: 'passw0rd123' }) });
  j = await r.json();
  check('duplicate email → 409 safe error', r.status === 409 && !JSON.stringify(j).includes('password'));

  // 4. Invalid email
  r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'X', email: 'notanemail', password: 'passw0rd123' }) });
  check('invalid email → 400', r.status === 400);

  // 5. Weak password
  r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'X', email: 'a@b.com', password: 'short' }) });
  check('weak password → 400', r.status === 400);

  // 6. Login correct
  r = await fetch(`${BASE}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: 'passw0rd123' }) });
  j = await r.json();
  check('login correct → 200 + JWT', r.status === 200 && !!j.token);

  // 7. Login wrong password
  r = await fetch(`${BASE}/auth/login`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ email, password: 'wrongpass1' }) });
  j = await r.json();
  check('login wrong → 401 generic', r.status === 401 && j.message === 'Invalid email or password');

  // 8. me without token
  r = await fetch(`${BASE}/auth/me`);
  check('me no token → 401', r.status === 401);

  // 9. me with token
  r = await fetch(`${BASE}/auth/me`, { headers: { Authorization: `Bearer ${token}` } });
  j = await r.json();
  check('me valid token → 200 + user, no hash', r.status === 200 && j.user.email === email && !JSON.stringify(j).includes('password_hash'));

  // 10. me invalid token
  r = await fetch(`${BASE}/auth/me`, { headers: { Authorization: 'Bearer garbage' } });
  check('me invalid token → 401', r.status === 401);

  // 11. expired token
  const jwt = require('jsonwebtoken');
  const expired = jwt.sign({ sub: j.user?.id || 'x' }, process.env.JWT_SECRET, { expiresIn: '-1s' });
  r = await fetch(`${BASE}/auth/me`, { headers: { Authorization: `Bearer ${expired}` } });
  check('me expired token → 401', r.status === 401);

  // 12. hash in DB not plaintext
  const { pool } = require('../src/config/db');
  const db = await pool.query('SELECT password_hash FROM users WHERE email=$1', [email]);
  check('DB stores bcrypt hash, not plaintext', db.rows[0].password_hash.startsWith('$2') && db.rows[0].password_hash !== 'passw0rd123');

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  process.exit(failed ? 1 : 0);
}

run().catch((e) => { console.error(e); process.exit(1); });
