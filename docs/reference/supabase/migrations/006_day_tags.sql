CREATE TABLE day_tags (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date date NOT NULL,
  tag text NOT NULL,          -- 'alcohol', 'workout'
  notes text,                  -- optional free-text note
  created_at timestamptz DEFAULT now()
);
-- Allow multiple workout entries per day, but not duplicate same tag same day
CREATE UNIQUE INDEX day_tags_user_date_tag ON day_tags(user_id, date, tag);
ALTER TABLE day_tags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users manage own tags" ON day_tags USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
