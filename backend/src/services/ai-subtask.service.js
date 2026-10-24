// AI subtask generation service — turns a parent task into suggested
// subtasks via Groq. Generation NEVER writes to PostgreSQL; suggestions
// are returned for the user to review and approve before persistence.
const groqService = require('./groq.service');
const taskService = require('./task.service');

const MAX_SUGGESTIONS = 10;
const MAX_INSTRUCTIONS_LENGTH = 500;
const MAX_TITLE_LENGTH = 200;
const MAX_DESCRIPTION_LENGTH = 500;

function aiError(statusCode, message) {
  const err = new Error(message);
  err.statusCode = statusCode;
  return err;
}

// Normalizes untrusted model output into clean suggestion objects.
// Anything malformed, empty, or oversized is rejected — never returned raw.
function normalizeSuggestions(raw) {
  const list = Array.isArray(raw) ? raw : raw?.suggestions;
  if (!Array.isArray(list) || list.length === 0) {
    throw aiError(502, 'AI returned no usable subtasks.');
  }
  if (list.length > MAX_SUGGESTIONS) {
    throw aiError(502, 'AI returned too many subtasks.');
  }

  const suggestions = [];
  for (const item of list) {
    const title = typeof item?.title === 'string' ? item.title.trim() : '';
    if (!title) continue; // skip items without a usable title
    if (title.length > MAX_TITLE_LENGTH) {
      throw aiError(502, 'AI returned an overly long subtask title.');
    }

    let description = null;
    if (item?.description != null) {
      if (typeof item.description !== 'string') {
        throw aiError(502, 'AI returned an invalid subtask description.');
      }
      description = item.description.trim().slice(0, MAX_DESCRIPTION_LENGTH) || null;
    }

    let estimatedMinutes = null;
    if (item?.estimatedMinutes != null) {
      const n = Number(item.estimatedMinutes);
      if (!Number.isFinite(n) || n < 5 || n > 480) {
        throw aiError(502, 'AI returned an invalid subtask duration.');
      }
      estimatedMinutes = Math.round(n);
    }

    suggestions.push({ title, description, estimatedMinutes });
  }

  if (suggestions.length === 0) {
    throw aiError(502, 'AI returned no usable subtasks.');
  }
  return suggestions;
}

/**
 * Generates subtask suggestions for a task. The task must belong to the
 * authenticated user (verified via taskService). No database writes here.
 */
async function generateSubtaskSuggestions(userId, { taskId, instructions }) {
  if (instructions !== undefined && instructions !== null && instructions.length > MAX_INSTRUCTIONS_LENGTH) {
    throw aiError(400, `Instructions must be ${MAX_INSTRUCTIONS_LENGTH} characters or fewer`);
  }

  let taskTitle = '';
  let taskDescription = '';
  if (taskId) {
    // Ownership enforced inside getTask (404 for other users' tasks).
    const task = await taskService.getTask(userId, taskId);
    taskTitle = task.title || '';
    taskDescription = task.description || '';
  }

  const context = [
    `Parent task: ${taskTitle}`,
    taskDescription ? `Details: ${taskDescription}` : null,
    instructions ? `User instructions: ${instructions}` : null,
  ].filter(Boolean).join('\n');

  const systemPrompt =
    'You are a precise productivity assistant. You break tasks into actionable, sequential subtasks. ' +
    'Respond with ONLY valid JSON in this exact shape: {"suggestions":[{"title":"...","description":"...","estimatedMinutes":25}]}. ' +
    'Rules: 3-10 subtasks; each title is short, concrete and starts with an action verb; ' +
    'description is one helpful sentence (optional); estimatedMinutes is a number between 5 and 480 (optional). ' +
    'No markdown, no commentary, no extra keys.';

  const userPrompt = `${context}\n\nGenerate the subtasks JSON now.`;

  const parsed = await groqService.generateJson(userPrompt, {
    systemPrompt,
    maxTokens: 1500,
  });

  return normalizeSuggestions(parsed);
}

module.exports = { generateSubtaskSuggestions, normalizeSuggestions, MAX_SUGGESTIONS, MAX_INSTRUCTIONS_LENGTH };
