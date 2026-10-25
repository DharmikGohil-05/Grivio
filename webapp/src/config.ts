// Central runtime configuration.
//
// The API base URL is resolved in this order:
//   1. VITE_API_BASE_URL (a Vite env var — set it on the host when the API
//      ever moves; it must be the URL *with* the /api suffix).
//   2. The production GRIVIO API on Render — the default, so a plain
//      `npm run dev` or a deployed build talks to the real backend with no
//      configuration and never to localhost.
//
// SECURITY: this client holds no server secrets. JWT_SECRET, DATABASE_URL
// and GROQ_API_KEY exist only on the backend; the browser only ever sees
// the user's own login token.
export const API_BASE_URL: string =
  (import.meta.env.VITE_API_BASE_URL as string | undefined)?.replace(/\/+$/, '') ||
  'https://grivio-api.onrender.com/api';

export const APP_NAME = 'GRIVIO';

// localStorage keys used by the web client (namespaced to avoid clashes).
export const STORAGE_KEYS = {
  token: 'grivio_web_token',
  theme: 'grivio_web_theme',
} as const;
