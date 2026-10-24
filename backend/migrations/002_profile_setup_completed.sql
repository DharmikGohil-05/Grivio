-- Adds setup completion tracking to profiles (Phase 4).
-- A user's profile row is created at registration with setup_completed=false;
-- the first-time setup flow flips it to true.
ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS setup_completed BOOLEAN NOT NULL DEFAULT FALSE;
