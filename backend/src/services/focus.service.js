// Focus session service — owns the session lifecycle.
// Timing rule: focus duration is derived from timestamps, never trusted
// from the client. Paused intervals are excluded via total_pause_seconds.
const { query } = require('../config/db');

function _notFound() {
  const err = new Error('Session not found');
  err.statusCode = 404;
  return err;
}

async function _getOwned(userId, id) {
  const r = await query('SELECT * FROM focus_sessions WHERE id = $1 AND user_id = $2', [id, userId]);
  if (r.rowCount === 0) throw _notFound();
  return r.rows[0];
}

async function startSession(userId, taskId) {
  if (taskId) {
    const t = await query('SELECT id FROM tasks WHERE id = $1 AND user_id = $2', [taskId, userId]);
    if (t.rowCount === 0) {
      const err = new Error('Task not found or not yours');
      err.statusCode = 400;
      throw err;
    }
  }
  const r = await query(
    `INSERT INTO focus_sessions (user_id, task_id, started_at, status)
     VALUES ($1, $2, NOW(), 'active')
     RETURNING *`,
    [userId, taskId ?? null]
  );
  return r.rows[0];
}

async function pauseSession(userId, id) {
  const s = await _getOwned(userId, id);
  if (s.status !== 'active') { const e = new Error('Only active sessions can be paused'); e.statusCode = 409; throw e; }
  if (s.paused_at) return s; // already paused — idempotent
  const r = await query('UPDATE focus_sessions SET paused_at = NOW() WHERE id = $1 RETURNING *', [id]);
  return r.rows[0];
}

async function resumeSession(userId, id) {
  const s = await _getOwned(userId, id);
  if (s.status !== 'active') { const e = new Error('Only active sessions can be resumed'); e.statusCode = 409; throw e; }
  if (!s.paused_at) return s;
  const r = await query(
    `UPDATE focus_sessions
     SET total_pause_seconds = total_pause_seconds + EXTRACT(EPOCH FROM (NOW() - paused_at))::int,
         paused_at = NULL
     WHERE id = $1 RETURNING *`,
    [id]
  );
  return r.rows[0];
}

// Elapsed focus seconds for a session, excluding paused time. Shared by
// complete/cancel so duration is consistent.
function _elapsedSeconds(s, endTs) {
  const started = new Date(s.started_at).getTime();
  const end = new Date(endTs).getTime();
  let paused = (s.total_pause_seconds || 0) * 1000;
  if (s.paused_at) paused += end - new Date(s.paused_at).getTime();
  return Math.max(0, Math.round((end - started - paused) / 1000));
}

async function completeSession(userId, id, { rating, reflection } = {}) {
  const s = await _getOwned(userId, id);
  if (s.status !== 'active') { const e = new Error('Session already finished'); e.statusCode = 409; throw e; }
  const end = new Date();
  const duration = _elapsedSeconds(s, end);
  const r = await query(
    `UPDATE focus_sessions
     SET status = 'completed', ended_at = $2, duration_seconds = $3,
         productivity_rating = COALESCE($4, productivity_rating),
         reflection = COALESCE($5, reflection),
         total_pause_seconds = total_pause_seconds + CASE WHEN paused_at IS NOT NULL THEN EXTRACT(EPOCH FROM ($2 - paused_at))::int ELSE 0 END,
         paused_at = NULL
     WHERE id = $1 RETURNING *`,
    [id, end, duration, rating ?? null, reflection ?? null]
  );
  return r.rows[0];
}

async function cancelSession(userId, id) {
  const s = await _getOwned(userId, id);
  if (s.status !== 'active') { const e = new Error('Session already finished'); e.statusCode = 409; throw e; }
  const end = new Date();
  const r = await query(
    `UPDATE focus_sessions SET status = 'cancelled', ended_at = $2, duration_seconds = $3, paused_at = NULL WHERE id = $1 RETURNING *`,
    [id, end, _elapsedSeconds(s, end)]
  );
  return r.rows[0];
}

async function listSessions(userId) {
  const r = await query(
    `SELECT fs.*, t.title AS task_title
     FROM focus_sessions fs LEFT JOIN tasks t ON t.id = fs.task_id
     WHERE fs.user_id = $1
     ORDER BY fs.started_at DESC LIMIT 50`,
    [userId]
  );
  return r.rows;
}

async function getSession(userId, id) {
  const r = await query(
    `SELECT fs.*, t.title AS task_title
     FROM focus_sessions fs LEFT JOIN tasks t ON t.id = fs.task_id
     WHERE fs.id = $1 AND fs.user_id = $2`,
    [id, userId]
  );
  if (r.rowCount === 0) throw _notFound();
  return r.rows[0];
}

async function updateSessionExtras(userId, id, { rating, reflection } = {}) {
  await _getOwned(userId, id);
  const r = await query(
    `UPDATE focus_sessions
     SET productivity_rating = COALESCE($2, productivity_rating),
         reflection = COALESCE($3, reflection)
     WHERE id = $1 RETURNING *`,
    [id, rating ?? null, reflection ?? null]
  );
  return r.rows[0];
}

module.exports = { startSession, pauseSession, resumeSession, completeSession, cancelSession, listSessions, getSession, updateSessionExtras };
