// First-time onboarding — the same 4 steps as the mobile setup flow:
// name → growth areas → first goal (optional) → daily available time.
// Finishes by PUTting the profile with setupCompleted: true, exactly like
// the app, so switching between app and web stays consistent.
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';

import * as ep from '../api/endpoints';
import { Button, ErrorBanner, Field, Input } from '../components/neu';
import { useAuth } from '../state/AuthContext';
import type { Profile } from '../types';

// The backend enforces a FIXED whitelist for profile growth areas
// (see backend/src/utils/profileValidate.js → GROWTH_AREAS), and the
// Flutter app offers exactly this list. Any other value is rejected
// with "One or more growth areas are not allowed".
const PRESET_AREAS = [
  'Career',
  'Learning',
  'Fitness',
  'Personal',
  'Finance',
  'Communication',
  'Other',
];

const TIME_CHOICES = ['30 minutes', '1 hour', '2 hours', '3+ hours'];

export default function Setup() {
  const { user, profile, setProfile } = useAuth();
  const navigate = useNavigate();

  const [step, setStep] = useState(0);
  const [name, setName] = useState(profile?.name || user?.name || '');
  const [areas, setAreas] = useState<string[]>(profile?.growthAreas ?? []);
  const [goalTitle, setGoalTitle] = useState('');
  const [goalDate, setGoalDate] = useState('');
  const [dailyTime, setDailyTime] = useState(profile?.dailyAvailableTime || TIME_CHOICES[1]);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const toggleArea = (a: string) =>
    setAreas((prev) => (prev.includes(a) ? prev.filter((x) => x !== a) : [...prev, a]));

  const next = () => {
    setError(null);
    if (step === 0 && name.trim().length < 2) {
      setError('Please tell us your name.');
      return;
    }
    if (step === 1 && areas.length === 0) {
      setError('Pick at least one growth area.');
      return;
    }
    if (step < 3) setStep(step + 1);
  };

  const finish = async () => {
    setError(null);
    setBusy(true);
    try {
      // Step 3's goal is real data: create it first (optional field).
      if (goalTitle.trim()) {
        await ep.createGoal({
          name: goalTitle.trim(),
          ...(goalDate ? { targetDate: goalDate } : {}),
          ...(areas[0] ? { growthArea: areas[0] } : {}),
        });
      }
      const updated: Profile = await ep.updateProfile({
        name: name.trim(),
        growthAreas: areas,
        dailyAvailableTime: dailyTime,
        setupCompleted: true,
      });
      setProfile(updated);
      navigate('/');
    } catch (e: any) {
      setError(e.message ?? 'Could not save your setup.');
    } finally {
      setBusy(false);
    }
  };

  const steps = ['About you', 'Growth areas', 'First goal', 'Daily time'];

  return (
    <div className="auth-shell">
      <div className="neu auth-card" style={{ maxWidth: 480 }}>
        <div className="auth-brand" style={{ marginBottom: 10 }}>
          <img src="/grivio_logo.png" alt="GRIVIO logo" style={{ width: 52, height: 52 }} />
          <h2>Let's set up your space</h2>
        </div>

        <div className="step-dots" aria-label={`Step ${step + 1} of 4`}>
          {steps.map((s, i) => (
            <span key={s} className={`step-dot ${i === step ? 'active' : ''}`} title={s} />
          ))}
        </div>

        <form
          className="stack"
          onSubmit={(e) => {
            e.preventDefault();
            if (step === 3) void finish();
            else next();
          }}
        >
          {error ? <ErrorBanner message={error} /> : null}

          {step === 0 && (
            <Field label="What should we call you?">
              <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Your name" autoFocus />
            </Field>
          )}

          {step === 1 && (
            <div className="stack">
              <p className="text-2">Which areas of your life do you want to grow?</p>
              <div className="row">
                {PRESET_AREAS.map((a) => (
                  <button
                    type="button"
                    key={a}
                    className={`chip ${areas.includes(a) ? 'active' : ''}`}
                    onClick={() => toggleArea(a)}
                  >
                    {a}
                  </button>
                ))}
              </div>
              <p className="small muted">
                These match the growth areas GRIVIO supports, so your choices stay in sync with the
                mobile app.
              </p>
            </div>
          )}

          {step === 2 && (
            <div className="stack">
              <p className="text-2">What's your first goal? (you can skip this)</p>
              <Field label="Goal">
                <Input
                  value={goalTitle}
                  placeholder="e.g. Run my first 10K"
                  onChange={(e) => setGoalTitle(e.target.value)}
                />
              </Field>
              <Field label="Target date (optional)">
                <Input type="date" value={goalDate} onChange={(e) => setGoalDate(e.target.value)} />
              </Field>
            </div>
          )}

          {step === 3 && (
            <div className="stack">
              <p className="text-2">How much time can you spend on growth each day?</p>
              <div className="row">
                {TIME_CHOICES.map((t) => (
                  <button
                    type="button"
                    key={t}
                    className={`chip ${dailyTime === t ? 'active' : ''}`}
                    onClick={() => setDailyTime(t)}
                  >
                    {t}
                  </button>
                ))}
              </div>
            </div>
          )}

          <div className="row" style={{ justifyContent: 'space-between' }}>
            <Button
              variant="ghost"
              onClick={() => setStep(Math.max(0, step - 1))}
              disabled={step === 0 || busy}
            >
              Back
            </Button>
            <Button variant="primary" type="submit" disabled={busy}>
              {busy ? 'Saving…' : step === 3 ? 'Finish setup' : 'Continue'}
            </Button>
          </div>
        </form>
      </div>
    </div>
  );
}
