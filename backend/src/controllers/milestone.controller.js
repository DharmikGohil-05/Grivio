// Milestone controller — thin HTTP layer over milestone.service.
const milestoneService = require('../services/milestone.service');
const { validateMilestoneInput } = require('../utils/goalValidate');

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
    // Statuses mirror the milestone CHECK constraint in migrations/001, so
    // a bad value gets a clean 400 instead of a SQL error.
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
