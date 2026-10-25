// Progress — analytics straight from GET /progress (server-computed).
import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import * as ep from '../api/endpoints';
import { BarChart, computeStreak, CountUp, Heatmap, TrendChart } from '../components/charts';
import { Button, ErrorBanner, IconSparkles, ProgressBar, Skeleton } from '../components/neu';
import type { ProgressData, TrendPoint } from '../types';
import { formatMinutes } from '../utils/dates';

// The backend accepts exactly these range values for GET /progress
// (see backend/src/controllers/progress.controller.js and the Flutter
// progress_screen, which uses the same keys): week | month | 3months.
const RANGES = [
  { key: 'week', label: 'Week' },
  { key: 'month', label: 'Month' },
  { key: '3months', label: '3 Months' },
];

export default function ProgressPage() {
  const [range, setRange] = useState('week');
  const [data, setData] = useState<ProgressData | null>(null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    try {
      setData(await ep.fetchProgress(range));
      setError(null);
    } catch (e: any) {
      setError(e.message ?? 'Could not load progress.');
    }
  }, [range]);

  useEffect(() => {
    void load();
  }, [load]);

  const s = data?.summary;

  // Merged per-day effort (focus minutes + tasks completed) drives the
  // heatmap and the streak — computed client-side, no extra API call.
  const effortPoints: TrendPoint[] = data
    ? mergeEffort(data.taskTrend, data.focusTrend)
    : [];
  const streak = computeStreak(effortPoints);

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <h1>Progress</h1>
          <p className="sub">Everything here is computed from your real data.</p>
        </div>
        <Link to="/weekly">
          <Button>
            <IconSparkles size={15} /> Weekly review
          </Button>
        </Link>
      </div>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="row">
        {RANGES.map((r) => (
          <button
            key={r.key}
            className={`chip ${range === r.key ? 'active' : ''}`}
            onClick={() => setRange(r.key)}
          >
            {r.label}
          </button>
        ))}
      </div>

      <div className="grid grid-4">
        {[
          { label: 'Tasks completed', value: s ? <CountUp value={s.tasksCompleted} /> : '—' },
          { label: 'Focus time', value: s ? <CountUp value={s.focusMinutes} format={formatMinutes} /> : '—' },
          { label: 'Completion rate', value: s ? <CountUp value={s.completionRate} format={(v) => `${v}%`} /> : '—' },
          { label: 'Active goals', value: s ? <CountUp value={s.activeGoals} /> : '—' },
        ].map((c) => (
          <div key={c.label} className="neu card center">
            <p className="muted small">{c.label}</p>
            <h2 style={{ marginTop: 6 }}>{c.value}</h2>
          </div>
        ))}
      </div>

      <div className="neu card">
        <div className="card-title">
          <h3>
            {streak > 0 ? '🔥' : '✨'} {streakLabel(streak)}
          </h3>
          <span className="small muted">last 13 weeks</span>
        </div>
        {data ? <Heatmap points={effortPoints} /> : <Skeleton height={130} />}
      </div>

      <div className="grid grid-2">
        <div className="neu card">
          <div className="card-title">
            <h3>Tasks completed</h3>
            <span className="small muted">per day</span>
          </div>
          {data ? <TrendChart points={data.taskTrend} height={172} /> : <Skeleton height={170} />}
        </div>
        <div className="neu card">
          <div className="card-title">
            <h3>Focus minutes</h3>
            <span className="small muted">per day</span>
          </div>
          {data ? <BarChart points={data.focusTrend} height={160} axes /> : <Skeleton height={170} />}
        </div>
      </div>

      <div className="neu card">
        <div className="card-title">
          <h3>Goal progress</h3>
        </div>
        {data ? (
          data.goalProgress.length ? (
            <div className="stack" style={{ gap: 14 }}>
              {data.goalProgress.map((g) => (
                <div key={g.id} className="stack" style={{ gap: 6 }}>
                  <div className="row" style={{ justifyContent: 'space-between' }}>
                    <Link to={`/goals/${g.id}`} style={{ fontWeight: 600 }}>
                      {g.name}
                    </Link>
                    <span className="small muted">{g.progress}%</span>
                  </div>
                  <ProgressBar value={g.progress} />
                </div>
              ))}
            </div>
          ) : (
            <p className="small muted">No goals to show yet.</p>
          )
        ) : (
          <Skeleton height={90} />
        )}
      </div>

      {data?.insights.length ? (
        <div className="neu card">
          <div className="card-title">
            <h3>Insights</h3>
          </div>
          <ul style={{ margin: 0, paddingLeft: 18 }} className="text-2">
            {data.insights.map((i, idx) => (
              <li key={idx} style={{ marginBottom: 6 }}>
                {i}
              </li>
            ))}
          </ul>
        </div>
      ) : null}
    </div>
  );
}

/** Merges the two per-day trend series into one effort series:
 *  each 30 focus minutes and each completed task count as one unit. */
function mergeEffort(taskTrend: TrendPoint[], focusTrend: TrendPoint[]): TrendPoint[] {
  const byDay = new Map<string, number>();
  for (const p of taskTrend) byDay.set(p.date, (byDay.get(p.date) ?? 0) + p.value);
  for (const p of focusTrend) byDay.set(p.date, (byDay.get(p.date) ?? 0) + Math.floor(p.value / 30));
  return [...byDay.entries()]
    .map(([date, value]) => ({ date, value }))
    .sort((a, b) => a.date.localeCompare(b.date));
}

/** Streak headline for the heatmap card. */
function streakLabel(days: number): string {
  return days > 0 ? `${days}-day streak` : 'No streak yet — light it up';
}
