// AI routes — JWT-protected. The only AI endpoint in Phase 11 is a minimal
// test/health endpoint; feature-specific AI endpoints arrive in later phases.
const express = require('express');
const router = express.Router();
const aiController = require('../controllers/ai.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.post('/ai/test', authMiddleware, aiController.test);
router.post('/ai/subtasks/generate', authMiddleware, aiController.generateSubtasks);
router.post('/ai/tasks/improve', authMiddleware, aiController.improveTask);
router.post('/ai/breakdown/generate', authMiddleware, aiController.generateBreakdown);
router.post('/ai/daily-plan/generate', authMiddleware, aiController.generateDailyPlan);
router.post('/ai/weekly-review/generate', authMiddleware, aiController.generateWeeklyReview);

module.exports = router;
