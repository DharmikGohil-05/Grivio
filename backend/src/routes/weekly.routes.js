// Weekly review routes — all JWT-protected; weekStart is a Monday date.
// Ownership is enforced server-side: services filter by req.userId.
const express = require('express');
const router = express.Router();
const weeklyController = require('../controllers/weekly.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.get('/weekly-reviews', authMiddleware, weeklyController.list);
router.get('/weekly-reviews/week/:weekStart', authMiddleware, weeklyController.getWeek);
router.post('/weekly-reviews', authMiddleware, weeklyController.upsert);

module.exports = router;
