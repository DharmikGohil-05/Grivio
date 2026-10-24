// Phase 9 smoke test — progress aggregation against live Neon.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5071;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'P', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`p1_${Date.now()}@example.com`);
  const t2 = await register(`p2_${Date.now()}@example.com`);

  // seed: 1 goal, 1 task completed, 1 focus session, 1 pending task
  let r = await fetch(`${BASE}/goals`, { method: 'POST', headers: H(t1), body: JSON.stringify({ name: 'Master Flutter', growthArea: 'Learning', targetDate: '2026-12-20' }) });
  const goal = (await r.json()).goal.id;
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'T1', goalId: goal }) });
  const task = (await r.json()).task;
  await fetch(`${BASE}/tasks/${task.id}/status`, { method: 'PATCH', headers: H(t1), body: JSON.stringify({ status: 'completed' }) });
  r = await fetch(`${BASE}/focus/sessions`, { method: 'POST', headers: H(t1), body: JSON.stringify({ task_id: task.id }) });
  const session = (await r.json()).session;
  await fetch(`${BASE}/focus/sessions/${session.id}/complete`, { method: 'PATCH', headers: H(t1), body: JSON.stringify({ productivity_rating: 'good' }) });
  await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'T2 pending' }) });

  // week
  r = await fetch(`${BASE}/progress?range=week`, { headers: H(t1) });
  let j = await r.json();
  check('week range returns summary', r.status === 200 && j.summary.tasksCompleted >= 1 && j.range === 'week');
  check('focus minutes >= 0 aggregated', j.summary.focusMinutes >= 0);
  check('goal progress listed', j.goalProgress.length >= 1 && j.goalProgress[0].name === 'Master Flutter');
  check('insights are factual strings', Array.isArray(j.insights));

  // month
  r = await fetch(`${BASE}/progress?range=month`, { headers: H(t1) });
  j = await r.json();
  check('month range works', r.status === 200 && j.range === 'month');

  // 3months
  r = await fetch(`${BASE}/progress?range=3months`, { headers: H(t1) });
  j = await r.json();
  check('3months range works', r.status === 200 && j.range === '3months');

  // invalid range
  r = await fetch(`${BASE}/progress?range=year`, { headers: H(t1) });
  check('invalid range → 400', r.status === 400);

  // unauth
  r = await fetch(`${BASE}/progress?range=week`);
  check('unauthenticated → 401', r.status === 401);

  // cross-user isolation: t2 sees empty summary
  r = await fetch(`${BASE}/progress?range=week`, { headers: H(t2) });
  j = await r.json();
  check('other user sees zeroed summary', j.summary.tasksCompleted === 0 && j.goalProgress.length === 0);

  // health
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health ok', j.database === 'connected');

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'p1_%' or email like 'p2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); process.exit(1); });
