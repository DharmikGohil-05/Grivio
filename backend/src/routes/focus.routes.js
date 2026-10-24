// Focus session routes — all JWT-protected; ownership enforced in service.
const express = require('express');
const router = express.Router();
const focusController = require('../controllers/focus.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.post('/focus/sessions', authMiddleware, focusController.start);
router.get('/focus/sessions', authMiddleware, focusController.list);
router.get('/focus/sessions/:id', authMiddleware, focusController.getOne);
router.patch('/focus/sessions/:id', authMiddleware, focusController.updateExtras);
router.patch('/focus/sessions/:id/pause', authMiddleware, focusController.pause);
router.patch('/focus/sessions/:id/resume', authMiddleware, focusController.resume);
router.patch('/focus/sessions/:id/complete', authMiddleware, focusController.complete);
router.patch('/focus/sessions/:id/cancel', authMiddleware, focusController.cancel);

module.exports = router;
