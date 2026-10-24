# GRIVIO — Development Workflow

A practical, beginner-friendly day-to-day guide. Commands are for Windows
PowerShell (on macOS/Linux use `npm` instead of `npm.cmd`).

## One-time setup

1. **Backend** — `cd backend; npm install; copy .env.example .env` then fill
   in `DATABASE_URL`, `JWT_SECRET` (and optionally `GROQ_API_KEY`).
2. **Migrate** — `npm run migrate` (idempotent; safe to re-run).
3. **Mobile** — `cd mobile; flutter pub get`.

## Daily loop

```powershell
# Terminal 1 — API on :5000
cd backend
npm.cmd start

# Terminal 2 — app on the emulator
cd mobile
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

`flutter run` supports `r` (hot reload) and `R` (hot restart) in its console.

## Where to change what

| Task | Start here |
| --- | --- |
| New/changed API endpoint | `backend/src/routes` → controller → service (SQL) |
| New validation rule | `backend/src/utils/*Validate.js` (server-side always) |
| New DB column/table | new file in `backend/migrations/` (never edit applied ones) |
| New screen | `mobile/lib/screens/` + wire into navigation |
| New API call from app | service in `mobile/lib/services/` (goes through `ApiClient`) |
| Look & feel | `core/theme/app_theme.dart` (tokens) or `widgets/neumorphic.dart` |

## Before you commit — the checklist

```powershell
# 1. Flutter
cd mobile
flutter analyze        # must stay "No issues found"
flutter test

# 2. Backend smoke suites (each boots its own test server)
cd ../backend
node scripts\auth_smoke_test.js
# …run the suites relevant to what you touched (13 total)

# 3. Never commit secrets
git status             # .env must never appear (it is git-ignored)
```

## Conventions used in this repo

- Responses follow `{ success, message, ... }`; the app maps failures to
  `ApiException` and shows the message.
- Identity comes from the verified JWT (`req.userId`) — never from a request
  body, even in new endpoints.
- AI features are preview-only: generate → edit → explicit confirm → normal
  CRUD call. No AI output is ever persisted directly.
- Weeks start on **Monday** everywhere.
- Comment the *why*, not the *what*.

See [`GIT_WORKFLOW.md`](GIT_WORKFLOW.md) for commit/branch discipline.
