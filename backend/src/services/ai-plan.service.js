// AI daily planner service — preview-only schedule generation.
//
// Loads the authenticated user's REAL profile and eligible tasks from
// PostgreSQL, asks Groq to arrange them inside the user's chosen
// availability window, then validates/normalizes the result server-side.
// AI output is untrusted: task IDs must exist in the user's own eligible
// list, times must sit inside the window, slots must never overlap, and
// durations must be sane. Nothing here writes to the database.
const { query } = require('../config/db');
const groqService = require('./groq.service');
const profileService = require('./profile.service');
const { PRIORITIES } = require('../utils/taskValidate');

const MAX_CONTEXT_LENGTH = 1000; // dailyContext cap (trimmed, plain text)
const MAX_ELIGIBLE_TASKS = 30; // bound the prompt size
const MIN_TASK_MINUTES = 5;
const MAX_TASK_MINUTES = 480;
const MAX_BREAK_MINUTES = 60;
const FALLBACK_MINUTES = 30; // used when a task has no estimate (flagged)

function aiError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

// ---------- time helpers (all times are "HH:MM" strings) ----------

function parseHHMM(value) {
  if (typeof value !== 'string') return null;
  const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(value.trim());
  if (!m) return null;
  return Number(m[1]) * 60 + Number(m[2]);
}

function toHHMM(minutes) {
  const h = Math.floor(minutes / 60).toString().padStart(2, '0');
  const m = (minutes % 60).toString().padStart(2, '0');
  return `${h}:${m}`;
}

function isValidDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.exec(value)) return false;
  const d = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === value;
}

/**
 * Validates and normalizes the planning request. Throws aiError(400) with
 * a safe message. Never echoes the user's free-text context back.
 */
function validateRequest(body) {
  const date = body?.date;
  const availableMinutes = body?.availableMinutes;
  if (!isValidDate(date)) {
    throw aiError(400, 'date must be a valid YYYY-MM-DD date');
  }
  if (!Number.isInteger(availableMinutes) || availableMinutes < 5 || availableMinutes > 1440) {
    throw aiError(400, 'availableMinutes must be an integer between 5 and 1440');
  }

  const startTime = body.startTime === undefined || body.startTime === null || body.startTime === '' ? null : body.startTime;
  const endTime = body.endTime === undefined || body.endTime === null || body.endTime === '' ? null : body.endTime;
  let start = startTime === null ? 9 * 60 : parseHHMM(startTime); // default 09:00
  let end = endTime === null ? null : parseHHMM(endTime);
  if (startTime !== null && start === null) throw aiError(400, 'startTime must be HH:MM');
  if (endTime !== null && end === null) throw aiError(400, 'endTime must be HH:MM');
  if (end === null) end = Math.min(start + availableMinutes, 24 * 60 - 1); // derive window
  if (start >= end) throw aiError(400, 'startTime must be before endTime');

  const breakMinutes = body.breakMinutes === undefined || body.breakMinutes === null ? 10 : body.breakMinutes;
  if (!Number.isInteger(breakMinutes) || breakMinutes < 0 || breakMinutes > MAX_BREAK_MINUTES) {
    throw aiError(400, `breakMinutes must be an integer between 0 and ${MAX_BREAK_MINUTES}`);
  }

  // Free-text context is used ONLY to steer this one prompt and to build
  // warnings — it is validated here and never persisted to the database.
  let dailyContext = body.dailyContext;
  if (dailyContext === undefined || dailyContext === null) dailyContext = '';
  if (typeof dailyContext !== 'string') throw aiError(400, 'dailyContext must be plain text');
  dailyContext = dailyContext.trim();
  if (dailyContext.length > MAX_CONTEXT_LENGTH) {
    throw aiError(400, `dailyContext must be ${MAX_CONTEXT_LENGTH} characters or fewer`);
  }

  // Capacity: never plan beyond the window OR the requested available time.
  const windowMinutes = end - start;
  const capacity = Math.min(availableMinutes, windowMinutes);
  if (capacity < MIN_TASK_MINUTES) throw aiError(400, 'The selected availability window is too small to plan in');

  return { date, availableMinutes, start, end, breakMinutes, dailyContext, capacity };
}

/**
 * Loads the user's eligible (incomplete, non-cancelled) tasks — the ONLY
 * tasks the plan may ever reference. Ownership enforced by user_id.
 */
async function loadEligibleTasks(userId, date) {
  const result = await query(
    `SELECT t.id, t.title, t.priority, t.due_date, t.estimated_minutes,
            t.category, t.status, g.name AS goal_name
     FROM tasks t
     LEFT JOIN goals g ON g.id = t.goal_id
     WHERE t.user_id = $1 AND t.status NOT IN ('completed', 'cancelled')
     ORDER BY t.due_date ASC NULLS LAST,
              CASE t.priority WHEN 'high' THEN 0 WHEN 'medium' THEN 1 ELSE 2 END,
              t.created_at ASC
     LIMIT $2`,
    [userId, MAX_ELIGIBLE_TASKS]
  );
  return result.rows.map((r) => ({
    id: r.id,
    title: r.title,
    priority: r.priority,
    dueDate: r.due_date ? new Date(r.due_date).toISOString().slice(0, 10) : null,
    overdue: r.due_date ? new Date(r.due_date).toISOString().slice(0, 10) < date : false,
    estimatedMinutes: r.estimated_minutes ?? null, // null → fallback estimate, flagged
    category: r.category ?? null,
    goalName: r.goal_name ?? null,
  }));
}

// ---------- task suggestions (user has no open tasks) ----------

const MAX_SUGGESTED_TASKS = 6;

/**
 * Proposes a short task list derived from the user's own written day
 * description — used ONLY when they have no open tasks to schedule.
 * PREVIEW ONLY: nothing is persisted here; the client shows the list and
 * creates tasks through the normal POST /tasks contract only after the
 * user explicitly picks them.
 */
async function suggestTasks(ctx) {
  const systemPrompt =
    "You are GRIVIO's daily planner. The user has no open tasks yet and described the day they want. " +
    'Respond with ONLY valid JSON: {"tasks":[{"title":"...","minutes":30,"priority":"low|medium|high"}]}. ' +
    `Rules: propose between 1 and ${MAX_SUGGESTED_TASKS} concrete, doable tasks that fit the description; ` +
    `minutes must be ${MIN_TASK_MINUTES}-${MAX_TASK_MINUTES}; total minutes must not exceed ${ctx.capacity}; ` +
    'titles must be specific and under 80 characters; priority reflects importance for this day. ' +
    'No markdown, no commentary, no extra keys.';

  const userPrompt = [
    `AVAILABILITY: ${ctx.capacity} minutes between ${toHHMM(ctx.start)} and ${toHHMM(ctx.end)} on ${ctx.date}.`,
    "USER'S PERSONAL DESCRIPTION OF THEIR DAY (preferences, not verified facts):",
    ctx.dailyContext,
  ].join('\n');

  const raw = await groqService.generateJson(userPrompt, { systemPrompt, maxTokens: 900 });

  // Model output is untrusted: validate every entry, drop what doesn't
  // fit, and fail safe with a 502 only when the shape is unusable.
  if (!raw || typeof raw !== 'object' || !Array.isArray(raw.tasks)) {
    throw aiError(502, 'AI returned a malformed task list. Please try again.');
  }

  const tasks = [];
  let total = 0;
  for (const entry of raw.tasks) {
    if (tasks.length >= MAX_SUGGESTED_TASKS) break;
    if (!entry || typeof entry.title !== 'string') continue;
    const title = entry.title.trim().replace(/\s+/g, ' ');
    if (!title || title.length > 200) continue;
    const minutes = Math.round(Number(entry.minutes));
    if (!Number.isFinite(minutes)) continue;
    const clamped = Math.min(Math.max(minutes, MIN_TASK_MINUTES), MAX_TASK_MINUTES);
    if (total + clamped > ctx.capacity) continue; // never propose beyond the window
    const priority = PRIORITIES.includes(entry.priority) ? entry.priority : 'medium';
    tasks.push({ title, minutes: clamped, priority });
    total += clamped;
  }
  if (tasks.length === 0) {
    throw aiError(502, 'AI could not suggest fitting tasks. Please try again.');
  }
  return tasks;
}

// ---------- request-side warnings (grounded in the actual request) ----------

// Finds clock times mentioned in free text (e.g. "5 PM", "17:30") so we can
// warn when the user's note mentions a time outside their chosen window.
function contextTimeWarnings(context, start, end) {
  if (!context) return [];
  const warnings = [];
  const lower = context.toLowerCase();
  const mentions = [];
  const re = /\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b/g;
  let m;
  while ((m = re.exec(lower)) !== null) {
    let h = Number(m[1]) % 12;
    if (m[3] === 'pm') h += 12;
    mentions.push({ text: m[0], minutes: h * 60 + Number(m[2] ?? 0) });
  }
  const re2 = /\b([01]?\d|2[0-3]):([0-5]\d)\b/g;
  while ((m = re2.exec(lower)) !== null) {
    mentions.push({ text: m[0], minutes: Number(m[1]) * 60 + Number(m[2]) });
  }
  const outside = mentions.filter((t) => t.minutes < start || t.minutes > end);
  if (outside.length > 0) {
    warnings.push(
      `Your note mentions ${outside[0].text}, which is outside your selected availability window ` +
        `(${toHHMM(start)}–${toHHMM(end)}). Tasks were kept inside the window.`
    );
  }
  // Long requested blocks vs capacity ("90 minutes", "2 hours").
  const blockRe = /\b(\d{1,3})\s*(hour|hr|minute|min)\b/g;
  while ((m = blockRe.exec(lower)) !== null) {
    const mins = m[2].startsWith('hour') || m[2].startsWith('hr') ? Number(m[1]) * 60 : Number(m[1]);
    if (mins > 60 && mins > 0) {
      warnings.push(`Your requested ${mins}-minute block may not fit with today's other tasks.`);
      break;
    }
  }
  return warnings;
}

// ---------- model output validation (untrusted) ----------

/**
 * Validates and normalizes the model's schedule. Invalid entries are
 * demoted to unscheduled instead of being trusted; only structurally
 * unusable output triggers a safe 502.
 */
function normalizePlan(raw, eligible, ctx) {
  if (!raw || typeof raw !== 'object' || !Array.isArray(raw.schedule)) {
    throw aiError(502, 'AI returned a malformed schedule. Please try again.');
  }

  // Whitelist of this user's own tasks — the only IDs the model's output
  // can resolve against; invented or foreign IDs simply won't match.
  const byId = new Map(eligible.map((t) => [t.id, t]));
  const scheduled = []; // { task, start, end, minutes, isFallback }
  const unscheduled = []; // { task, reason }
  const seen = new Set();
  const warnings = [];
  let droppedUnknown = 0;

  for (const entry of raw.schedule) {
    const task = byId.get(entry?.taskId);
    if (!task) { droppedUnknown++; continue; } // never invent IDs / never use others' tasks
    if (seen.has(task.id)) continue; // no double-booking
    seen.add(task.id);

    const start = parseHHMM(entry?.start);
    let minutes = Number(entry?.minutes);
    if (start === null || !Number.isInteger(minutes) || minutes < MIN_TASK_MINUTES || minutes > MAX_TASK_MINUTES) {
      unscheduled.push({ task, reason: 'AI returned an invalid time for this task' });
      continue;
    }
    const isFallback = task.estimatedMinutes == null;
    if (isFallback) minutes = Math.min(minutes, MAX_TASK_MINUTES); // model's best guess, flagged
    const end = start + minutes;

    // Out-of-window or over-capacity entries are rejected from the schedule.
    if (start < ctx.start || end > ctx.end) {
      unscheduled.push({ task, reason: 'Does not fit inside your availability window' });
      continue;
    }
    const used = scheduled.reduce((n, s) => n + s.minutes, 0) + unscheduledFromBreaks(raw, ctx);
    if (used + minutes > ctx.capacity) {
      unscheduled.push({ task, reason: 'Not enough available time today' });
      continue;
    }
    if (scheduled.some((s) => start < s.end && end > s.start)) {
      unscheduled.push({ task, reason: 'Would overlap another scheduled task' });
      continue;
    }
    scheduled.push({ task, start, end, minutes, isFallback });
  }

  // Validated breaks — inside the window, no overlap with tasks or each other.
  const breaks = [];
  if (Array.isArray(raw.breaks)) {
    for (const b of raw.breaks) {
      const start = parseHHMM(b?.start);
      const minutes = Number(b?.minutes);
      if (start === null || !Number.isInteger(minutes) || minutes < 1 || minutes > MAX_BREAK_MINUTES) continue;
      const end = start + minutes;
      if (start < ctx.start || end > ctx.end) continue;
      const clashesTask = scheduled.some((s) => start < s.end && end > s.start);
      const clashesBreak = breaks.some((x) => start < x.end && end > x.start);
      if (!clashesTask && !clashesBreak) breaks.push({ start, end, minutes });
    }
  }

  // Unscheduled items coming back from the model (validated the same way).
  if (Array.isArray(raw.unscheduled)) {
    for (const u of raw.unscheduled) {
      const task = byId.get(u?.taskId);
      if (!task || seen.has(task.id)) continue;
      seen.add(task.id);
      const reason = typeof u?.reason === 'string' && u.reason.trim()
        ? u.reason.trim().slice(0, 120)
        : 'Not enough available time today';
      unscheduled.push({ task, reason });
    }
  }

  // Nothing usable came back → safe error, never expose the raw payload.
  if (scheduled.length === 0 && unscheduled.length === 0) {
    throw aiError(502, 'AI returned an unusable schedule. Please try again.');
  }
  if (droppedUnknown > 0) {
    warnings.push('Some AI-suggested items were skipped because they were not your tasks.');
  }
  if (scheduled.some((s) => s.isFallback)) {
    const names = scheduled.filter((s) => s.isFallback).map((s) => s.task.title);
    warnings.push(
      `No time estimate was set for: ${names.join(', ')}. A ${FALLBACK_MINUTES}-minute placeholder was assumed — adjust as needed.`
    );
  }

  const plannedMinutes = scheduled.reduce((n, s) => n + s.minutes, 0);
  const breakMinutes = breaks.reduce((n, b) => n + b.minutes, 0);
  if (unscheduled.length > 0) {
    warnings.push('Some tasks remain unscheduled because your available time is limited.');
  }

  scheduled.sort((a, b) => a.start - b.start);
  return {
    scheduled,
    unscheduled,
    breaks,
    warnings,
    plannedMinutes: plannedMinutes + breakMinutes, // tasks + breaks, counted once each
    remainingMinutes: Math.max(0, ctx.capacity - plannedMinutes - breakMinutes),
  };
}

// Model-proposed break minutes (used only for capacity checks while normalizing).
function unscheduledFromBreaks(raw, ctx) {
  if (!Array.isArray(raw.breaks)) return 0;
  let total = 0;
  for (const b of raw.breaks) {
    const start = parseHHMM(b?.start);
    const minutes = Number(b?.minutes);
    if (start !== null && Number.isInteger(minutes) && minutes > 0 && minutes <= MAX_BREAK_MINUTES) total += minutes;
  }
  return Math.min(total, MAX_BREAK_MINUTES * 8);
}

/**
 * Generates a daily plan for the authenticated user. PREVIEW ONLY —
 * no database writes happen here; acceptance is a separate user action.
 */
async function generateDailyPlan(userId, body) {
  const ctx = validateRequest(body);

  // Real data: profile availability + eligible tasks (both owner-scoped).
  let profileAvailable = null;
  try {
    const profile = await profileService.getProfile(userId);
    profileAvailable = profile.daily_available_time ?? null;
  } catch {
    // Profile may not exist yet — planning still works from the request.
  }
  const eligible = await loadEligibleTasks(userId, ctx.date);
  if (eligible.length === 0) {
    // No tasks to schedule. With a written day description the model can
    // PROPOSE tasks (preview only — the client persists nothing until the
    // user explicitly picks them). Without a description we stay honest
    // and return an empty plan rather than inventing tasks from nothing.
    if (ctx.dailyContext) {
      const suggestedTasks = await suggestTasks(ctx);
      return {
        date: ctx.date,
        availableMinutes: ctx.availableMinutes,
        startTime: toHHMM(ctx.start),
        endTime: toHHMM(ctx.end),
        breakMinutes: ctx.breakMinutes,
        capacityMinutes: ctx.capacity,
        plannedMinutes: 0,
        remainingMinutes: ctx.capacity,
        contextApplied: true,
        scheduledTasks: [],
        unscheduledTasks: [],
        breaks: [],
        suggestedTasks,
        warnings: [
          `You have no open tasks yet — review the ${suggestedTasks.length} suggested task(s) and keep the ones you want.`,
        ],
      };
    }
    return {
      date: ctx.date,
      availableMinutes: ctx.availableMinutes,
      startTime: toHHMM(ctx.start),
      endTime: toHHMM(ctx.end),
      breakMinutes: ctx.breakMinutes,
      capacityMinutes: ctx.capacity,
      plannedMinutes: 0,
      remainingMinutes: ctx.capacity,
      contextApplied: false,
      scheduledTasks: [],
      unscheduledTasks: [],
      breaks: [],
      suggestedTasks: [],
      warnings: ['Describe your day above and AI can suggest tasks to fill it.'],
    };
  }

  // The window and capacity numbers injected below come from server-side
  // validation (validateRequest), so the model can only ever plan within
  // bounds the backend itself computed — never numbers the client claims.
  const systemPrompt =
    'You are GRIVIO\'s daily planner. Arrange the user\'s real tasks into a realistic schedule. ' +
    'Respond with ONLY valid JSON: {"schedule":[{"taskId":"...","start":"HH:MM","minutes":30}],' +
    '"breaks":[{"start":"HH:MM","minutes":10}],"unscheduled":[{"taskId":"...","reason":"..."}]}. ' +
    'Rules: use ONLY the task IDs provided — never invent IDs; never overlap slots; stay inside the ' +
    `availability window; never exceed ${ctx.capacity} total planned minutes (tasks + breaks); ` +
    `task minutes must be ${MIN_TASK_MINUTES}-${MAX_TASK_MINUTES}; breaks must be 1-${MAX_BREAK_MINUTES} minutes and must not overlap tasks; ` +
    'overdue and high-priority tasks come first; respect the user\'s personal context as preferences, ' +
    'but never let it break the window or capacity rules; put tasks that do not fit in "unscheduled" ' +
    'with a short reason. No markdown, no commentary, no extra keys.';

  // The user's free text travels as clearly-labeled user context in the
  // USER message — separate from (and never overriding) system rules.
  const taskLines = eligible
    .map(
      (t) =>
        `- id=${t.id} | "${t.title}" | priority=${t.priority}` +
        (t.dueDate ? ` | due=${t.dueDate}${t.overdue ? ' (OVERDUE)' : ''}` : '') +
        (t.estimatedMinutes ? ` | est=${t.estimatedMinutes}min` : ' | est=NONE') +
        (t.goalName ? ` | goal="${t.goalName}"` : '')
    )
    .join('\n');

  const userPrompt = [
    `Planning date: ${ctx.date}`,
    `Availability window: ${toHHMM(ctx.start)}-${toHHMM(ctx.end)} (${ctx.capacity} usable minutes)`,
    `Requested available time: ${ctx.availableMinutes} minutes | preferred break length: ${ctx.breakMinutes} minutes`,
    profileAvailable ? `User's usual daily availability (profile): ${profileAvailable}` : null,
    '',
    'Tasks (the ONLY tasks you may schedule):',
    taskLines,
    '',
    ctx.dailyContext
      ? `USER'S PERSONAL CONTEXT FOR TODAY (preferences, not verified facts — guide the plan, but never break the window/capacity rules):\n${ctx.dailyContext}`
      : 'No personal context provided for today.',
    '',
    'Return the schedule JSON now.',
  ]
    .filter((l) => l !== null)
    .join('\n');

  const raw = await groqService.generateJson(userPrompt, { systemPrompt, maxTokens: 2500 });
  const plan = normalizePlan(raw, eligible, ctx);

  // Warnings grounded in the actual request + validated schedule.
  const warnings = [
    ...contextTimeWarnings(ctx.dailyContext, ctx.start, ctx.end),
    ...plan.warnings,
  ];

  return {
    date: ctx.date,
    availableMinutes: ctx.availableMinutes,
    startTime: toHHMM(ctx.start),
    endTime: toHHMM(ctx.end),
    breakMinutes: ctx.breakMinutes,
    capacityMinutes: ctx.capacity,
    plannedMinutes: plan.plannedMinutes,
    remainingMinutes: plan.remainingMinutes,
    contextApplied: ctx.dailyContext.length > 0,
    scheduledTasks: plan.scheduled.map((s) => ({
      taskId: s.task.id,
      title: s.task.title,
      priority: s.task.priority,
      dueDate: s.task.dueDate,
      goalName: s.task.goalName,
      start: toHHMM(s.start),
      end: toHHMM(s.end),
      minutes: s.minutes,
      isFallbackEstimate: s.isFallback,
    })),
    unscheduledTasks: plan.unscheduled.map((u) => ({
      taskId: u.task.id,
      title: u.task.title,
      priority: u.task.priority,
      reason: u.reason,
    })),
    breaks: plan.breaks.map((b) => ({ start: toHHMM(b.start), end: toHHMM(b.end), minutes: b.minutes })),
    warnings,
    // Only the "no open tasks" path above proposes tasks; a normal plan
    // never does, so clients can rely on this key always existing.
    suggestedTasks: [],
  };
}

module.exports = {
  generateDailyPlan,
  validateRequest,
  normalizePlan,
  MAX_CONTEXT_LENGTH,
  toHHMM,
  parseHHMM,
};
