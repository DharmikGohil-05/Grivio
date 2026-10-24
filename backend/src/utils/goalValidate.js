// Goal/milestone input validation — fixed allowed values for
// status/priority-style fields so only safe strings reach the DB.

const GOAL_STATUSES = ['active', 'completed', 'archived'];
const MILESTONE_STATUSES = ['pending', 'in_progress', 'completed'];

function validateGoalInput(body) {
  const errors = [];
  if (typeof body.name !== 'string' || !body.name.trim()) errors.push('Goal name is required');
  else if (body.name.trim().length > 160) errors.push('Goal name must be 160 characters or fewer');

  if (body.growthArea !== undefined && body.growthArea !== null && typeof body.growthArea !== 'string') {
    errors.push('Growth area must be text');
  }
  if (body.targetDate !== undefined && body.targetDate !== null && isNaN(Date.parse(body.targetDate))) {
    errors.push('Target date must be a valid date');
  }
  if (body.status !== undefined && !GOAL_STATUSES.includes(body.status)) {
    errors.push(`Status must be one of: ${GOAL_STATUSES.join(', ')}`);
  }
  return errors;
}

function validateMilestoneInput(body) {
  const errors = [];
  if (typeof body.title !== 'string' || !body.title.trim()) errors.push('Milestone title is required');
  else if (body.title.trim().length > 160) errors.push('Milestone title must be 160 characters or fewer');

  if (body.position !== undefined && (!Number.isInteger(body.position) || body.position < 0)) {
    errors.push('Position must be a non-negative integer');
  }
  if (body.status !== undefined && !MILESTONE_STATUSES.includes(body.status)) {
    errors.push(`Status must be one of: ${MILESTONE_STATUSES.join(', ')}`);
  }
  return errors;
}

module.exports = { validateGoalInput, validateMilestoneInput, GOAL_STATUSES, MILESTONE_STATUSES };
