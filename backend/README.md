# Grivio Backend

Node.js + Express API for Grivio.

## Scripts

```bash
npm install
npm start      # production-style start
npm run dev    # nodemon with auto-reload
```

## Endpoints

- `GET /api/health` — health check

## Environment

Copy `.env.example` to `.env` and fill in values:

- `PORT`
- `DATABASE_URL`
- `JWT_SECRET`
- `GROQ_API_KEY`

`.env` is git-ignored. Never commit secrets.

## Structure

```
src/
├── config/        # environment configuration
├── controllers/   # request handlers
├── middleware/    # error handling, 404
├── models/        # (Phase 2)
├── routes/        # route definitions
├── services/      # (Phase 11+) Groq AI
├── utils/         # helpers
├── app.js
└── server.js
```
