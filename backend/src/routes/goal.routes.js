// Goal and milestone routes. All require a valid JWT.
// Milestones are nested under the owning goal for creation/listing;
// direct milestone edit/delete goes through /api/milestones/:id.
const express = require('express');
const router = express.Router();
const goalController = require('../controllers/goal.controller');
const milestoneController = require('../controllers/milestone.controller');
const authMiddleware = require('../middleware/auth.middleware');

// Goals
router.get('/goals', authMiddleware, goalController.list);
router.post('/goals', authMiddleware, goalController.create);
router.get('/goals/:id', authMiddleware, goalController.getOne);
router.put('/goals/:id', authMiddleware, goalController.update);
router.delete('/goals/:id', authMiddleware, goalController.remove);

// Milestones nested under a goal
router.get('/goals/:goalId/milestones', authMiddleware, milestoneController.list);
router.post('/goals/:goalId/milestones', authMiddleware, milestoneController.create);

// Milestones direct edit/delete
router.put('/milestones/:id', authMiddleware, milestoneController.update);
router.delete('/milestones/:id', authMiddleware, milestoneController.remove);

module.exports = router;
