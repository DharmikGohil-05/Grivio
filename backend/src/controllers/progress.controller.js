// Progress controller — serves the aggregated personal performance report.
// Identity comes from the JWT middleware; no user_id is accepted from the
// client, so cross-user access is impossible.
const progressService = require('../services/progress.service');

exports.get = async (req, res) => {
  try {
    const range = req.query.range || 'week';
    const data = await progressService.getProgress(req.userId, range);
    return res.status(200).json({ success: true, ...data });
  } catch (err) {
    return res.status(err.statusCode || 500).json({ success: false, message: err.statusCode ? err.message : 'Server error' });
  }
};
