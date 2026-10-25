import { Navigate, Route, Routes, useLocation } from 'react-router-dom';
import type { ReactNode } from 'react';

import { Layout } from './components/Layout';
import { Skeleton } from './components/neu';
import Focus from './pages/Focus';
import GoalDetail from './pages/GoalDetail';
import Goals from './pages/Goals';
import Home from './pages/Home';
import Login from './pages/Login';
import Profile from './pages/Profile';
import ProgressPage from './pages/ProgressPage';
import Register from './pages/Register';
import Setup from './pages/Setup';
import TaskDetail from './pages/TaskDetail';
import Tasks from './pages/Tasks';
import WeeklyReview from './pages/WeeklyReview';
import { useAuth } from './state/AuthContext';

// Route guards — same rules the mobile app's startup router applies:
// no token → Login; token but profile not set up → Setup; else the app.
function RequireAuth({ children }: { children: ReactNode }) {
  const { token, bootstrapping } = useAuth();
  const location = useLocation();
  if (bootstrapping) return <BootSplash />;
  if (!token) return <Navigate to="/login" replace state={{ from: location }} />;
  return <Layout>{children}</Layout>;
}

function RequireSetup({ children }: { children: ReactNode }) {
  const { profile } = useAuth();
  if (profile && !profile.setupCompleted) return <Navigate to="/setup" replace />;
  return children;
}

function BootSplash() {
  return (
    <div className="auth-shell">
      <div className="stack" style={{ alignItems: 'center', width: 260 }}>
        <img src="/grivio_logo.png" alt="GRIVIO" style={{ width: 64, height: 64, borderRadius: 18 }} />
        <Skeleton height={14} width={160} />
        <Skeleton height={14} width={110} />
      </div>
    </div>
  );
}

export default function App() {
  const { token, profile, bootstrapping } = useAuth();

  return (
    <Routes>
      <Route
        path="/login"
        element={token && !bootstrapping ? <Navigate to="/" replace /> : <Login />}
      />
      <Route
        path="/register"
        element={token && !bootstrapping ? <Navigate to="/" replace /> : <Register />}
      />
      <Route
        path="/setup"
        element={
          !token ? (
            <Navigate to="/login" replace />
          ) : bootstrapping ? (
            <BootSplash />
          ) : profile?.setupCompleted ? (
            <Navigate to="/" replace />
          ) : (
            <Setup />
          )
        }
      />
      <Route
        path="/"
        element={
          <RequireAuth>
            <RequireSetup>
              <Home />
            </RequireSetup>
          </RequireAuth>
        }
      />
      <Route
        path="/tasks"
        element={
          <RequireAuth>
            <RequireSetup>
              <Tasks />
            </RequireSetup>
          </RequireAuth>
        }
      />
      <Route
        path="/tasks/:id"
        element={
          <RequireAuth>
            <RequireSetup>
              <TaskDetail />
            </RequireSetup>
          </RequireAuth>
        }
      />
      <Route
        path="/goals"
        element={
          <RequireAuth>
            <RequireSetup>
              <Goals />
            </RequireSetup>
          </RequireAuth>
        }
      />
      <Route
        path="/goals/:id"
        element={
          <RequireAuth>
            <RequireSetup>
              <GoalDetail />
            </RequireSetup>
          </RequireAuth>
        }
      />
      <Route
        path="/focus"
        element={
          <RequireAuth>
            <RequireSetup>
              <Focus />
            </RequireSetup>
          </RequireAuth>
        }
      />
      <Route
        path="/progress"
        element={
          <RequireAuth>
            <RequireSetup>
              <ProgressPage />
            </RequireSetup>
          </RequireAuth>
        }
      />
      <Route
        path="/weekly"
        element={
          <RequireAuth>
            <RequireSetup>
              <WeeklyReview />
            </RequireSetup>
          </RequireAuth>
        }
      />
      <Route
        path="/profile"
        element={
          <RequireAuth>
            <RequireSetup>
              <Profile />
            </RequireSetup>
          </RequireAuth>
        }
      />
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  );
}
