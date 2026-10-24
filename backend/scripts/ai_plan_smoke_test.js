// Phase 14 smoke test — AI daily planner (mocked Groq, live Neon).
// Verifies auth, request validation, context handling + bounds, ownership,
// schedule normalization (overlap / out-of-window / unknown IDs), provider
// error mapping, and that generation alone writes NOTHING to the database.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5077;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'Plan', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });
const realFetch = global.fetch;
let lastGroqBody = null; // captured so we can assert what reaches Groq

function setMock(handler) {
  global.fetch = async (u, opts) => {
    if (typeof u === 'string' && u.includes('api.groq.com')) {
      lastGroqBody = opts?.body ? JSON.parse(opts.body) : null;
      return handler(u, opts);
    }
    return realFetch(u, opts);
  };
}
const jsonChoice = (obj) => async () => ({ ok: true, status: 200, json: async () => ({ choices: [{ message: { content: typeof obj === 'string' ? obj : JSON.stringify(obj) } }] }) });

const TODAY = new Date(Date.now() + 86400000).toISOString().slice(0, 10);
const baseReq = (over = {}) => ({ date: TODAY, availableMinutes: 180, startTime: '15:00', endTime: '20:00', breakMinutes: 10, ...over });

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`d1_${Date.now()}@example.com`);
  const t2 = await register(`d2_${Date.now()}@example.com`);

  // t1 gets real tasks (one overdue, one without estimate); t2 owns a task
  // that must NEVER appear in t1's plan.
  let r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Revise DSA', priority: 'high', estimatedMinutes: 60 }) });
  const taskA = (await r.json()).task;
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Project work', priority: 'medium' }) });
  const taskB = (await r.json()).task;
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Old deadline', priority: 'low', estimatedMinutes: 30, dueDate: '2020-01-01' }) });
  await r.json();
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Finished thing' }) });
  const doneTask = (await r.json()).task;
  await fetch(`${BASE}/tasks/${doneTask.id}`, { method: 'PUT', headers: H(t1), body: JSON.stringify({ status: 'completed' }) });
  r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t2), body: JSON.stringify({ title: 'T2 secret task', estimatedMinutes: 60 }) });
  const taskT2 = (await r.json()).task;

  const countRows = async () => {
    const { query } = require('../src/config/db');
    const r1 = await query(`SELECT COUNT(*)::int c FROM tasks`);
    const r2 = await query(`SELECT COUNT(*)::int c FROM subtasks`);
    return { tasks: r1.rows[0].c, subtasks: r2.rows[0].c };
  };

  // 1. Unauthenticated → 401
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(baseReq()) });
  check('unauthenticated → 401', r.status === 401);

  // 2. Invalid date → 400
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ date: 'not-a-date' })) });
  check('invalid date → 400', r.status === 400);

  // 3. Invalid availability → 400
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ availableMinutes: 3 })) });
  check('availableMinutes too small → 400', r.status === 400);
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ availableMinutes: 99999 })) });
  check('availableMinutes too large → 400', r.status === 400);

  // 4. Invalid window → 400
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ startTime: '20:00', endTime: '15:00' })) });
  check('start after end → 400', r.status === 400);
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ startTime: '25:99' })) });
  check('malformed startTime → 400', r.status === 400);

  // 5. Oversized context → 400; non-string → 400
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ dailyContext: 'x'.repeat(1001) })) });
  check('context > 1000 chars → 400', r.status === 400);
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ dailyContext: { evil: true } })) });
  check('non-string context → 400', r.status === 400);

  // 6. Empty context accepted + valid generation (mocked schedule).
  //    Schedule: valid 15:00 DSA, an OVERLAPPING slot, an OUT-OF-WINDOW
  //    slot, an UNKNOWN taskId (t2's), plus an unscheduled entry.
  setMock(jsonChoice({
    schedule: [
      { taskId: taskA.id, start: '15:00', minutes: 60 },
      { taskId: taskB.id, start: '15:30', minutes: 45 }, // overlaps DSA → rejected
      { taskId: 'ffffffff-ffff-ffff-ffff-ffffffffffff', start: '16:00', minutes: 30 }, // unknown → dropped
      { taskId: taskT2.id, start: '16:00', minutes: 30 }, // other user's → dropped
    ],
    breaks: [{ start: '16:00', minutes: 10 }],
    unscheduled: [],
  }));
  const before = await countRows();
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ dailyContext: '' })) });
  let j = await r.json();
  check('empty context → 200 plan', r.status === 200 && j.success && Array.isArray(j.data.scheduledTasks));
  check('overlapping slot rejected → moved to unscheduled', j.data.unscheduledTasks.some((u) => u.taskId === taskB.id));
  check('no overlapping slots in output', j.data.scheduledTasks.every((s, i, arr) =>
    arr.every((o, k) => k === i || s.start >= o.end || s.end <= o.start)));
  check('unknown/foreign taskIds never returned',
    !JSON.stringify(j.data).includes('ffffffff-ffff-ffff-ffff-ffffffffffff') &&
    !JSON.stringify(j.data).includes(taskT2.id));
  check('completed task excluded', !JSON.stringify(j.data).includes('Finished thing'));
  check('totals consistent (planned + remaining = capacity)',
    j.data.plannedMinutes + j.data.remainingMinutes === j.data.capacityMinutes);
  check('no GROQ_API_KEY leaked', !JSON.stringify(j).includes(process.env.GROQ_API_KEY));

  // 7. Valid daily context reaches Groq in the USER prompt (not system).
  setMock(jsonChoice({ schedule: [{ taskId: taskA.id, start: '15:00', minutes: 60 }], breaks: [], unscheduled: [{ taskId: taskB.id, reason: 'User asked to keep evening free' }] }));
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ dailyContext: 'I have an exam tomorrow. Prioritize revision and leave 30 minutes free before dinner.' })) });
  j = await r.json();
  check('valid context → 200 + contextApplied', r.status === 200 && j.data.contextApplied === true);
  const userMsg = lastGroqBody?.messages?.find((m) => m.role === 'user')?.content ?? '';
  check('context included in user message', userMsg.includes('exam tomorrow'));
  const sysMsg = lastGroqBody?.messages?.find((m) => m.role === 'system')?.content ?? '';
  check('context NOT in system rules', !sysMsg.includes('exam tomorrow'));

  // 8. Out-of-window schedule entries rejected (13:00 is before 15:00 window).
  setMock(jsonChoice({ schedule: [{ taskId: taskA.id, start: '13:00', minutes: 60 }], breaks: [], unscheduled: [] }));
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq()) });
  j = await r.json();
  check('out-of-window entry never scheduled',
    r.status === 200 && j.data.scheduledTasks.length === 0 && j.data.unscheduledTasks.some((u) => u.taskId === taskA.id));

  // 9. Malformed model output → 502, raw payload never exposed.
  setMock(jsonChoice('not json at all'));
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq()) });
  j = await r.json();
  check('malformed output → 502 safe', r.status === 502 && !String(j.message).includes('not json'));

  setMock(jsonChoice({ breaks: [] })); // missing schedule array
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq()) });
  check('missing schedule array → 502', r.status === 502);

  // 10. Context warning: note mentions time outside window → grounded warning.
  setMock(jsonChoice({ schedule: [{ taskId: taskA.id, start: '15:00', minutes: 60 }], breaks: [], unscheduled: [] }));
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq({ dailyContext: 'I have an appointment at 9 AM. Do not schedule work then.' })) });
  j = await r.json();
  check('out-of-window context mention → warning', r.status === 200 && j.data.warnings.some((w) => w.includes('9 am') || w.includes('outside your selected availability')));

  // 11. Provider failures: 429 → 429, timeout → 504, missing key → 503.
  setMock(async () => ({ ok: false, status: 429, json: async () => ({}) }));
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq()) });
  check('rate limit → 429', r.status === 429);

  setMock(async () => { const e = new Error('aborted'); e.name = 'AbortError'; throw e; });
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq()) });
  check('timeout → 504', r.status === 504);

  const envConfig = require('../src/config/env');
  const savedKey = envConfig.groqApiKey;
  envConfig.groqApiKey = '';
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify(baseReq()) });
  check('missing GROQ_API_KEY → 503', r.status === 503);
  envConfig.groqApiKey = savedKey;

  // 12. Generation caused NO database writes.
  const after = await countRows();
  check('generation creates no DB records', before.tasks === after.tasks && before.subtasks === after.subtasks);

  // 13. Cross-user isolation: t2's plan prompt never contains t1's tasks.
  setMock(jsonChoice({ schedule: [{ taskId: taskT2.id, start: '15:00', minutes: 60 }], breaks: [], unscheduled: [] }));
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t2), body: JSON.stringify(baseReq()) });
  j = await r.json();
  const t2UserMsg = lastGroqBody?.messages?.find((m) => m.role === 'user')?.content ?? '';
  check("t2 prompt contains only t2's task", r.status === 200 && t2UserMsg.includes('T2 secret task') && !t2UserMsg.includes('Revise DSA'));

  // 14. User with no eligible tasks → honest empty plan (no AI call needed).
  const t3 = await register(`d3_${Date.now()}@example.com`);
  r = await fetch(`${BASE}/ai/daily-plan/generate`, { method: 'POST', headers: H(t3), body: JSON.stringify(baseReq()) });
  j = await r.json();
  check('no eligible tasks → 200 empty plan', r.status === 200 && j.data.scheduledTasks.length === 0 && j.data.warnings.length > 0);

  // 15. Existing endpoints intact + health.
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health ok', r.status === 200 && j.database === 'connected');
  r = await fetch(`${BASE}/tasks`, { headers: H(t1) });
  check('tasks list intact', r.status === 200);
  r = await fetch(`${BASE}/goals`, { headers: H(t1) });
  check('goals list intact', r.status === 200);

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  global.fetch = realFetch;
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'd1_%' or email like 'd2_%' or email like 'd3_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); global.fetch = realFetch; process.exit(1); });
