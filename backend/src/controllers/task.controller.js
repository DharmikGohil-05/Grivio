// Task controller — thin HTTP layer over task.service.
const taskService = require('../services/task.service');
const { validateTaskInput } = require('../utils/taskValidate');

function errJson(res, err) {
  return res.status(err.statusCode || 500).json({ success: false, message: err.statusCode ? err.message : 'Server error' });
}

exports.list = async (req, res) => {
  try {
    const tasks = await taskService.listTasks(req.userId, {
      status: req.query.status,
      priority: req.query.priority,
      category: req.query.category,
      goalId: req.query.goalId,
      milestoneId: req.query.milestoneId,
      date: req.query.date,
    });
    return res.status(200).json({ success: true, tasks });
  } catch (err) { return errJson(res, err); }
};

exports.getOne = async (req, res) => {
  try {
    const task = await taskService.getTask(req.userId, req.params.id);
    return res.status(200).json({ success: true, task });
  } catch (err) { return errJson(res, err); }
};

exports.create = async (req, res) => {
  try {
    const errors = validateTaskInput(req.body ?? {});
    if (errors.length) return res.status(400).json({ success: false, message: errors.join('. ') });
    const task = await taskService.createTask(req.userId, req.body);
    return res.status(201).json({ success: true, message: 'Task created', task });
  } catch (err) { return errJson(res, err); }
};

exports.update = async (req, res) => {
  try {
    if (req.body.title !== undefined && (typeof req.body.title !== 'string' || !req.body.title.trim())) {
      return res.status(400).json({ success: false, message: 'Title cannot be empty' });
    }
    const task = await taskService.updateTask(req.userId, req.params.id, req.body);
    return res.status(200).json({ success: true, message: 'Task updated', task });
  } catch (err) { return errJson(res, err); }
};

exports.setStatus = async (req, res) => {
  try {
    const { status } = req.body ?? {};
    if (!['pending', 'in_progress', 'completed', 'cancelled'].includes(status)) {
      return res.status(400).json({ success: false, message: 'Invalid status' });
    }
    const task = await taskService.setTaskStatus(req.userId, req.params.id, status);
    return res.status(200).json({ success: true, message: 'Status updated', task });
  } catch (err) { return errJson(res, err); }
};

exports.remove = async (req, res) => {
  try {
    await taskService.deleteTask(req.userId, req.params.id);
    return res.status(200).json({ success: true, message: 'Task deleted' });
  } catch (err) { return errJson(res, err); }
};
