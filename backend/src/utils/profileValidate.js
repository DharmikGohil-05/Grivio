// Profile validation — the backend is the source of truth for allowed
// values. Flutter sends data; this module decides what is acceptable.
// Growth areas and daily time use FIXED lists so junk never reaches the DB.

const GROWTH_AREAS = [
  'Career',
  'Learning',
  'Fitness',
  'Personal',
  'Finance',
  'Communication',
  'Other',
];

const DAILY_TIMES = ['30 minutes', '1 hour', '2 hours', '3+ hours'];

// Returns an array of problems (empty = valid).
function validateProfileInput({ name, growthAreas, mainGoal, dailyAvailableTime }) {
  const errors = [];

  if (typeof name !== 'string' || !name.trim()) {
    errors.push('Name is required');
  } else if (name.trim().length > 120) {
    errors.push('Name must be 120 characters or fewer');
  }

  if (growthAreas !== undefined) {
    if (!Array.isArray(growthAreas)) {
      errors.push('Growth areas must be a list');
    } else if (growthAreas.some((g) => !GROWTH_AREAS.includes(g))) {
      errors.push('One or more growth areas are not allowed');
    }
  }

  if (mainGoal !== undefined && mainGoal !== null && typeof mainGoal !== 'string') {
    errors.push('Main goal must be text');
  } else if (typeof mainGoal === 'string' && mainGoal.length > 500) {
    errors.push('Main goal must be 500 characters or fewer');
  }

  if (
    dailyAvailableTime !== undefined &&
    dailyAvailableTime !== null &&
    !DAILY_TIMES.includes(dailyAvailableTime)
  ) {
    errors.push('Daily time must be one of the provided options');
  }

  return errors;
}

module.exports = { validateProfileInput, GROWTH_AREAS, DAILY_TIMES };
