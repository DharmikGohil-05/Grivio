// Profile service — reads and writes the authenticated user's profile.
// IMPORTANT: the userId always comes from the verified JWT (set by the
// auth middleware), never from the request body, so one user cannot
// read or modify another user's profile.
const { query } = require('../config/db');

// Fetch the profile for the given user.
async function getProfile(userId) {
  const result = await query(
    `SELECT id, user_id, name, profile_picture, short_description,
            growth_areas, main_goal, daily_available_time,
            setup_completed, created_at, updated_at
     FROM profiles WHERE user_id = $1`,
    [userId]
  );
  if (result.rowCount === 0) {
    const err = new Error('Profile not found');
    err.statusCode = 404;
    throw err;
  }
  return result.rows[0];
}

// Create or update the profile for the given user.
// Only the fields present in `fields` are updated; updated_at bumps.
async function upsertProfile(userId, fields) {
  const name = typeof fields.name === 'string' ? fields.name.trim() : undefined;
  const growthAreas = Array.isArray(fields.growthAreas) ? fields.growthAreas : undefined;
  const mainGoal = typeof fields.mainGoal === 'string' ? fields.mainGoal.trim() : undefined;
  const dailyAvailableTime =
    typeof fields.dailyAvailableTime === 'string' ? fields.dailyAvailableTime : undefined;
  const profilePicture =
    typeof fields.profilePicture === 'string' ? fields.profilePicture : undefined;
  const setupCompleted =
    typeof fields.setupCompleted === 'boolean' ? fields.setupCompleted : undefined;

  const result = await query(
    `UPDATE profiles SET
       name                 = COALESCE($2, name),
       growth_areas         = COALESCE($3, growth_areas),
       main_goal            = COALESCE($4, main_goal),
       daily_available_time = COALESCE($5, daily_available_time),
       profile_picture      = COALESCE($6, profile_picture),
       setup_completed      = COALESCE($7, setup_completed),
       updated_at           = NOW()
     WHERE user_id = $1
     RETURNING id, user_id, name, profile_picture, short_description,
               growth_areas, main_goal, daily_available_time,
               setup_completed, created_at, updated_at`,
    [userId, name ?? null, growthAreas ?? null, mainGoal ?? null, dailyAvailableTime ?? null, profilePicture ?? null, setupCompleted ?? null]
  );

  if (result.rowCount === 0) {
    const err = new Error('Profile not found');
    err.statusCode = 404;
    throw err;
  }
  return result.rows[0];
}

module.exports = { getProfile, upsertProfile };
