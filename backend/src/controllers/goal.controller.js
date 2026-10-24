// Goal controller — thin HTTP layer over goal.service.
const goalService = require('../services/goal.service');
const { validateGoalInput } = require('../utils/goalValidate');

// Shared error responder: err.statusCode (set by services for expected
// problems) becomes the HTTP status; anything else is treated as an
// unexpected bug and reported as a generic 500 so internals never leak.
function errJson(res, err) {
  return res
    .status(err.statusCode || 500)
    .json({ success: false, message: err.statusCode ? err.message : 'Server error' });
}

exports.list = async (req, res) => {
  try {
    const goals = await goalService.listGoals(req.userId, req.query.status);
    return res.status(200).json({ success: true, goals });
  } catch (err) {
    return errJson(res, err);
  }
};

exports.getOne = async (req, res) => {
  try {
    const goal = await goalService.getGoal(req.userId, req.params.id);
    return res.status(200).json({ success: true, goal });
  } catch (err) {
    return errJson(res, err);
  }
};

exports.create = async (req, res) => {
  try {
    const errors = validateGoalInput(req.body ?? {});
    if (errors.length) {
      return res.status(400).json({ success: false, message: errors.join('. ') });
    }
    const goal = await goalService.createGoal(req.userId, req.body);
    return res.status(201).json({ success: true, message: 'Goal created', goal });
  } catch (err) {
    return errJson(res, err);
  }
};

exports.update = async (req, res) => {
  try {
    // Updates are partial, so only name/status are type-checked here —
    // the other columns are optional free text. The service ignores any
    // field that was not sent (COALESCE keeps the stored value).
    if (req.body.name !== undefined && (typeof req.body.name !== 'string' || !req.body.name.trim())) {
      return res.status(400).json({ success: false, message: 'Name cannot be empty' });
    }
    if (req.body.status !== undefined && !['active', 'completed', 'archived'].includes(req.body.status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }
    const goal = await goalService.updateGoal(req.userId, req.params.id, req.body);
    return res.status(200).json({ success: true, message: 'Goal updated', goal });
  } catch (err) {
    return errJson(res, err);
  }
};

exports.remove = async (req, res) => {
  try {
    await goalService.deleteGoal(req.userId, req.params.id);
    return res.status(200).json({ success: true, message: 'Goal deleted' });
  } catch (err) {
    return errJson(res, err);
  }
};
