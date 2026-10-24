// Phase 13 smoke test — AI task improvement + goal breakdown (mocked Groq,
// live Neon). Verifies auth, ownership, input bounds, output normalization,
// error mapping, preview-only generation, and that only confirmed items
// are persisted through the existing APIs.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5076;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'AI', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });
const realFetch = global.fetch;

function setMock(handler) {
  global.fetch = async (u, opts) => (typeof u === 'string' && u.includes('api.groq.com')) ? handler(u, opts) : realFetch(u, opts);
}
// Returns a fetch handler that replies with a chat-completion payload.
const jsonChoice = (obj) => async () => ({ ok: true, status: 200, json: async () => ({ choices: [{ message: { content: typeof obj === 'string' ? obj : JSON.stringify(obj) } }] }) });

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`p1_${Date.now()}@example.com`);
  const t2 = await register(`p2_${Date.now()}@example.com`);

  // Fixtures: task + goal for t1; goal for t2 (cross-user).
  let r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Study', priority: 'medium' }) });
  const task = (await r.json()).task;
  r = await fetch(`${BASE}/goals`, { method: 'POST', headers: H(t1), body: JSON.stringify({ name: 'Learn backend development', growthArea: 'Learning' }) });
  const goal = (await r.json()).goal;
  r = await fetch(`${BASE}/goals`, { method: 'POST', headers: H(t2), body: JSON.stringify({ name: 'Secret goal', growthArea: 'Career' }) });
  const goal2 = (await r.json()).goal;

  // Count rows for "no writes during generation" checks.
  const countTables = async () => {
    const q = async (sql) => (await require('../src/config/db').query(sql)).rows[0].c;
    return {
      milestones: await q(`SELECT COUNT(*)::int c FROM milestones m JOIN goals g ON g.id = m.goal_id WHERE g.user_id IN (SELECT id FROM users WHERE email LIKE 'p1_%')`),
      tasks: await q(`SELECT COUNT(*)::int c FROM tasks WHERE user_id IN (SELECT id FROM users WHERE email LIKE 'p1_%')`),
    };
  };

  // ---------- Feature A: task improvement ----------
  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ taskId: task.id }) });
  check('improve unauthenticated → 401', r.status === 401);

  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: '' }) });
  check('improve no taskId and empty title → 400', r.status === 400);

  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'x'.repeat(201) }) });
  check('improve oversized title → 400', r.status === 400);

  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: '00000000-0000-0000-0000-000000000000' }) });
  check('improve nonexistent task → 404', r.status === 404);

  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t2), body: JSON.stringify({ taskId: task.id }) });
  check('improve cross-user task → 404', r.status === 404);

  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id, instructions: 'x'.repeat(501) }) });
  check('improve oversized instructions → 400', r.status === 400);

  // Successful improvement — mocked Groq.
  setMock(jsonChoice({ improvedTitle: 'Study linked lists for 45 minutes', description: 'Focused session', category: 'Learning', priority: 'high', estimatedMinutes: 45, subtasks: [{ title: 'Read the concept' }] }));
  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id, instructions: 'Practical for beginners' }) });
  let j = await r.json();
  check('improve → 200 with proposal', r.status === 200 && j.success && j.data.title === 'Study linked lists for 45 minutes');
  check('improve normalizes category/priority/minutes', j.data.category === 'Learning' && j.data.priority === 'high' && j.data.estimatedMinutes === 45);
  check('improve suggestion includes subtasks', Array.isArray(j.data.subtasks) && j.data.subtasks.length === 1);

  // Generation wrote nothing.
  let before = await countTables();

  // Invalid priority from model is dropped (not rejected wholesale, never trusted).
  setMock(jsonChoice({ improvedTitle: 'Better study', priority: 'urgent', category: 'Space travel', estimatedMinutes: 45 }));
  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  j = await r.json();
  check('invalid priority/category dropped', r.status === 200 && j.data.priority === undefined && j.data.category === undefined && j.data.title === 'Better study');

  // Invalid duration → 502.
  setMock(jsonChoice({ improvedTitle: 'X', estimatedMinutes: 99999 }));
  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('invalid duration → 502', r.status === 502);

  // Malformed model output → 502, no raw leak.
  setMock(jsonChoice('this is not json'));
  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  j = await r.json();
  check('malformed output → 502 safe', r.status === 502 && !String(j.message).includes('not json'));

  // Empty output → 502.
  setMock(jsonChoice({}));
  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('empty proposal → 502', r.status === 502);

  // Rate limit + timeout + missing key.
  setMock(async () => ({ ok: false, status: 429, json: async () => ({}) }));
  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('improve rate limit → 429', r.status === 429);

  setMock(async () => { const e = new Error('aborted'); e.name = 'AbortError'; throw e; });
  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('improve timeout → 504', r.status === 504);

  const envConfig = require('../src/config/env');
  const savedKey = envConfig.groqApiKey;
  envConfig.groqApiKey = '';
  r = await fetch(`${BASE}/ai/tasks/improve`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('improve missing key → 503', r.status === 503);
  envConfig.groqApiKey = savedKey;

  // ---------- Feature B: breakdown ----------
  r = await fetch(`${BASE}/ai/breakdown/generate`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ goalId: goal.id }) });
  check('breakdown unauthenticated → 401', r.status === 401);

  r = await fetch(`${BASE}/ai/breakdown/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({}) });
  check('breakdown no goalId/title → 400', r.status === 400);

  r = await fetch(`${BASE}/ai/breakdown/generate`, { method: 'POST', headers: H(t2), body: JSON.stringify({ goalId: goal.id }) });
  check('breakdown cross-user goal → 404', r.status === 404);

  r = await fetch(`${BASE}/ai/breakdown/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ goalId: goal.id, instructions: 'x'.repeat(501) }) });
  check('breakdown oversized instructions → 400', r.status === 400);

  // Successful breakdown — mocked.
  setMock(jsonChoice({ phases: [
    { title: 'Set up environment', description: 'Install tools', tasks: [{ title: 'Install Flutter SDK', estimatedMinutes: 40 }] },
    { title: 'Build MVP', tasks: [{ title: 'Create screens' }] },
  ] }));
  r = await fetch(`${BASE}/ai/breakdown/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ goalId: goal.id, instructions: 'MVP first' }) });
  j = await r.json();
  check('breakdown → 200 with phases', r.status === 200 && j.success && j.data.phases.length === 2 && j.data.phases[0].title === 'Set up environment');
  check('breakdown normalizes tasks', j.data.phases[0].tasks[0].estimatedMinutes === 40 && j.data.phases[1].tasks[0].estimatedMinutes === undefined);

  // Generation wrote NOTHING (milestones/tasks unchanged).
  let after = await countTables();
  check('generation creates no DB records', before.milestones === after.milestones && before.tasks === after.tasks);

  // Invalid hierarchy values → 502.
  setMock(jsonChoice({ phases: Array.from({ length: 9 }, (_, i) => ({ title: `P${i}`, tasks: [] })) }));
  r = await fetch(`${BASE}/ai/breakdown/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ goalId: goal.id }) });
  check('too many phases → 502', r.status === 502);

  setMock(jsonChoice({ phases: [{ title: 'P', tasks: [{ title: 'T', estimatedMinutes: 3 }] }] }));
  r = await fetch(`${BASE}/ai/breakdown/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ goalId: goal.id }) });
  check('task duration < 5 min → 502', r.status === 502);

  setMock(jsonChoice({ phases: [] }));
  r = await fetch(`${BASE}/ai/breakdown/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ goalId: goal.id }) });
  check('empty phases → 502', r.status === 502);

  setMock(jsonChoice('nope'));
  r = await fetch(`${BASE}/ai/breakdown/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ goalId: goal.id }) });
  check('breakdown malformed → 502', r.status === 502);

  // ---------- Persistence: only confirmed items via EXISTING APIs ----------
  // Simulates the client's "Create selected items": milestone then task.
  before = await countTables();
  r = await fetch(`${BASE}/goals/${goal.id}/milestones`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Set up environment', description: 'Install tools' }) });
  const ms = await r.json();
  check('existing milestone API creates phase', r.status === 201 || r.status === 200);
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Install Flutter SDK', goalId: goal.id, milestoneId: ms.milestone.id, estimatedMinutes: 40 }) });
  check('existing task API creates linked task', r.status === 201 || r.status === 200);
  after = await countTables();
  check('confirmed items persisted (+1 milestone, +1 task)', after.milestones === before.milestones + 1 && after.tasks === before.tasks + 1);

  // Partial-failure retry safety: re-posting an already-created milestone
  // is the client's responsibility; server keeps ownership strict.
  r = await fetch(`${BASE}/goals/${goal2.id}/milestones`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Nope' }) });
  check('cross-user milestone create → 4xx', r.status >= 400 && r.status < 500);

  // Applying selected improvement fields via existing update API updates
  // only what's sent (title only here; status/goal untouched).
  r = await fetch(`${BASE}/tasks/${task.id}`, { method: 'PUT', headers: H(t1), body: JSON.stringify({ title: 'Study DSA daily' }) });
  j = await r.json();
  check('improvement apply via existing task update', r.status === 200 || r.status === 201);
  r = await fetch(`${BASE}/tasks/${task.id}`, { headers: H(t1) });
  j = await r.json();
  const updated = j.task ?? j;
  check('only confirmed field changed', updated.title === 'Study DSA daily' && updated.status === 'pending' && updated.priority === 'medium');

  // Existing endpoints still work.
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health ok', r.status === 200 && j.database === 'connected');
  r = await fetch(`${BASE}/goals`, { headers: H(t1) });
  check('goals list intact', r.status === 200);
  r = await fetch(`${BASE}/tasks/${task.id}/subtasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Existing subtask API' }) });
  check('subtask API intact', r.status === 201 || r.status === 200);

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  global.fetch = realFetch;
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'p1_%' or email like 'p2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); global.fetch = realFetch; process.exit(1); });
