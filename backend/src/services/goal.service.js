// Goal service — all goal business logic. Every query is scoped by
// the JWT-derived userId so users can only touch their own goals.
const { query } = require('../config/db');

// Goal list: each goal also gets its real milestone counts and computed
// progress (accurate count from milestones, not trusting the column alone).
async function listGoals(userId, statusFilter) {
  const params = [userId];
  let where = 'g.user_id = $1';
  if (statusFilter) {
    params.push(statusFilter);
    where += ` AND g.status = $${params.length}`;
  }
  const result = await query(
    `SELECT g.id, g.name, g.description, g.why_it_matters, g.growth_area,
            g.target_date, g.status, g.progress, g.created_at, g.updated_at,
            COUNT(m.id)::int AS milestone_count,
            COUNT(m.id) FILTER (WHERE m.status = 'completed')::int AS completed_milestones
     FROM goals g
     -- LEFT JOIN (not JOIN): goals with zero milestones still appear,
     -- with their counts at 0 instead of vanishing from the list.
     LEFT JOIN milestones m ON m.goal_id = g.id
     WHERE ${where}
     GROUP BY g.id
     ORDER BY g.created_at DESC`,
    params
  );
  return result.rows;
}

// One goal, but only if it belongs to this user.
async function getGoal(userId, goalId) {
  const result = await query(
    `SELECT g.id, g.name, g.description, g.why_it_matters, g.growth_area,
            g.target_date, g.status, g.progress, g.created_at, g.updated_at,
            COUNT(m.id)::int AS milestone_count,
            COUNT(m.id) FILTER (WHERE m.status = 'completed')::int AS completed_milestones
     FROM goals g
     LEFT JOIN milestones m ON m.goal_id = g.id
     WHERE g.id = $1 AND g.user_id = $2
     GROUP BY g.id`,
    [goalId, userId]
  );
  if (result.rowCount === 0) {
    const err = new Error('Goal not found');
    err.statusCode = 404;
    throw err;
  }
  return result.rows[0];
}

async function createGoal(userId, fields) {
  const result = await query(
    `INSERT INTO goals (user_id, name, description, why_it_matters, growth_area, target_date, status)
     VALUES ($1, $2, $3, $4, $5, $6, 'active')
     RETURNING id, name, description, why_it_matters, growth_area, target_date, status, progress, created_at, updated_at`,
    [userId, fields.name.trim(), fields.description ?? null, fields.whyItMatters ?? null, fields.growthArea ?? null, fields.targetDate ?? null]
  );
  return result.rows[0];
}

// Updates only the fields provided; updated_at always refreshed.
async function updateGoal(userId, goalId, fields) {
  const existing = await query('SELECT id FROM goals WHERE id = $1 AND user_id = $2', [goalId, userId]);
  if (existing.rowCount === 0) {
    const err = new Error('Goal not found');
    err.statusCode = 404;
    throw err;
  }
  const result = await query(
    `UPDATE goals SET
       name = COALESCE($3, name),
       description = COALESCE($4, description),
       why_it_matters = COALESCE($5, why_it_matters),
       growth_area = COALESCE($6, growth_area),
       target_date = COALESCE($7, target_date),
       status = COALESCE($8, status),
       updated_at = NOW()
     WHERE id = $1 AND user_id = $2
     RETURNING id, name, description, why_it_matters, growth_area, target_date, status, progress, created_at, updated_at`,
    [goalId, userId, fields.name ?? null, fields.description ?? null, fields.whyItMatters ?? null, fields.growthArea ?? null, fields.targetDate ?? null, fields.status ?? null]
  );
  return result.rows[0];
}

// Hard delete — milestones/tasks cascade/SET NULL per schema.
async function deleteGoal(userId, goalId) {
  const result = await query('DELETE FROM goals WHERE id = $1 AND user_id = $2 RETURNING id', [goalId, userId]);
  if (result.rowCount === 0) {
    const err = new Error('Goal not found');
    err.statusCode = 404;
    throw err;
  }
  return true;
}

// Recompute a goal's progress from its milestones and persist it.
// progress = completed milestones / total milestones (0 if none).
// NULLIF guards the division: a goal with no milestones yields NULL (then
// 0 via COALESCE) instead of a divide-by-zero SQL error.
async function recalculateProgress(goalId) {
  const result = await query(
    `UPDATE goals g SET
       progress = COALESCE((
         SELECT ROUND(100.0 * COUNT(*) FILTER (WHERE status = 'completed') / NULLIF(COUNT(*), 0))
         FROM milestones WHERE goal_id = g.id), 0),
       updated_at = NOW()
     WHERE g.id = $1
     RETURNING progress`,
    [goalId]
  );
  return result.rows[0]?.progress ?? 0;
}

module.exports = { listGoals, getGoal, createGoal, updateGoal, deleteGoal, recalculateProgress };
