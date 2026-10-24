# Grivio Backend

Node.js + Express API for GRIVIO — a personal-growth and productivity app.
Stores users, profiles, goals, milestones, tasks, subtasks, focus sessions,
progress data, weekly reviews and daily reflections in a PostgreSQL database
(Neon in development), and exposes five AI features through Groq.

**Security model in one line:** every request is authenticated with a JWT and
every query is scoped to the authenticated user — one user can never read or
modify another user's data.

---

## Architecture

```
HTTP request
  → routes/        (path → controller, authMiddleware applied per route)
  → controllers/   (parse + validate input, call exactly one service,
                    shape the { success, message, ... } JSON response)
  → services/      (business logic + SQL; the only layer that touches the DB)
  → config/db.js   (pg connection pool)
```

- `src/app.js` assembles middleware and routes; it never calls `listen()`.
- `src/server.js` owns the port, so smoke tests can import the same app and
  bind it to a different port.
- Middleware order: `express.json()` → `cors()` → routers → 404 → error
  handler (Express only invokes the 4-argument error handler via
  `next(err)`, so it must be registered last).

## Folder structure

```
backend/
├── migrations/          # 001..006, applied in filename order by npm run migrate
├── scripts/             # migrate.js + 13 smoke-test suites + inspection helpers
├── src/
│   ├── config/          # env.js (config), db.js (pg pool)
│   ├── controllers/     # request handlers
│   ├── middleware/      # auth.middleware.js (JWT), errorHandler, notFound
│   ├── routes/          # route definitions (authMiddleware per route)
│   ├── services/        # business logic + SQL, incl. ai-*.service.js + groq.service.js
│   ├── utils/           # jwt, password (bcrypt), validators
│   ├── app.js
│   └── server.js
├── .env.example         # placeholder template (real values live in git-ignored .env)
├── package.json
└── README.md
```

## Endpoints

All endpoints are prefixed with `/api`. ✅ = requires `Authorization: Bearer <token>`.

### Health (public)

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/health` | public | Server status; `database` field reports `connected` / `disconnected` |

### Authentication

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| POST | `/auth/register` | public | Create account → `{ user, token }` |
| POST | `/auth/login` | public | Sign in → `{ user, token }` |
| GET | `/auth/me` | ✅ | Current user from the token |
| POST | `/auth/logout` | public | By design: JWT is stateless, the client discards the token |

### Profile

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/profile` | ✅ | Profile incl. `setupCompleted` flag |
| PUT | `/profile` | ✅ | Partial update (COALESCE keeps existing values) |

### Goals & milestones

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/goals` | ✅ | List (`?status=active\|completed\|paused`) |
| POST | `/goals` | ✅ | Create |
| GET | `/goals/:id` | ✅ | One goal with milestone counts |
| PUT | `/goals/:id` | ✅ | Partial update |
| DELETE | `/goals/:id` | ✅ | Delete (milestone links handled per migration 001) |
| GET | `/goals/:goalId/milestones` | ✅ | List milestones of a goal |
| POST | `/goals/:goalId/milestones` | ✅ | Create milestone |
| PUT | `/milestones/:id` | ✅ | Update milestone |
| DELETE | `/milestones/:id` | ✅ | Delete milestone |

### Tasks & subtasks

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/tasks` | ✅ | List with filters (`?status`, `?goalId`, `?milestoneId`, …) |
| POST | `/tasks` | ✅ | Create (optional `goalId` / `milestoneId`) |
| GET | `/tasks/:id` | ✅ | One task incl. denormalized parent names |
| PUT | `/tasks/:id` | ✅ | Partial update |
| DELETE | `/tasks/:id` | ✅ | Delete |
| PATCH | `/tasks/:id/status` | ✅ | Status transition (stamps/clears `completed_at`) |
| GET | `/tasks/:taskId/subtasks` | ✅ | List subtasks |
| POST | `/tasks/:taskId/subtasks` | ✅ | Create subtask |
| PUT | `/subtasks/:id` | ✅ | Update subtask |
| DELETE | `/subtasks/:id` | ✅ | Delete subtask |

### Focus sessions

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| POST | `/focus/sessions` | ✅ | Start (linked to an optional task) |
| GET | `/focus/sessions` | ✅ | List sessions |
| GET | `/focus/sessions/:id` | ✅ | One session (used for recovery after app restart) |
| PATCH | `/focus/sessions/:id` | ✅ | Update extras (e.g. reflection) |
| PATCH | `/focus/sessions/:id/pause` | ✅ | Pause — records `paused_at` |
| PATCH | `/focus/sessions/:id/resume` | ✅ | Resume — folds pause into `total_pause_seconds` |
| PATCH | `/focus/sessions/:id/complete` | ✅ | Complete — elapsed time excludes paused time (server clock) |
| PATCH | `/focus/sessions/:id/cancel` | ✅ | Cancel — still records elapsed time |

### Progress, weekly reviews, reflections

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| GET | `/progress` | ✅ | Stats, trends, goal progress and insights for the logged-in user |
| GET | `/weekly-reviews` | ✅ | List saved weekly reviews |
| GET | `/weekly-reviews/week/:weekStart` | ✅ | One week — `weekStart` must be a **Monday** |
| POST | `/weekly-reviews` | ✅ | Create-or-replace a week's review |
| GET | `/reflections` | ✅ | Daily reflection by date (`?date=YYYY-MM-DD`) |
| POST | `/reflections` | ✅ | Upsert today's reflection |

### AI (Groq, server-side only)

| Method | Path | Auth | Description |
| --- | --- | --- | --- |
| POST | `/ai/test` | ✅ | Connectivity check (does not touch user data) |
| POST | `/ai/subtasks/generate` | ✅ | Subtask suggestions for one of the user's tasks (`taskId` required) |
| POST | `/ai/tasks/improve` | ✅ | Improved title/description/priority/category/duration proposal |
| POST | `/ai/breakdown/generate` | ✅ | Goal → phases + tasks proposal |
| POST | `/ai/daily-plan/generate` | ✅ | Suggested day schedule (foreign/unknown task IDs are dropped server-side) |
| POST | `/ai/weekly-review/generate` | ✅ | Narrative growth review for a week (low-data weeks skip the model) |

> AI endpoints return **suggestions only**. The backend never writes AI output
> to the database; the mobile app shows editable previews and only explicitly
> confirmed items are saved through the normal CRUD endpoints above.

## Environment variables

Copy `.env.example` to `.env` and fill in real values. Names only — values are
never committed (`.env` is git-ignored):

| Variable | Required | Purpose |
| --- | --- | --- |
| `PORT` | no (default 5000) | HTTP port |
| `DATABASE_URL` | yes (for data) | PostgreSQL connection string (Neon) |
| `JWT_SECRET` | yes (for auth) | HMAC secret for signing/verifying tokens |
| `GROQ_API_KEY` | no* | Groq API key — *AI routes return 503 while missing; everything else works |
| `GROQ_MODEL` | no | Overrides the default Groq model |
| `NODE_ENV` | no | `development` / `production` |

## Setup and startup (Windows)

```powershell
cd backend
npm install
copy .env.example .env      # then fill in real values
npm run migrate             # applies migrations/001..006 in order
npm.cmd start               # or: npm run dev (nodemon auto-reload)
```

> On this machine use `npm.cmd` (not `npm`) — PowerShell's execution policy
> blocks `npm.ps1`.

Health check:

```powershell
Invoke-WebRequest http://localhost:5000/api/health -UseBasicParsing
# {"success":true,"message":"Grivio API is running","database":"connected"}
```

## Migrations

Plain SQL files in `migrations/`, applied in filename order and tracked in a
`schema_migrations` table:

```powershell
npm run migrate
```

Never edit an applied migration — add a new numbered file instead.

## Tests (smoke suites)

Each suite boots the app on its own test port with a throwaway user and hits
every requirement over HTTP. The AI suites **mock Groq's HTTP response** — no
live Groq call is ever made by tests.

```powershell
node scripts\auth_smoke_test.js
node scripts\ai_plan_smoke_test.js
# … one script per feature: profile, goal, task, focus, progress, weekly,
#   reflection, ai, ai_subtask, ai_features, ai_weekly
```

Utility scripts: `migrate.js`, `list_tables.js`, `inspect_*.js`,
`cleanup_test_users.js` (removes throwaway `*_test` users).

## AI integration

`services/groq.service.js` is the **only** place the Groq API is called
(Node's built-in `fetch` + `AbortController`, 30 s timeout — no extra
dependency). The `ai-*.service.js` files build prompts from the requesting
user's own data only, parse/validate the JSON answer, and map provider
failures to safe HTTP statuses (401/403 → 503, 429 → 429, 5xx → 502,
timeout → 504, missing config → 503).

## Troubleshooting

| Symptom | Likely cause |
| --- | --- |
| `database: disconnected` in `/health` | `DATABASE_URL` missing/invalid or DB asleep (free Neon tiers pause) |
| AI routes return 503 | `GROQ_API_KEY` not set in `.env` — by design the server still runs |
| `Invalid or expired token` (401) | JWT expired or wrong `JWT_SECRET` — log in again for a fresh token |
| `npm` blocked by execution policy | Use `npm.cmd start` instead |
| Port 5000 already in use | Another backend instance is running — stop it or set `PORT` |
