// Root error boundary — if any screen ever throws during render, the app
// shows a recoverable error card instead of unmounting to a black screen.
// (A Plan My Day response bug previously blanked the whole UI this way.)
import { Component, type ReactNode } from 'react';

interface Props {
  children: ReactNode;
}

interface State {
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error) {
    // Surface the failure for debugging; the UI below stays user-friendly.
    console.error('GRIVIO UI error:', error);
  }

  render() {
    const { error } = this.state;
    if (!error) return this.props.children;

    return (
      <div className="auth-shell">
        <div className="neu card stack" style={{ width: 360, textAlign: 'center' }}>
          <h3>Something went wrong</h3>
          <p className="small text-2">
            The screen hit an unexpected error. Your data is safe — reload to continue.
          </p>
          <p className="small muted" style={{ wordBreak: 'break-word' }}>
            {error.message}
          </p>
          <div className="row" style={{ justifyContent: 'center', gap: 10 }}>
            <button className="btn btn-ghost" onClick={() => this.setState({ error: null })}>
              Try again
            </button>
            <button className="btn btn-primary" onClick={() => window.location.reload()}>
              Reload app
            </button>
          </div>
        </div>
      </div>
    );
  }
}
