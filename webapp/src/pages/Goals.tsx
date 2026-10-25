// Goals — cards with server-computed progress + create dialog.
import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';

import * as ep from '../api/endpoints';
import {
  Button,
  EmptyState,
  ErrorBanner,
  Field,
  IconFlag,
  IconPlus,
  Input,
  Modal,
  ProgressBar,
  Skeleton,
  Textarea,
} from '../components/neu';
import type { Goal } from '../types';
import { formatDay } from '../utils/dates';

const FILTERS = [
  { key: 'active', label: 'Active' },
  { key: 'completed', label: 'Completed' },
  { key: 'archived', label: 'Archived' },
];

export default function Goals() {
  const [goals, setGoals] = useState<Goal[] | null>(null);
  const [filter, setFilter] = useState('active');
  const [error, setError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);

  const load = useCallback(async () => {
    try {
      setGoals(await ep.listGoals(filter));
      setError(null);
    } catch (e: any) {
      setError(e.message ?? 'Could not load goals.');
      setGoals((v) => v ?? []);
    }
  }, [filter]);

  useEffect(() => {
    void load();
  }, [load]);

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <h1>Goals</h1>
          <p className="sub">Big directions, broken into milestones you can finish.</p>
        </div>
        <Button variant="primary" onClick={() => setCreating(true)}>
          <IconPlus size={16} /> New goal
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
      </div>

      {goals === null ? (
        <div className="grid grid-2">
          <Skeleton height={130} />
          <Skeleton height={130} />
        </div>
      ) : goals.length ? (
        <div className="grid grid-2">
          {goals.map((g) => (
            <Link key={g.id} to={`/goals/${g.id}`} style={{ color: 'inherit' }}>
              <div className="neu card stack" style={{ gap: 10 }}>
                <div className="row" style={{ justifyContent: 'space-between' }}>
                  <h3>{g.name}</h3>
                  {g.growthArea ? <span className="badge badge-accent">{g.growthArea}</span> : null}
                </div>
                {g.description ? <p className="small text-2">{g.description}</p> : null}
                <ProgressBar value={g.progress} />
                <div className="row" style={{ justifyContent: 'space-between' }}>
                  <span className="small muted">
                    {g.completedMilestones}/{g.milestoneCount} milestones · {g.progress}%
                  </span>
                  {g.targetDate ? (
                    <span className="small muted">target {formatDay(g.targetDate)}</span>
                  ) : null}
                </div>
              </div>
            </Link>
          ))}
        </div>
      ) : (
        <EmptyState
          icon={<IconFlag size={26} />}
          title={filter === 'active' ? 'No active goals yet' : `No ${filter} goals`}
          message="Create a goal, then break it into milestones and tasks — or let AI draft the breakdown."
          action={
            filter === 'active' ? (
              <Button size="sm" onClick={() => setCreating(true)}>
                New goal
              </Button>
            ) : undefined
          }
        />
      )}

      {creating ? (
        <GoalFormModal
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

export function GoalFormModal({
  presetName = '',
  onClose,
  onCreated,
}: {
  presetName?: string;
  onClose: () => void;
  onCreated: (g: Goal) => void;
}) {
  const [name, setName] = useState(presetName);
  const [description, setDescription] = useState('');
  const [why, setWhy] = useState('');
  const [area, setArea] = useState('');
  const [targetDate, setTargetDate] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    if (name.trim().length < 2) {
      setError('Give your goal a name.');
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const g = await ep.createGoal({
        name: name.trim(),
        ...(description.trim() ? { description: description.trim() } : {}),
        ...(why.trim() ? { whyItMatters: why.trim() } : {}),
        ...(area.trim() ? { growthArea: area.trim() } : {}),
        ...(targetDate ? { targetDate } : {}),
      });
      onCreated(g);
    } catch (e: any) {
      setError(e.message ?? 'Could not create the goal.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title="New goal" onClose={onClose}>
      <form
        className="stack"
        onSubmit={(e) => {
          e.preventDefault();
          void submit();
        }}
      >
        {error ? <ErrorBanner message={error} /> : null}
        <Field label="Goal">
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. Launch my portfolio" autoFocus />
        </Field>
        <Field label="Description">
          <Textarea value={description} onChange={(e) => setDescription(e.target.value)} placeholder="Optional context…" />
        </Field>
        <Field label="Why it matters" hint="A strong 'why' keeps you going on hard days.">
          <Input value={why} onChange={(e) => setWhy(e.target.value)} placeholder="e.g. It's the first step to freelancing" />
        </Field>
        <div className="grid grid-2">
          <Field label="Growth area">
            <Input value={area} onChange={(e) => setArea(e.target.value)} placeholder="e.g. Career" />
          </Field>
          <Field label="Target date">
            <Input type="date" value={targetDate} onChange={(e) => setTargetDate(e.target.value)} />
          </Field>
        </div>
        <div className="row" style={{ justifyContent: 'flex-end' }}>
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" type="submit" disabled={busy}>
            {busy ? 'Creating…' : 'Create goal'}
          </Button>
        </div>
      </form>
    </Modal>
  );
}
