// Phase 5 smoke test — goals + milestones + progress behavior.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5057;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email, name = 'Goal Tester') {
  const r = await fetch(`${BASE}/auth/register`, {
    method: 'POST', headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, email, password: 'passw0rd123' }),
  });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`g1_${Date.now()}@example.com`);
  const t2 = await register(`g2_${Date.now()}@example.com`);

  // 1. create goal (auth)
  let r = await fetch(`${BASE}/goals`, { method: 'POST', headers: H(t1), body: JSON.stringify({ name: 'Become a Flutter Developer', growthArea: 'Learning', targetDate: '2026-12-20', whyItMatters: 'Job readiness' }) });
  let j = await r.json();
  check('create goal → 201', r.status === 201 && j.goal.status === 'active');
  const goalId = j.goal.id;

  // 2. create goal without auth
  r = await fetch(`${BASE}/goals`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'X' }) });
  check('create goal without auth → 401', r.status === 401);

  // 3. list own goals
  r = await fetch(`${BASE}/goals`, { headers: H(t1) });
  j = await r.json();
  check('list own goals → 1 goal', r.status === 200 && j.goals.length === 1);

  // 4. other user cannot fetch goal
  r = await fetch(`${BASE}/goals/${goalId}`, { headers: H(t2) });
  check("other user cannot read goal → 404", r.status === 404);

  // 5. update own goal
  r = await fetch(`${BASE}/goals/${goalId}`, { method: 'PUT', headers: H(t1), body: JSON.stringify({ whyItMatters: 'Career growth' }) });
  j = await r.json();
  check('update own goal works', r.status === 200 && j.goal.why_it_matters === 'Career growth');

  // 6. other user cannot update
  r = await fetch(`${BASE}/goals/${goalId}`, { method: 'PUT', headers: H(t2), body: JSON.stringify({ name: 'Hacked' }) });
  check('other user cannot update goal → 404', r.status === 404);

  // 7. create milestones
  for (const title of ['Learn Dart', 'Master Flutter UI', 'Learn State Management', 'Build Real Projects']) {
    r = await fetch(`${BASE}/goals/${goalId}/milestones`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title }) });
    check(`milestone '${title}' created`, r.status === 201);
  }

  // 8. other user cannot add milestone to our goal
  r = await fetch(`${BASE}/goals/${goalId}/milestones`, { method: 'POST', headers: H(t2), body: JSON.stringify({ title: 'Intruder' }) });
  check('other user cannot create milestone → 404', r.status === 404);

  // 9. list milestones
  r = await fetch(`${BASE}/goals/${goalId}/milestones`, { headers: H(t1) });
  j = await r.json();
  const milestones = j.milestones;
  check('4 milestones listed in order', milestones.length === 4 && milestones[0].position === 0);

  // 10. update milestone status → progress 25%
  r = await fetch(`${BASE}/milestones/${milestones[0].id}`, { method: 'PUT', headers: H(t1), body: JSON.stringify({ status: 'completed' }) });
  check('milestone status → completed', r.status === 200);
  r = await fetch(`${BASE}/goals/${goalId}`, { headers: H(t1) });
  j = await r.json();
  check('goal progress 25%', j.goal.progress === 25);

  // complete all → 100%
  for (let i = 1; i < 4; i++) {
    await fetch(`${BASE}/milestones/${milestones[i].id}`, { method: 'PUT', headers: H(t1), body: JSON.stringify({ status: 'completed' }) });
  }
  r = await fetch(`${BASE}/goals/${goalId}`, { headers: H(t1) });
  j = await r.json();
  check('all milestones → 100% progress', j.goal.progress === 100);

  // 11. invalid milestone status
  r = await fetch(`${BASE}/milestones/${milestones[0].id}`, { method: 'PUT', headers: H(t1), body: JSON.stringify({ status: 'banana' }) });
  check('invalid milestone status → 400', r.status === 400);

  // 12. delete a milestone → progress drops
  r = await fetch(`${BASE}/milestones/${milestones[3].id}`, { method: 'DELETE', headers: H(t1) });
  check('delete milestone', r.status === 200);
  r = await fetch(`${BASE}/goals/${goalId}`, { headers: H(t1) });
  j = await r.json();
  check('progress recalculated to 100% of 3 (3/3)', j.goal.progress === 100);

  // 13. invalid goal data
  r = await fetch(`${BASE}/goals`, { method: 'POST', headers: H(t1), body: JSON.stringify({ name: '  ' }) });
  check('empty goal name → 400', r.status === 400);

  // 14. health still ok
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health still works', r.status === 200 && j.database === 'connected');

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();

  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'g1_%' or email like 'g2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); process.exit(1); });
