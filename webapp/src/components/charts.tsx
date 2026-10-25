// Hand-rolled SVG charts — no chart dependency, full token control.
// All charts read colors from the CSS variables, so they follow
// Light/Dark/System automatically. Every chart animates its data in
// (line draws itself, bars grow, ring sweeps) via CSS keyframes.
import { useEffect, useId, useState } from 'react';

import type { TrendPoint } from '../types';

/** Count-up number: eases from 0 to [value] on mount (and re-runs when
 *  value changes), formatting each frame through [format]. */
export function CountUp({
  value,
  format = (v) => String(v),
  duration = 900,
}: {
  value: number;
  format?: (v: number) => string;
  duration?: number;
}) {
  const [display, setDisplay] = useState(0);
  useEffect(() => {
    let raf = 0;
    let done = false;
    const start = performance.now();
    const finish = () => {
      // Fallback for hidden/occluded tabs where rAF is suspended:
      // snap to the final value so the number is never stuck at 0.
      if (done) return;
      done = true;
      setDisplay(value);
    };
    const tick = (now: number) => {
      if (done) return;
      const t = Math.min(1, (now - start) / duration);
      const eased = 1 - Math.pow(1 - t, 3); // easeOutCubic
      setDisplay(Math.round(value * eased));
      if (t < 1) raf = requestAnimationFrame(tick);
      else finish();
    };
    raf = requestAnimationFrame(tick);
    const timer = window.setTimeout(finish, duration + 120);
    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(timer);
    };
  }, [value, duration]);
  return <>{format(display)}</>;
}

/** Depth progress ring — the dashboard centrepiece.
 *
 * Layered like the reference design: a raised disc, an ENGRAVED groove
 * (inset neumorphic shadow) where the arc travels, an indigo→cyan gradient
 * arc with a soft glow and a leading dot, and a big centred percentage.
 * The arc sweeps from 0 → value on mount (rAF kicks off the CSS transition)
 * and re-eases whenever the value changes. */
export function ProgressRing({
  value,
  size = 136,
  stroke = 13,
  label,
  sublabel,
}: {
  value: number; // 0..100
  size?: number;
  stroke?: number;
  label?: string;
  sublabel?: string;
}) {
  const v = Math.max(0, Math.min(100, value));
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  const id = useId();

  // Start at 0 so the first paint animates the sweep instead of
  // appearing already full; later value changes re-use the same
  // transition. rAF is the natural trigger, but a hidden/occluded tab
  // can suspend rAF, so a macrotask fallback guarantees the sweep state
  // is always set (the CSS transition itself only plays while the page
  // is visible, which is exactly what we want).
  const [swept, setSwept] = useState(0);
  useEffect(() => {
    let done = false;
    const go = () => {
      if (done) return;
      done = true;
      setSwept(v);
    };
    const raf = requestAnimationFrame(go);
    const timer = window.setTimeout(go, 80);
    return () => {
      cancelAnimationFrame(raf);
      clearTimeout(timer);
    };
  }, [v]);

  // Head dot position: 12 o'clock start, clockwise.
  const angle = (-90 + (swept / 100) * 360) * (Math.PI / 180);
  const hx = size / 2 + r * Math.cos(angle);
  const hy = size / 2 + r * Math.sin(angle);

  return (
    <div
      className="depth-ring"
      style={{ width: size, height: size }}
      role="img"
      aria-label={`${Math.round(v)}% complete`}
    >
      {/* Engraved groove the arc travels through */}
      <div className="depth-ring__well" style={{ inset: stroke }} />
      <svg width={size} height={size} style={{ position: 'relative', display: 'block' }}>
        <defs>
          <linearGradient id={`ring-${id}`} x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" style={{ stopColor: 'var(--accent)' }} />
            <stop offset="100%" style={{ stopColor: 'var(--accent-cyan)' }} />
          </linearGradient>
        </defs>
        <circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          stroke={`url(#ring-${id})`}
          strokeWidth={stroke}
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={c - (swept / 100) * c}
          transform={`rotate(-90 ${size / 2} ${size / 2})`}
          className="depth-ring__arc"
        />
        {swept > 1 ? (
          <circle cx={hx} cy={hy} r={stroke * 0.34} className="depth-ring__head" />
        ) : null}
      </svg>
      <div className="depth-ring__center">
        <strong style={{ fontSize: size * 0.2, letterSpacing: '-0.03em' }}>
          {Math.round(v)}%
        </strong>
        {label ? <span className="small muted">{label}</span> : null}
        {sublabel ? <span className="small muted">{sublabel}</span> : null}
      </div>
    </div>
  );
}

/** Vertical bar chart for focus minutes per day.
 *  With `axes` it gains the reference-style frame: value gridlines with
 *  labels down the left, weekday labels under every bar, and taller
 *  gradient (cyan→indigo) bars — all still growing in staggered. */
export function BarChart({
  points,
  height = 150,
  axes = false,
}: {
  points: TrendPoint[];
  height?: number;
  axes?: boolean;
}) {
  if (!points.length) return <p className="small muted">No data yet.</p>;
  const top = niceMax(Math.max(...points.map((p) => p.value), 1));
  const gridFractions = [0.75, 0.5, 0.25];

  const bars = (
    <div
      className="row"
      style={{ alignItems: 'flex-end', gap: 6, height: '100%', flexWrap: 'nowrap', position: 'relative', zIndex: 1 }}
    >
      {points.map((p, i) => (
        <div key={p.date} className="chart-bar-wrap" style={{ flex: '1 1 10px', maxWidth: 26, minWidth: 3, height: '100%' }}>
          <div
            className="chart-bar"
            style={
              {
                height: `${Math.max(3, (p.value / top) * 100)}%`,
                animationDelay: `${Math.min(i * 45, 760)}ms`,
              } as React.CSSProperties
            }
          />
          <div className="chart-tip" role="tooltip">
            <strong>{p.value}</strong> · {p.date}
          </div>
        </div>
      ))}
    </div>
  );

  if (!axes) {
    return <div className="row" style={{ alignItems: 'flex-end', gap: 6, height, flexWrap: 'nowrap', overflowX: 'auto', paddingBottom: 4 }}>{bars}</div>;
  }

  // Thin the weekday labels on dense ranges so they never collide.
  const stride = Math.max(1, Math.ceil(points.length / 10));

  return (
    <div className="chart-frame">
      <div className="chart-plot" style={{ height }}>
        <div className="chart-gridlines" aria-hidden="true">
          {[1, ...gridFractions].map((f) => (
            <div key={f} className="chart-gridline" style={{ bottom: `${f * 100}%` }}>
              <span>{Math.round(top * f)}</span>
            </div>
          ))}
        </div>
        {bars}
      </div>
      <div className="chart-xaxis" aria-hidden="true">
        {points.map((p, i) => (
          <span key={p.date} className="chart-xlabel-slot">
            {i % stride === 0 ? weekdayShort(p.date) : ''}
          </span>
        ))}
      </div>
    </div>
  );
}

/** Soft area/line trend chart for tasks completed per day. Lives in the
 *  same labelled chart frame as the bar chart (value gridlines on the
 *  left, weekday labels underneath), scales with 20% headroom so a flat
 *  series never pins itself to the top edge, and draws itself in with a
 *  smooth Catmull-Rom curve. The area and dots animate via `backwards`
 *  fill-mode: if animations ever fail to run, everything rests in its
 *  final (visible) state instead of staying hidden. */
export function TrendChart({ points, height = 172 }: { points: TrendPoint[]; height?: number }) {
  const id = useId();
  if (points.length < 2) return <p className="small muted">Not enough data for a trend yet.</p>;

  const w = 600;
  const h = 160;
  // niceMax(max × 1.2): 20% breathing room above the peak, snapped to a
  // round number so the gridline labels read cleanly.
  const top = niceMax(Math.max(...points.map((p) => p.value), 1) * 1.2);
  const yOf = (v: number) => h * (1 - v / top);
  const step = w / (points.length - 1);
  const xy = points.map((p, i) => [i * step, yOf(p.value)] as const);

  const line = smoothPath(xy);
  const area = `${line} L${w},${h} L0,${h} Z`;

  const gridFractions = top <= 4 ? [1, 0.5] : [1, 0.75, 0.5, 0.25];
  const stride = Math.max(1, Math.ceil(points.length / 10));

  return (
    <div className="chart-frame">
      <div className="chart-plot" style={{ height }}>
        <div className="chart-gridlines" aria-hidden="true">
          {gridFractions.map((f) => (
            <div key={f} className="chart-gridline" style={{ bottom: `${f * 100}%` }}>
              <span>{Math.round(top * f)}</span>
            </div>
          ))}
        </div>
        <svg
          viewBox={`0 0 ${w} ${h}`}
          width="100%"
          height="100%"
          preserveAspectRatio="none"
          role="img"
          aria-label="Trend chart"
          style={{ position: 'absolute', inset: 0, display: 'block', overflow: 'visible' }}
        >
          <defs>
            <linearGradient id={`area-${id}`} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" style={{ stopColor: 'var(--accent-cyan)', stopOpacity: 0.34 }} />
              <stop offset="100%" style={{ stopColor: 'var(--accent)', stopOpacity: 0.02 }} />
            </linearGradient>
            <linearGradient id={`stroke-${id}`} x1="0" y1="0" x2="1" y2="0">
              <stop offset="0%" style={{ stopColor: 'var(--accent)' }} />
              <stop offset="100%" style={{ stopColor: 'var(--accent-cyan)' }} />
            </linearGradient>
          </defs>
          <path d={area} fill={`url(#area-${id})`} className="trend-area" />
          {/* Indigo underlay beneath the gradient stroke: identical path
              and width, so the gradient covers it completely — but if a
              browser ever fails to resolve the gradient reference, the
              line still paints instead of vanishing. */}
          <path
            d={line}
            fill="none"
            stroke="var(--accent)"
            strokeWidth="2.75"
            strokeLinejoin="round"
            strokeLinecap="round"
            className="trend-line"
          />
          <path
            d={line}
            fill="none"
            stroke={`url(#stroke-${id})`}
            strokeWidth="2.75"
            strokeLinejoin="round"
            strokeLinecap="round"
            className="trend-line"
          />
          {points.length <= 14
            ? xy.map(([x, y], i) => (
                <circle
                  key={i}
                  cx={x}
                  cy={y}
                  r="3.4"
                  fill="var(--surface)"
                  stroke="var(--accent-cyan)"
                  strokeWidth="2.25"
                  className="trend-dot"
                  style={{ animationDelay: `${Math.min(i * 40, 600)}ms` }}
                />
              ))
            : null}
        </svg>
      </div>
      <div className="chart-xaxis chart-xaxis--points" aria-hidden="true">
        {points.map((p, i) =>
          i % stride === 0 ? (
            <span
              key={p.date}
              className="chart-xlabel-point"
              style={{ left: `${(i / (points.length - 1)) * 100}%` }}
            >
              {weekdayShort(p.date)}
            </span>
          ) : null
        )}
      </div>
    </div>
  );
}

/** Catmull-Rom → cubic bézier: a soft curve through every point instead
 *  of a rigid polyline (the same feel as the mobile chart's smoothing). */
function smoothPath(pts: readonly (readonly [number, number])[]): string {
  if (pts.length < 3) {
    return pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)},${y.toFixed(1)}`).join(' ');
  }
  let d = `M${pts[0][0].toFixed(1)},${pts[0][1].toFixed(1)}`;
  for (let i = 0; i < pts.length - 1; i++) {
    const p0 = pts[Math.max(0, i - 1)];
    const p1 = pts[i];
    const p2 = pts[i + 1];
    const p3 = pts[Math.min(pts.length - 1, i + 2)];
    const c1x = p1[0] + (p2[0] - p0[0]) / 6;
    const c1y = p1[1] + (p2[1] - p0[1]) / 6;
    const c2x = p2[0] - (p3[0] - p1[0]) / 6;
    const c2y = p2[1] - (p3[1] - p1[1]) / 6;
    d += ` C${c1x.toFixed(1)},${c1y.toFixed(1)} ${c2x.toFixed(1)},${c2y.toFixed(1)} ${p2[0].toFixed(1)},${p2[1].toFixed(1)}`;
  }
  return d;
}

/** Weekday short name for a YYYY-MM-DD key (parses only the date part so
 *  a stray time or UTC offset can never shift the day). */
function weekdayShort(key: string): string {
  const [y, m, d] = key.slice(0, 10).split('-').map(Number);
  return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][new Date(y, m - 1, d).getDay()] ?? '';
}

/** Rounds a maximum up to a 1/2/5×10ⁿ "nice" number so gridline labels
 *  stay readable (7 → 10, 240 → 250, 1300 → 2000). */
function niceMax(v: number): number {
  if (v <= 4) return 4;
  const mag = Math.pow(10, Math.floor(Math.log10(v)));
  const norm = v / mag;
  const step = norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 2.5 ? 2.5 : norm <= 5 ? 5 : 10;
  return step * mag;
}

/**
 * GitHub-style effort heatmap: one cell per day, color intensity = daily
 * effort (focus minutes ÷ 30 + tasks completed), 0 = engraved groove,
 * 4 = full accent→cyan blend. Weeks run Mon→Sun (matching the app's
 * weekly-review convention) and the grid ends on today.
 */
export function Heatmap({ points, weeks = 13 }: { points: TrendPoint[]; weeks?: number }) {
  const byDay = new Map(points.map((p) => [p.date, p.value]));
  const today = new Date();
  const todayKey = toKey(today);
  // Monday-start weeks
  const daysFromMonday = (today.getDay() + 6) % 7;
  const currentWeekStart = addDays(todayKey, -daysFromMonday);

  const max = Math.max(...points.map((p) => p.value), 1);
  const levelFor = (key: string) => {
    const v = byDay.get(key) ?? 0;
    if (v <= 0) return 0;
    return Math.min(4, 1 + Math.ceil((v / max) * 3));
  };

  const columns: (string | null)[][] = [];
  for (let w = 0; w < weeks; w++) {
    const weekStart = addDays(currentWeekStart, 7 * (w - (weeks - 1)));
    columns.push(
      Array.from({ length: 7 }, (_, d) => {
        const key = addDays(weekStart, d);
        return key <= todayKey ? key : null;
      }),
    );
  }

  const rowLabels = ['M', '', 'W', '', 'F', '', ''];
  return (
    <div>
      <div style={{ display: 'flex', gap: 4, overflowX: 'auto', paddingBottom: 4 }}>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 3, width: 12, flex: 'none' }}>
          {rowLabels.map((l, i) => (
            <span key={i} className="small muted" style={{ fontSize: 9, lineHeight: '14px' }}>
              {l}
            </span>
          ))}
        </div>
        {columns.map((col, ci) => (
          <div key={ci} style={{ display: 'flex', flexDirection: 'column', gap: 3, flex: 'none' }}>
            {col.map((key, ri) =>
              key === null ? (
                <span key={ri} style={{ width: 14, height: 14 }} />
              ) : (
                <span
                  key={ri}
                  className={`heat-cell heat-${levelFor(key)}`}
                  title={`${key}: ${byDay.get(key) ?? 0} min focus · effort`}
                  style={{ animationDelay: `${Math.min(ci * 40, 800)}ms` }}
                />
              ),
            )}
          </div>
        ))}
      </div>
      <div className="row" style={{ gap: 6, marginTop: 10, fontSize: 11 }}>
        <span className="small muted">Less</span>
        {[0, 1, 2, 3, 4].map((l) => (
          <span key={l} className={`heat-cell heat-${l}`} style={{ width: 11, height: 11, animation: 'none' }} />
        ))}
        <span className="small muted">More</span>
        <span className="small muted" style={{ marginLeft: 'auto' }}>
          1 cell = 30 min focus or 1 task
        </span>
      </div>
    </div>
  );
}

/** Consecutive active days ending today or yesterday (so an in-progress
 *  today never hides an otherwise-alive streak). */
export function computeStreak(points: TrendPoint[]): number {
  const active = new Set(points.filter((p) => p.value > 0).map((p) => p.date));
  let streak = 0;
  let cursor = toKey(new Date());
  if (active.has(cursor)) streak++;
  cursor = addDays(cursor, -1);
  while (active.has(cursor)) {
    streak++;
    cursor = addDays(cursor, -1);
  }
  return streak;
}

function toKey(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
}

function addDays(key: string, days: number): string {
  const [y, m, d] = key.split('-').map(Number);
  const dt = new Date(y, m - 1, d + days);
  return toKey(dt);
}
