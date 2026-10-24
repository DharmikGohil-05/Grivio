// Milestone service — every operation verifies that the milestone's
// goal belongs to the authenticated user (prevents IDOR: user A must
// never modify user B's milestones by guessing an id).
const { query } = require('../config/db');
const { recalculateProgress } = require('./goal.service');

// Loads the goal id for a milestone and checks ownership in one step.
async function _assertMilestoneOwnership(userId, milestoneId) {
  const result = await query(
    `SELECT m.id, m.goal_id
     FROM milestones m
     JOIN goals g ON g.id = m.goal_id
     WHERE m.id = $1 AND g.user_id = $2`,
    [milestoneId, userId]
  );
  if (result.rowCount === 0) {
    const err = new Error('Milestone not found');
    err.statusCode = 404;
    throw err;
  }
  return result.rows[0];
}

// List milestones of a goal owned by the user, ordered for the timeline.
async function listMilestones(userId, goalId) {
  const goal = await query('SELECT id FROM goals WHERE id = $1 AND user_id = $2', [goalId, userId]);
  if (goal.rowCount === 0) {
    const err = new Error('Goal not found');
    err.statusCode = 404;
    throw err;
  }
  const result = await query(
    'SELECT id, goal_id, title, description, position, status, created_at, updated_at FROM milestones WHERE goal_id = $1 ORDER BY position ASC, created_at ASC',
    [goalId]
  );
  return result.rows;
}

async function createMilestone(userId, goalId, fields) {
  // Ownership: only goals owned by this user may receive milestones.
  const goal = await query('SELECT id FROM goals WHERE id = $1 AND user_id = $2', [goalId, userId]);
  if (goal.rowCount === 0) {
    const err = new Error('Goal not found');
    err.statusCode = 404;
    throw err;
  }

  // Default position: append at the end.
  let position = fields.position;
  if (position === undefined || position === null) {
    const max = await query('SELECT COALESCE(MAX(position), -1) + 1 AS next FROM milestones WHERE goal_id = $1', [goalId]);
    position = max.rows[0].next;
  }

  const result = await query(
    `INSERT INTO milestones (goal_id, title, description, position, status)
     VALUES ($1, $2, $3, $4, 'pending')
     RETURNING id, goal_id, title, description, position, status, created_at, updated_at`,
    [goalId, fields.title.trim(), fields.description ?? null, position]
  );
  await recalculateProgress(goalId);
  return result.rows[0];
}

async function updateMilestone(userId, milestoneId, fields) {
  const m = await _assertMilestoneOwnership(userId, milestoneId);
  const result = await query(
    `UPDATE milestones SET
       title = COALESCE($2, title),
       description = COALESCE($3, description),
       position = COALESCE($4, position),
       status = COALESCE($5, status),
       updated_at = NOW()
     WHERE id = $1
     RETURNING id, goal_id, title, description, position, status, created_at, updated_at`,
    [milestoneId, fields.title ?? null, fields.description ?? null, fields.position ?? null, fields.status ?? null]
  );
  // Milestone state changes goal progress.
  await recalculateProgress(m.goal_id);
  return result.rows[0];
}

async function deleteMilestone(userId, milestoneId) {
  const m = await _assertMilestoneOwnership(userId, milestoneId);
  await query('DELETE FROM milestones WHERE id = $1', [milestoneId]);
  await recalculateProgress(m.goal_id);
  return true;
}

module.exports = { listMilestones, createMilestone, updateMilestone, deleteMilestone };
