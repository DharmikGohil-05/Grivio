import { describe, expect, it } from 'vitest';

import { addDays, elapsedSeconds, formatMinutes, mondayStart, toKey } from './dates';

describe('mondayStart', () => {
  it('returns the same day when given a Monday', () => {
    // 2026-10-19 is a Monday.
    expect(mondayStart('2026-10-19')).toBe('2026-10-19');
  });

  it('walks back to Monday for every other weekday', () => {
    expect(mondayStart('2026-10-20')).toBe('2026-10-19'); // Tue
    expect(mondayStart('2026-10-21')).toBe('2026-10-19'); // Wed
    expect(mondayStart('2026-10-24')).toBe('2026-10-19'); // Sat
    expect(mondayStart('2026-10-25')).toBe('2026-10-19'); // Sun
  });

  it('never crosses a month boundary incorrectly', () => {
    // 2026-11-02 is a Monday; Sunday 2026-11-01 belongs to the previous week.
    expect(mondayStart('2026-11-01')).toBe('2026-10-26');
  });
});

describe('addDays / toKey', () => {
  it('adds across month boundaries', () => {
    expect(addDays('2026-10-31', 1)).toBe('2026-11-01');
    expect(addDays('2026-10-01', -1)).toBe('2026-09-30');
  });

  it('round-trips through toKey', () => {
    expect(addDays('2026-02-28', 1)).toBe('2026-03-01');
    expect(toKey(new Date(2026, 0, 5))).toBe('2026-01-05');
  });
});

describe('elapsedSeconds', () => {
  it('counts up while active', () => {
    const startedAt = new Date(Date.now() - 65_000).toISOString();
    const e = elapsedSeconds({ startedAt, pausedAt: null, totalPauseSeconds: 0 });
    expect(e).toBeGreaterThanOrEqual(64);
    expect(e).toBeLessThanOrEqual(66);
  });

  it('freezes at the pause moment and subtracts paused time', () => {
    const startedAt = new Date(Date.now() - 300_000).toISOString(); // 5 min ago
    const pausedAt = new Date(Date.now() - 100_000).toISOString(); // paused 100s ago
    // 200s ran before pausing.
    expect(elapsedSeconds({ startedAt, pausedAt, totalPauseSeconds: 0 })).toBe(200);
    // totalPauseSeconds folds previous pause/resume cycles.
    expect(elapsedSeconds({ startedAt, pausedAt: null, totalPauseSeconds: 100 })).toBeGreaterThanOrEqual(199);
  });
});

describe('formatMinutes', () => {
  it('formats hours and minutes', () => {
    expect(formatMinutes(90)).toBe('1h 30m');
    expect(formatMinutes(60)).toBe('1h');
    expect(formatMinutes(45)).toBe('45m');
  });
});
