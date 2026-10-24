# services/

Business logic + SQL — the only layer that touches the database.

- `auth|profile|goal|milestone|task|subtask` — CRUD logic; every query is
  scoped to the authenticated user's id.
- `focus` — session lifecycle; elapsed time always excludes paused time.
- `progress|weekly|reflection` — aggregation and review logic (Monday-start weeks).
- `groq.service.js` — the only module allowed to call the Groq API.
- `ai-*.service.js` — the five AI features; suggestions only, never written
  to the database by the backend.
