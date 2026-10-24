// Profile controller — handles HTTP for /api/profile.
// The authenticated user id comes from authMiddleware (req.userId);
// we deliberately ignore any user_id sent by the client.
const profileService = require('../services/profile.service');
const { validateProfileInput } = require('../utils/profileValidate');

// GET /api/profile — return the caller's own profile.
exports.getProfile = async (req, res) => {
  try {
    const profile = await profileService.getProfile(req.userId);
    return res.status(200).json({ success: true, profile });
  } catch (err) {
    return res
      .status(err.statusCode || 500)
      .json({ success: false, message: err.statusCode ? err.message : 'Server error' });
  }
};

// PUT /api/profile — create/update the caller's own profile.
exports.updateProfile = async (req, res) => {
  try {
    const errors = validateProfileInput(req.body ?? {});
    if (errors.length) {
      return res.status(400).json({ success: false, message: errors.join('. ') });
    }

    const profile = await profileService.upsertProfile(req.userId, req.body);
    return res.status(200).json({ success: true, message: 'Profile updated', profile });
  } catch (err) {
    return res
      .status(err.statusCode || 500)
      .json({ success: false, message: err.statusCode ? err.message : 'Server error' });
  }
};
