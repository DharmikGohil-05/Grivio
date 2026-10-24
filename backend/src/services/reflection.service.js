// Daily reflection service — one reflection per user per day.
// Reuses the existing `reflections` table from Phase 2.
const { query } = require('../config/db');

async function getReflectionByDate(userId, date) {
  const r = await query(
    'SELECT id, user_id, reflection_date, went_well, was_difficult, to_improve, created_at, updated_at FROM reflections WHERE user_id = $1 AND reflection_date = $2',
    [userId, date]
  );
  return r.rows[0] ?? null;
}

// Upsert on (user_id, reflection_date) — one daily reflection per user.
// ON CONFLICT only works because of the UNIQUE (user_id, reflection_date)
// constraint added in migrations/006, making "one per day" a database
// guarantee rather than just application logic.
async function upsertReflection(userId, { date, wentWell, wasDifficult, toImprove }) {
  const r = await query(
    `INSERT INTO reflections (user_id, reflection_date, went_well, was_difficult, to_improve)
     VALUES ($1, $2, $3, $4, $5)
     ON CONFLICT (user_id, reflection_date) DO UPDATE SET
       went_well = EXCLUDED.went_well,
       was_difficult = EXCLUDED.was_difficult,
       to_improve = EXCLUDED.to_improve,
       updated_at = NOW()
     RETURNING *`,
    [userId, date, wentWell ?? null, wasDifficult ?? null, toImprove ?? null]
  );
  return r.rows[0];
}

module.exports = { getReflectionByDate, upsertReflection };
