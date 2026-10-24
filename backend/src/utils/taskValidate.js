// Task input validation — ownership of goal/milestone is verified in the
// service layer so a task can never be linked to someone else's data.

const PRIORITIES = ['low', 'medium', 'high'];
const TASK_STATUSES = ['pending', 'in_progress', 'completed', 'cancelled'];

function validateTaskInput(body) {
  const errors = [];
  if (typeof body.title !== 'string' || !body.title.trim()) errors.push('Title is required');
  else if (body.title.trim().length > 200) errors.push('Title must be 200 characters or fewer');

  if (body.description !== undefined && body.description !== null && typeof body.description !== 'string') {
    errors.push('Description must be text');
  }
  if (body.priority !== undefined && !PRIORITIES.includes(body.priority)) {
    errors.push(`Priority must be one of: ${PRIORITIES.join(', ')}`);
  }
  if (body.status !== undefined && !TASK_STATUSES.includes(body.status)) {
    errors.push(`Status must be one of: ${TASK_STATUSES.join(', ')}`);
  }
  if (body.estimatedMinutes !== undefined && body.estimatedMinutes !== null) {
    const n = Number(body.estimatedMinutes);
    if (!Number.isFinite(n) || n <= 0 || n > 100000) errors.push('Estimated duration must be a positive number');
  }
  if (body.dueDate !== undefined && body.dueDate !== null && isNaN(Date.parse(body.dueDate))) {
    errors.push('Due date must be a valid date');
  }
  return errors;
}

module.exports = { validateTaskInput, PRIORITIES, TASK_STATUSES };
