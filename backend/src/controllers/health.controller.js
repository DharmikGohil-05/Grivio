// POST /api/health controller.
// Reports whether the API is up AND whether the database is reachable.
// Never leaks credentials, internal errors, or secrets to clients.
const { checkConnection } = require('../config/db');

exports.healthCheck = async (req, res) => {
  let database = 'disconnected';
  try {
    await checkConnection();
    database = 'connected';
  } catch {
    // DB may simply not be configured yet; the API still reports itself.
  }

  res.status(200).json({
    success: true,
    message: 'Grivio API is running',
    database,
  });
};
