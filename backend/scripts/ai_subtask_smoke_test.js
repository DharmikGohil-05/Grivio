// Phase 12 AI subtask generation smoke test — mocked Groq, live Neon.
// Verifies auth, ownership, validation, normalization, error mapping,
// and that generation alone writes NOTHING to the database.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5075;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'AI', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });
const realFetch = global.fetch;

function setMock(url, handler) {
  global.fetch = async (u, opts) => (typeof u === 'string' && u.includes('api.groq.com')) ? handler(u, opts) : realFetch(u, opts);
}

async function run() {
  const server = app.listen(PORT);
  const t1 = await register(`s1_${Date.now()}@example.com`);
  const t2 = await register(`s2_${Date.now()}@example.com`);

  // t1 gets a real task; t2 is the "other user"
  let r = await fetch(`${BASE}/tasks`, { method: 'POST', headers: H(t1), body: JSON.stringify({ title: 'Learn DSA', description: 'Data structures and algorithms' }) });
  const task = (await r.json()).task;
  const subtasksBefore = await (await fetch(`${BASE}/tasks/${task.id}/subtasks`, { headers: H(t1) })).json();

  // 1. Unauthenticated → 401
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ taskId: task.id }) });
  check('unauthenticated → 401', r.status === 401);

  // 2. Missing taskId → 400
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({}) });
  check('missing taskId → 400', r.status === 400);

  // 3. Invalid taskId type → 400
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: 42 }) });
  check('invalid taskId type → 400', r.status === 400);

  // 4. Nonexistent task → 404
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: '00000000-0000-0000-0000-000000000000' }) });
  check('nonexistent task → 404', r.status === 404);

  // 5. Other user's task → 404 (ownership enforced)
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t2), body: JSON.stringify({ taskId: task.id }) });
  check('other user task → 404', r.status === 404);

  // 6. Oversized instructions → 400
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id, instructions: 'x'.repeat(501) }) });
  check('oversized instructions → 400', r.status === 400);

  // 7. Successful generation — mocked Groq returns clean JSON
  setMock('groq', async () => ({
    ok: true, status: 200,
    json: async () => ({ choices: [{ message: { content: JSON.stringify({ suggestions: [
      { title: 'Review arrays and strings', description: 'Basic operations', estimatedMinutes: 25 },
      { title: 'Learn linked lists', estimatedMinutes: 40 },
    ] }) } }] }),
  }));
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id, instructions: 'Keep steps under 30 minutes' }) });
  let j = await r.json();
  check('generate → 200 + suggestions', r.status === 200 && j.success && j.data.suggestions.length === 2 && j.data.suggestions[0].title === 'Review arrays and strings');
  check('suggestions normalized (title/desc/min)', j.data.suggestions[1].estimatedMinutes === 40 && j.data.suggestions[1].description == null);
  check('no API key in response', !JSON.stringify(j).includes(process.env.GROQ_API_KEY));

  // 8. Generation wrote NOTHING to the database
  const subtasksAfter = await (await fetch(`${BASE}/tasks/${task.id}/subtasks`, { headers: H(t1) })).json();
  check('generation creates no DB records', subtasksAfter.subtasks.length === subtasksBefore.subtasks.length);

  // 9. Malformed model output → 502
  setMock('groq', async () => ({ ok: true, status: 200, json: async () => ({ choices: [{ message: { content: 'not json at all' } }] }) }));
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('malformed JSON → 502 safe error', r.status === 502);

  // 10. Empty suggestions → 502
  setMock('groq', async () => ({ ok: true, status: 200, json: async () => ({ suggestions: [] }) }));
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('empty suggestions → 502', r.status === 502);

  // 11. Oversized list → 502
  setMock('groq', async () => ({ ok: true, status: 200, json: async () => ({ suggestions: Array.from({ length: 11 }, (_, i) => ({ title: `Step ${i}` })) }) }));
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('oversized list → 502', r.status === 502);

  // 12. Invalid duration → 502
  setMock('groq', async () => ({ ok: true, status: 200, json: async () => ({ suggestions: [{ title: 'X', estimatedMinutes: 9999 }] }) }));
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('invalid duration → 502', r.status === 502);

  // 13. Rate limit → 429
  setMock('groq', async () => ({ ok: false, status: 429, json: async () => ({}) }));
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('rate limit → 429', r.status === 429);

  // 14. Timeout → 504
  setMock('groq', async () => { const e = new Error('aborted'); e.name = 'AbortError'; throw e; });
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('timeout → 504', r.status === 504);

  // 15. Missing API key → 503
  const envConfig = require('../src/config/env');
  const savedKey = envConfig.groqApiKey;
  envConfig.groqApiKey = '';
  setMock('groq', async () => ({ ok: true, status: 200, json: async () => ({ suggestions: [{ title: 'X' }] }) }));
  r = await fetch(`${BASE}/ai/subtasks/generate`, { method: 'POST', headers: H(t1), body: JSON.stringify({ taskId: task.id }) });
  check('missing GROQ_API_KEY → 503', r.status === 503);
  envConfig.groqApiKey = savedKey;

  // 16. Health + existing task API still fine
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health ok', r.status === 200 && j.database === 'connected');
  r = await fetch(`${BASE}/tasks/${task.id}`, { headers: H(t1) });
  check('existing task API intact', r.status === 200);

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  global.fetch = realFetch;
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 's1_%' or email like 's2_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); global.fetch = realFetch; process.exit(1); });
