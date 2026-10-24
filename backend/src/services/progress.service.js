// Progress service — aggregates the user's real activity into a personal
// performance report. All queries are scoped by JWT userId and use
// parameterized SQL aggregations (no N+1, no client-side fake stats).
const { query } = require('../config/db');

const RANGES = {
  week: 7,
  month: 30,
  '3months': 90,
};

function _daysFor(range) {
  return RANGES[range] ?? null;
}

// Builds the full progress payload for a range.
async function getProgress(userId, range) {
  const days = _daysFor(range);
  if (days === null) {
    const err = new Error('Invalid range. Use week, month, or 3months.');
    err.statusCode = 400;
    throw err;
  }

  // Range → cutoff timestamp: 86400000 ms = one day of history.
  const since = new Date(Date.now() - days * 86400000);

  // Summary metrics — single pass per metric, all parameterized.
  const summaryPromise = query(
    `SELECT
       (SELECT COUNT(*)::int FROM tasks
          WHERE user_id = $1 AND status = 'completed' AND completed_at >= $2) AS tasks_completed,
       (SELECT COALESCE(SUM(duration_seconds), 0)::int FROM focus_sessions
          WHERE user_id = $1 AND status = 'completed' AND started_at >= $2) AS focus_seconds,
       (SELECT COUNT(*)::int FROM tasks WHERE user_id = $1 AND status != 'cancelled' AND (created_at >= $2 OR completed_at >= $2)) AS tasks_total,
       (SELECT COUNT(*)::int FROM goals WHERE user_id = $1 AND status = 'active') AS active_goals`,
    [userId, since]
  );

  // Trend bucketing: daily for week/month, weekly for 3 months.
  // 90 daily points would crowd the chart, so the longer range rolls up
  // by week (date_trunc) instead.
  const bucket = days > 30 ? 'week' : 'day';
  const taskTrendPromise = query(
    `SELECT date_trunc('${bucket}', completed_at) AS bucket, COUNT(*)::int AS count
     FROM tasks
     WHERE user_id = $1 AND status = 'completed' AND completed_at >= $2
     GROUP BY 1 ORDER BY 1`,
    [userId, since]
  );
  const focusTrendPromise = query(
    `SELECT date_trunc('${bucket}', started_at) AS bucket, COALESCE(SUM(duration_seconds), 0)::int AS seconds
     FROM focus_sessions
     WHERE user_id = $1 AND status = 'completed' AND started_at >= $2
     GROUP BY 1 ORDER BY 1`,
    [userId, since]
  );

  const goalsPromise = query(
    `SELECT id, name, progress, target_date, status
     FROM goals WHERE user_id = $1 AND status != 'archived'
     ORDER BY target_date NULLS LAST, created_at DESC LIMIT 8`,
    [userId]
  );

  // All four queries are independent, so Promise.all runs them
  // concurrently — one network round-trip each, all at once, instead of
  // waiting for them one after another.
  const [summaryRes, taskTrendRes, focusTrendRes, goalsRes] = await Promise.all([
    summaryPromise, taskTrendPromise, focusTrendPromise, goalsPromise,
  ]);

  const s = summaryRes.rows[0];
  const focusMinutes = Math.round(s.focus_seconds / 60);
  // tasks_total (created or completed in the window, cancelled excluded)
  // is the denominator of the rate; the ternary avoids dividing by zero
  // when the window contains no tasks.
  const completionRate = s.tasks_total === 0 ? 0 : Math.round((100.0 * s.tasks_completed) / s.tasks_total);

  // Factual, data-backed insights only — no motivation fluff.
  const insights = [];
  if (s.tasks_completed > 0) insights.push(`You completed ${s.tasks_completed} task${s.tasks_completed === 1 ? '' : 's'} in the last ${days} days.`);
  if (focusMinutes > 0) {
    const h = Math.floor(focusMinutes / 60);
    const m = focusMinutes % 60;
    insights.push(`You spent ${h > 0 ? `${h}h ` : ''}${m}m in Focus during this period.`);
  }
  if (s.tasks_total > 0) insights.push(`Completion rate: ${completionRate}% of ${s.tasks_total} tasks.`);

  return {
    range,
    summary: {
      tasksCompleted: s.tasks_completed,
      focusMinutes,
      completionRate,
      activeGoals: s.active_goals,
    },
    taskTrend: taskTrendRes.rows.map((r) => ({ date: r.bucket, count: r.count })),
    focusTrend: focusTrendRes.rows.map((r) => ({ date: r.bucket, minutes: Math.round(r.seconds / 60) })),
    goalProgress: goalsRes.rows.map((g) => ({
      id: g.id,
      name: g.name,
      progress: g.progress,
      targetDate: g.target_date,
      status: g.status,
    })),
    insights,
  };
}

module.exports = { getProgress };
