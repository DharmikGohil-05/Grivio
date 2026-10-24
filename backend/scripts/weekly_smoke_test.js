// Phase 10 smoke test — weekly reviews + real weekly stats on live Neon.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5072;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'W', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });

function mondayOf(d) {
  const x = new Date(d);
  const day = (x.getUTCDay() + 6) % 7; // Mon=0
  x.setUTCDate(x.getUTCDate() - day);
  return x.toISOString().substring(0, 10);
}

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`w1_${Date.now()}@example.com`);
  const t2 = await register(`w2_${Date.now()}@example.com`);
  const monday = mondayOf(new Date());

  // create a completed task + focus session so stats are non-zero
  let r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'T' }) });
  const task = (await r.json()).task;
  await fetch(`${BASE}/tasks/${task.id}/status`, { method: 'PATCH', headers: H(t1), body: JSON.stringify({ status: 'completed' }) });
  r = await fetch(`${BASE}/focus/sessions`, { method: 'POST', headers: H(t1), body: '{}' });
  const s = (await r.json()).session;
  await fetch(`${BASE}/focus/sessions/${s.id}/complete`, { method: 'PATCH', headers: H(t1), body: '{}' });

  // 1. get week (no review yet) — should return stats + null review
  r = await fetch(`${BASE}/weekly-reviews/week/${monday}`, { headers: H(t1) });
  let j = await r.json();
  check('week returns stats + null review', r.status === 200 && j.review === null && j.stats.tasksCompleted >= 1);

  // 2. create review
  r = await fetch(`${BASE}/weekly-reviews`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: monday, biggestWin: 'Shipped landing page', needsAttention: 'Too much context switching', nextWeekFocus: 'Deep work mornings', summary: 'Solid week overall' }) });
  check('create review → 200', r.status === 200);

  // 3. same week upsert updates instead of duplicating
  r = await fetch(`${BASE}/weekly-reviews`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: monday, biggestWin: 'Shipped landing page v2' }) });
  j = await r.json();
  check('same week upsert updates', r.status === 200 && j.review.biggest_win === 'Shipped landing page v2');

  // 4. list
  r = await fetch(`${BASE}/weekly-reviews`, { headers: H(t1) });
  j = await r.json();
  check('list returns 1 review (no dup)', j.reviews.length === 1);

  // 5. invalid weekStart (not Monday)
  const notMonday = mondayOf(new Date(Date.now() - 86400000)); // tomorrow-ish
  r = await fetch(`${BASE}/weekly-reviews/week/${monday}`, { headers: H(t1) });
  check('week fetch ok', r.status === 200);
  r = await fetch(`${BASE}/weekly-reviews`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: '2026-10-07' }) });
  check('non-Monday weekStart → 400', r.status === 400);

  // 6. unauth
  r = await fetch(`${BASE}/weekly-reviews`);
  check('unauth → 401', r.status === 401);

  // 7. cross-user cannot see t1 reviews
  r = await fetch(`${BASE}/weekly-reviews`, { headers: H(t2) });
  j = await r.json();
  check('other user sees empty list', j.reviews.length === 0);
  r = await fetch(`${BASE}/weekly-reviews/week/${monday}`, { headers: H(t2) });
  j = await r.json();
  check('other user week stats are zeroed', j.stats.tasksCompleted === 0 && j.review === null);

  // 8. health
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health ok', j.database === 'connected');

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'w1_%' or email like 'w2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); process.exit(1); });
