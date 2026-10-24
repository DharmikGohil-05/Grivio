// Milestone controller — thin HTTP layer over milestone.service.
const milestoneService = require('../services/milestone.service');
const { validateMilestoneInput } = require('../utils/goalValidate');

function errJson(res, err) {
  return res
    .status(err.statusCode || 500)
    .json({ success: false, message: err.statusCode ? err.message : 'Server error' });
}

exports.list = async (req, res) => {
  try {
    const milestones = await milestoneService.listMilestones(req.userId, req.params.goalId);
    return res.status(200).json({ success: true, milestones });
  } catch (err) {
    return errJson(res, err);
  }
};

exports.create = async (req, res) => {
  try {
    const errors = validateMilestoneInput(req.body ?? {});
    if (errors.length) {
      return res.status(400).json({ success: false, message: errors.join('. ') });
    }
    const milestone = await milestoneService.createMilestone(req.userId, req.params.goalId, req.body);
    return res.status(201).json({ success: true, message: 'Milestone created', milestone });
  } catch (err) {
    return errJson(res, err);
  }
};

exports.update = async (req, res) => {
  try {
    if (req.body.status !== undefined && !['pending', 'in_progress', 'completed'].includes(req.body.status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }
    const milestone = await milestoneService.updateMilestone(req.userId, req.params.id, req.body);
    return res.status(200).json({ success: true, message: 'Milestone updated', milestone });
  } catch (err) {
    return errJson(res, err);
  }
};

exports.remove = async (req, res) => {
  try {
    await milestoneService.deleteMilestone(req.userId, req.params.id);
    return res.status(200).json({ success: true, message: 'Milestone deleted' });
  } catch (err) {
    return errJson(res, err);
  }
};
