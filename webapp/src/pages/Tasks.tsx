// Tasks — list with filters + create dialog (real POST /tasks).
import { useCallback, useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';

import * as ep from '../api/endpoints';
import {
  Button,
  Checkbox,
  EmptyState,
  ErrorBanner,
  Field,
  IconPlus,
  Input,
  Modal,
  PriorityBadge,
  Select,
  Skeleton,
  Textarea,
} from '../components/neu';
import type { Goal, Milestone, Task } from '../types';
import { formatDay } from '../utils/dates';

const FILTERS = [
  { key: '', label: 'All' },
  { key: 'pending', label: 'Pending' },
  { key: 'in_progress', label: 'In progress' },
  { key: 'completed', label: 'Completed' },
];

export default function Tasks() {
  const [tasks, setTasks] = useState<Task[] | null>(null);
  const [goals, setGoals] = useState<Goal[]>([]);
  const [filter, setFilter] = useState('');
  const [goalFilter, setGoalFilter] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  const load = useCallback(async () => {
    try {
      const t = await ep.listTasks();
      setTasks(t);
      setGoals(await ep.listGoals());
      setError(null);
    } catch (e: any) {
      setError(e.message ?? 'Could not load tasks.');
      setTasks((v) => v ?? []);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const visible = useMemo(
    () =>
      (tasks ?? []).filter(
        (t) => (!filter || t.status === filter) && (!goalFilter || t.goalId === goalFilter),
      ),
    [tasks, filter, goalFilter],
  );

  const toggle = async (t: Task) => {
    const next = t.status === 'completed' ? 'pending' : 'completed';
    setTasks((l) => (l ?? []).map((x) => (x.id === t.id ? { ...x, status: next } : x)));
    try {
      const updated = await ep.setTaskStatus(t.id, next);
      setTasks((l) => (l ?? []).map((x) => (x.id === t.id ? updated : x)));
    } catch (e: any) {
      setError(e.message ?? 'Could not update the task.');
      void load();
    }
  };

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <h1>Tasks</h1>
          <p className="sub">Break goals into days you can actually finish.</p>
        </div>
        <Button variant="primary" onClick={() => setCreating(true)}>
          <IconPlus size={16} /> New task
        </Button>
      </div>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="row">
        {FILTERS.map((f) => (
          <button
            key={f.key}
            className={`chip ${filter === f.key ? 'active' : ''}`}
            onClick={() => setFilter(f.key)}
          >
            {f.label}
          </button>
        ))}
        {goals.length ? (
          <Select
            style={{ maxWidth: 220, minHeight: 34, padding: '4px 12px', borderRadius: 100 }}
            value={goalFilter}
            onChange={(e) => setGoalFilter(e.target.value)}
            aria-label="Filter by goal"
          >
            <option value="">All goals</option>
            {goals.map((g) => (
              <option key={g.id} value={g.id}>
                {g.name}
              </option>
            ))}
          </Select>
        ) : null}
      </div>

      {tasks === null ? (
        <div className="stack">
          <Skeleton height={56} />
          <Skeleton height={56} />
          <Skeleton height={56} />
        </div>
      ) : visible.length ? (
        <div className="stack" style={{ gap: 10 }}>
          {visible.map((t) => (
            <div key={t.id} className={`list-row ${t.status === 'completed' ? 'done' : ''}`}>
              <Checkbox
                checked={t.status === 'completed'}
                onChange={() => void toggle(t)}
                label={`Complete ${t.title}`}
              />
              <Link to={`/tasks/${t.id}`} className="grow title" style={{ color: 'inherit' }}>
                {t.title}
              </Link>
              {t.goalName ? <span className="badge badge-accent">{t.goalName}</span> : null}
              {t.subtaskCount > 0 ? (
                <span className="small muted">
                  {t.completedSubtasks}/{t.subtaskCount}
                </span>
              ) : null}
              {t.dueDate ? <span className="small muted">{formatDay(t.dueDate)}</span> : null}
              <PriorityBadge priority={t.priority} />
            </div>
          ))}
        </div>
      ) : (
        <EmptyState
          icon={<IconPlus size={24} />}
          title={filter || goalFilter ? 'Nothing matches these filters' : 'No tasks yet'}
          message={
            filter || goalFilter
              ? 'Try a different filter.'
              : 'Create your first task — or open a goal and let AI break it down.'
          }
          action={
            !filter && !goalFilter ? (
              <Button size="sm" onClick={() => setCreating(true)}>
                New task
              </Button>
            ) : undefined
          }
        />
      )}

      {creating ? (
        <TaskFormModal
          goals={goals}
          onClose={() => setCreating(false)}
          onCreated={() => {
            setCreating(false);
            void load();
          }}
        />
      ) : null}
    </div>
  );
}

/** Create-task dialog. Milestone select appears once a goal is chosen. */
export function TaskFormModal({
  goals,
  onClose,
  onCreated,
}: {
  goals: Goal[];
  onClose: () => void;
  onCreated: (t: Task) => void;
}) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [priority, setPriority] = useState('medium');
  const [category, setCategory] = useState('');
  const [dueDate, setDueDate] = useState('');
  const [estimatedMinutes, setEstimatedMinutes] = useState('');
  const [goalId, setGoalId] = useState('');
  const [milestones, setMilestones] = useState<Milestone[]>([]);
  const [milestoneId, setMilestoneId] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Load the chosen goal's milestones so the task can hang off one.
  useEffect(() => {
    setMilestoneId('');
    if (!goalId) {
      setMilestones([]);
      return;
    }
    void ep.listMilestones(goalId).then(setMilestones).catch(() => setMilestones([]));
  }, [goalId]);

  const submit = async () => {
    setError(null);
    if (title.trim().length < 1) {
      setError('Give the task a title.');
      return;
    }
    setBusy(true);
    try {
      const t = await ep.createTask({
        title: title.trim(),
        ...(description.trim() ? { description: description.trim() } : {}),
        priority,
        ...(category.trim() ? { category: category.trim() } : {}),
        ...(dueDate ? { dueDate } : {}),
        ...(estimatedMinutes ? { estimatedMinutes: parseInt(estimatedMinutes, 10) } : {}),
        ...(goalId ? { goalId } : {}),
        ...(milestoneId ? { milestoneId } : {}),
      });
      onCreated(t);
    } catch (e: any) {
      setError(e.message ?? 'Could not create the task.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title="New task" onClose={onClose}>
      <form
        className="stack"
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        {error ? <ErrorBanner message={error} /> : null}
        <Field label="Title">
          <Input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="e.g. Draft project outline" autoFocus />
        </Field>
        <Field label="Description">
          <Textarea value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Optional details…" />
        </Field>
        <div className="grid grid-3">
          <Field label="Priority">
            <Select value={priority} onChange={(e) => setPriority(e.target.value)}>
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
            </Select>
          </Field>
          <Field label="Due date">
            <Input type="date" value={dueDate} onChange={(e) => setDueDate(e.target.value)} />
          </Field>
          <Field label="Est. minutes">
            <Input
              type="number"
              min={5}
              step={5}
              value={estimatedMinutes}
              onChange={(e) => setEstimatedMinutes(e.target.value)}
              placeholder="e.g. 45"
            />
          </Field>
        </div>
        <div className="grid grid-2">
          <Field label="Category">
            <Input value={category} onChange={(e) => setCategory(e.target.value)} placeholder="e.g. Work, Health…" />
          </Field>
          <Field label="Goal">
            <Select value={goalId} onChange={(e) => setGoalId(e.target.value)}>
              <option value="">No goal</option>
              {goals.map((g) => (
                <option key={g.id} value={g.id}>
                  {g.name}
                </option>
              ))}
            </Select>
          </Field>
        </div>
        {goalId && milestones.length ? (
          <Field label="Milestone">
            <Select value={milestoneId} onChange={(e) => setMilestoneId(e.target.value)}>
              <option value="">None</option>
              {milestones.map((m) => (
                <option key={m.id} value={m.id}>
                  {m.title}
                </option>
              ))}
            </Select>
          </Field>
        ) : null}
        <div className="row" style={{ justifyContent: 'flex-end' }}>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" type="submit" disabled={busy}>
            {busy ? 'Creating…' : 'Create task'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
