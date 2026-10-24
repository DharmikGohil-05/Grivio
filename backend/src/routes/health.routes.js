// Health route — deliberately PUBLIC (no authMiddleware) so uptime
// monitors and developers can probe the API without credentials.
const express = require('express');
const router = express.Router();

const { healthCheck } = require('../controllers/health.controller');

router.get('/', healthCheck);

module.exports = router;
