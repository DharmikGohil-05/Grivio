// Goal controller — thin HTTP layer over goal.service.
const goalService = require('../services/goal.service');
const { validateGoalInput } = require('../utils/goalValidate');

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
