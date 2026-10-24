// Reflection routes — daily reflection, JWT-protected; ownership is
// enforced server-side: services filter by req.userId.
const express = require('express');
const router = express.Router();
const reflectionController = require('../controllers/reflection.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.get('/reflections', authMiddleware, reflectionController.getByDate);
router.post('/reflections', authMiddleware, reflectionController.upsert);

module.exports = router;
