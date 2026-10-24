// Task + subtask routes — all JWT-protected; ownership is enforced in
// the service layer via req.userId.
const express = require('express');
const router = express.Router();
const taskController = require('../controllers/task.controller');
const subtaskController = require('../controllers/subtask.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.get('/tasks', authMiddleware, taskController.list);
router.post('/tasks', authMiddleware, taskController.create);
router.get('/tasks/:id', authMiddleware, taskController.getOne);
router.put('/tasks/:id', authMiddleware, taskController.update);
router.delete('/tasks/:id', authMiddleware, taskController.remove);
router.patch('/tasks/:id/status', authMiddleware, taskController.setStatus);

router.get('/tasks/:taskId/subtasks', authMiddleware, subtaskController.list);
router.post('/tasks/:taskId/subtasks', authMiddleware, subtaskController.create);
router.put('/subtasks/:id', authMiddleware, subtaskController.update);
router.delete('/subtasks/:id', authMiddleware, subtaskController.remove);

module.exports = router;
