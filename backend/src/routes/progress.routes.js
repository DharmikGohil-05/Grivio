// Progress route — GET /api/progress?range=week|month|3months
// JWT-protected; the caller's identity comes from the token, and the
// service scopes every query to that user id.
const express = require('express');
const router = express.Router();
const progressController = require('../controllers/progress.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.get('/progress', authMiddleware, progressController.get);

module.exports = router;
