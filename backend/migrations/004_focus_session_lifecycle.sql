-- Adds session lifecycle fields to focus_sessions (Phase 8).
-- Phase 2 created the table for later use with started_at/ended_at/
-- duration_seconds/rating/reflection but no status and no pause tracking.
-- These columns keep a single session accurate across pause/resume and
-- app restarts without inventing new fields.
ALTER TABLE focus_sessions
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'completed';

ALTER TABLE focus_sessions
  ADD COLUMN IF NOT EXISTS paused_at TIMESTAMPTZ;

ALTER TABLE focus_sessions
  ADD COLUMN IF NOT EXISTS total_pause_seconds INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
  ALTER TABLE focus_sessions DROP CONSTRAINT IF EXISTS focus_sessions_status_check;
  ALTER TABLE focus_sessions ADD CONSTRAINT focus_sessions_status_check
    CHECK (status IN ('active', 'completed', 'cancelled'));
END $$;
