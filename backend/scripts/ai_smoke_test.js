// Phase 11 AI smoke test — mocks the Groq HTTP call so no tokens are spent.
// Covers: auth, validation, missing config, normalization, provider errors,
// rate limits, timeouts, and secret-leak checks.
require('dotenv').config();
const app = require('../src/app');

const PORT = 5074;
const BASE = `http://localhost:${PORT}/api`;
let passed = 0, failed = 0;
function check(name, cond) { console.log(`${cond ? 'PASS' : 'FAIL'} - ${name}`); cond ? passed++ : failed++; }

async function register(email) {
  const r = await fetch(`${BASE}/auth/register`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: 'AI', email, password: 'passw0rd123' }) });
  return (await r.json()).token;
}
const H = (t) => ({ 'Content-Type': 'application/json', Authorization: `Bearer ${t}` });

// Replace global fetch with a mock that simulates Groq responses.
// Only Groq API calls are mocked — test-server requests pass through.
let mockResponse = null;
let mockFetchCalled = false;
const realFetch = global.fetch;
function setMock(status, body) {
  global.fetch = async (url, opts) => {
    // Pass through requests to the test server itself.
    if (typeof url === 'string' && !url.includes('api.groq.com')) {
      return realFetch(url, opts);
    }
    mockFetchCalled = true;
    if (body === 'THROW_NETWORK') throw new Error('network down');
    if (body === 'ABORT') {
      const e = new Error('aborted');
      e.name = 'AbortError';
      throw e;
    }
    if (body === 'BAD_JSON') return { ok: true, status, json: async () => { throw new Error('bad'); } };
    return { ok: status >= 200 && status < 300, status, json: async () => body };
  };
}

async function run() {
  const server = app.listen(PORT);
  const token = await register(`ai_${Date.now()}@example.com`);

  // 1. Unauthenticated → 401
  let r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ prompt: 'Hello' }) });
  check('unauthenticated → 401', r.status === 401);

  // 2. Empty prompt → 400
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: '   ' }) });
  check('empty prompt → 400', r.status === 400);

  // 3. Missing prompt → 400
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({}) });
  check('missing prompt → 400', r.status === 400);

  // 4. Oversized prompt → 400
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'x'.repeat(2001) }) });
  check('oversized prompt → 400', r.status === 400);

  // 5. Valid request → normalized { success, data.text }, no key leaked
  setMock(200, { choices: [{ message: { content: '  Try the Pomodoro technique.  ' } }] });
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'How to focus?' }) });
  let j = await r.json();
  check('valid → 200 + trimmed text', r.status === 200 && j.success && j.data.text === 'Try the Pomodoro technique.');
  check('response contains no API key', !JSON.stringify(j).includes(process.env.GROQ_API_KEY));
  check('fetch was called (mock active)', mockFetchCalled);

  // 6. Rate limit → 429
  setMock(429, {});
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'hi' }) });
  check('rate limit → 429 safe error', r.status === 429 && !JSON.stringify(j).includes('Bearer'));

  // 7. Provider 500 → 502
  setMock(500, {});
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'hi' }) });
  check('provider 500 → 502 safe error', r.status === 502);

  // 8. Provider 401 → 503
  setMock(401, {});
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'hi' }) });
  check('provider 401 → 503 safe error', r.status === 503);

  // 9. Timeout → 504
  setMock(200, 'ABORT');
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'hi' }) });
  check('timeout → 504 safe error', r.status === 504);

  // 10. Network failure → 502
  setMock(200, 'THROW_NETWORK');
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'hi' }) });
  check('network failure → 502 safe error', r.status === 502);

  // 11. Malformed JSON → 502
  setMock(200, 'BAD_JSON');
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'hi' }) });
  check('malformed response → 502 safe error', r.status === 502);

  // 12. Empty content → 502
  setMock(200, { choices: [{ message: { content: '   ' } }] });
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'hi' }) });
  check('empty AI content → 502', r.status === 502);

  // 13. Missing config → 503 (config captured env at load, so clear the object)
  const envConfig = require('../src/config/env');
  const savedKey = envConfig.groqApiKey;
  envConfig.groqApiKey = '';
  setMock(200, { choices: [{ message: { content: 'x' } }] });
  r = await fetch(`${BASE}/ai/test`, { method: 'POST', headers: H(token), body: JSON.stringify({ prompt: 'hi' }) });
  check('missing GROQ_API_KEY → 503', r.status === 503);
  envConfig.groqApiKey = savedKey;

  // 14. Health still fine + DB connected
  r = await fetch(`${BASE}/health`);
  j = await r.json();
  check('/api/health ok', r.status === 200 && j.database === 'connected');

  console.log(`\n${passed} passed, ${failed} failed`);
  server.close();
  global.fetch = realFetch;
  const { pool } = require('../src/config/db');
  await pool.query("delete from users where email like 'ai_%'");
  process.exit(failed ? 1 : 0);
}
run().catch((e) => { console.error(e); global.fetch = realFetch; process.exit(1); });
