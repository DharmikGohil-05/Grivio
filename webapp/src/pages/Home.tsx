// Home dashboard — greeting, today-at-a-glance, progress ring, current
// goal, and the "Plan my day" AI planner (preview-only, like the app).
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';

import * as ep from '../api/endpoints';
import { BarChart, ProgressRing } from '../components/charts';
import {
  Button,
  Checkbox,
  EmptyState,
  ErrorBanner,
  Field,
  IconFlag,
  IconPlus,
  IconSparkles,
  Input,
  Modal,
  PriorityBadge,
  Skeleton,
  Textarea,
} from '../components/neu';
import { useAuth } from '../state/AuthContext';
import type { DailyPlan, FocusSession, Goal, Task } from '../types';
import { formatDay, formatMinutes, toKey } from '../utils/dates';

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

export default function Home() {
  const { user, profile } = useAuth();
  const [tasks, setTasks] = useState<Task[] | null>(null);
  const [goals, setGoals] = useState<Goal[] | null>(null);
  const [sessions, setSessions] = useState<FocusSession[] | null>(null);
  const [focusToday, setFocusToday] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [plannerOpen, setPlannerOpen] = useState(false);

  const load = useCallback(async () => {
    try {
      const [t, g, s] = await Promise.all([
        ep.listTasks(),
        ep.listGoals('active'),
        ep.listSessions(),
      ]);
      setTasks(t);
      setGoals(g);
      setSessions(s);
      const today = toKey(new Date());
      const mins = s
        .filter((x) => x.status === 'completed' && x.durationSeconds)
        .filter((x) => (x.endedAt ?? '').slice(0, 10) === today)
        .reduce((acc, x) => acc + Math.round((x.durationSeconds ?? 0) / 60), 0);
      setFocusToday(mins);
      setError(null);
    } catch (e: any) {
      setError(e.message ?? 'Could not load your day.');
      setTasks((v) => v ?? []);
      setGoals((v) => v ?? []);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const today = toKey(new Date());

  // "Today" = anything due today or earlier that isn't finished/cancelled —
  // same definition the mobile home uses.
  const todaysTasks = useMemo(
    () =>
      (tasks ?? []).filter(
        (t) =>
          (t.status === 'pending' || t.status === 'in_progress') &&
          t.dueDate !== null &&
          t.dueDate <= today,
      ),
    [tasks, today],
  );

  const doneToday = todaysTasks.filter((t) => t.status === 'completed').length;
  // Before completion the list only contains open tasks, so completion % is
  // measured against everything fetched for today including just-completed.
  const ringValue = todaysTasks.length
    ? Math.round(
        ((tasks ?? []).filter(
          (t) => t.dueDate !== null && t.dueDate <= today && t.status === 'completed',
        ).length /
          Math.max(
            1,
            (tasks ?? []).filter((t) => t.dueDate !== null && t.dueDate <= today).length,
          )) *
          100,
      )
    : 0;

  const currentGoal = useMemo(() => {
    const withDate = (goals ?? []).filter((g) => g.targetDate);
    withDate.sort((a, b) => (a.targetDate! < b.targetDate! ? -1 : 1));
    return (goals ?? [])[0] ? (withDate[0] ?? (goals as Goal[])[0]) : null;
  }, [goals]);

  const toggleTask = async (t: Task) => {
    // Optimistic flip, then reconcile with the server's answer.
    const nextStatus = t.status === 'completed' ? 'pending' : 'completed';
    setTasks((list) =>
      (list ?? []).map((x) => (x.id === t.id ? { ...x, status: nextStatus } : x)),
    );
    try {
      const updated = await ep.setTaskStatus(t.id, nextStatus);
      setTasks((list) => (list ?? []).map((x) => (x.id === t.id ? updated : x)));
    } catch (e: any) {
      setError(e.message ?? 'Could not update task.');
      void load();
    }
  };

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <h1>
            {greeting()}, {user?.name?.split(' ')[0] ?? 'there'}
          </h1>
          <p className="sub">{formatDay(today)}</p>
        </div>
        <Button variant="primary" onClick={() => setPlannerOpen(true)}>
          <IconSparkles size={17} /> Plan my day
        </Button>
      </div>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="grid grid-2">
        <div className="neu card row" style={{ gap: 24, justifyContent: 'center' }}>
          {tasks === null ? (
            <Skeleton height={148} width={148} />
          ) : (
            <ProgressRing value={ringValue} size={148} stroke={14} label="today" />
          )}
          <div className="stack" style={{ gap: 10 }}>
            <div>
              <p className="muted small">Tasks due</p>
              <h2>{tasks === null ? '—' : todaysTasks.length}</h2>
            </div>
            <div>
              <p className="muted small">Completed today</p>
              <h2>{tasks === null ? '—' : doneToday}</h2>
            </div>
            <div>
              <p className="muted small">Focus time today</p>
              <h2>{formatMinutes(focusToday)}</h2>
            </div>
          </div>
        </div>

        <div className="neu card">
          <div className="card-title">
            <h3>Current goal</h3>
            <Link to="/goals" className="small">
              All goals →
            </Link>
          </div>
          {goals === null ? (
            <Skeleton height={90} />
          ) : currentGoal ? (
            <div className="stack">
              <div className="row" style={{ justifyContent: 'space-between' }}>
                <Link to={`/goals/${currentGoal.id}`} style={{ fontWeight: 700, fontSize: 16 }}>
                  {currentGoal.name}
                </Link>
                <span className="badge badge-accent">{currentGoal.status}</span>
              </div>
              {currentGoal.targetDate ? (
                <p className="small muted">Target: {formatDay(currentGoal.targetDate)}</p>
              ) : null}
              <div className="progress-track">
                <div className="progress-fill" style={{ width: `${currentGoal.progress}%` }} />
              </div>
              <p className="small text-2">
                {currentGoal.progress}% · {currentGoal.completedMilestones}/
                {currentGoal.milestoneCount} milestones
              </p>
            </div>
          ) : (
            <EmptyState
              icon={<IconFlag size={26} />}
              title="Set your first growth goal"
              message="Goals give your tasks direction and your progress meaning."
              action={
                <Link to="/goals">
                  <Button size="sm">
                    <IconPlus size={14} /> Add goal
                  </Button>
                </Link>
              }
            />
          )}
        </div>
      </div>

      <div className="neu card">
        <div className="card-title">
          <h3>Today at a glance</h3>
          <Link to="/tasks" className="small">
            View all →
          </Link>
        </div>
        {tasks === null ? (
          <div className="stack">
            <Skeleton height={52} />
            <Skeleton height={52} />
          </div>
        ) : todaysTasks.length ? (
          <div className="stack" style={{ gap: 10 }}>
            {todaysTasks.map((t) => (
              <div key={t.id} className={`list-row ${t.status === 'completed' ? 'done' : ''}`}>
                <Checkbox
                  checked={t.status === 'completed'}
                  onChange={() => void toggleTask(t)}
                  label={`Complete ${t.title}`}
                />
                <Link to={`/tasks/${t.id}`} className="grow title" style={{ color: 'inherit' }}>
                  {t.title}
                </Link>
                <PriorityBadge priority={t.priority} />
                {t.dueDate && t.dueDate < today ? (
                  <span className="badge badge-high">overdue</span>
                ) : null}
              </div>
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<IconPlus size={24} />}
            title="No tasks planned for today"
            message="Add a task or let AI sketch a plan for your day."
            action={
              <Link to="/tasks">
                <Button size="sm">Go to tasks</Button>
              </Link>
            }
          />
        )}
      </div>

      <div className="neu card">
        <div className="card-title">
          <h3>Focus this week</h3>
          <Link to="/progress" className="small">
            Progress →
          </Link>
        </div>
        <BarChart points={weeklyFocusPoints(sessions ?? [])} height={150} axes />
      </div>

      {plannerOpen ? (
        <PlanMyDayModal
          onClose={() => {
            setPlannerOpen(false);
            void load(); // tasks may have been created from AI suggestions
          }}
          defaultMinutes={parseDailyMinutes(profile?.dailyAvailableTime)}
        />
      ) : null}
    </div>
  );
}

/** Best-effort minutes from the profile's free-text daily time choice. */
function parseDailyMinutes(v: string | null | undefined): number {
  if (!v) return 120;
  const hours = v.match(/(\d+(\.\d+)?)\s*\+?\s*hour/i);
  if (hours) return Math.round(parseFloat(hours[1]) * 60);
  const mins = v.match(/(\d+)\s*min/i);
  if (mins) return parseInt(mins[1], 10);
  return 120;
}

/** Last 7 days of focus minutes derived from real completed sessions,
 *  keyed by each session's end day (oldest → newest). */
function weeklyFocusPoints(sessions: FocusSession[]) {
  const byDay = new Map<string, number>();
  for (const s of sessions) {
    if (s.status !== 'completed' || !s.durationSeconds || !s.endedAt) continue;
    const day = s.endedAt.slice(0, 10);
    byDay.set(day, (byDay.get(day) ?? 0) + Math.round(s.durationSeconds / 60));
  }
  const pts: { date: string; value: number }[] = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const key = toKey(d);
    pts.push({ date: key, value: byDay.get(key) ?? 0 });
  }
  return pts;
}

/* ------------------------------------------------------------------ */
/* Plan My Day — AI daily planner (preview-only; nothing is persisted). */

function PlanMyDayModal({
  onClose,
  defaultMinutes,
}: {
  onClose: () => void;
  defaultMinutes: number;
}) {
  const [minutes, setMinutes] = useState(defaultMinutes);
  const [start, setStart] = useState('09:00');
  const [end, setEnd] = useState('18:00');
  const [breakM, setBreakM] = useState(10);
  const [context, setContext] = useState('');
  const [plan, setPlan] = useState<DailyPlan | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  // Indices of AI-suggested tasks the user wants to keep (all on by default).
  const [picked, setPicked] = useState<Set<number>>(new Set());

  const generate = async () => {
    setBusy(true);
    setError(null);
    try {
      const p = await ep.aiDailyPlan({
        date: toKey(new Date()),
        availableMinutes: minutes,
        startTime: start,
        endTime: end,
        breakMinutes: breakM,
        dailyContext: context,
      });
      setPlan(p);
      // Start with every suggestion checked — the user unchecks what they don't want.
      setPicked(new Set((p?.suggestedTasks ?? []).map((_, i) => i)));
    } catch (e: any) {
      setError(e.message ?? 'Could not generate a plan.');
    } finally {
      setBusy(false);
    }
  };

  // Creates only the ticked suggestions through the normal task endpoint
  // (a real POST per task — this is the one step that persists anything),
  // then re-plans from the user's now-real task list.
  const acceptSuggestions = async () => {
    if (!plan || picked.size === 0) return;
    setBusy(true);
    setError(null);
    try {
      const chosen = plan.suggestedTasks.filter((_, i) => picked.has(i));
      for (const s of chosen) {
        await ep.createTask({
          title: s.title,
          priority: s.priority,
          estimatedMinutes: s.minutes,
          dueDate: plan.date,
        });
      }
      // Re-run the planner: the tasks now really exist, so this second
      // call returns a normal schedule instead of suggestions.
      const p = await ep.aiDailyPlan({
        date: plan.date,
        availableMinutes: minutes,
        startTime: start,
        endTime: end,
        breakMinutes: breakM,
        dailyContext: context,
      });
      setPlan(p);
      setPicked(new Set());
    } catch (e: any) {
      setError(e.message ?? 'Could not add the selected tasks.');
    } finally {
      setBusy(false);
    }
  };

  const togglePick = (i: number) => {
    setPicked((prev) => {
      const next = new Set(prev);
      if (next.has(i)) next.delete(i);
      else next.add(i);
      return next;
    });
  };

  // Reordering happens purely in memory — accepting a plan never writes
  // anything, exactly like the mobile SessionPlanStore.
  const move = (i: number, dir: -1 | 1) => {
    if (!plan) return;
    const arr = [...plan.scheduled];
    const j = i + dir;
    if (j < 0 || j >= arr.length) return;
    [arr[i], arr[j]] = [arr[j], arr[i]];
    setPlan({ ...plan, scheduled: arr });
  };

  const suggestions = plan?.suggestedTasks ?? [];

  return (
    <Modal title="Plan my day" onClose={onClose} wide>
      <div className="stack">
        <p className="small text-2">
          AI suggests a schedule from your open tasks. Everything stays editable and
          <strong> nothing is saved</strong> — start a focus session from any slot when you're ready.
        </p>

        {!plan ? (
          <>
            {error ? <ErrorBanner message={error} /> : null}
            <div className="grid grid-3">
              <Field label="Available minutes">
                <Input
                  type="number"
                  min={15}
                  step={15}
                  value={minutes}
                  onChange={(e) => setMinutes(parseInt(e.target.value || '0', 10))}
                />
              </Field>
              <Field label="Start time">
                <Input type="time" value={start} onChange={(e) => setStart(e.target.value)} />
              </Field>
              <Field label="End time">
                <Input type="time" value={end} onChange={(e) => setEnd(e.target.value)} />
              </Field>
            </div>
            <Field label="Break minutes (between slots)">
              <Input
                type="number"
                min={0}
                max={60}
                value={breakM}
                onChange={(e) => setBreakM(parseInt(e.target.value || '0', 10))}
              />
            </Field>
            <Field label="What should your day look like?" hint="Treated as context, never as stored data.">
              <Textarea
                value={context}
                placeholder="e.g. Deep work in the morning, meetings after lunch, gym at 6."
                onChange={(e) => setContext(e.target.value)}
              />
            </Field>
            <Button variant="primary" onClick={() => void generate()} disabled={busy}>
              <IconSparkles size={16} /> {busy ? 'Thinking…' : 'Generate plan'}
            </Button>
          </>
        ) : (
          <>
            <div className="row" style={{ gap: 10 }}>
              <span className="badge badge-accent">capacity {formatMinutes(plan.capacityMinutes)}</span>
              <span className="badge badge-accent">planned {formatMinutes(plan.plannedMinutes)}</span>
              <span className="badge badge-accent">left {formatMinutes(plan.remainingMinutes)}</span>
            </div>

            {plan.warnings.map((w, i) => (
              <div key={i} className="banner banner-warn">
                {w}
              </div>
            ))}

            {suggestions.length > 0 ? (
              // AI proposed tasks because there was nothing to schedule.
              // Nothing exists yet — the user ticks what they want, and only
              // those are created when they press the button below.
              <>
                <div className="stack" style={{ gap: 10 }}>
                  {suggestions.map((s, i) => (
                    <div key={i} className="list-row">
                      <Checkbox checked={picked.has(i)} onChange={() => togglePick(i)} />
                      <div className="grow">
                        <p className="title">{s.title}</p>
                        <p className="small muted">{formatMinutes(s.minutes)}</p>
                      </div>
                      <PriorityBadge priority={s.priority} />
                    </div>
                  ))}
                </div>
                <div className="row" style={{ justifyContent: 'space-between' }}>
                  <Button
                    variant="ghost"
                    onClick={() => {
                      setPlan(null);
                      setError(null);
                    }}
                  >
                    Start over
                  </Button>
                  <Button
                    variant="primary"
                    onClick={() => void acceptSuggestions()}
                    disabled={busy || picked.size === 0}
                  >
                    <IconPlus size={16} />
                    {busy ? 'Adding…' : `Add ${picked.size} selected & plan my day`}
                  </Button>
                </div>
              </>
            ) : (
              <>
            <div className="stack" style={{ gap: 10 }}>
              {plan.scheduled.map((s, i) => (
                <div key={`${s.taskId}-${i}`} className="list-row">
                  <span className="badge badge-accent" style={{ minWidth: 52, justifyContent: 'center' }}>
                    {s.start}
                  </span>
                  <div className="grow">
                    <p className="title">{s.title}</p>
                    <p className="small muted">
                      {formatMinutes(s.minutes)}
                      {s.isFallbackEstimate ? ' · estimated' : ''}
                    </p>
                  </div>
                  <PriorityBadge priority={s.priority} />
                  <div className="row" style={{ gap: 4, flexWrap: 'nowrap' }}>
                    <Button size="sm" variant="ghost" onClick={() => move(i, -1)} aria-label="Move up">
                      ↑
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => move(i, 1)} aria-label="Move down">
                      ↓
                    </Button>
                    <Link to={`/focus?task=${s.taskId}`}>
                      <Button size="sm">Focus</Button>
                    </Link>
                  </div>
                </div>
              ))}
              {plan.breaks.map((b, i) => (
                <p key={i} className="small muted center">
                  ☕ break at {b.start} · {b.minutes}m
                </p>
              ))}
            </div>

            {plan.unscheduled.length ? (
              <div className="neu-inset" style={{ padding: 14 }}>
                <p className="small" style={{ fontWeight: 700, marginBottom: 6 }}>
                  Didn't fit
                </p>
                {plan.unscheduled.map((u, i) => (
                  <p key={i} className="small text-2">
                    • {u.title} — {u.reason}
                  </p>
                ))}
              </div>
            ) : null}
              </>
            )}

            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <Button
                variant="ghost"
                onClick={() => {
                  setPlan(null);
                  setError(null);
                }}
              >
                Regenerate
              </Button>
              <Button variant="primary" onClick={onClose}>
                Done
              </Button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
}
