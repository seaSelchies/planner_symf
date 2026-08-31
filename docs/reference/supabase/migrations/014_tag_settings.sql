-- 014_tag_settings.sql
-- Per-user configurable goals and display preferences for each day tag.

CREATE TABLE IF NOT EXISTS public.tag_settings (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tag_type      text        NOT NULL,
  enabled       boolean     NOT NULL DEFAULT true,
  -- 'increase' | 'decrease' | 'maintain'
  goal          text        NOT NULL DEFAULT 'maintain',
  -- For 'maintain' goal: surface a nudge after N days without logging the tag.
  -- Notification wiring is a future task; this just persists the preference.
  reminder_days integer     NULL,
  created_at    timestamptz DEFAULT now(),
  CONSTRAINT tag_settings_user_tag_unique UNIQUE (user_id, tag_type)
);

ALTER TABLE public.tag_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own tag settings"
  ON public.tag_settings FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
