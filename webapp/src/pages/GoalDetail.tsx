// Goal detail — milestones CRUD, the goal's tasks, and the AI breakdown
// (phases → milestones/tasks proposal). Confirmed items are created
// through the normal endpoints; nothing is auto-saved.
import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';

import * as ep from '../api/endpoints';
import {
  Button,
  EmptyState,
  ErrorBanner,
  Field,
  IconCheck,
  IconPlus,
  IconSparkles,
  IconTrash,
  Input,
  Modal,
  PriorityBadge,
  ProgressBar,
  Skeleton,
} from '../components/neu';
import type { BreakdownProposal, Goal, Milestone, Task } from '../types';
import { formatDay } from '../utils/dates';

const MILESTONE_FLOW: Milestone['status'][] = ['pending', 'in_progress', 'completed'];

export default function GoalDetail() {
  const { id = '' } = useParams();
  const navigate = useNavigate();

  const [goal, setGoal] = useState<Goal | null>(null);
  const [milestones, setMilestones] = useState<Milestone[]>([]);
  const [tasks, setTasks] = useState<Task[]>([]);
  const [newMilestone, setNewMilestone] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [breakdownOpen, setBreakdownOpen] = useState(false);

  const load = useCallback(async () => {
    try {
      const [g, m, t] = await Promise.all([
        ep.fetchGoal(id),
        ep.listMilestones(id),
        ep.listTasks({ goalId: id }),
      ]);
      setGoal(g);
      setMilestones(m);
      setTasks(t);
    } catch (e: any) {
      setError(e.message ?? 'Could not load the goal.');
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  const addMilestone = async () => {
    if (!newMilestone.trim()) return;
    try {
      await ep.createMilestone(id, { title: newMilestone.trim() });
      setNewMilestone('');
      setMilestones(await ep.listMilestones(id));
      setGoal(await ep.fetchGoal(id)); // progress is server-computed
    } catch (e: any) {
      setError(e.message ?? 'Could not add the milestone.');
    }
  };

  const cycleStatus = async (m: Milestone) => {
    const next =
      MILESTONE_FLOW[(MILESTONE_FLOW.indexOf(m.status) + 1) % MILESTONE_FLOW.length];
    try {
      await ep.updateMilestone(m.id, { status: next });
      setMilestones(await ep.listMilestones(id));
      setGoal(await ep.fetchGoal(id));
    } catch (e: any) {
      setError(e.message ?? 'Could not update the milestone.');
    }
  };

  const removeMilestone = async (m: Milestone) => {
    try {
      await ep.deleteMilestone(m.id);
      setMilestones((l) => l.filter((x) => x.id !== m.id));
      setGoal(await ep.fetchGoal(id));
    } catch (e: any) {
      setError(e.message ?? 'Could not delete the milestone.');
    }
  };

  const setStatus = async (status: string) => {
    try {
      setGoal(await ep.updateGoal(id, { status }));
    } catch (e: any) {
      setError(e.message ?? 'Could not update the goal.');
    }
  };

  const remove = async () => {
    if (!window.confirm('Delete this goal? This cannot be undone.')) return;
    try {
      await ep.deleteGoal(id);
      navigate('/goals');
    } catch (e: any) {
      setError(e.message ?? 'Could not delete the goal.');
    }
  };

  if (!goal) {
    return (
      <div className="stack">
        {error ? <ErrorBanner message={error} /> : null}
        <Skeleton height={160} />
        <Skeleton height={180} />
      </div>
    );
  }

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <p className="small">
            <Link to="/goals">← Goals</Link>
          </p>
          <h1>{goal.name}</h1>
          <div className="row" style={{ marginTop: 6 }}>
            {goal.growthArea ? <span className="badge badge-accent">{goal.growthArea}</span> : null}
            {goal.targetDate ? <span className="small muted">target {formatDay(goal.targetDate)}</span> : null}
          </div>
        </div>
        <Button variant="primary" onClick={() => setBreakdownOpen(true)}>
          <IconSparkles size={16} /> Break down with AI
        </Button>
      </div>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="neu card stack">
        <ProgressBar value={goal.progress} />
        <div className="row" style={{ justifyContent: 'space-between' }}>
          <span className="small text-2">
            {goal.progress}% · {goal.completedMilestones}/{goal.milestoneCount} milestones ·{' '}
            {tasks.filter((t) => t.status === 'completed').length}/{tasks.length} tasks done
          </span>
          <div className="row" style={{ gap: 6 }}>
            {['active', 'completed', 'archived'].map((s) => (
              <button
                key={s}
                className={`chip ${goal.status === s ? 'active' : ''}`}
                onClick={() => void setStatus(s)}
                style={{ textTransform: 'capitalize' }}
              >
                {s}
              </button>
            ))}
            <Button variant="danger" size="sm" onClick={() => void remove()}>
              <IconTrash size={14} />
            </Button>
          </div>
        </div>
        {goal.whyItMatters ? (
          <p className="small text-2">
            <strong>Why:</strong> {goal.whyItMatters}
          </p>
        ) : null}
      </div>

      <div className="neu card">
        <div className="card-title">
          <h3>Milestones</h3>
        </div>
        <div className="stack" style={{ gap: 10 }}>
          {milestones.map((m) => (
            <div key={m.id} className={`list-row ${m.status === 'completed' ? 'done' : ''}`}>
              <button
                className={`checkbox ${m.status === 'completed' ? 'checked' : ''}`}
                onClick={() => void cycleStatus(m)}
                aria-label={`Cycle status of ${m.title}`}
                title={`Status: ${m.status.replace('_', ' ')} — click to advance`}
              >
                <IconCheck size={14} />
              </button>
              <span className="grow title">{m.title}</span>
              <span className="small muted" style={{ textTransform: 'capitalize' }}>
                {m.status.replace('_', ' ')}
              </span>
              <Button variant="ghost" size="sm" onClick={() => void removeMilestone(m)} aria-label="Delete milestone">
                <IconTrash size={14} />
              </Button>
            </div>
          ))}
          {!milestones.length ? (
            <p className="small muted">
              No milestones yet — add them manually or let AI propose phases.
            </p>
          ) : null}
          <div className="row" style={{ flexWrap: 'nowrap' }}>
            <Input
              value={newMilestone}
              placeholder="Add a milestone…"
              onChange={(e) => setNewMilestone(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') void addMilestone();
              }}
            />
            <Button onClick={() => void addMilestone()} disabled={!newMilestone.trim()}>
              <IconPlus size={15} />
            </Button>
          </div>
        </div>
      </div>

      <div className="neu card">
        <div className="card-title">
          <h3>Tasks in this goal</h3>
          <Link to="/tasks" className="small">
            All tasks →
          </Link>
        </div>
        {tasks.length ? (
          <div className="stack" style={{ gap: 10 }}>
            {tasks.map((t) => (
              <Link key={t.id} to={`/tasks/${t.id}`} style={{ color: 'inherit' }}>
                <div className={`list-row ${t.status === 'completed' ? 'done' : ''}`}>
                  <span className="grow title">{t.title}</span>
                  {t.milestoneTitle ? <span className="small muted">↳ {t.milestoneTitle}</span> : null}
                  <PriorityBadge priority={t.priority} />
                </div>
              </Link>
            ))}
          </div>
        ) : (
          <EmptyState
            icon={<IconPlus size={22} />}
            title="No tasks yet"
            message="Add tasks under this goal, or break the goal down with AI."
          />
        )}
      </div>

      {breakdownOpen ? (
        <AIBreakdownModal
          goal={goal}
          onClose={() => setBreakdownOpen(false)}
          onCreated={() => void load()}
        />
      ) : null}
    </div>
  );
}

/* ------------- AI Breakdown: phases → milestones + tasks (preview) ------------- */

function AIBreakdownModal({
  goal,
  onClose,
  onCreated,
}: {
  goal: Goal;
  onClose: () => void;
  onCreated: () => void;
}) {
  const [instructions, setInstructions] = useState('');
  const [proposal, setProposal] = useState<BreakdownProposal | null>(null);
  const [pickedPhases, setPickedPhases] = useState<Set<number>>(new Set());
  const [pickedTasks, setPickedTasks] = useState<Set<string>>(new Set()); // `${phase}:${task}`
  const [busy, setBusy] = useState(false);
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const generate = async () => {
    setBusy(true);
    setError(null);
    try {
      const p = await ep.aiBreakdown({ goalId: goal.id, instructions });
      setProposal(p);
      setPickedPhases(new Set(p.phases.map((_, i) => i)));
      setPickedTasks(
        new Set(
          p.phases.flatMap((ph, pi) => ph.tasks.map((_, ti) => `${pi}:${ti}`)),
        ),
      );
    } catch (e: any) {
      setError(e.message ?? 'AI is unavailable right now.');
    } finally {
      setBusy(false);
    }
  };

  // Confirmation creates real data: one milestone per checked phase, then
  // one task per checked item under its milestone.
  const createSelected = async () => {
    if (!proposal) return;
    setCreating(true);
    setError(null);
    try {
      for (const pi of [...pickedPhases].sort()) {
        const phase = proposal.phases[pi];
        const ms = await ep.createMilestone(goal.id, {
          title: phase.title,
          ...(phase.description ? { description: phase.description } : {}),
        });
        for (const ti of phase.tasks.map((_, i) => i).filter((i) => pickedTasks.has(`${pi}:${i}`))) {
          const t = phase.tasks[ti];
          await ep.createTask({
            title: t.title,
            ...(t.description ? { description: t.description } : {}),
            ...(t.estimatedMinutes ? { estimatedMinutes: t.estimatedMinutes } : {}),
            goalId: goal.id,
            milestoneId: ms.id,
          });
        }
      }
      onCreated();
      onClose();
    } catch (e: any) {
      setError(e.message ?? 'Could not create the selected items.');
    } finally {
      setCreating(false);
    }
  };

  const togglePhase = (pi: number) => {
    const n = new Set(pickedPhases);
    if (n.has(pi)) {
      n.delete(pi);
      const t = new Set(pickedTasks);
      [...pickedTasks].filter((k) => k.startsWith(`${pi}:`)).forEach((k) => t.delete(k));
      setPickedTasks(t);
    } else {
      n.add(pi);
    }
    setPickedPhases(n);
  };

  const toggleTask = (k: string) => {
    const n = new Set(pickedTasks);
    if (n.has(k)) n.delete(k);
    else n.add(k);
    setPickedTasks(n);
  };

  const totalPicked = [...pickedTasks].filter((k) =>
    pickedPhases.has(parseInt(k.split(':')[0], 10)),
  ).length;

  return (
    <Modal title="✨ Break down this goal" onClose={onClose} wide>
      <div className="stack">
        <p className="small text-2">
          AI proposes phases (→ milestones) and tasks. Check what to keep — only confirmed
          items are created, under <strong>{goal.name}</strong>.
        </p>
        {error ? <ErrorBanner message={error} /> : null}

        {proposal === null ? (
          <>
            <Field label="Anything AI should know?" hint="Optional.">
              <Input value={instructions} onChange={(e) => setInstructions(e.target.value)} />
            </Field>
            <Button variant="primary" onClick={() => void generate()} disabled={busy}>
              <IconSparkles size={16} /> {busy ? 'Thinking…' : 'Generate breakdown'}
            </Button>
          </>
        ) : (
          <>
            {proposal.phases.map((ph, pi) => (
              <div key={pi} className="neu-inset" style={{ padding: 14 }}>
                <div className="row">
                  <button
                    className={`checkbox ${pickedPhases.has(pi) ? 'checked' : ''}`}
                    onClick={() => togglePhase(pi)}
                    aria-label={`Keep phase ${ph.title}`}
                  >
                    <IconCheck size={14} />
                  </button>
                  <div className="grow">
                    <p className="title">{ph.title}</p>
                    {ph.description ? <p className="small muted">{ph.description}</p> : null}
                  </div>
                  <span className="small muted">milestone</span>
                </div>
                <div className="stack mt-1" style={{ gap: 8 }}>
                  {ph.tasks.map((t, ti) => {
                    const k = `${pi}:${ti}`;
                    return (
                      <div key={k} className="row" style={{ gap: 10 }}>
                        <button
                          className={`checkbox ${pickedTasks.has(k) ? 'checked' : ''}`}
                          onClick={() => toggleTask(k)}
                          aria-label={`Keep task ${t.title}`}
                          disabled={!pickedPhases.has(pi)}
                          style={{ opacity: pickedPhases.has(pi) ? 1 : 0.4 }}
                        >
                          <IconCheck size={12} />
                        </button>
                        <span className="grow small">{t.title}</span>
                        {t.estimatedMinutes ? (
                          <span className="small muted">≈{t.estimatedMinutes}m</span>
                        ) : null}
                      </div>
                    );
                  })}
                </div>
              </div>
            ))}
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <Button variant="ghost" onClick={() => void generate()} disabled={busy}>
                Regenerate
              </Button>
              <Button
                variant="primary"
                onClick={() => void createSelected()}
                disabled={!totalPicked || creating}
              >
                {creating
                  ? 'Creating…'
                  : `Create ${pickedPhases.size} milestone(s), ${totalPicked} task(s)`}
              </Button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
}
