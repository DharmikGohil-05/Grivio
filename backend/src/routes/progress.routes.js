// Progress route — GET /api/progress?range=week|month|3months
const express = require('express');
const router = express.Router();
const progressController = require('../controllers/progress.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.get('/progress', authMiddleware, progressController.get);

module.exports = router;
