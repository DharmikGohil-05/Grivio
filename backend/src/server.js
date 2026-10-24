const app = require('./app');
const config = require('./config/env');

const server = app.listen(config.port, () => {
  console.log(`Grivio API listening on port ${config.port}`);
});

process.on('unhandledRejection', (err) => {
  console.error('Unhandled rejection:', err);
  server.close(() => process.exit(1));
});
