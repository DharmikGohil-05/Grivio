-- Phase 10: one daily reflection per user (upsert support).
DO $$
BEGIN
  ALTER TABLE reflections DROP CONSTRAINT IF EXISTS reflections_user_date_unique;
  ALTER TABLE reflections ADD CONSTRAINT reflections_user_date_unique
    UNIQUE (user_id, reflection_date);
END $$;
