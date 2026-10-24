// Task service — all task business logic. Ownership is enforced via
// req.userId on every query; a user can never read/modify another's task.
const { query } = require('../config/db');

// List tasks for the caller, with optional filters.
// Subtask counts are joined in so the UI can show "2/5 subtasks".
async function listTasks(userId, filters = {}) {
  const params = [userId];
  let where = 't.user_id = $1';

  if (filters.status) { params.push(filters.status); where += ` AND t.status = $${params.length}`; }
  if (filters.priority) { params.push(filters.priority); where += ` AND t.priority = $${params.length}`; }
  if (filters.category) { params.push(filters.category); where += ` AND t.category = $${params.length}`; }
  if (filters.goalId) { params.push(filters.goalId); where += ` AND t.goal_id = $${params.length}`; }
  if (filters.milestoneId) { params.push(filters.milestoneId); where += ` AND t.milestone_id = $${params.length}`; }
  if (filters.date) { params.push(filters.date); where += ` AND t.due_date = $${params.length}`; }

  const result = await query(
    `SELECT t.id, t.user_id, t.goal_id, t.milestone_id, t.title, t.description,
            t.due_date, t.priority, t.estimated_minutes, t.category, t.status,
            t.completed_at, t.created_at, t.updated_at,
            g.name AS goal_name, m.title AS milestone_title,
            COUNT(s.id)::int AS subtask_count,
            COUNT(s.id) FILTER (WHERE s.is_completed)::int AS completed_subtasks
     FROM tasks t
     LEFT JOIN goals g ON g.id = t.goal_id
     LEFT JOIN milestones m ON m.id = t.milestone_id
     LEFT JOIN subtasks s ON s.task_id = t.id
     WHERE ${where}
     GROUP BY t.id, g.name, m.title
     ORDER BY t.due_date NULLS LAST, t.created_at DESC`,
    params
  );
  return result.rows;
}

async function getTask(userId, taskId) {
  const result = await query(
    `SELECT t.*, g.name AS goal_name, m.title AS milestone_title
     FROM tasks t
     LEFT JOIN goals g ON g.id = t.goal_id
     LEFT JOIN milestones m ON m.id = t.milestone_id
     WHERE t.id = $1 AND t.user_id = $2`,
    [taskId, userId]
  );
  if (result.rowCount === 0) throw notFound();
  return result.rows[0];
}

// Validates that goal/milestone (when provided) belong to this user.
// Milestone must also belong to the chosen goal — never trust the client.
async function _assertLinks(userId, goalId, milestoneId) {
  if (goalId) {
    const g = await query('SELECT id FROM goals WHERE id = $1 AND user_id = $2', [goalId, userId]);
    if (g.rowCount === 0) {
      const err = new Error('Goal not found or not yours');
      err.statusCode = 400;
      throw err;
    }
  }
  if (milestoneId) {
    const m = await query(
      `SELECT m.id FROM milestones m JOIN goals g ON g.id = m.goal_id
       WHERE m.id = $1 AND g.user_id = $2${goalId ? ' AND m.goal_id = $3' : ''}`,
      goalId ? [milestoneId, userId, goalId] : [milestoneId, userId]
    );
    if (m.rowCount === 0) {
      const err = new Error('Milestone not found or does not belong to that goal');
      err.statusCode = 400;
      throw err;
    }
  }
}

async function createTask(userId, fields) {
  await _assertLinks(userId, fields.goalId ?? null, fields.milestoneId ?? null);
  const result = await query(
    // COALESCE($7, 'medium'): a missing priority defaults to 'medium'
    // right in SQL, matching the column default in the schema.
    `INSERT INTO tasks (user_id, goal_id, milestone_id, title, description, due_date, priority, estimated_minutes, category, status)
     VALUES ($1, $2, $3, $4, $5, $6, COALESCE($7, 'medium'), $8, $9, 'pending')
     RETURNING *`,
    [
      userId,
      fields.goalId ?? null,
      fields.milestoneId ?? null,
      fields.title.trim(),
      fields.description ?? null,
      fields.dueDate ?? null,
      fields.priority ?? null,
      fields.estimatedMinutes ?? null,
      fields.category ?? null,
    ]
  );
  return result.rows[0];
}

async function updateTask(userId, taskId, fields) {
  const existing = await query('SELECT id FROM tasks WHERE id = $1 AND user_id = $2', [taskId, userId]);
  if (existing.rowCount === 0) throw notFound();

  await _assertLinks(userId, fields.goalId ?? undefined, fields.milestoneId ?? undefined);

  const result = await query(
    // completed_at is stamped only when this update sets status to
    // 'completed'; every other partial update leaves the old timestamp as-is.
    `UPDATE tasks SET
       title = COALESCE($3, title),
       description = COALESCE($4, description),
       due_date = COALESCE($5, due_date),
       priority = COALESCE($6, priority),
       estimated_minutes = COALESCE($7, estimated_minutes),
       category = COALESCE($8, category),
       goal_id = COALESCE($9, goal_id),
       milestone_id = COALESCE($10, milestone_id),
       status = COALESCE($11::text, status),
       completed_at = CASE WHEN $11::text = 'completed' THEN NOW() ELSE completed_at END,
       updated_at = NOW()
     WHERE id = $1 AND user_id = $2
     RETURNING *`,
    [
      taskId, userId,
      fields.title ?? null, fields.description ?? null, fields.dueDate ?? null,
      fields.priority ?? null, fields.estimatedMinutes ?? null, fields.category ?? null,
      fields.goalId ?? null, fields.milestoneId ?? null, fields.status ?? null,
    ]
  );
  return result.rows[0];
}

// Dedicated status endpoint: moving TO 'completed' stamps completed_at
// with NOW(); moving AWAY from 'completed' clears it (ELSE NULL) so the
// progress/weekly stats never count work that was un-completed.
async function setTaskStatus(userId, taskId, status) {
  const result = await query(
    `UPDATE tasks SET status = $3::text,
       completed_at = CASE WHEN $3::text = 'completed' THEN NOW() ELSE NULL END,
       updated_at = NOW()
     WHERE id = $1 AND user_id = $2
     RETURNING *`,
    [taskId, userId, status]
  );
  if (result.rowCount === 0) throw notFound();
  return result.rows[0];
}

async function deleteTask(userId, taskId) {
  const result = await query('DELETE FROM tasks WHERE id = $1 AND user_id = $2 RETURNING id', [taskId, userId]);
  if (result.rowCount === 0) throw notFound();
  return true;
}

function notFound() {
  const err = new Error('Task not found');
  err.statusCode = 404;
  return err;
}

module.exports = { listTasks, getTask, createTask, updateTask, setTaskStatus, deleteTask };
