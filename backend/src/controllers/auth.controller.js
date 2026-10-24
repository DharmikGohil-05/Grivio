// Auth controller — handles the HTTP layer for register/login/me.
// All business logic lives in auth.service.js; this file only shapes
// the request/response and HTTP status codes.
const authService = require('../services/auth.service');
const { validateRegisterInput, validateLoginInput } = require('../utils/validate');

// POST /api/auth/register
exports.register = async (req, res) => {
  try {
    const errors = validateRegisterInput(req.body ?? {});
    if (errors.length) {
      return res.status(400).json({ success: false, message: errors.join('. ') });
    }

    const { user, token } = await authService.register(req.body);
    return res.status(201).json({ success: true, message: 'Account created', user, token });
  } catch (err) {
    return res
      .status(err.statusCode || 500)
      .json({ success: false, message: err.statusCode ? err.message : 'Server error' });
  }
};

// POST /api/auth/login
exports.login = async (req, res) => {
  try {
    const errors = validateLoginInput(req.body ?? {});
    if (errors.length) {
      return res.status(400).json({ success: false, message: errors.join('. ') });
    }

    const { user, token } = await authService.login(req.body);
    return res.status(200).json({ success: true, message: 'Logged in', user, token });
  } catch (err) {
    return res
      .status(err.statusCode || 500)
      .json({ success: false, message: err.statusCode ? err.message : 'Server error' });
  }
};

// GET /api/auth/me — returns the user identified by the JWT middleware.
exports.me = async (req, res) => {
  try {
    const user = await authService.getCurrentUser(req.userId);
    return res.status(200).json({ success: true, user });
  } catch (err) {
    return res
      .status(err.statusCode || 500)
      .json({ success: false, message: err.statusCode ? err.message : 'Server error' });
  }
};
