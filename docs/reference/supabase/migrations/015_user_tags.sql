-- 015_user_tags.sql
-- User-defined custom tags (emoji + name) that appear alongside built-in tags.

CREATE TABLE IF NOT EXISTS public.user_tags (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text        NOT NULL,
  emoji       text        NOT NULL DEFAULT '🏷️',
  builtin_key text        DEFAULT NULL, -- 'alcohol' | 'workout' | 'intimacy' for seeded tags
  created_at  timestamptz DEFAULT now()
);

ALTER TABLE public.user_tags ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own custom tags"
  ON public.user_tags FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Custom tag IDs are stored as the tag_type value in tag_settings and as the tag
-- value in day_tags (both are plain text columns, so no schema change needed there).
