-- 016_seed_builtin_tags.sql
-- Moves the 4 built-in tags out of the app's hardcoded config and into the
-- user_tags table (one row per user). Updates tag_settings and day_tags to
-- use the new UUIDs instead of the old string keys ('alcohol', etc.).

-- Add builtin_key column if running 015 already happened without it
ALTER TABLE public.user_tags
  ADD COLUMN IF NOT EXISTS builtin_key text DEFAULT NULL;

DO $$
DECLARE
  u         RECORD;
  b         RECORD;
  tag_uuid  UUID;
BEGIN
  FOR b IN SELECT * FROM (VALUES
    ('alcohol',  'Alcohol',  '🍷',  'decrease'),
    ('workout',  'Workout',  '🏋️', 'increase')  ,
    ('intimacy', 'Intimacy', '❤️',  'maintain')
  ) AS t(old_key, tag_name, emoji, default_goal) LOOP

    FOR u IN SELECT id FROM auth.users LOOP

      -- Find existing user_tags row (idempotent re-run support)
      SELECT id INTO tag_uuid
        FROM public.user_tags
       WHERE user_id = u.id AND builtin_key = b.old_key
       LIMIT 1;

      IF tag_uuid IS NULL THEN
        INSERT INTO public.user_tags (user_id, name, emoji, builtin_key)
        VALUES (u.id, b.tag_name, b.emoji, b.old_key)
        RETURNING id INTO tag_uuid;
      END IF;

      -- Migrate existing tag_settings row (old string key → new UUID)
      UPDATE public.tag_settings
         SET tag_type = tag_uuid::text
       WHERE user_id = u.id AND tag_type = b.old_key;

      -- Insert default settings row if none existed
      INSERT INTO public.tag_settings (user_id, tag_type, enabled, goal, reminder_days)
      VALUES (u.id, tag_uuid::text, true, b.default_goal, NULL)
      ON CONFLICT (user_id, tag_type) DO NOTHING;

      -- Migrate day_tags rows (old string key → new UUID)
      UPDATE public.day_tags
         SET tag = tag_uuid::text
       WHERE user_id = u.id AND tag = b.old_key;

    END LOOP;
  END LOOP;
END $$;
