require('dotenv').config();
const app = require('../src/app');

const server = app.listen(5099, async () => {
  const b = 'http://127.0.0.1:5099/api';
  const r = await fetch(`${b}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name: 'x', email: `dbg${Date.now()}@e.com`, password: 'pass1234' }),
  });
  const j = await r.json();
  const t = j.token;
  const c = await fetch(`${b}/tasks`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${t}` },
    body: JSON.stringify({ title: 't' }),
  });
  const task = (await c.json()).task;
  const u = await fetch(`${b}/tasks/${task.id}/status`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${t}` },
    body: JSON.stringify({ status: 'completed' }),
  });
  console.log(u.status, await u.text());
  server.close();
  process.exit(0);
});
