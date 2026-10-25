// Task detail — edit fields, status transitions, subtasks, and the two
// contextual AI features (subtask suggestions, task improvement).
// AI outputs are editable previews; only confirmed items hit the normal
// CRUD endpoints, exactly like the mobile sheets.
import { useCallback, useEffect, useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';

import * as ep from '../api/endpoints';
import {
  Button,
  Checkbox,
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
  Select,
  Skeleton,
  Textarea,
} from '../components/neu';
import type { Subtask, Task, TaskImprovement, SubtaskSuggestion } from '../types';

const STATUSES: { key: string; label: string }[] = [
  { key: 'pending', label: 'Pending' },
  { key: 'in_progress', label: 'In progress' },
  { key: 'completed', label: 'Completed' },
  { key: 'cancelled', label: 'Cancelled' },
];

export default function TaskDetail() {
  const { id = '' } = useParams();
  const navigate = useNavigate();

  const [task, setTask] = useState<Task | null>(null);
  const [subtasks, setSubtasks] = useState<Subtask[]>([]);
  const [form, setForm] = useState({
    title: '',
    description: '',
    priority: 'medium',
    category: '',
    dueDate: '',
    estimatedMinutes: '',
  });
  const [newSub, setNewSub] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);
  const [aiOpen, setAiOpen] = useState<null | 'assist' | 'improve'>(null);

  const load = useCallback(async () => {
    try {
      const [t, s] = await Promise.all([ep.fetchTask(id), ep.listSubtasks(id)]);
      setTask(t);
      setSubtasks(s);
      setForm({
        title: t.title,
        description: t.description ?? '',
        priority: t.priority,
        category: t.category ?? '',
        dueDate: t.dueDate ?? '',
        estimatedMinutes: t.estimatedMinutes != null ? String(t.estimatedMinutes) : '',
      });
    } catch (e: any) {
      setError(e.message ?? 'Could not load the task.');
    }
  }, [id]);

  useEffect(() => {
    void load();
  }, [load]);

  const save = async () => {
    if (!task) return;
    setBusy(true);
    setSaved(false);
    setError(null);
    try {
      const updated = await ep.updateTask(task.id, {
        title: form.title.trim(),
        description: form.description.trim() || null,
        priority: form.priority,
        category: form.category.trim() || null,
        dueDate: form.dueDate || null,
        estimatedMinutes: form.estimatedMinutes ? parseInt(form.estimatedMinutes, 10) : null,
      });
      setTask(updated);
      setSaved(true);
    } catch (e: any) {
      setError(e.message ?? 'Could not save the task.');
    } finally {
      setBusy(false);
    }
  };

  const setStatus = async (status: string) => {
    if (!task) return;
    try {
      setTask(await ep.setTaskStatus(task.id, status));
    } catch (e: any) {
      setError(e.message ?? 'Could not change the status.');
    }
  };

  const remove = async () => {
    if (!task || !window.confirm('Delete this task? This cannot be undone.')) return;
    try {
      await ep.deleteTask(task.id);
      navigate('/tasks');
    } catch (e: any) {
      setError(e.message ?? 'Could not delete the task.');
    }
  };

  const addSubtask = async () => {
    if (!task || !newSub.trim()) return;
    try {
      await ep.createSubtask(task.id, newSub.trim());
      setNewSub('');
      setSubtasks(await ep.listSubtasks(task.id));
      setTask(await ep.fetchTask(task.id));
    } catch (e: any) {
      setError(e.message ?? 'Could not add the subtask.');
    }
  };

  const toggleSubtask = async (s: Subtask) => {
    try {
      await ep.updateSubtask(s.id, { isCompleted: !s.isCompleted });
      setSubtasks(await ep.listSubtasks(task!.id));
      setTask(await ep.fetchTask(task!.id));
    } catch (e: any) {
      setError(e.message ?? 'Could not update the subtask.');
    }
  };

  const removeSubtask = async (s: Subtask) => {
    try {
      await ep.deleteSubtask(s.id);
      setSubtasks((l) => l.filter((x) => x.id !== s.id));
      setTask(await ep.fetchTask(task!.id));
    } catch (e: any) {
      setError(e.message ?? 'Could not delete the subtask.');
    }
  };

  if (!task) {
    return (
      <div className="stack">
        {error ? <ErrorBanner message={error} /> : null}
        <Skeleton height={200} />
        <Skeleton height={140} />
      </div>
    );
  }

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <p className="small">
            <Link to="/tasks">← Tasks</Link>
          </p>
          <h1>{task.title}</h1>
          <div className="row" style={{ marginTop: 6 }}>
            <PriorityBadge priority={task.priority} />
            {task.goalName ? <span className="badge badge-accent">{task.goalName}</span> : null}
            {task.milestoneTitle ? (
              <span className="small muted">↳ {task.milestoneTitle}</span>
            ) : null}
          </div>
        </div>
        <div className="row">
          <Button onClick={() => setAiOpen('assist')}>
            <IconSparkles size={15} /> AI assist
          </Button>
          <Button onClick={() => setAiOpen('improve')}>
            <IconSparkles size={15} /> Improve
          </Button>
        </div>
      </div>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="neu card stack">
        <div className="card-title">
          <h3>Details</h3>
          <div className="row" style={{ gap: 6 }}>
            {STATUSES.map((s) => (
              <button
                key={s.key}
                className={`chip ${task.status === s.key ? 'active' : ''}`}
                onClick={() => void setStatus(s.key)}
              >
                {s.label}
              </button>
            ))}
          </div>
        </div>

        <Field label="Title">
          <Input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} />
        </Field>
        <Field label="Description">
          <Textarea
            value={form.description}
            onChange={(e) => setForm({ ...form, description: e.target.value })}
          />
        </Field>
        <div className="grid grid-3">
          <Field label="Priority">
            <Select value={form.priority} onChange={(e) => setForm({ ...form, priority: e.target.value })}>
              <option value="low">Low</option>
              <option value="medium">Medium</option>
              <option value="high">High</option>
            </Select>
          </Field>
          <Field label="Due date">
            <Input
              type="date"
              value={form.dueDate}
              onChange={(e) => setForm({ ...form, dueDate: e.target.value })}
            />
          </Field>
          <Field label="Est. minutes">
            <Input
              type="number"
              min={5}
              step={5}
              value={form.estimatedMinutes}
              onChange={(e) => setForm({ ...form, estimatedMinutes: e.target.value })}
            />
          </Field>
        </div>
        <Field label="Category">
          <Input value={form.category} onChange={(e) => setForm({ ...form, category: e.target.value })} />
        </Field>

        <div className="row" style={{ justifyContent: 'space-between' }}>
          <Button variant="danger" onClick={() => void remove()}>
            <IconTrash size={15} /> Delete task
          </Button>
          <div className="row">
            {saved ? <span className="small" style={{ color: 'var(--success)' }}>Saved ✓</span> : null}
            <Button variant="primary" onClick={() => void save()} disabled={busy}>
              {busy ? 'Saving…' : 'Save changes'}
            </Button>
          </div>
        </div>
      </div>

      <div className="neu card">
        <div className="card-title">
          <h3>
            Subtasks{' '}
            {/* GET /tasks/:id returns the raw task row without the
                subtask_count aggregate (only the list endpoint computes
                it), so — exactly like the Flutter task detail screen —
                the counts are derived from the fetched subtask list. */}
            <span className="muted small">
              {subtasks.filter((s) => s.isCompleted).length}/{subtasks.length}
            </span>
          </h3>
        </div>
        <div className="stack" style={{ gap: 10 }}>
          {subtasks.map((s) => (
            <div key={s.id} className={`list-row ${s.isCompleted ? 'done' : ''}`}>
              <Checkbox checked={s.isCompleted} onChange={() => void toggleSubtask(s)} label={s.title} />
              <span className="grow title">{s.title}</span>
              <Button variant="ghost" size="sm" onClick={() => void removeSubtask(s)} aria-label="Delete subtask">
                <IconTrash size={14} />
              </Button>
            </div>
          ))}
          {!subtasks.length ? (
            <p className="small muted">No subtasks yet — break this down manually or ask AI for ideas.</p>
          ) : null}
          <div className="row" style={{ flexWrap: 'nowrap' }}>
            <Input
              value={newSub}
              placeholder="Add a subtask…"
              onChange={(e) => setNewSub(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') void addSubtask();
              }}
            />
            <Button onClick={() => void addSubtask()} disabled={!newSub.trim()}>
              <IconPlus size={15} />
            </Button>
          </div>
        </div>
      </div>

      {aiOpen === 'assist' ? (
        <AIAssistModal task={task} onClose={() => setAiOpen(null)} onAdded={() => void load()} />
      ) : null}
      {aiOpen === 'improve' ? (
        <AIImproveModal task={task} onClose={() => setAiOpen(null)} onApplied={() => void load()} />
      ) : null}
    </div>
  );
}

/* ---------------- AI Assist: subtask suggestions (preview) ---------------- */

function AIAssistModal({
  task,
  onClose,
  onAdded,
}: {
  task: Task;
  onClose: () => void;
  onAdded: () => void;
}) {
  const [instructions, setInstructions] = useState('');
  const [ideas, setIdeas] = useState<SubtaskSuggestion[] | null>(null);
  const [picked, setPicked] = useState<Set<number>>(new Set());
  const [busy, setBusy] = useState(false);
  const [adding, setAdding] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const generate = async () => {
    setBusy(true);
    setError(null);
    try {
      const s = await ep.aiSubtasks(task.id, instructions);
      setIdeas(s);
      setPicked(new Set(s.map((_, i) => i))); // preselect all, user can uncheck
    } catch (e: any) {
      setError(e.message ?? 'AI is unavailable right now.');
    } finally {
      setBusy(false);
    }
  };

  // Only the checked suggestions become real subtasks — the AI itself
  // never writes anything.
  const addSelected = async () => {
    if (!ideas) return;
    setAdding(true);
    setError(null);
    try {
      for (const i of [...picked].sort()) {
        await ep.createSubtask(task.id, ideas[i].title);
      }
      onAdded();
      onClose();
    } catch (e: any) {
      setError(e.message ?? 'Could not add the selected subtasks.');
    } finally {
      setAdding(false);
    }
  };

  return (
    <Modal title="✨ AI subtask ideas" onClose={onClose}>
      <div className="stack">
        <p className="small text-2">
          Suggestions for <strong>{task.title}</strong>. Edit nothing, keep what you like —
          only checked items are created.
        </p>
        {error ? <ErrorBanner message={error} /> : null}

        {ideas === null ? (
          <>
            <Field label="Anything AI should know?" hint="Optional instructions, e.g. 'keep each under 30 minutes'.">
              <Textarea value={instructions} onChange={(e) => setInstructions(e.target.value)} />
            </Field>
            <Button variant="primary" onClick={() => void generate()} disabled={busy}>
              <IconSparkles size={16} /> {busy ? 'Generating…' : 'Suggest subtasks'}
            </Button>
          </>
        ) : ideas.length ? (
          <>
            {ideas.map((s, i) => (
              <div key={i} className={`list-row ${picked.has(i) ? '' : ''}`}>
                <Checkbox
                  checked={picked.has(i)}
                  onChange={() => {
                    const n = new Set(picked);
                    if (n.has(i)) n.delete(i);
                    else n.add(i);
                    setPicked(n);
                  }}
                  label={s.title}
                />
                <div className="grow">
                  <p className="title">{s.title}</p>
                  {s.description ? <p className="small muted">{s.description}</p> : null}
                </div>
                {s.estimatedMinutes ? (
                  <span className="small muted">{s.estimatedMinutes}m</span>
                ) : null}
              </div>
            ))}
            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <Button variant="ghost" onClick={() => void generate()} disabled={busy}>
                Regenerate
              </Button>
              <Button variant="primary" onClick={() => void addSelected()} disabled={!picked.size || adding}>
                <IconCheck size={15} /> {adding ? 'Adding…' : `Add ${picked.size} subtask(s)`}
              </Button>
            </div>
          </>
        ) : (
          <EmptyState icon={<IconSparkles size={24} />} title="No ideas this time" message="Try adding instructions or regenerating." />
        )}
      </div>
    </Modal>
  );
}

/* ---------------- AI Improve: proposal (preview) ---------------- */

function AIImproveModal({
  task,
  onClose,
  onApplied,
}: {
  task: Task;
  onClose: () => void;
  onApplied: () => void;
}) {
  const [proposal, setProposal] = useState<TaskImprovement | null>(null);
  const [picked, setPicked] = useState<Set<string>>(new Set());
  const [busy, setBusy] = useState(false);
  const [applying, setApplying] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const generate = async () => {
    setBusy(true);
    setError(null);
    try {
      const p = await ep.aiImprove({
        taskId: task.id,
        title: task.title,
        description: task.description,
      });
      setProposal(p);
      // Preselect only fields that actually differ from the current task.
      const n = new Set<string>();
      if (p.title && p.title !== task.title) n.add('title');
      if (p.description && p.description !== task.description) n.add('description');
      if (p.priority && p.priority !== task.priority) n.add('priority');
      if (p.category && p.category !== task.category) n.add('category');
      if (p.estimatedMinutes && p.estimatedMinutes !== task.estimatedMinutes)
        n.add('estimatedMinutes');
      setPicked(n);
    } catch (e: any) {
      setError(e.message ?? 'AI is unavailable right now.');
    } finally {
      setBusy(false);
    }
  };

  const apply = async () => {
    if (!proposal) return;
    setApplying(true);
    setError(null);
    try {
      const fields: Record<string, unknown> = {};
      if (picked.has('title') && proposal.title) fields.title = proposal.title;
      if (picked.has('description')) fields.description = proposal.description;
      if (picked.has('priority') && proposal.priority) fields.priority = proposal.priority;
      if (picked.has('category')) fields.category = proposal.category;
      if (picked.has('estimatedMinutes') && proposal.estimatedMinutes)
        fields.estimatedMinutes = proposal.estimatedMinutes;
      await ep.updateTask(task.id, fields);
      onApplied();
      onClose();
    } catch (e: any) {
      setError(e.message ?? 'Could not apply the improvements.');
    } finally {
      setApplying(false);
    }
  };

  const toggle = (k: string) => {
    const n = new Set(picked);
    if (n.has(k)) n.delete(k);
    else n.add(k);
    setPicked(n);
  };

  return (
    <Modal title="✨ Improve this task" onClose={onClose}>
      <div className="stack">
        <p className="small text-2">
          A rewritten version of this task. Choose exactly which fields to apply.
        </p>
        {error ? <ErrorBanner message={error} /> : null}

        {proposal === null ? (
          <Button variant="primary" onClick={() => void generate()} disabled={busy}>
            <IconSparkles size={16} /> {busy ? 'Thinking…' : 'Generate improvements'}
          </Button>
        ) : (
          <>
            {proposal.title ? (
              <label className="list-row" style={{ cursor: 'pointer' }}>
                <Checkbox checked={picked.has('title')} onChange={() => toggle('title')} label="Apply title" />
                <div className="grow">
                  <p className="small muted">Title</p>
                  <p className="title">{proposal.title}</p>
                </div>
              </label>
            ) : null}
            {proposal.description ? (
              <label className="list-row" style={{ cursor: 'pointer', alignItems: 'flex-start' }}>
                <Checkbox
                  checked={picked.has('description')}
                  onChange={() => toggle('description')}
                  label="Apply description"
                />
                <div className="grow">
                  <p className="small muted">Description</p>
                  <p>{proposal.description}</p>
                </div>
              </label>
            ) : null}
            <div className="row">
              {proposal.priority ? (
                <button className={`chip ${picked.has('priority') ? 'active' : ''}`} onClick={() => toggle('priority')}>
                  Priority: {proposal.priority}
                </button>
              ) : null}
              {proposal.category ? (
                <button className={`chip ${picked.has('category') ? 'active' : ''}`} onClick={() => toggle('category')}>
                  Category: {proposal.category}
                </button>
              ) : null}
              {proposal.estimatedMinutes ? (
                <button
                  className={`chip ${picked.has('estimatedMinutes') ? 'active' : ''}`}
                  onClick={() => toggle('estimatedMinutes')}
                >
                  ≈ {proposal.estimatedMinutes} min
                </button>
              ) : null}
            </div>

            {proposal.subtasks.length ? (
              <div className="neu-inset" style={{ padding: 14 }}>
                <p className="small" style={{ fontWeight: 700, marginBottom: 6 }}>
                  Suggested subtasks (preview only)
                </p>
                {proposal.subtasks.map((s, i) => (
                  <p key={i} className="small text-2">
                    • {s}
                  </p>
                ))}
                <p className="small muted mt-1">Use “AI assist” on the task to add any of these.</p>
              </div>
            ) : null}

            <div className="row" style={{ justifyContent: 'flex-end' }}>
              <Button variant="ghost" onClick={() => void generate()} disabled={busy}>
                Regenerate
              </Button>
              <Button variant="primary" onClick={() => void apply()} disabled={!picked.size || applying}>
                {applying ? 'Applying…' : `Apply ${picked.size} change(s)`}
              </Button>
            </div>
          </>
        )}
      </div>
    </Modal>
  );
}
