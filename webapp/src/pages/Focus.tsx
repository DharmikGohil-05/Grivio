// Focus — timer with pause/resume, unfinished-session recovery, completion
// reflection and history. Elapsed time is always recomputed from server
// timestamps (started_at, paused_at, total_pause_seconds), never from a
// local counter, so closing the tab can't corrupt a session.
import { useCallback, useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

import * as ep from '../api/endpoints';
import { ProgressRing } from '../components/charts';
import {
  Button,
  EmptyState,
  ErrorBanner,
  Field,
  IconCheck,
  IconPlus,
  IconTimer,
  Modal,
  Select,
  Skeleton,
  Textarea,
} from '../components/neu';
import type { FocusSession, Task } from '../types';
import { elapsedSeconds, formatDay, formatMinutes } from '../utils/dates';

const RATINGS = ['Low', 'Okay', 'Good', 'Excellent'];

function fmtClock(totalSeconds: number): string {
  const h = Math.floor(totalSeconds / 3600);
  const m = Math.floor((totalSeconds % 3600) / 60);
  const s = totalSeconds % 60;
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

export default function Focus() {
  const [params] = useSearchParams();
  const preselect = params.get('task');

  const [tasks, setTasks] = useState<Task[]>([]);
  const [sessions, setSessions] = useState<FocusSession[] | null>(null);
  const [active, setActive] = useState<FocusSession | null>(null);
  const [selectedTask, setSelectedTask] = useState('');
  // `setTick` (below) only exists to trigger a 1s repaint while a session
  // runs; elapsed time itself is always recomputed from server timestamps,
  // so no local counter can drift.
  const [, setTick] = useState(0);
  const [error, setError] = useState<string | null>(null);
  const [reflecting, setReflecting] = useState<FocusSession | null>(null);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    try {
      const [open, s] = await Promise.all([
        ep.listTasks(),
        ep.listSessions(),
      ]);
      setTasks(open.filter((t) => t.status === 'pending' || t.status === 'in_progress'));
      setSessions(s);
      // Session recovery: any unfinished session becomes the active one,
      // exactly like the mobile app's recovery prompt. NOTE: the backend
      // has no 'paused' status — a paused session is status 'active' with
      // paused_at set (see backend focus.service.js), so 'active' alone
      // covers both running and paused sessions.
      const unfinished = s.find((x) => x.status === 'active');
      setActive(unfinished ?? null);
      if (preselect) setSelectedTask(preselect);
      setError(null);
    } catch (e: any) {
      setError(e.message ?? 'Could not load focus data.');
      setSessions((v) => v ?? []);
    }
  }, [preselect]);

  useEffect(() => {
    void load();
  }, [load]);

  // Repaint once a second only while a session is running. A paused
  // session has paused_at set (the backend has no 'paused' status), and
  // elapsedSeconds() already freezes at the pause moment.
  useEffect(() => {
    if (!active || active.pausedAt) return;
    const t = window.setInterval(() => setTick((x) => x + 1), 1000);
    return () => window.clearInterval(t);
  }, [active]);

  // Recomputed every render; the 1s `tick` state is what triggers those
  // renders while a session runs, so no local counter can drift.
  const elapsed = active ? elapsedSeconds(active) : 0;

  const start = async () => {
    setBusy(true);
    setError(null);
    try {
      setActive(await ep.startSession(selectedTask || null));
      setSessions(await ep.listSessions());
    } catch (e: any) {
      setError(e.message ?? 'Could not start the session.');
    } finally {
      setBusy(false);
    }
  };

  const pause = async () => {
    if (!active) return;
    try {
      setActive(await ep.pauseSession(active.id));
    } catch (e: any) {
      setError(e.message ?? 'Could not pause.');
    }
  };

  const resume = async () => {
    if (!active) return;
    try {
      setActive(await ep.resumeSession(active.id));
    } catch (e: any) {
      setError(e.message ?? 'Could not resume.');
    }
  };

  const complete = async (rating: string | null, reflection: string | null) => {
    if (!active) return;
    try {
      await ep.completeSession(active.id, rating, reflection);
      setActive(null);
      setReflecting(null);
      setSessions(await ep.listSessions());
    } catch (e: any) {
      setError(e.message ?? 'Could not complete the session.');
    }
  };

  const cancel = async () => {
    if (!active || !window.confirm('Cancel this focus session?')) return;
    try {
      await ep.cancelSession(active.id);
      setActive(null);
      setSessions(await ep.listSessions());
    } catch (e: any) {
      setError(e.message ?? 'Could not cancel the session.');
    }
  };

  const history = (sessions ?? [])
    .filter((s) => s.status === 'completed')
    .slice(0, 12);

  const focusToday = history
    .filter((s) => (s.endedAt ?? '').slice(0, 10) === new Date().toISOString().slice(0, 10))
    .reduce((acc, s) => acc + Math.round((s.durationSeconds ?? 0) / 60), 0);

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <h1>Focus</h1>
          <p className="sub">One task. One timer. Real progress.</p>
        </div>
      </div>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="neu card stack" style={{ alignItems: 'center', padding: '34px 24px' }}>
        {active ? (
          <>
            {/* Paused = paused_at set; the backend has no 'paused' status. */}
            {active.pausedAt ? (
              <span className="badge badge-medium">paused</span>
            ) : (
              <span className="badge badge-accent">focusing</span>
            )}
            <div className="timer-display" aria-live="polite">
              {fmtClock(elapsed)}
            </div>
            <p className="text-2">
              {active.taskTitle ? `Working on: ${active.taskTitle}` : 'Free focus session'}
            </p>
            <div className="row" style={{ justifyContent: 'center', marginTop: 8 }}>
              {active.pausedAt ? (
                <Button variant="primary" onClick={() => void resume()}>
                  Resume
                </Button>
              ) : (
                <Button onClick={() => void pause()}>Pause</Button>
              )}
              <Button variant="primary" onClick={() => setReflecting(active)}>
                <IconCheck size={15} /> Complete
              </Button>
              <Button variant="ghost" onClick={() => void cancel()}>
                Cancel
              </Button>
            </div>
          </>
        ) : (
          <>
            <div style={{ opacity: 0.85 }}>
              <ProgressRing value={0} size={108} stroke={9} label="ready" />
            </div>
            <Field label="What are you focusing on?">
              <Select
                value={selectedTask}
                onChange={(e) => setSelectedTask(e.target.value)}
                style={{ maxWidth: 340 }}
              >
                <option value="">Free session (no task)</option>
                {tasks.map((t) => (
                  <option key={t.id} value={t.id}>
                    {t.title}
                  </option>
                ))}
              </Select>
            </Field>
            <Button variant="primary" onClick={() => void start()} disabled={busy}>
              <IconTimer size={17} /> {busy ? 'Starting…' : 'Start focus'}
            </Button>
            <p className="small muted">
              {focusToday ? `You've focused ${formatMinutes(focusToday)} today.` : 'No focus time yet today.'}
            </p>
          </>
        )}
      </div>

      <div className="neu card">
        <div className="card-title">
          <h3>Recent sessions</h3>
        </div>
        {sessions === null ? (
          <div className="stack">
            <Skeleton height={48} />
            <Skeleton height={48} />
          </div>
        ) : history.length ? (
          <div className="stack" style={{ gap: 10 }}>
            {history.map((s) => (
              <div key={s.id} className="list-row">
                <IconTimer size={18} />
                <div className="grow">
                  <p className="title">{s.taskTitle ?? 'Free session'}</p>
                  <p className="small muted">{s.endedAt ? formatDay(s.endedAt.slice(0, 10)) : ''}</p>
                </div>
                {s.productivityRating ? (
                  <span className="badge badge-accent" style={{ textTransform: 'capitalize' }}>
                    {s.productivityRating}
                  </span>
                ) : null}
                <span className="small text-2">{formatMinutes(Math.round((s.durationSeconds ?? 0) / 60))}</span>
              </div>
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<IconPlus size={22} />}
            title="No completed sessions yet"
            message="Start your first focus session — it'll show up here with its reflection."
          />
        )}
      </div>

      {reflecting ? (
        <ReflectionModal session={reflecting} onClose={() => setReflecting(null)} onSave={complete} />
      ) : null}
    </div>
  );
}

/** Post-completion reflection: rating + note, saved with the session. */
function ReflectionModal({
  session,
  onClose,
  onSave,
}: {
  session: FocusSession;
  onClose: () => void;
  onSave: (rating: string | null, reflection: string | null) => Promise<void>;
}) {
  const [rating, setRating] = useState<string | null>(null);
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);

  const save = async () => {
    setBusy(true);
    try {
      await onSave(rating, note.trim() || null);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title="Session complete 🎉" onClose={onClose}>
      <div className="stack">
        <p className="text-2">
          Nice work
          {session.taskTitle ? ` on “${session.taskTitle}”` : ''}. How did it feel?
        </p>
        <div className="row">
          {RATINGS.map((r) => (
            <button
              key={r}
              className={`chip ${rating === r ? 'active' : ''}`}
              onClick={() => setRating(r)}
            >
              {r}
            </button>
          ))}
        </div>
        <Field label="Reflection (optional)">
          <Textarea
            value={note}
            placeholder="What worked? What will you do differently next time?"
            onChange={(e) => setNote(e.target.value)}
          />
        </Field>
        <div className="row" style={{ justifyContent: 'flex-end' }}>
          <Button variant="ghost" onClick={onClose}>
            Skip
          </Button>
          <Button variant="primary" onClick={() => void save()} disabled={busy}>
            {busy ? 'Saving…' : 'Save reflection'}
          </Button>
        </div>
      </div>
    </Modal>
  );
}
