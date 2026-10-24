// Reflection controller — daily reflection CRUD (Phase 10).
const reflectionService = require('../services/reflection.service');

function errJson(res, err) {
  return res.status(err.statusCode || 500).json({ success: false, message: err.statusCode ? err.message : 'Server error' });
}

// GET /api/reflections?date=YYYY-MM-DD — reflection for that day (nullable).
exports.getByDate = async (req, res) => {
  try {
    const date = req.query.date;
    if (typeof date !== 'string' || isNaN(Date.parse(date))) {
      return res.status(400).json({ success: false, message: 'Valid date is required' });
    }
    const reflection = await reflectionService.getReflectionByDate(req.userId, date);
    return res.status(200).json({ success: true, reflection });
  } catch (err) { return errJson(res, err); }
};

// POST /api/reflections — upsert today's (or given date's) reflection.
exports.upsert = async (req, res) => {
  try {
    const body = req.body ?? {};
    const date = body.date || new Date().toISOString().substring(0, 10);
    if (isNaN(Date.parse(date))) {
      return res.status(400).json({ success: false, message: 'Invalid date' });
    }
    for (const key of ['wentWell', 'wasDifficult', 'toImprove']) {
      if (body[key] !== undefined && typeof body[key] !== 'string') {
        return res.status(400).json({ success: false, message: `${key} must be text` });
      }
    }
    const reflection = await reflectionService.upsertReflection(req.userId, {
      date,
      wentWell: body.wentWell,
      wasDifficult: body.wasDifficult,
      toImprove: body.toImprove,
    });
    return res.status(200).json({ success: true, message: 'Reflection saved', reflection });
  } catch (err) { return errJson(res, err); }
};
