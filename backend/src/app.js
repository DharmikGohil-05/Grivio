// Express app assembly. This file does NOT call listen() — server.js
// owns the port — so tests can import the same app and bind it to a
// different (test) port.
const express = require('express');
const cors = require('cors');

const healthRoutes = require('./routes/health.routes');
const authRoutes = require('./routes/auth.routes');
const profileRoutes = require('./routes/profile.routes');
const goalRoutes = require('./routes/goal.routes');
const taskRoutes = require('./routes/task.routes');
const focusRoutes = require('./routes/focus.routes');
const progressRoutes = require('./routes/progress.routes');
const weeklyRoutes = require('./routes/weekly.routes');
const reflectionRoutes = require('./routes/reflection.routes');
const aiRoutes = require('./routes/ai.routes');
const notFound = require('./middleware/notFound');
const errorHandler = require('./middleware/errorHandler');
const config = require('./config/env');

const app = express();

// CORS policy:
//   - CORS_ORIGINS set (production)  → strict allow-list of browser origins.
//   - CORS_ORIGINS empty (dev)       → permissive, so emulators, the Vite
//                                      dev server and curl just work.
// Requests without an Origin header (curl, the Flutter app, server-to-
// server calls) are never subject to CORS and are always allowed — only
// browsers enforce it. A disallowed origin simply gets no CORS headers,
// so the browser blocks the response; the API itself is unaffected.
const corsOptions = config.corsOrigins.length
  ? {
      origin(origin, callback) {
        // Trailing slashes are stripped on both sides so an entry like
        // "https://app.example.com/" matches the Origin "https://app.example.com".
        const allowed = !origin || config.corsOrigins.includes(origin.replace(/\/+$/, ''));
        callback(null, allowed);
      },
      allowedHeaders: ['Content-Type', 'Authorization'],
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
    }
  : {};

// Middleware order matters:
// 1) express.json() first so every route below sees a parsed req.body.
// 2) cors() next so CORS headers are attached to every response,
//    including error responses.
app.use(express.json());

// CORS sits after express.json() so its headers are attached to every
// response — including errors — while bodies still parse for all routes.
app.use(cors(corsOptions));

// Health is public; every other router applies authMiddleware per-route.
// Note: goal/task/focus/... routers define their own full paths
// (e.g. /goals), which is why they mount directly on '/api'.
app.use('/api/health', healthRoutes);
app.use('/api/auth', authRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api', goalRoutes);
app.use('/api', taskRoutes);
app.use('/api', focusRoutes);
app.use('/api', progressRoutes);
app.use('/api', weeklyRoutes);
app.use('/api', reflectionRoutes);
app.use('/api', aiRoutes);
// notFound must come AFTER every route: anything not matched above falls
// through to it and still returns the standard JSON envelope.
// errorHandler goes LAST: Express only runs 4-argument error middleware
// when next(err) is called, and only from handlers registered before it.
app.use(notFound);
app.use(errorHandler);

module.exports = app;
