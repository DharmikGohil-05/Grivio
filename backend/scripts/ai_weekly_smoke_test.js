// Phase 15 smoke test — AI weekly growth review (mocked Groq, live Neon).
// Verifies auth, Monday-week validation, real-data gathering + week
// boundaries, user isolation, low-data honesty, statistic scrubbing,
// read-only generation, and provider error mapping.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5078;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'Weekly', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });
const realFetch = global.fetch;
let lastGroqBody = null;

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

// This Monday (same convention as weekly.service).
function mondayOf(d) {
  const date = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()));
  const dow = date.getUTCDay(); // Sun=0
  date.setUTCDate(date.getUTCDate() - ((dow + 6) % 7));
  return date.toISOString().slice(0, 10);
}
const THIS_MONDAY = mondayOf(new Date());
const LAST_MONDAY = mondayOf(new Date(Date.now() - 7 * 86400000));

// Decent mocked review with realistic sections.
const goodReview = {
  wins: ['You completed tasks this week and kept your streak of showing up.'],
  progressHighlights: ['Two goals moved forward through completed tasks.'],
  patterns: ['You tended to complete work on tasks you had already started.'],
  challenges: ['Some tasks slipped past their due dates.'],
  nextWeekPriorities: ['Pick one overdue task and finish it first.'],
  suggestedActions: ['Block 25 minutes tomorrow for your most urgent task.'],
  dataLimitations: [],
};

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`w1_${Date.now()}@example.com`);
  const t2 = await register(`w2_${Date.now()}@example.com`);

  // t1: real activity — completed task, focus session, weekly review fields,
  // daily reflection. t2: nothing (low-data state).
  let r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Finish DSA set', priority: 'high', estimatedMinutes: 60 }) });
  const task = (await r.json()).task;
  await fetch(`${BASE}/tasks/${task.id}`, { method: 'PUT', headers: H(t1), body: JSON.stringify({ status: 'completed' }) });

  r = await fetch(`${BASE}/focus/sessions`, { method: 'POST', headers: H(t1), body: JSON.stringify({ task_id: task.id }) });
  const session = (await r.json()).session;
  await fetch(`${BASE}/focus/sessions/${session.id}/complete`, { method: 'PATCH', headers: H(t1), body: JSON.stringify({ productivity_rating: 'good', reflection: 'Deep work felt easy' }) });

  await fetch(`${BASE}/weekly-reviews`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY, biggestWin: 'Shipped the DSA set', needsAttention: 'Procrastinated evenings', nextWeekFocus: 'Morning sessions' }) });
  await fetch(`${BASE}/reflections`, { method: 'POST', headers: H(t1), body: JSON.stringify({ date: THIS_MONDAY, wentWell: 'Focused well', wasDifficult: 'Late start', toImprove: 'Sleep earlier' }) }).catch(() => {});
  // t2 gets ONE task so its generation path exercises a real prompt
  // (instead of the low-data shortcut) for the isolation test below.
  await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t2), body: JSON.stringify({ title: 'T2 own task', estimatedMinutes: 30 }) });

  const countAll = async () => {
    const { query } = require('../src/config/db');
    const q = async (sql) => (await query(sql)).rows[0].c;
    return {
      tasks: await q('SELECT COUNT(*)::int c FROM tasks'),
      sessions: await q('SELECT COUNT(*)::int c FROM focus_sessions'),
      weekly: await q('SELECT COUNT(*)::int c FROM weekly_reviews'),
      reflections: await q('SELECT COUNT(*)::int c FROM reflections'),
      goals: await q('SELECT COUNT(*)::int c FROM goals'),
      milestones: await q('SELECT COUNT(*)::int c FROM milestones'),
      subtasks: await q('SELECT COUNT(*)::int c FROM subtasks'),
    };
  };

  // 1. Unauthenticated → 401
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  check('unauthenticated → 401', r.status === 401);

  // 2. Validation: missing / malformed / non-Monday.
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({}) });
  check('missing weekStart → 400', r.status === 400);
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: 'not-a-date' }) });
  check('malformed weekStart → 400', r.status === 400);
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: '2026-10-07' }) }); // Wednesday
  check('non-Monday weekStart → 400', r.status === 400);

  // 3. Successful generation — mocked Groq, real stats in the prompt.
  setMock(jsonChoice(goodReview));
  const before = await countAll();
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  let j = await r.json();
  check('generate → 200 structured review', r.status === 200 && j.success && j.data.weekStart === THIS_MONDAY);
  check('weekEnd = weekStart + 6 days', (() => {
    const s = new Date(`${j.data.weekStart}T00:00:00Z`);
    const e = new Date(`${j.data.weekEnd}T00:00:00Z`);
    return (e - s) === 6 * 86400000;
  })());
  check('all sections present as arrays',
    ['wins', 'progressHighlights', 'patterns', 'challenges', 'nextWeekPriorities', 'suggestedActions', 'dataLimitations']
      .every((k) => Array.isArray(j.data[k])));
  check('summary is backend-computed (real stats)', j.data.summary.tasksCompleted === 1 && typeof j.data.summary.focusMinutes === 'number');
  check('lowData false for active user', j.data.lowData === false);

  // 4. Week boundary correctness: prompt facts use THIS week only.
  const userMsg = lastGroqBody?.messages?.find((m) => m.role === 'user')?.content ?? '';
  check('prompt contains this week range', userMsg.includes(THIS_MONDAY));
  check('prompt does NOT contain last week', !userMsg.includes(LAST_MONDAY));

  // 5. User isolation: t1's reflection text never in t2's prompt.
  setMock(jsonChoice(goodReview));
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t2), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  j = await r.json();
  const t2Msg = lastGroqBody?.messages?.find((m) => m.role === 'user')?.content ?? '';
  check('t2 prompt has no t1 reflections', !t2Msg.includes('Shipped the DSA set') && !t2Msg.includes('Focused well'));
  check('t2 prompt has no t1 tasks', !t2Msg.includes('Finish DSA set'));

  // 6. Low-data: t2 has no activity → honest lowData response, NO Groq call.
  lastGroqBody = null;
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t2), body: JSON.stringify({ weekStart: LAST_MONDAY }) });
  j = await r.json();
  check('no activity → lowData true', r.status === 200 && j.data.lowData === true);
  check('low-data skips Groq entirely', lastGroqBody === null);
  check('low-data has honest limitation', j.data.dataLimitations.length > 0);

  // 7. Missing weekly reflection still works (t1 for LAST week: no review rows).
  setMock(jsonChoice(goodReview));
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: LAST_MONDAY }) });
  j = await r.json();
  check('missing reflection does not block generation', r.status === 200 && j.data.lowData === false || r.status === 200);

  // 8. Fabricated-statistic scrubbing: model claims a fake % and hours.
  setMock(jsonChoice({
    ...goodReview,
    wins: ['You completed 98% of your work this week.', 'You focused for 42 hours — amazing work.'],
    patterns: ['Your completion rate held steady.'], // no number → fine
  }));
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  j = await r.json();
  const winsText = JSON.stringify(j.data.wins);
  check('fabricated percentage removed', r.status === 200 && !winsText.includes('98%'));
  check('fabricated hours removed', !winsText.includes('42 hours'));
  check('legit numberless sentence kept', j.data.patterns.some((p) => p.includes('completion rate held steady')));

  // 9. Malformed / unusable model output → 502, raw never exposed.
  setMock(jsonChoice('this is not json'));
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  j = await r.json();
  check('malformed output → 502 safe', r.status === 502 && !String(j.message).includes('not json'));

  setMock(jsonChoice({ wins: [], patterns: [] })); // all sections empty
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  check('all-empty sections → 502', r.status === 502);

  setMock(jsonChoice({ wins: 42, patterns: 'nope' })); // wrong types
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  check('non-array sections → 502', r.status === 502);

  // 10. Oversized items are truncated, section counts capped.
  setMock(jsonChoice({ ...goodReview, wins: Array.from({ length: 30 }, (_, i) => `Item ${i} ` + 'x'.repeat(500)) }));
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  j = await r.json();
  check('section capped at 6 items', r.status === 200 && j.data.wins.length === 6);
  check('items truncated to 300 chars', j.data.wins.every((w) => w.length <= 300));

  // 11. Provider errors: 429 → 429, timeout → 504, missing key → 503.
  setMock(async () => ({ ok: false, status: 429, json: async () => ({}) }));
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  check('rate limit → 429', r.status === 429);

  setMock(async () => { const e = new Error('aborted'); e.name = 'AbortError'; throw e; });
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  check('timeout → 504', r.status === 504);

  const envConfig = require('../src/config/env');
  const savedKey = envConfig.groqApiKey;
  envConfig.groqApiKey = '';
  r = await fetch(`${BASE}/ai/weekly-review/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY }) });
  check('missing GROQ_API_KEY → 503', r.status === 503);
  envConfig.groqApiKey = savedKey;

  // 12. READ-ONLY: generation + regeneration changed zero rows.
  const after = await countAll();
  check('generation modifies no tables',
    before.tasks === after.tasks && before.sessions === after.sessions && before.weekly === after.weekly &&
    before.reflections === after.reflections && before.goals === after.goals &&
    before.milestones === after.milestones && before.subtasks === after.subtasks);

  // 13. Existing weekly-review endpoints intact (screen behavior unchanged).
  r = await fetch(`${BASE}/weekly-reviews/week/${THIS_MONDAY}`, { headers: H(t1) });
  j = await r.json();
  check('GET week stats intact', r.status === 200 && j.stats && typeof j.stats.tasksCompleted === 'number');
  check('saved reflection untouched', j.review && j.review.biggest_win === 'Shipped the DSA set');
  r = await fetch(`${BASE}/weekly-reviews`, { method: 'POST', headers: H(t1), body: JSON.stringify({ weekStart: THIS_MONDAY, biggestWin: 'Shipped the DSA set', needsAttention: 'Procrastinated evenings', nextWeekFocus: 'Morning sessions' }) });
  check('upsert weekly review intact', r.status === 200);
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health ok', r.status === 200 && j.database === 'connected');

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  global.fetch = realFetch;
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'w1_%' or email like 'w2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); global.fetch = realFetch; process.exit(1); });
