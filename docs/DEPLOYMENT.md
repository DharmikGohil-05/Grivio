# Deployment

How GRIVIO is deployed, what each environment needs, and how to verify a
deployment. The API is already live; this document describes the setup and
how to reproduce or change it.

```
┌──────────────┐   HTTPS + JWT    ┌────────────────────────────┐
│  Web app     │ ───────────────► │  Backend (Render)          │
│  static host │                  │  https://grivio-api.onrender.com/api
└──────────────┘                  │  Node 18+ · Express        │
┌──────────────┐   HTTPS + JWT    │  CORS allow-list (see below)│
│  Flutter app │ ───────────────► └─────────────┬──────────────┘
└──────────────┘                               │ SQL (TLS)
                                    ┌──────────▼──────────┐
                                    │  Postgres (Neon)    │
                                    └─────────────────────┘
```

| Piece | Where it runs | Config source |
| --- | --- | --- |
| Backend API | Render web service, root `backend/` | service environment variables |
| Database | Neon (Postgres) | `DATABASE_URL` |
| Web app | any static host (Vercel / Netlify / GitHub Pages / …), root `webapp/` | `VITE_API_BASE_URL` (optional) |
| Flutter app | devices | compile-time `--dart-define=API_BASE_URL` |

All three clients default to the production API
(`https://grivio-api.onrender.com/api`), so **a plain build with no
configuration talks to production** and never to localhost.

---

## 1. Backend on Render

Render is connected to this repository's GitHub `main` branch: **every push
to `main` triggers a deploy** (no CI config exists — the push itself is the
trigger).

### One-time service setup

1. Render → **New → Web Service** → connect `DharmikGohil-05/Grivio`.
2. Settings:
   - **Root directory:** `backend` (Render must build from the backend folder)
   - **Runtime:** Node
   - **Build command:** `npm install`
   - **Start command:** `npm start`  (`node src/server.js`)
3. Add the environment variables below (Render → *Environment* tab).
4. Deploy, then run migrations once against the production database:
   ```powershell
   cd backend
   $env:DATABASE_URL = "<production connection string>"
   npm run migrate
   ```

### Environment variables

| Key | Required | Notes |
| --- | --- | --- |
| `DATABASE_URL` | yes | Neon connection string, include `?sslmode=require` |
| `JWT_SECRET` | yes | random 96-char hex; rotating it logs everyone out |
| `GROQ_API_KEY` | yes | AI features return 503 without it |
| `GROQ_MODEL` | no | overrides the default model in `groq.service.js` |
| `NODE_ENV` | yes | set to `production` |
| `PORT` | set by Render | do not hardcode |
| `CORS_ORIGINS` | see §2 | comma-separated browser origins |

Never put `GROQ_API_KEY`, `JWT_SECRET` or `DATABASE_URL` in the Flutter app
or the web bundle — they belong only on the server (see `webapp/src/config.ts`).

### Health check

```
GET https://grivio-api.onrender.com/api/health
```

Returns JSON with database/AI status — use it after every deploy. The
free-tier instance sleeps after idle, so the **first request after a pause
can take 20–60 s**; the Flutter client already retries once for this.

---

## 2. CORS allow-list

The policy lives in `backend/src/app.js` and is driven by `CORS_ORIGINS`:

| `CORS_ORIGINS` | Behaviour |
| --- | --- |
| **empty** (default in dev) | permissive — Vite, Flutter emulators, curl all work |
| **set** (production) | only the listed origins get CORS headers; every other origin is blocked by the browser |

```bash
# examples
CORS_ORIGINS=https://grivio.vercel.app,http://localhost:4173
CORS_ORIGINS=https://grivio-api.onrender.com
```

Details that matter:

- Origins are compared **scheme + host + port** exactly; trailing slashes in
  the list are ignored (`https://app.example.com/` matches `https://app.example.com`).
- Requests **without an `Origin` header** (curl, the Flutter app, server-to-
  server calls) are always allowed — CORS only ever constrains browsers.
- Allowed headers: `Content-Type`, `Authorization` (the API authenticates with
  a Bearer token, not cookies, so `credentials` is intentionally off).
- A denied origin receives no CORS headers; the API itself still answers —
  only the browser blocks the response.
- Local development needs **no** `CORS_ORIGINS`; leave it unset.

Verify from the browser console of the deployed web app:

```js
await fetch('https://grivio-api.onrender.com/api/health').then(r => r.json());
```

---

## 3. Database (Neon)

- Schema is managed by plain SQL migrations in `backend/migrations/`
  (`001` → `006`), applied in filename order by:
  ```powershell
  npm run migrate          # DATABASE_URL must point at the target DB
  ```
- Migrations are idempotent (`CREATE TABLE IF NOT EXISTS`, guarded
  `ALTER`s), so re-running them is safe.
- Deleting a user cascades to their goals, tasks, sessions and reflections;
  test accounts with `test_…@example.com` are removed by
  `node scripts/cleanup_test_users.js`.

---

## 4. Web app

```powershell
cd webapp
npm install
npm run typecheck          # tsc --noEmit
npm run lint               # eslint
npm run test               # vitest
npm run build              # → dist/
```

Deploy the **`dist/`** folder to any static host.

| Host | Setting |
| --- | --- |
| Vercel / Netlify | build command `npm run build`, output dir `dist`, root `webapp/` |
| GitHub Pages | publish `webapp/dist` (SPA → serve `index.html` for unknown paths) |

`VITE_API_BASE_URL` is **only** needed when the API is *not* the production
Render URL; it must include the `/api` suffix. It is read at build time.

Local preview of a production build:

```powershell
npm run preview -- --port 4173     # serves dist/ → http://localhost:4173
```

---

## 5. Flutter app

The API base URL is baked in **at compile time** (no runtime secrets):

```powershell
flutter run                                            # production (Render) — default
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api   # Android emulator
flutter run --dart-define=API_BASE_URL=http://localhost:5000/api   # iOS simulator
flutter build apk --release --dart-define=API_BASE_URL=https://grivio-api.onrender.com/api
```

Release builds should be created **without** the define (production is the
default) or with the production URL spelled out — never with a localhost or
LAN address.

---

## 6. Post-deploy verification checklist

1. `GET /api/health` → 200, database `ok`.
2. Register + login on the deployed API (web browser dev tools).
3. CORS: a fetch from the deployed web origin succeeds; from an
   unlisted origin it is blocked (expected).
4. Web build loads the production API with no `VITE_API_BASE_URL` set.
5. An AI feature (e.g. *Plan my day*) answers — proves `GROQ_API_KEY` is set.
6. Flutter release build points at the production URL.

## 7. Rollback

Render keeps every deploy: **Dashboard → the service → Deploys →
"Rollback to previous deploy"**, or push a revert commit to `main`. The
database is untouched by rollbacks (migrations are additive).

---

## Current status

| Item | Status |
| --- | --- |
| Backend on Render (`grivio-api.onrender.com`) | ✅ live, auto-deploys from `main` |
| Neon production database + migrations 001–006 | ✅ live |
| CORS allow-list (`CORS_ORIGINS` in `app.js`) | ✅ implemented — set the variable on Render to tighten |
| Web build verified against production API | ✅ |
| Web host (Vercel/Netlify/etc.) | ⬜ pick a host and publish `webapp/dist` |
| Flutter release build | ⬜ `flutter build apk --release` |
