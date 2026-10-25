import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

import { Button, ErrorBanner, Field, Input } from '../components/neu';
import { useAuth } from '../state/AuthContext';

export default function Register() {
  const { register } = useAuth();
  const navigate = useNavigate();
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    setError(null);
    // Client-side checks mirror the backend validator so the user hears
    // about problems before a round-trip.
    if (name.trim().length < 2) {
      setError('Please enter your name.');
      return;
    }
    if (!/^\S+@\S+\.\S+$/.test(email.trim())) {
      setError('Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setError('Password must be at least 6 characters.');
      return;
    }
    setBusy(true);
    try {
      await register(name.trim(), email.trim(), password);
      navigate('/setup'); // fresh accounts land in onboarding
    } catch (e: any) {
      setError(e.message ?? 'Could not create your account.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="auth-shell">
      <div className="neu auth-card">
        <div className="auth-brand">
          <img src="/grivio_logo.png" alt="GRIVIO logo" />
          <div>
            <span className="brand-name" style={{ fontSize: 26 }}>
              GRIVIO
            </span>
            <p className="small text-2">Goals → Focus → Progress. Start today.</p>
          </div>
        </div>

        <form
          className="stack"
          onSubmit={(e) => {
            e.preventDefault();
            void submit();
          }}
        >
          {error ? <ErrorBanner message={error} /> : null}
          <Field label="Name">
            <Input
              autoComplete="name"
              placeholder="Your name"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
          </Field>
          <Field label="Email">
            <Input
              type="email"
              autoComplete="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </Field>
          <Field label="Password" hint="At least 6 characters.">
            <Input
              type="password"
              autoComplete="new-password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </Field>
          <Button variant="primary" type="submit" disabled={busy}>
            {busy ? 'Creating account…' : 'Create account'}
          </Button>
          <p className="small center text-2">
            Already have an account? <Link to="/login">Sign in</Link>
          </p>
        </form>
      </div>
    </div>
  );
}
