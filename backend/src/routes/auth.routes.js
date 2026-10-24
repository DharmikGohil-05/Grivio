// Auth routes:
//   POST /api/auth/register  — create account
//   POST /api/auth/login     — issue JWT
//   GET  /api/auth/me        — current user (protected)
const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const authMiddleware = require('../middleware/auth.middleware');

router.post('/register', authController.register);
router.post('/login', authController.login);
router.get('/me', authMiddleware, authController.me);

// Logout is client-side (delete the stored token) — JWT is stateless.
// Documented here so the design is easy to extend with refresh tokens later.
router.post('/logout', (req, res) => {
  res.status(200).json({ success: true, message: 'Logged out. Discard the token on the client.' });
});

module.exports = router;
