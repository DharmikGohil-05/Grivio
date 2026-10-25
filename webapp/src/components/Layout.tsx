// App shell: fixed sidebar on desktop, sticky top bar + floating neumorphic
// bottom navigation on mobile — mirroring the Flutter app's 5 destinations.
import type { ReactNode } from 'react';
import { NavLink, useNavigate } from 'react-router-dom';

import { useAuth } from '../state/AuthContext';
import { useTheme } from '../state/ThemeContext';
import {
  IconChart,
  IconFlag,
  IconHome,
  IconLogout,
  IconMoon,
  IconSun,
  IconTimer,
  IconUser,
} from './neu';

const NAV = [
  { to: '/', label: 'Home', icon: IconHome, end: true },
  { to: '/goals', label: 'Goals', icon: IconFlag },
  { to: '/focus', label: 'Focus', icon: IconTimer },
  { to: '/progress', label: 'Progress', icon: IconChart },
  { to: '/profile', label: 'Profile', icon: IconUser },
];

function NavItems({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <>
      {NAV.map(({ to, label, icon: Icon, end }) => (
        <NavLink
          key={to}
          to={to}
          end={end}
          onClick={onNavigate}
          className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
        >
          <Icon size={21} />
          <span>{label}</span>
        </NavLink>
      ))}
    </>
  );
}

export function Layout({ children }: { children: ReactNode }) {
  const { resolved, preference, setPreference } = useTheme();
  const { logout, user } = useAuth();
  const navigate = useNavigate();

  // The sun/moon button cycles light → dark → system, showing current mode.
  const cycleTheme = () => {
    const next = preference === 'light' ? 'dark' : preference === 'dark' ? 'system' : 'light';
    setPreference(next);
  };

  const onLogout = async () => {
    await logout();
    navigate('/login');
  };

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <div className="brand">
          <img src="/grivio_logo.png" alt="GRIVIO logo" />
          <span className="brand-name">GRIVIO</span>
        </div>
        <NavItems />
        <div className="sidebar-footer">
          <div className="nav-item" style={{ cursor: 'default' }} title="Theme: light / dark / system">
            {resolved === 'dark' ? <IconMoon size={19} /> : <IconSun size={19} />}
            <span className="small text-2" style={{ textTransform: 'capitalize' }}>
              {preference} theme
            </span>
          </div>
          <button className="nav-item" onClick={onLogout} style={{ color: 'var(--danger)' }}>
            <IconLogout size={19} />
            <span>Log out</span>
          </button>
          {user ? (
            <p className="small muted" style={{ padding: '4px 14px', overflowWrap: 'anywhere' }}>
              {user.email}
            </p>
          ) : null}
        </div>
      </aside>

      <main className="app-main">
        <header className="topbar">
          <div className="brand" style={{ padding: 0 }}>
            <img src="/grivio_logo.png" alt="GRIVIO logo" style={{ width: 32, height: 32 }} />
            <span className="brand-name" style={{ fontSize: 17 }}>
              GRIVIO
            </span>
          </div>
          <button className="btn btn-ghost btn-icon" onClick={cycleTheme} aria-label="Cycle theme">
            {resolved === 'dark' ? <IconMoon size={18} /> : <IconSun size={18} />}
          </button>
        </header>

        {children}
      </main>

      <nav className="bottom-nav" aria-label="Primary">
        <NavItems />
      </nav>
    </div>
  );
}
