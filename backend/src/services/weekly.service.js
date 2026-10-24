// Weekly review service — one review per user per ISO week (Mon–Sun).
// Statistics for a week are computed from the user's REAL activity,
// same conventions as Phase 9 (completed-at based task counts, duration
// based focus sums from completed focus_sessions only).
const { query } = require('../config/db');

function _notFound() {
  const err = new Error('Review not found');
  err.statusCode = 404;
  return err;
}

// Validates 'YYYY-MM-DD' and that it is a Monday.
function _validateWeekStart(weekStart) {
  const d = new Date(weekStart);
  if (isNaN(d.getTime())) throw invalid('Invalid weekStart date');
  // JS: Sunday=0; treat Monday as week start.
  if (d.getUTCDay() !== 1) throw invalid('weekStart must be a Monday');
  return d;
}
function invalid(msg) {
  const e = new Error(msg);
  e.statusCode = 400;
  return e;
}

function _addDays(d, n) {
  return new Date(d.getTime() + n * 86400000);
}

// Aggregates real activity for [weekStart, weekEnd).
async function weekStats(userId, weekStart) {
  const start = _validateWeekStart(weekStart);
  const end = _addDays(start, 7);

  const stats = await query(
    `SELECT
       (SELECT COUNT(*)::int FROM tasks
          WHERE user_id = $1 AND status = 'completed' AND completed_at >= $2 AND completed_at < $3) AS tasks_completed,
       (SELECT COALESCE(SUM(duration_seconds), 0)::int FROM focus_sessions
          WHERE user_id = $1 AND status = 'completed' AND started_at >= $2 AND started_at < $3) AS focus_seconds,
       (SELECT COUNT(DISTINCT goal_id)::int FROM tasks
          WHERE user_id = $1 AND status = 'completed' AND completed_at >= $2 AND completed_at < $3 AND goal_id IS NOT NULL) AS goals_progressed,
       (SELECT COUNT(*)::int FROM tasks WHERE user_id = $1 AND status != 'cancelled' AND (created_at >= $2 AND created_at < $3 OR completed_at >= $2 AND completed_at < $3)) AS tasks_total`,
    [userId, start, end]
  );
  const s = stats.rows[0];
  const rate = s.tasks_total === 0 ? 0 : Math.round((100.0 * s.tasks_completed) / s.tasks_total);
  return {
    weekStart: start.toISOString().substring(0, 10),
    weekEnd: _addDays(end, -1).toISOString().substring(0, 10),
    tasksCompleted: s.tasks_completed,
    focusMinutes: Math.round(s.focus_seconds / 60),
    goalsProgressed: s.goals_progressed,
    completionRate: rate,
  };
}

async function getReview(userId, weekStart) {
  _validateWeekStart(weekStart);
  const r = await query(
    'SELECT id, user_id, week_start, week_end, summary, biggest_win, needs_attention, next_week_focus, created_at, updated_at FROM weekly_reviews WHERE user_id = $1 AND week_start = $2',
    [userId, weekStart]
  );
  return r.rows[0] ?? null;
}

async function listReviews(userId) {
  const r = await query(
    'SELECT id, week_start, week_end, biggest_win, needs_attention, next_week_focus, summary, created_at, updated_at FROM weekly_reviews WHERE user_id = $1 ORDER BY week_start DESC LIMIT 52',
    [userId]
  );
  return r.rows;
}

// Upsert on (user_id, week_start) — one review per week per user.
async function upsertReview(userId, { weekStart, biggestWin, needsAttention, nextWeekFocus, summary }) {
  const start = _validateWeekStart(weekStart);
  const end = _addDays(start, 6);
  const r = await query(
    `INSERT INTO weekly_reviews (user_id, week_start, week_end, biggest_win, needs_attention, next_week_focus, summary)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     ON CONFLICT (user_id, week_start) DO UPDATE SET
       biggest_win = EXCLUDED.biggest_win,
       needs_attention = EXCLUDED.needs_attention,
       next_week_focus = EXCLUDED.next_week_focus,
       summary = EXCLUDED.summary,
       updated_at = NOW()
     RETURNING id, user_id, week_start, week_end, summary, biggest_win, needs_attention, next_week_focus, created_at, updated_at`,
    [userId, start, end, biggestWin ?? null, needsAttention ?? null, nextWeekFocus ?? null, summary ?? null]
  );
  return r.rows[0];
}

module.exports = { weekStats, getReview, listReviews, upsertReview };
