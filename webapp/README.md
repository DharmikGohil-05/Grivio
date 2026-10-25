# GRIVIO Web

The GRIVIO web client — a complete, production-ready single-page app for the
GRIVIO personal-growth backend. Login/onboarding, home dashboard, goals &
milestones, tasks & subtasks, focus timer with recovery & reflection,
progress charts, weekly reviews, profile/settings, Light/Dark/System themes,
and all five AI features (preview-only generation with confirm-before-create).

Built with Vite + React 18 + TypeScript (strict) + react-router-dom 6.
Styled with a hand-rolled neumorphic design system (CSS custom properties +
inline SVG icons/charts — no UI, chart, or icon dependencies). Tokens mirror
the Flutter app's `app_theme.dart`, so web and mobile share one visual
language.

## Backend

Everything is real data from the live API:

- **Production backend (default):** `https://grivio-api.onrender.com/api`
- No configuration needed — `npm run dev` and any deployed build talk to the
  real backend out of the box. The client never points at localhost unless
  you explicitly override `VITE_API_BASE_URL`.
- CORS is fully permissive on the backend (`Access-Control-Allow-Origin: *`,
  verified against the live Render deployment), so no proxy or backend
  change is required.

### Environment variables

| Variable           | Where            | Required | Purpose                                                                                         |
| ------------------ | ---------------- | -------- | ----------------------------------------------------------------------------------------------- |
| `VITE_API_BASE_URL` | Build host (Vercel/Netlify/etc.) | No | Override the API base URL. Must include the `/api` suffix. Defaults to the Render production API. |

No secrets exist in this client. `JWT_SECRET`, `DATABASE_URL`, and
`GROQ_API_KEY` live only on the backend; the browser only ever sees the
user's own login token (stored in `localStorage` under `grivio_web_token`).

## Commands

```bash
npm install        # install dependencies
npm run dev        # start dev server (Vite; prints the local URL)
npm run typecheck  # TypeScript strict check (tsc --noEmit)
npm run lint       # ESLint
npm test           # Vitest unit tests
npm run build      # typecheck + production build to dist/
npm run preview    # serve the production build locally (port 4173)
```

All green as of this build: typecheck ✅ · lint (0 problems) ✅ · tests 8/8 ✅ ·
production build ✅ (~246 kB JS / ~74 kB gzip, ~13 kB CSS).

## Deployment

The SPA is host-agnostic. Both major hosts are pre-configured:

- **Vercel** — `vercel.json` rewrites all routes to `index.html`.
- **Netlify** — `public/_redirects` serves the SPA fallback.

Deploy steps (either host):

1. Push the `webapp/` folder to your repo (or point the host at it as the
   root directory).
2. Set the build command to `npm run build` and the output directory to
   `dist`.
3. (Optional) Set `VITE_API_BASE_URL` if the API base ever changes —
   otherwise the Render production API is used automatically.
4. Deploy. Client-side routing works out of the box via the included
   rewrites; no server config is needed.

## Project structure

```
webapp/
├── public/
│   ├── grivio_logo.png      # actual GRIVIO logo asset
│   └── _redirects           # Netlify SPA fallback
├── src/
│   ├── api/                 # typed API client + endpoint functions
│   ├── components/          # neumorphic UI kit (buttons, cards, inputs…) + inline SVG icons
│   ├── pages/               # Login, Register, Setup, Home, Tasks, TaskDetail,
│   │                        # Goals, GoalDetail, Focus, ProgressPage, WeeklyReview, Profile
│   ├── styles.css           # design system (CSS custom properties, light/dark themes)
│   ├── charts.tsx           # hand-rolled SVG charts (no chart library)
│   ├── config.ts            # API base URL + localStorage keys
│   ├── types.ts             # shared API types (camelCase request / snake_case response)
│   ├── AuthContext.tsx      # login/register/token bootstrap
│   ├── ThemeContext.tsx     # Light/Dark/System with persistence
│   └── App.tsx              # router + auth/setup guards
├── vercel.json              # Vercel SPA rewrites
└── vite.config.ts           # Vite + Vitest config
```

## Notes

- **AI features** (Plan My Day, AI Assist, Improve, Goal Breakdown, Growth
  Review) are wired to the backend but intentionally **preview-only**: the
  UI shows what AI proposes and only creates items after explicit
  confirmation. Generating a preview makes a real (billable) Groq call —
  keep it out of automated tests.
- **Focus timer** math mirrors the mobile app: elapsed time is computed from
  server timestamps (`started_at`, `paused_at`, `total_pause_seconds`), never
  from a local counter, so recovery after a refresh or crash is accurate.
- **API contract** quirk worth knowing: request bodies are camelCase,
  responses are snake_case — the client's typed mappers handle the
  translation in one place (`src/api/`).
