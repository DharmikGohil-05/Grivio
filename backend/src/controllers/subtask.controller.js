// Subtask controller — thin HTTP layer over subtask.service.
const subtaskService = require('../services/subtask.service');

function errJson(res, err) {
  return res.status(err.statusCode || 500).json({ success: false, message: err.statusCode ? err.message : 'Server error' });
}

exports.list = async (req, res) => {
  try {
    const subtasks = await subtaskService.listSubtasks(req.userId, req.params.taskId);
    return res.status(200).json({ success: true, subtasks });
  } catch (err) { return errJson(res, err); }
};

exports.create = async (req, res) => {
  try {
    const title = req.body?.title;
    if (typeof title !== 'string' || !title.trim()) {
      return res.status(400).json({ success: false, message: 'Title is required' });
    }
    const subtask = await subtaskService.createSubtask(req.userId, req.params.taskId, req.body);
    return res.status(201).json({ success: true, message: 'Subtask created', subtask });
  } catch (err) { return errJson(res, err); }
};

exports.update = async (req, res) => {
  try {
    const subtask = await subtaskService.updateSubtask(req.userId, req.params.id, req.body ?? {});
    return res.status(200).json({ success: true, message: 'Subtask updated', subtask });
  } catch (err) { return errJson(res, err); }
};

exports.remove = async (req, res) => {
  try {
    await subtaskService.deleteSubtask(req.userId, req.params.id);
    return res.status(200).json({ success: true, message: 'Subtask deleted' });
  } catch (err) { return errJson(res, err); }
};
