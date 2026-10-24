// Phase 8 smoke test — focus sessions lifecycle against live Neon DB.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5059;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'F', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`f1_${Date.now()}@example.com`);
  const t2 = await register(`f2_${Date.now()}@example.com`);

  let r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Learn Riverpod' }) });
  const task = (await r.json()).task;

  // 1. start with task
  r = await fetch(`${BASE}/focus/sessions`, { method: 'POST', headers: H(t1), body: JSON.stringify({ task_id: task.id }) });
  let j = await r.json();
  check('start session with task → 201, active', r.status === 201 && j.session.status === 'active');
  const s1 = j.session.id;

  // 2. start without auth → 401
  r = await fetch(`${BASE}/focus/sessions`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{}' });
  check('start without auth → 401', r.status === 401);

  // 3. start with other user's task → 400
  r = await fetch(`${BASE}/focus/sessions`, { method: 'POST', headers: H(t2), body: JSON.stringify({ task_id: task.id }) });
  check('task ownership enforced → 400', r.status === 400);

  // 4. pause + resume
  r = await fetch(`${BASE}/focus/sessions/${s1}/pause`, { method: 'PATCH', headers: H(t1) });
  check('pause session', r.status === 200 && (await r.json()).session.paused_at !== null);
  r = await fetch(`${BASE}/focus/sessions/${s1}/resume`, { method: 'PATCH', headers: H(t1) });
  j = await r.json();
  check('resume clears paused_at, accrues pause', r.status === 200 && j.session.paused_at === null && j.session.total_pause_seconds >= 0);

  // 5. other user cannot complete
  r = await fetch(`${BASE}/focus/sessions/${s1}/complete`, { method: 'PATCH', headers: H(t2), body: '{}' });
  check('other user cannot complete → 404', r.status === 404);

  // 6. complete
  r = await fetch(`${BASE}/focus/sessions/${s1}/complete`, { method: 'PATCH', headers: H(t1), body: JSON.stringify({ productivity_rating: 'good', reflection: 'Did a lot' }) });
  j = await r.json();
  check('complete session', r.status === 200 && j.session.status === 'completed' && j.session.duration_seconds !== null && j.session.productivity_rating === 'good');

  // 7. duplicate completion → 409
  r = await fetch(`${BASE}/focus/sessions/${s1}/complete`, { method: 'PATCH', headers: H(t1), body: '{}' });
  check('duplicate completion → 409', r.status === 409);

  // 8. cancel flow
  r = await fetch(`${BASE}/focus/sessions`, { method: 'POST', headers: H(t1), body: '{}' });
  const s2 = (await r.json()).session.id;
  r = await fetch(`${BASE}/focus/sessions/${s2}/cancel`, { method: 'PATCH', headers: H(t1) });
  j = await r.json();
  check('cancel session', r.status === 200 && j.session.status === 'cancelled');

  // 9. list own sessions
  r = await fetch(`${BASE}/focus/sessions`, { headers: H(t1) });
  j = await r.json();
  check('list sessions → 2', j.sessions.length === 2);

  // 10. get one own session
  r = await fetch(`${BASE}/focus/sessions/${s1}`, { headers: H(t1) });
  check('get own session', r.status === 200);

  // 11. other user cannot get
  r = await fetch(`${BASE}/focus/sessions/${s1}`, { headers: H(t2) });
  check('other user cannot read session → 404', r.status === 404);

  // 12. health
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health database connected', j.database === 'connected');

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'f1_%' or email like 'f2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); process.exit(1); });
