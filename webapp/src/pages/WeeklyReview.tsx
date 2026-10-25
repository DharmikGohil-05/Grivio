// Weekly review — Monday-start week stats (server-computed), the saved
// narrative review (POST /weekly-reviews is create-or-replace per week),
// and the AI Growth Review (read-only preview; generating writes nothing).
import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import * as ep from '../api/endpoints';
import {
  Button,
  ErrorBanner,
  Field,
  IconSparkles,
  Skeleton,
  Textarea,
} from '../components/neu';
import type { AIWeeklyReview, WeeklyReview, WeeklyStats } from '../types';
import { addDays, formatDay, formatMinutes, mondayStart } from '../utils/dates';

export default function WeeklyReviewPage() {
  // Start on the current week, always snapped to a Monday (the backend
  // rejects non-Monday weekStart values).
  const [weekStart, setWeekStart] = useState(() => mondayStart(new Date().toISOString().slice(0, 10)));
  const [stats, setStats] = useState<WeeklyStats | null>(null);
  const [review, setReview] = useState<WeeklyReview | null>(null);
  const [form, setForm] = useState({ summary: '', biggestWin: '', needsAttention: '', nextWeekFocus: '' });
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);
  const [ai, setAi] = useState<AIWeeklyReview | null>(null);
  const [aiBusy, setAiBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const r = await ep.fetchWeek(weekStart);
      setStats(r.stats);
      setReview(r.review);
      setForm({
        summary: r.review?.summary ?? '',
        biggestWin: r.review?.biggestWin ?? '',
        needsAttention: r.review?.needsAttention ?? '',
        nextWeekFocus: r.review?.nextWeekFocus ?? '',
      });
      setError(null);
    } catch (e: any) {
      setError(e.message ?? 'Could not load the week.');
    }
  }, [weekStart]);

  useEffect(() => {
    void load();
  }, [load]);

  const save = async () => {
    setBusy(true);
    setSaved(false);
    setError(null);
    try {
      const r = await ep.saveWeeklyReview({
        weekStart,
        ...(form.summary.trim() ? { summary: form.summary.trim() } : {}),
        ...(form.biggestWin.trim() ? { biggestWin: form.biggestWin.trim() } : {}),
        ...(form.needsAttention.trim() ? { needsAttention: form.needsAttention.trim() } : {}),
        ...(form.nextWeekFocus.trim() ? { nextWeekFocus: form.nextWeekFocus.trim() } : {}),
      });
      setReview(r);
      setSaved(true);
    } catch (e: any) {
      setError(e.message ?? 'Could not save the review.');
    } finally {
      setBusy(false);
    }
  };

  const generateAI = async () => {
    setAiBusy(true);
    setError(null);
    try {
      setAi(await ep.aiWeeklyReview(weekStart));
    } catch (e: any) {
      setError(e.message ?? 'AI is unavailable right now.');
    } finally {
      setAiBusy(false);
    }
  };

  const weekEnd = addDays(weekStart, 6);

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <p className="small">
            <Link to="/progress">← Progress</Link>
          </p>
          <h1>Weekly review</h1>
          <p className="sub">
            {formatDay(weekStart)} → {formatDay(weekEnd)}
          </p>
        </div>
        <div className="row">
          <Button size="sm" onClick={() => setWeekStart(addDays(weekStart, -7))}>
            ← Previous
          </Button>
          <Button size="sm" onClick={() => setWeekStart(mondayStart(new Date().toISOString().slice(0, 10)))}>
            This week
          </Button>
          <Button
            size="sm"
            onClick={() => setWeekStart(addDays(weekStart, 7))}
            disabled={weekStart >= mondayStart(new Date().toISOString().slice(0, 10))}
          >
            Next →
          </Button>
        </div>
      </div>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="grid grid-4">
        {[
          { label: 'Tasks completed', value: stats ? String(stats.tasksCompleted) : '—' },
          { label: 'Focus time', value: stats ? formatMinutes(stats.focusMinutes) : '—' },
          { label: 'Goals progressed', value: stats ? String(stats.goalsProgressed) : '—' },
          { label: 'Completion rate', value: stats ? `${stats.completionRate}%` : '—' },
        ].map((c) => (
          <div key={c.label} className="neu card center">
            <p className="muted small">{c.label}</p>
            <h2 style={{ marginTop: 6 }}>{c.value}</h2>
          </div>
        ))}
      </div>

      {/* ----- AI Growth Review (preview-only) ----- */}
      <div className="neu card stack">
        <div className="card-title">
          <h3>
            <IconSparkles size={17} /> AI Growth Review
          </h3>
          {ai ? (
            <div className="row" style={{ gap: 6 }}>
              <Button size="sm" variant="ghost" onClick={() => void generateAI()} disabled={aiBusy}>
                {aiBusy ? 'Generating…' : 'Regenerate'}
              </Button>
              <Button size="sm" variant="ghost" onClick={() => setAi(null)}>
                Dismiss
              </Button>
            </div>
          ) : (
            <Button size="sm" onClick={() => void generateAI()} disabled={aiBusy}>
              <IconSparkles size={14} /> {aiBusy ? 'Generating…' : 'Generate review'}
            </Button>
          )}
        </div>

        {!ai ? (
          <p className="small muted">
            A narrative review of your week, built from your real stats. Generating it never
            changes your data.
          </p>
        ) : (
          <div className="stack">
            {ai.lowData ? (
              <div className="banner banner-info">
                Light week — the review sticks to what your data can honestly support.
              </div>
            ) : null}

            {[
              { title: 'Wins', items: ai.wins },
              { title: 'Progress highlights', items: ai.progressHighlights },
              { title: 'Patterns', items: ai.patterns },
              { title: 'Challenges', items: ai.challenges },
              { title: 'Next week priorities', items: ai.nextWeekPriorities },
              { title: 'Suggested actions', items: ai.suggestedActions },
            ]
              .filter((b) => b.items.length)
              .map((b) => (
                <div key={b.title} className="neu-inset" style={{ padding: 14 }}>
                  <p style={{ fontWeight: 700, marginBottom: 6 }}>{b.title}</p>
                  <ul style={{ margin: 0, paddingLeft: 18 }} className="text-2">
                    {b.items.map((x, i) => (
                      <li key={i} style={{ marginBottom: 4 }}>
                        {x}
                      </li>
                    ))}
                  </ul>
                </div>
              ))}

            {ai.dataLimitations.length ? (
              <p className="small muted">
                Note: {ai.dataLimitations.join(' · ')}
              </p>
            ) : null}
          </div>
        )}
      </div>

      {/* ----- Saved weekly review narrative ----- */}
      <div className="neu card stack">
        <div className="card-title">
          <h3>Your reflection</h3>
          {review ? <span className="badge badge-success">saved</span> : null}
        </div>
        <Field label="Week summary">
          <Textarea
            value={form.summary}
            onChange={(e) => setForm({ ...form, summary: e.target.value })}
            placeholder="How did this week go?"
          />
        </Field>
        <div className="grid grid-2">
          <Field label="Biggest win">
            <Textarea
              value={form.biggestWin}
              onChange={(e) => setForm({ ...form, biggestWin: e.target.value })}
            />
          </Field>
          <Field label="Needs attention">
            <Textarea
              value={form.needsAttention}
              onChange={(e) => setForm({ ...form, needsAttention: e.target.value })}
            />
          </Field>
        </div>
        <Field label="Next week focus">
          <Textarea
            value={form.nextWeekFocus}
            onChange={(e) => setForm({ ...form, nextWeekFocus: e.target.value })}
          />
        </Field>
        <div className="row" style={{ justifyContent: 'flex-end' }}>
          {saved ? <span className="small" style={{ color: 'var(--success)' }}>Saved ✓</span> : null}
          <Button variant="primary" onClick={() => void save()} disabled={busy}>
            {busy ? 'Saving…' : 'Save review'}
          </Button>
        </div>
      </div>

      {stats === null && !error ? <Skeleton height={80} /> : null}
    </div>
  );
}
