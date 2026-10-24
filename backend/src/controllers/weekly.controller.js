// Weekly review controller — thin HTTP layer over weekly.service.
const weeklyService = require('../services/weekly.service');

// Shared error responder: err.statusCode (set by services for expected
// problems) becomes the HTTP status; anything else is treated as an
// unexpected bug and reported as a generic 500 so internals never leak.
function errJson(res, err) {
  return res.status(err.statusCode || 500).json({ success: false, message: err.statusCode ? err.message : 'Server error' });
}

// GET /api/weekly-reviews — list own reviews (no stats).
exports.list = async (req, res) => {
  try {
    const reviews = await weeklyService.listReviews(req.userId);
    return res.status(200).json({ success: true, reviews });
  } catch (err) { return errJson(res, err); }
};

// GET /api/weekly-reviews/week/:weekStart — review (nullable) + real stats.
exports.getWeek = async (req, res) => {
  try {
    const stats = await weeklyService.weekStats(req.userId, req.params.weekStart);
    const review = await weeklyService.getReview(req.userId, req.params.weekStart);
    return res.status(200).json({ success: true, stats, review });
  } catch (err) { return errJson(res, err); }
};

// POST /api/weekly-reviews — upsert the review for that week.
exports.upsert = async (req, res) => {
  try {
    const body = req.body ?? {};
    if (typeof body.weekStart !== 'string') {
      return res.status(400).json({ success: false, message: 'weekStart is required' });
    }
    // weekStart's format (and that it is a Monday) is validated in the
    // service; here we only make sure the free-text fields really are text
    // before they reach the database.
    for (const [key, val] of Object.entries(body)) {
      if (['biggestWin', 'needsAttention', 'nextWeekFocus', 'summary'].includes(key) && typeof val !== 'string' && val != null) {
        return res.status(400).json({ success: false, message: `${key} must be text` });
      }
    }
    const review = await weeklyService.upsertReview(req.userId, body);
    return res.status(200).json({ success: true, message: 'Review saved', review });
  } catch (err) { return errJson(res, err); }
};
