-- Allows 'cancelled' as a valid task status (Phase 6).
-- The Phase 2 constraint only allowed pending/in_progress/completed.
DO $$
BEGIN
  ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_status_check;
  ALTER TABLE tasks ADD CONSTRAINT tasks_status_check
    CHECK (status IN ('pending', 'in_progress', 'completed', 'cancelled'));
END $$;
