// Profile & settings — identity, growth areas, daily time, theme and
// account controls. Theme choice persists exactly like the mobile app.
import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';

import * as ep from '../api/endpoints';
import {
  Button,
  ErrorBanner,
  Field,
  Input,
} from '../components/neu';
import { useAuth } from '../state/AuthContext';
import { useTheme } from '../state/ThemeContext';
import type { ThemePreference } from '../state/ThemeContext';

// The backend enforces a FIXED whitelist for profile growth areas
// (backend/src/utils/profileValidate.js → GROWTH_AREAS); the Flutter app
// offers exactly this list. Values outside it are rejected by the API.
const AREAS = ['Career', 'Learning', 'Fitness', 'Personal', 'Finance', 'Communication', 'Other'];
const TIME_CHOICES = ['30 minutes', '1 hour', '2 hours', '3+ hours'];
const THEME_OPTIONS: { key: ThemePreference; label: string }[] = [
  { key: 'light', label: 'Light' },
  { key: 'dark', label: 'Dark' },
  { key: 'system', label: 'System' },
];

export default function Profile() {
  const { user, profile, setProfile, logout } = useAuth();
  const { preference, setPreference } = useTheme();
  const navigate = useNavigate();

  const [name, setName] = useState('');
  const [areas, setAreas] = useState<string[]>([]);
  const [mainGoal, setMainGoal] = useState('');
  const [dailyTime, setDailyTime] = useState(TIME_CHOICES[1]);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    if (profile) {
      setName(profile.name);
      setAreas(profile.growthAreas);
      setMainGoal(profile.mainGoal ?? '');
      setDailyTime(profile.dailyAvailableTime ?? TIME_CHOICES[1]);
    }
  }, [profile]);

  const toggleArea = (a: string) =>
    setAreas((prev) => (prev.includes(a) ? prev.filter((x) => x !== a) : [...prev, a]));

  const save = async () => {
    setBusy(true);
    setSaved(false);
    setError(null);
    try {
      const updated = await ep.updateProfile({
        name: name.trim(),
        growthAreas: areas,
        mainGoal: mainGoal.trim() || null,
        dailyAvailableTime: dailyTime,
      });
      setProfile(updated);
      setSaved(true);
    } catch (e: any) {
      setError(e.message ?? 'Could not save your profile.');
    } finally {
      setBusy(false);
    }
  };

  const onLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <div className="stack">
      <div className="page-head">
        <div>
          <h1>Profile</h1>
          <p className="sub">{user?.email}</p>
        </div>
      </div>

      {error ? <ErrorBanner message={error} /> : null}

      <div className="neu card stack">
        <div className="card-title">
          <h3>About you</h3>
        </div>
        <Field label="Name">
          <Input value={name} onChange={(e) => setName(e.target.value)} />
        </Field>

        <Field label="Growth areas">
          <div className="row">
            {AREAS.map((a) => (
              <button
                key={a}
                type="button"
                className={`chip ${areas.includes(a) ? 'active' : ''}`}
                onClick={() => toggleArea(a)}
              >
                {a}
              </button>
            ))}
          </div>
          {areas.length === 0 ? (
            <span className="small muted">Pick at least one area to grow.</span>
          ) : null}
        </Field>

        <Field label="Main goal right now">
          <Input
            value={mainGoal}
            onChange={(e) => setMainGoal(e.target.value)}
            placeholder="e.g. Ship my first project"
          />
        </Field>

        <Field label="Daily available time">
          <div className="row">
            {TIME_CHOICES.map((t) => (
              <button
                key={t}
                className={`chip ${dailyTime === t ? 'active' : ''}`}
                onClick={() => setDailyTime(t)}
              >
                {t}
              </button>
            ))}
          </div>
        </Field>

        <div className="row" style={{ justifyContent: 'flex-end' }}>
          {saved ? <span className="small" style={{ color: 'var(--success)' }}>Saved ✓</span> : null}
          <Button variant="primary" onClick={() => void save()} disabled={busy}>
            {busy ? 'Saving…' : 'Save changes'}
          </Button>
        </div>
      </div>

      <div className="neu card stack">
        <div className="card-title">
          <h3>Appearance</h3>
        </div>
        <p className="small text-2">Choose how GRIVIO looks. Your pick is remembered.</p>
        <div className="row">
          {THEME_OPTIONS.map((o) => (
            <button
              key={o.key}
              className={`chip ${preference === o.key ? 'active' : ''}`}
              onClick={() => setPreference(o.key)}
            >
              {o.label}
            </button>
          ))}
        </div>
      </div>

      <div className="neu card stack">
        <div className="card-title">
          <h3>Account</h3>
        </div>
        <p className="small text-2">
          Signing out clears this device's session. Your data stays safely on the server.
        </p>
        <div className="row">
          <Button variant="danger" onClick={() => void onLogout()}>
            Log out
          </Button>
        </div>
      </div>
    </div>
  );
}
