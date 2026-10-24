// Server entry point. Deliberately does NOT check the database before
// listening: the API can boot while Postgres is still starting (common on
// cloud/dev setups) and report the real state through GET /api/health
// instead of crashing on startup.
const app = require('./app');
const config = require('./config/env');

const server = app.listen(config.port, () => {
  console.log(`Grivio API listening on port ${config.port}`);
});

// A rejected promise nobody awaited (e.g. a failed query in the
// background) would normally crash Node with little context. Log it, stop
// accepting new connections, then exit non-zero so the process manager
// restarts a clean instance instead of leaving a half-broken server up.
process.on('unhandledRejection', (err) => {
  console.error('Unhandled rejection:', err);
  server.close(() => process.exit(1));
});
