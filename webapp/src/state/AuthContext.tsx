/* eslint-disable react-refresh/only-export-components -- React convention:
   a context file exports both its provider component and its use* hook. */
import { createContext, useCallback, useContext, useEffect, useMemo, useState } from 'react';
import type { ReactNode } from 'react';

import { setAuthToken } from '../api/client';
import * as apiEndpoints from '../api/endpoints';
import { STORAGE_KEYS } from '../config';
import type { Profile, User } from '../types';

interface AuthState {
  user: User | null;
  profile: Profile | null;
  token: string | null;
  /** True while the stored token is being restored on first load. */
  bootstrapping: boolean;
  login: (email: string, password: string) => Promise<void>;
  register: (name: string, email: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshProfile: () => Promise<Profile | null>;
  setProfile: (p: Profile) => void;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [token, setToken] = useState<string | null>(() =>
    localStorage.getItem(STORAGE_KEYS.token),
  );
  const [user, setUser] = useState<User | null>(null);
  const [profile, setProfileState] = useState<Profile | null>(null);
  const [bootstrapping, setBootstrapping] = useState(!!localStorage.getItem(STORAGE_KEYS.token));

  // Keep the fetch wrapper's bearer header in sync with the stored token.
  useEffect(() => setAuthToken(token), [token]);

  const refreshProfile = useCallback(async () => {
    try {
      const p = await apiEndpoints.fetchProfile();
      setProfileState(p);
      return p;
    } catch {
      return null;
    }
  }, []);

  // Restore the session from the persisted JWT (same flow as the app:
  // token presence is not proof of validity — /auth/me is).
  useEffect(() => {
    let cancelled = false;
    if (!token) {
      setBootstrapping(false);
      return;
    }
    (async () => {
      try {
        const me = await apiEndpoints.fetchMe();
        if (cancelled) return;
        setUser(me);
        await refreshProfile();
      } catch {
        // Invalid/expired token: clear it so the router sends the user to
        // the login screen — exactly what the mobile app does.
        if (!cancelled) {
          localStorage.removeItem(STORAGE_KEYS.token);
          setToken(null);
          setUser(null);
          setProfileState(null);
        }
      } finally {
        if (!cancelled) setBootstrapping(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [token, refreshProfile]);

  const startSession = (t: string, u: User) => {
    localStorage.setItem(STORAGE_KEYS.token, t);
    setToken(t);
    setUser(u);
  };

  const login = useCallback(async (email: string, password: string) => {
    const r = await apiEndpoints.login(email, password);
    startSession(r.token, r.user);
    await refreshProfile();
  }, [refreshProfile]);

  const register = useCallback(
    async (name: string, email: string, password: string) => {
      const r = await apiEndpoints.register(name, email, password);
      startSession(r.token, r.user);
      await refreshProfile();
    },
    [refreshProfile],
  );

  const logout = useCallback(async () => {
    // Best-effort server call; the client clears state regardless because
    // JWTs are stateless (same as the mobile app's logout).
    try {
      await apiEndpoints.logoutServer();
    } catch {
      /* ignore */
    }
    localStorage.removeItem(STORAGE_KEYS.token);
    setToken(null);
    setUser(null);
    setProfileState(null);
  }, []);

  const value = useMemo<AuthState>(
    () => ({
      user,
      profile,
      token,
      bootstrapping,
      login,
      register,
      logout,
      refreshProfile,
      setProfile: setProfileState,
    }),
    [user, profile, token, bootstrapping, login, register, logout, refreshProfile],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside <AuthProvider>');
  return ctx;
}
