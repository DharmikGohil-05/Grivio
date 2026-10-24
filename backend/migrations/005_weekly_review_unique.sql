-- Phase 10: enforce one review per user per week and track updates.
-- Existing schema already had biggest_win/needs_attention/next_week_focus/
-- summary columns, so only the uniqueness + updated_at are added.
ALTER TABLE weekly_reviews
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

DO $$
BEGIN
  ALTER TABLE weekly_reviews DROP CONSTRAINT IF EXISTS weekly_reviews_user_week_unique;
  ALTER TABLE weekly_reviews ADD CONSTRAINT weekly_reviews_user_week_unique
    UNIQUE (user_id, week_start);
END $$;
