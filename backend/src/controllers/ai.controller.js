// AI controller — thin HTTP layer over the Groq service.
// Validates input, enforces auth via middleware, and normalizes all
// provider errors into the project's standard { success, message } format.
const groqService = require('../services/groq.service');

const MAX_PROMPT_LENGTH = 2000; // bound input so the endpoint can't be abused

function errJson(res, err) {
  return res
    .status(err.statusCode || 500)
    .json({ success: false, message: err.statusCode ? err.message : 'Server error' });
}

// POST /api/ai/test — minimal authenticated AI health/test endpoint.
exports.test = async (req, res) => {
  try {
    const prompt = req.body?.prompt;
    if (typeof prompt !== 'string' || !prompt.trim()) {
      return res.status(400).json({ success: false, message: 'Prompt is required' });
    }
    if (prompt.length > MAX_PROMPT_LENGTH) {
      return res.status(400).json({ success: false, message: `Prompt must be ${MAX_PROMPT_LENGTH} characters or fewer` });
    }

    const result = await groqService.generateText(prompt.trim());
    return res.status(200).json({ success: true, data: { text: result.text } });
  } catch (err) {
    return errJson(res, err);
  }
};

// POST /api/ai/subtasks/generate — AI subtask suggestions for a task.
// Returns suggestions only; nothing is persisted until the user approves.
const aiSubtaskService = require('../services/ai-subtask.service');

exports.generateSubtasks = async (req, res) => {
  try {
    const { taskId } = req.body ?? {};
    const instructions = req.body?.instructions;

    if (typeof taskId !== 'string' || !taskId.trim()) {
      return res.status(400).json({ success: false, message: 'A valid taskId is required' });
    }
    if (instructions !== undefined && instructions !== null && typeof instructions !== 'string') {
      return res.status(400).json({ success: false, message: 'instructions must be text' });
    }

    const suggestions = await aiSubtaskService.generateSubtaskSuggestions(req.userId, {
      taskId: taskId.trim(),
      instructions: instructions?.trim() || null,
    });

    return res.status(200).json({ success: true, data: { suggestions } });
  } catch (err) {
    return errJson(res, err);
  }
};

// POST /api/ai/tasks/improve — AI improvement proposal for a task.
// Accepts either an existing taskId or an unsaved title/description.
const aiFeaturesService = require('../services/ai-features.service');

exports.improveTask = async (req, res) => {
  try {
    const { taskId, title, description, instructions } = req.body ?? {};
    if (instructions !== undefined && instructions !== null && typeof instructions !== 'string') {
      return res.status(400).json({ success: false, message: 'instructions must be text' });
    }
    const proposal = await aiFeaturesService.improveTask(req.userId, {
      taskId: taskId || null,
      title: title ?? null,
      description: description ?? null,
      instructions: instructions?.trim() || null,
    });
    return res.status(200).json({ success: true, data: proposal });
  } catch (err) {
    return errJson(res, err);
  }
};

// POST /api/ai/breakdown/generate — AI hierarchy breakdown for a goal.
// Accepts either an existing goalId or an unsaved title/description.
exports.generateBreakdown = async (req, res) => {
  try {
    const { goalId, title, description, instructions } = req.body ?? {};
    if (instructions !== undefined && instructions !== null && typeof instructions !== 'string') {
      return res.status(400).json({ success: false, message: 'instructions must be text' });
    }
    const breakdown = await aiFeaturesService.generateBreakdown(req.userId, {
      goalId: goalId || null,
      title: title ?? null,
      description: description ?? null,
      instructions: instructions?.trim() || null,
    });
    return res.status(200).json({ success: true, data: breakdown });
  } catch (err) {
    return errJson(res, err);
  }
};

// POST /api/ai/daily-plan/generate — AI daily planner (Phase 14).
// PREVIEW ONLY: loads the user's real profile + eligible tasks, generates
// a validated schedule, and never writes anything to the database.
const aiPlanService = require('../services/ai-plan.service');

exports.generateDailyPlan = async (req, res) => {
  try {
    const plan = await aiPlanService.generateDailyPlan(req.userId, req.body ?? {});
    return res.status(200).json({ success: true, data: plan });
  } catch (err) {
    return errJson(res, err);
  }
};

// POST /api/ai/weekly-review/generate — AI weekly growth review (Phase 15).
// Read-only: gathers real activity for the requested Mon–Sun week and
// returns a structured review without writing anything to the database.
const aiWeeklyService = require('../services/ai-weekly.service');

exports.generateWeeklyReview = async (req, res) => {
  try {
    const review = await aiWeeklyService.generateWeeklyReview(req.userId, req.body ?? {});
    return res.status(200).json({ success: true, data: review });
  } catch (err) {
    return errJson(res, err);
  }
};
