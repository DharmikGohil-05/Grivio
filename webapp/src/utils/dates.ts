// Date helpers shared by the web client.
//
// The GRIVIO backend uses Monday-start weeks everywhere (weekly reviews
// validate that weekStart IS a Monday), and 'YYYY-MM-DD' strings for
// calendar days. These helpers work on plain calendar days (local time),
// never on UTC timestamps, so a date like '2026-10-24' can never shift
// into the neighbouring day.

/** 'YYYY-MM-DD' for a local Date. */
export function toKey(d: Date): string {
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}

/** Parse 'YYYY-MM-DD' as a *local* date (no timezone shift). */
export function fromKey(key: string): Date {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, (m ?? 1) - 1, d ?? 1);
}

/** The Monday of the week containing `key` (backend week convention). */
export function mondayStart(key: string): string {
  const d = fromKey(key);
  const weekday = d.getDay(); // 0=Sun … 6=Sat
  const daysSinceMonday = (weekday + 6) % 7;
  d.setDate(d.getDate() - daysSinceMonday);
  return toKey(d);
}

/** Add `days` calendar days to a 'YYYY-MM-DD' key. */
export function addDays(key: string, days: number): string {
  const d = fromKey(key);
  d.setDate(d.getDate() + days);
  return toKey(d);
}

/** Human-readable short date, e.g. 'Fri, 24 Oct'. */
export function formatDay(key: string): string {
  return fromKey(key).toLocaleDateString(undefined, {
    weekday: 'short',
    day: 'numeric',
    month: 'short',
  });
}

/** '1h 30m' / '45m' style duration. */
export function formatMinutes(total: number): string {
  const h = Math.floor(total / 60);
  const m = total % 60;
  if (h && m) return `${h}h ${m}m`;
  if (h) return `${h}h`;
  return `${m}m`;
}

/** Elapsed focus seconds for a session, excluding paused time
 *  (same math the backend applies on complete — see focus.service.js). */
export function elapsedSeconds(session: {
  startedAt: string;
  pausedAt?: string | null;
  totalPauseSeconds: number;
}): number {
  const started = Date.parse(session.startedAt);
  const now = Date.now();
  const pausedAt = session.pausedAt ? Date.parse(session.pausedAt) : null;
  // While paused, "now" is frozen at the pause moment.
  const end = pausedAt != null ? pausedAt : now;
  const gross = Math.max(0, Math.floor((end - started) / 1000));
  return Math.max(0, gross - (session.totalPauseSeconds ?? 0));
}

/** 'HH:MM' + minutes → 'HH:MM' (used by the daily planner). */
export function addToTime(start: string, minutes: number): string {
  const [h, m] = start.split(':').map(Number);
  const total = (h || 0) * 60 + (m || 0) + minutes;
  const hh = Math.floor(total / 60) % 24;
  const mm = total % 60;
  return `${String(hh).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
}
