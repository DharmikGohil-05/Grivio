/// <reference types="vitest" />
import react from '@vitejs/plugin-react';
import { defineConfig } from 'vite';

// base '/' + SPA rewrites (vercel.json / public/_redirects) let client-side
// routes work on direct reload; no server-side config is required.
export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'node',
    include: ['src/**/*.test.ts'],
  },
});
