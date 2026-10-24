// Subtask service — a subtask is only accessible when its parent
// task belongs to the authenticated user (ownership is verified through
// the task, so cross-user access is impossible).
const { query } = require('../config/db');

// Shared ownership check: confirm the parent task belongs to this user.
async function _assertTaskOwner(userId, taskId) {
  const r = await query('SELECT id FROM tasks WHERE id = $1 AND user_id = $2', [taskId, userId]);
  if (r.rowCount === 0) {
    const err = new Error('Task not found');
    err.statusCode = 404;
    throw err;
  }
}

// Confirm the subtask's parent task belongs to this user.
async function _assertSubtaskOwner(userId, subtaskId) {
  const r = await query(
    `SELECT s.id FROM subtasks s JOIN tasks t ON t.id = s.task_id
     WHERE s.id = $1 AND t.user_id = $2`,
    [subtaskId, userId]
  );
  if (r.rowCount === 0) {
    const err = new Error('Subtask not found');
    err.statusCode = 404;
    throw err;
  }
}

async function listSubtasks(userId, taskId) {
  await _assertTaskOwner(userId, taskId);
  const r = await query(
    'SELECT id, task_id, title, is_completed, position, created_at, updated_at FROM subtasks WHERE task_id = $1 ORDER BY position ASC, created_at ASC',
    [taskId]
  );
  return r.rows;
}

async function createSubtask(userId, taskId, fields) {
  await _assertTaskOwner(userId, taskId);
  let position = fields.position;
  if (position === undefined || position === null) {
    const max = await query('SELECT COALESCE(MAX(position), -1) + 1 AS next FROM subtasks WHERE task_id = $1', [taskId]);
    position = max.rows[0].next;
  }
  const r = await query(
    `INSERT INTO subtasks (task_id, title, is_completed, position)
     VALUES ($1, $2, FALSE, $3)
     RETURNING id, task_id, title, is_completed, position, created_at, updated_at`,
    [taskId, fields.title.trim(), position]
  );
  return r.rows[0];
}

async function updateSubtask(userId, subtaskId, fields) {
  await _assertSubtaskOwner(userId, subtaskId);
  const r = await query(
    `UPDATE subtasks SET
       title = COALESCE($2, title),
       is_completed = COALESCE($3, is_completed),
       position = COALESCE($4, position),
       updated_at = NOW()
     WHERE id = $1
     RETURNING id, task_id, title, is_completed, position, created_at, updated_at`,
    [subtaskId, fields.title ?? null, fields.isCompleted ?? null, fields.position ?? null]
  );
  return r.rows[0];
}

async function deleteSubtask(userId, subtaskId) {
  await _assertSubtaskOwner(userId, subtaskId);
  await query('DELETE FROM subtasks WHERE id = $1', [subtaskId]);
  return true;
}

module.exports = { listSubtasks, createSubtask, updateSubtask, deleteSubtask };
