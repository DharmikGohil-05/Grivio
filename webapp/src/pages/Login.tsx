import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

import { Button, ErrorBanner, Field, Input } from '../components/neu';
import { useAuth } from '../state/AuthContext';

export default function Login() {
  const { login } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  const submit = async () => {
    setError(null);
    if (!email.trim() || !password) {
      setError('Enter your email and password.');
      return;
    }
    setBusy(true);
    try {
      await login(email.trim(), password);
      navigate('/');
    } catch (e: any) {
      setError(e.message ?? 'Could not sign in.');
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
            <p className="small text-2">Welcome back — let's keep growing.</p>
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
          <Field label="Email">
            <Input
              type="email"
              autoComplete="email"
              placeholder="you@example.com"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
          </Field>
          <Field label="Password">
            <Input
              type="password"
              autoComplete="current-password"
              placeholder="••••••••"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
          </Field>
          <Button variant="primary" type="submit" disabled={busy}>
            {busy ? 'Signing in…' : 'Sign in'}
          </Button>
          <p className="small center text-2">
            New to GRIVIO? <Link to="/register">Create an account</Link>
          </p>
        </form>
      </div>
    </div>
  );
}
