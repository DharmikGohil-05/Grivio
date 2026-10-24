// AI task improvement + breakdown services — preview-only generation via
// Groq. Nothing here writes to PostgreSQL; the user must explicitly confirm
// before any persistence happens through the existing task/goal APIs.
const groqService = require('./groq.service');
const taskService = require('./task.service');
const goalService = require('./goal.service');

const MAX_INSTRUCTIONS_LENGTH = 500;
const MAX_TITLE_LENGTH = 200;
const MAX_DESCRIPTION_LENGTH = 1000;
const MAX_PHASES = 8;
const MAX_TASKS_PER_PHASE = 8;
const VALID_PRIORITIES = ['low', 'medium', 'high'];
const VALID_CATEGORIES = ['Career', 'Learning', 'Fitness', 'Personal', 'Finance', 'Communication', 'Other'];

function aiError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

function cleanString(value, maxLen) {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'string') return null;
  const trimmed = value.trim();
  return trimmed ? trimmed.slice(0, maxLen) : null;
}

// ---------- Feature A: task improvement ----------

function normalizeImprovement(raw) {
  const out = {};

  const title = cleanString(raw?.improvedTitle ?? raw?.title, MAX_TITLE_LENGTH);
  if (title) out.title = title;

  const description = cleanString(raw?.description, MAX_DESCRIPTION_LENGTH);
  if (description) out.description = description;

  const category = cleanString(raw?.category, 50);
  if (category && VALID_CATEGORIES.includes(category)) out.category = category;

  const priority = cleanString(raw?.priority, 10);
  if (priority && VALID_PRIORITIES.includes(priority)) out.priority = priority;

  if (raw?.estimatedMinutes != null) {
    const n = Number(raw.estimatedMinutes);
    if (!Number.isFinite(n) || n < 5 || n > 480) {
      throw aiError(502, 'AI returned an invalid estimated duration.');
    }
    out.estimatedMinutes = Math.round(n);
  }

  // Optional suggested subtasks (titles only — user reviews before saving).
  if (Array.isArray(raw?.subtasks)) {
    if (raw.subtasks.length > 10) throw aiError(502, 'AI returned too many subtasks.');
    const subs = [];
    for (const s of raw.subtasks) {
      const t = cleanString(s?.title ?? s, MAX_TITLE_LENGTH);
      if (t) subs.push({ title: t });
    }
    if (subs.length) out.subtasks = subs;
  }

  if (Object.keys(out).length === 0) {
    throw aiError(502, 'AI returned no usable improvements.');
  }
  return out;
}

async function improveTask(userId, { taskId, title, description, instructions }) {
  if (instructions && instructions.length > MAX_INSTRUCTIONS_LENGTH) {
    throw aiError(400, `Instructions must be ${MAX_INSTRUCTIONS_LENGTH} characters or fewer`);
  }

  // Existing task: load authoritative data + enforce ownership.
  let currentTitle = '';
  let currentDescription = '';
  if (taskId) {
    const task = await taskService.getTask(userId, taskId);
    currentTitle = task.title || '';
    currentDescription = task.description || '';
  } else {
    // Unsaved task: only bounded client fields, validated.
    if (typeof title !== 'string' || !title.trim()) {
      throw aiError(400, 'A non-empty title is required');
    }
    if (title.length > MAX_TITLE_LENGTH) {
      throw aiError(400, `Title must be ${MAX_TITLE_LENGTH} characters or fewer`);
    }
    if (description != null && (typeof description !== 'string' || description.length > MAX_DESCRIPTION_LENGTH)) {
      throw aiError(400, `Description must be ${MAX_DESCRIPTION_LENGTH} characters or fewer`);
    }
    currentTitle = title.trim();
    currentDescription = (description || '').trim();
  }

  const systemPrompt =
    'You are a precise productivity assistant. You rewrite vague tasks into actionable ones. ' +
    'Respond with ONLY valid JSON: {"improvedTitle":"...","description":"...","category":"...","priority":"...","estimatedMinutes":30,"subtasks":[{"title":"..."}]}. ' +
    `Category must be one of: ${VALID_CATEGORIES.join(', ')}. Priority must be one of: ${VALID_PRIORITIES.join(', ')}. ` +
    'Preserve the user\'s original intent. Never invent deadlines or claim work is done. No markdown, no commentary.';

  const userPrompt = [
    `Current task: ${currentTitle}`,
    currentDescription ? `Current description: ${currentDescription}` : null,
    instructions ? `User instructions: ${instructions}` : null,
    'Return the improved task JSON now.',
  ].filter(Boolean).join('\n');

  const parsed = await groqService.generateJson(userPrompt, { systemPrompt, maxTokens: 1000 });
  return normalizeImprovement(parsed);
}

// ---------- Feature B: goal/task breakdown ----------

function normalizeBreakdown(raw) {
  const phasesRaw = raw?.phases;
  if (!Array.isArray(phasesRaw) || phasesRaw.length === 0) {
    throw aiError(502, 'AI returned no usable breakdown.');
  }
  if (phasesRaw.length > MAX_PHASES) {
    throw aiError(502, 'AI returned too many phases.');
  }

  const phases = [];
  for (const p of phasesRaw) {
    const title = cleanString(p?.title, MAX_TITLE_LENGTH);
    if (!title) continue;
    const description = cleanString(p?.description, MAX_DESCRIPTION_LENGTH);

    const tasks = [];
    if (Array.isArray(p?.tasks)) {
      if (p.tasks.length > MAX_TASKS_PER_PHASE) {
        throw aiError(502, 'AI returned too many tasks in one phase.');
      }
      for (const t of p.tasks) {
        const tTitle = cleanString(t?.title, MAX_TITLE_LENGTH);
        if (!tTitle) continue;
        const tDesc = cleanString(t?.description, MAX_DESCRIPTION_LENGTH);
        let minutes = null;
        if (t?.estimatedMinutes != null) {
          const n = Number(t.estimatedMinutes);
          if (!Number.isFinite(n) || n < 5 || n > 480) {
            throw aiError(502, 'AI returned an invalid task duration.');
          }
          minutes = Math.round(n);
        }
        tasks.push({ title: tTitle, ...(tDesc ? { description: tDesc } : {}), ...(minutes ? { estimatedMinutes: minutes } : {}) });
      }
    }

    phases.push({ title, ...(description ? { description } : {}), tasks });
  }

  if (phases.length === 0) {
    throw aiError(502, 'AI returned no usable breakdown.');
  }
  return { phases };
}

async function generateBreakdown(userId, { goalId, title, description, instructions }) {
  if (instructions && instructions.length > MAX_INSTRUCTIONS_LENGTH) {
    throw aiError(400, `Instructions must be ${MAX_INSTRUCTIONS_LENGTH} characters or fewer`);
  }

  let currentTitle = '';
  let currentDescription = '';
  if (goalId) {
    const goal = await goalService.getGoal(userId, goalId);
    currentTitle = goal.name || '';
    currentDescription = [goal.description, goal.why_it_matters].filter(Boolean).join(' ');
  } else {
    if (typeof title !== 'string' || !title.trim()) {
      throw aiError(400, 'A non-empty title is required');
    }
    if (title.length > MAX_TITLE_LENGTH) {
      throw aiError(400, `Title must be ${MAX_TITLE_LENGTH} characters or fewer`);
    }
    if (description != null && (typeof description !== 'string' || description.length > MAX_DESCRIPTION_LENGTH)) {
      throw aiError(400, `Description must be ${MAX_DESCRIPTION_LENGTH} characters or fewer`);
    }
    currentTitle = title.trim();
    currentDescription = (description || '').trim();
  }

  const systemPrompt =
    'You are a precise productivity assistant. You break large goals or tasks into a practical, sequential hierarchy. ' +
    'Respond with ONLY valid JSON: {"phases":[{"title":"...","description":"...","tasks":[{"title":"...","description":"...","estimatedMinutes":60}]}]}. ' +
    'Rules: 2-8 phases in a sensible order; each phase has 0-8 actionable tasks; ' +
    'task titles start with action verbs; durations are 5-480 minutes. No markdown, no commentary.';

  const userPrompt = [
    `Goal or large task: ${currentTitle}`,
    currentDescription ? `Context: ${currentDescription}` : null,
    instructions ? `User instructions: ${instructions}` : null,
    'Return the breakdown JSON now.',
  ].filter(Boolean).join('\n');

  const parsed = await groqService.generateJson(userPrompt, { systemPrompt, maxTokens: 2000 });
  return normalizeBreakdown(parsed);
}

module.exports = { improveTask, generateBreakdown, normalizeImprovement, normalizeBreakdown };
