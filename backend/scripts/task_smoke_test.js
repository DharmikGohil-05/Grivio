// Phase 6 smoke test — tasks + subtasks + ownership + linking rules.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5058;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'T', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`t1_${Date.now()}@example.com`);
  const t2 = await register(`t2_${Date.now()}@example.com`);

  // setup goal + milestone for t1
  let r = await fetch(`${BASE}/goals`, { method: 'POST', headers: H(t1), body: JSON.stringify({ name: 'G1' }) });
  const g1 = (await r.json()).goal.id;
  r = await fetch(`${BASE}/goals/${g1}/milestones`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'M1' }) });
  const m1 = (await r.json()).milestone.id;

  // 1. create task linked to goal + milestone
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Learn Riverpod basics', description: 'providers', goalId: g1, milestoneId: m1, dueDate: '2026-10-15', priority: 'high', estimatedMinutes: 60, category: 'Learning' }) });
  let j = await r.json();
  check('create task with goal+milestone → 201', r.status === 201 && j.task.status === 'pending');
  const taskId = j.task.id;

  // 2. create task without auth → 401
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ title: 'x' }) });
  check('create task without auth → 401', r.status === 401);

  // 3. create task linked to someone else's goal → 400
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t2), body: JSON.stringify({ title: 'x', goalId: g1 }) });
  check('task with other user goal → 400', r.status === 400);

  // 4. list tasks (with filter by status + milestone)
  r = await fetch(`${BASE}/tasks?status=pending&milestoneId=${m1}`, { headers: H(t1) });
  j = await r.json();
  check('list filter pending+milestone → 1 task', r.status === 200 && j.tasks.length === 1);

  // 5. other user gets empty list
  r = await fetch(`${BASE}/tasks`, { headers: H(t2) });
  j = await r.json();
  check('other user list empty', j.tasks.length === 0);

  // 6. other user cannot read task
  r = await fetch(`${BASE}/tasks/${taskId}`, { headers: H(t2) });
  check('other user cannot read task → 404', r.status === 404);

  // 7. subtasks CRUD
  r = await fetch(`${BASE}/tasks/${taskId}/subtasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Understand providers' }) });
  const s1 = (await r.json()).subtask;
  check('create subtask', r.status === 201);
  r = await fetch(`${BASE}/tasks/${taskId}/subtasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Learn StateProvider' }) });
  const s2 = (await r.json()).subtask;
  check('create second subtask', r.status === 201);

  r = await fetch(`${BASE}/subtasks/${s1.id}`, { method: 'PUT', headers: H(t1), body: JSON.stringify({ isCompleted: true }) });
  check('complete subtask', r.status === 200);

  // 8. other user cannot touch subtask
  r = await fetch(`${BASE}/subtasks/${s1.id}`, { method: 'PUT', headers: H(t2), body: JSON.stringify({ isCompleted: false }) });
  check('other user cannot update subtask → 404', r.status === 404);

  // 9. update task status to completed
  r = await fetch(`${BASE}/tasks/${taskId}/status`, { method: 'PATCH', headers: H(t1), body: JSON.stringify({ status: 'completed' }) });
  j = await r.json();
  check('task status completed + completed_at', r.status === 200 && j.task.completed_at !== null);

  // 10. invalid priority rejected
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'x', priority: 'urgent' }) });
  check('invalid priority → 400', r.status === 400);

  // 11. other user cannot update task
  r = await fetch(`${BASE}/tasks/${taskId}`, { method: 'PUT', headers: H(t2), body: JSON.stringify({ title: 'hacked' }) });
  check('other user cannot update task → 404', r.status === 404);

  // 12. delete task
  r = await fetch(`${BASE}/tasks/${taskId}`, { method: 'DELETE', headers: H(t1) });
  check('delete task', r.status === 200);

  // 13. health
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health ok', r.status === 200 && j.database === 'connected');

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 't1_%' or email like 't2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); process.exit(1); });
