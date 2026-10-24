// Focus session controller — thin HTTP layer over focus.service.
const focusService = require('../services/focus.service');

function errJson(res, err) {
  return res.status(err.statusCode || 500).json({ success: false, message: err.statusCode ? err.message : 'Server error' });
}

exports.start = async (req, res) => {
  try {
    const session = await focusService.startSession(req.userId, req.body?.task_id ?? null);
    return res.status(201).json({ success: true, message: 'Session started', session });
  } catch (err) { return errJson(res, err); }
};

exports.pause = async (req, res) => {
  try {
    const session = await focusService.pauseSession(req.userId, req.params.id);
    return res.status(200).json({ success: true, session });
  } catch (err) { return errJson(res, err); }
};

exports.resume = async (req, res) => {
  try {
    const session = await focusService.resumeSession(req.userId, req.params.id);
    return res.status(200).json({ success: true, session });
  } catch (err) { return errJson(res, err); }
};

exports.complete = async (req, res) => {
  try {
    const session = await focusService.completeSession(req.userId, req.params.id, {
      rating: req.body?.productivity_rating,
      reflection: req.body?.reflection,
    });
    return res.status(200).json({ success: true, message: 'Session completed', session });
  } catch (err) { return errJson(res, err); }
};

exports.cancel = async (req, res) => {
  try {
    const session = await focusService.cancelSession(req.userId, req.params.id);
    return res.status(200).json({ success: true, message: 'Session cancelled', session });
  } catch (err) { return errJson(res, err); }
};

exports.list = async (req, res) => {
  try {
    const sessions = await focusService.listSessions(req.userId);
    return res.status(200).json({ success: true, sessions });
  } catch (err) { return errJson(res, err); }
};

exports.getOne = async (req, res) => {
  try {
    const session = await focusService.getSession(req.userId, req.params.id);
    return res.status(200).json({ success: true, session });
  } catch (err) { return errJson(res, err); }
};

// PATCH /api/focus/sessions/:id — attach rating/reflection after completion.
exports.updateExtras = async (req, res) => {
  try {
    const session = await focusService.updateSessionExtras(req.userId, req.params.id, {
      rating: req.body?.productivity_rating,
      reflection: req.body?.reflection,
    });
    return res.status(200).json({ success: true, session });
  } catch (err) { return errJson(res, err); }
};
