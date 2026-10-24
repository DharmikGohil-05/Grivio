# GRIVIO

**GRIVIO** is a personal-growth and productivity mobile application:
a neumorphic Flutter app backed by a Node.js API and PostgreSQL, with five
AI assist features that turn your own data into suggestions — never into
automatic changes.

Core loop: **Goal → Milestone → Task → Focus → Progress → Reflection →
Improvement**

## Features

- **Accounts & profile** — signup/login (JWT), first-time setup wizard
- **Goals & milestones** — targets with server-computed progress
- **Tasks & subtasks** — priorities, due dates, categories, status flow
- **Focus mode** — timer sessions with pause/resume, session recovery after
  an app restart, reflections
- **Progress** — charts and trends (fl_chart) computed server-side
- **Weekly review & daily reflection** — Monday-start weeks, saved narratives
- **AI assist** (preview-only, via the backend → Groq):
  subtask suggestions · task improvement · goal breakdown ·
  daily planner · weekly growth review
- **Design** — neumorphic UI, light/dark/system themes, 5-tab navigation

## Architecture

```
┌────────────────┐   JWT + JSON    ┌─────────────────┐    HTTPS     ┌────────┐
│  Flutter app   │ ──────────────▶ │  Express API     │ ───────────▶ │  Neon  │
│  (mobile/)     │ ◀────────────── │  (backend/)      │              │  PG DB │
└────────────────┘                 └─────────────────┘              └────────┘
        │                                    │
        │  never holds a Groq key            │  GROQ_API_KEY (server only)
        ▼                                    ▼
   user sees previews                 Groq (openai/gpt-oss-120b by default)
```

- The app talks **only** to the GRIVIO backend; the backend is the only
  component that holds secrets and talks to Groq.
- AI responses are editable previews; data changes only through the normal
  CRUD endpoints after explicit user confirmation.
- Every query is scoped to the authenticated user (ownership enforced
  server-side from the verified token).

## Technology stack

| Layer | Technology |
| --- | --- |
| Mobile | Flutter (Dart), http, flutter_secure_storage, fl_chart |
| Backend | Node.js, Express 5, pg, bcryptjs, jsonwebtoken, dotenv |
| Database | PostgreSQL (Neon in development) |
| AI | Groq API — server-side only |
| Hosting | Local development. **Render deployment: planned, not yet done** |

## Repository structure

```
grivio/
├── mobile/     # Flutter app (lib/, test/, android/, ios/, assets/)
├── backend/    # Express API (src/, migrations/, scripts/ + smoke tests)
├── docs/       # architecture, development workflow, AI features, git workflow
├── .gitignore  # keeps .env, node_modules, build outputs out of git
└── README.md
```

## Prerequisites

- Flutter SDK (Dart ^3.8.1)
- Node.js 18+ (built-in `fetch`; developed on Node 24)
- A PostgreSQL database (e.g. a free Neon project)
- A Groq API key (optional — only needed for the AI features)

## Local development setup

### 1. Backend

```powershell
cd backend
npm install
copy .env.example .env      # fill in DATABASE_URL, JWT_SECRET (+ optional GROQ_API_KEY)
npm run migrate             # applies migrations/001..006 in order
npm.cmd start               # http://localhost:5000
```

> Windows note: use `npm.cmd` — PowerShell's execution policy blocks `npm.ps1`.

### 2. Mobile

```powershell
cd mobile
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

## Environment variables

Defined in `backend/.env` (never committed — copy from `.env.example`):

| Name | Purpose |
| --- | --- |
| `PORT` | API port (default 5000) |
| `DATABASE_URL` | PostgreSQL connection string |
| `JWT_SECRET` | token signing secret |
| `GROQ_API_KEY` | Groq key — AI routes return 503 while absent |
| `GROQ_MODEL` | optional model override |
| `NODE_ENV` | development / production |

## Database and migrations

Plain SQL files in `backend/migrations/`, applied in filename order and
tracked in `schema_migrations`:

```powershell
cd backend
npm run migrate
```

Rules: never edit an applied migration; add a new numbered file instead.

## Running tests

```powershell
# Backend smoke suites (each boots its own server on a test port;
# AI responses are mocked — tests never call Groq live)
cd backend
node scripts\auth_smoke_test.js        # + profile, goal, task, focus, progress,
                                       #   weekly, reflection, ai*, 13 total

# Flutter
cd mobile
flutter analyze
flutter test
```

## API URL: emulator vs device vs production

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api      # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api     # iOS simulator
flutter run --dart-define=API_BASE_URL=http://192.168.x.x:5000/api   # physical device (your PC's LAN IP)
```

For production the app is rebuilt with the deployed API's URL — the value is
a compile-time define, so it can never leak runtime secrets into the app.

## Security notes

- **Secrets live only in `backend/.env`** (git-ignored) or the host's
  environment. The Flutter app contains no API keys, no database URLs and no
  JWT secret — it only stores the user's own login token in
  flutter_secure-storage.
- Passwords are stored as bcrypt hashes (per-user salt), never plaintext.
- Identity always comes from the **verified JWT** (`req.userId`), never from
  the request body — this prevents horizontal privilege escalation (IDOR).
- AI prompts are built from the requesting user's own data only; free-text
  user context is treated as user input, never as instructions, and is not
  stored.

## Deployment status

| Item | Status |
| --- | --- |
| Backend running locally + Neon database | ✅ done and smoke-tested |
| Flutter app on Android emulator | ✅ done |
| **Render (or any host) deployment** | ⬜ **planned — not implemented yet** |
| Production API URL baked into a release build | ⬜ planned |

Planned deployment steps (not yet executed): create a Render web service for
`backend/` (Node 18+), set `DATABASE_URL`, `JWT_SECRET`, `GROQ_API_KEY`,
`NODE_ENV=production` in its environment, run `npm run migrate` once, then
rebuild the app with `--dart-define=API_BASE_URL=<your-render-url>/api` and
tighten CORS in `backend/src/app.js` (currently permissive for local
development).

## More documentation

- [`backend/README.md`](backend/README.md) — API, endpoints, troubleshooting
- [`mobile/README.md`](mobile/README.md) — app architecture, theming, running
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — components and data flow
- [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) — day-to-day workflow
- [`docs/AI_FEATURES.md`](docs/AI_FEATURES.md) — the five AI features and their guardrails
- [`docs/GIT_WORKFLOW.md`](docs/GIT_WORKFLOW.md) — commits, branching, pushing
