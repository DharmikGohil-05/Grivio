# Grivio

Grivio is a professional personal-growth and productivity mobile application.

Core philosophy:

Goal → Milestone → Task → Focus → Progress → Reflection → Improvement

## Technology stack

| Layer     | Technology                    |
| --------- | ----------------------------- |
| Mobile    | Flutter                       |
| Backend   | Node.js + Express             |
| Database  | PostgreSQL (Phase 2+)         |
| AI        | Groq API (via backend, Phase 11+) |
| Hosting   | Render (Phase 16)             |

## Project structure

```
grivio/
├── mobile/          # Flutter application
├── backend/         # Node.js + Express API
├── .gitignore
└── README.md
```

## Running the backend (development)

```bash
cd backend
npm install
cp .env.example .env   # fill in values later; none needed for /api/health
npm run dev            # or: npm start
```

Health check:

```bash
curl http://localhost:5000/api/health
```

Expected:

```json
{ "success": true, "message": "Grivio API is running" }
```

## Running the mobile app

```bash
cd mobile
flutter pub get
flutter run
```

The API base URL is injected via `--dart-define`:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000/api
```

(Android emulator uses `10.0.2.2`; iOS simulator can use `localhost`.)

## Environment variables

Defined in `backend/.env.example`:

- `PORT`
- `DATABASE_URL`
- `JWT_SECRET`
- `GROQ_API_KEY`

No real values yet — secrets are never committed.

## Current development phase

**Phase 1 — Project foundation + architecture.**

Implemented:

- Flutter project with Grivio identity, light/dark theme foundation, Inter typography
- Express backend with `GET /api/health`, CORS, JSON parsing, error handling
- Environment variable template, `.gitignore` rules, documentation

Not yet implemented: authentication, PostgreSQL, profile, goals, tasks,
focus, progress, reflections, Groq AI, Render deployment.
