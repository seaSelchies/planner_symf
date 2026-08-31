-- ============================================================
-- Migration 008: Meal logs (actual food eaten)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.meal_logs (
  id         uuid primary key default uuid_generate_v4(),
  user_id    uuid not null references auth.users(id) on delete cascade,
  date       date not null,
  meal_type  text not null check (meal_type in ('breakfast','lunch','dinner')),
  notes      text,
  created_at timestamptz not null default now(),
  UNIQUE (user_id, date, meal_type)
);

ALTER TABLE public.meal_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own meal logs"
  ON public.meal_logs FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Ingredients attached to a meal log
CREATE TABLE IF NOT EXISTS public.meal_log_ingredients (
  id              uuid primary key default uuid_generate_v4(),
  meal_log_id     uuid not null references public.meal_logs(id) on delete cascade,
  ingredient_name text not null,
  fodmap_tier     text check (fodmap_tier in ('low','moderate','high','unknown'))
                       not null default 'unknown'
);

ALTER TABLE public.meal_log_ingredients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage their own meal log ingredients"
  ON public.meal_log_ingredients FOR ALL
  USING (
    exists (
      select 1 from public.meal_logs ml
      where ml.id = meal_log_id and ml.user_id = auth.uid()
    )
  )
  WITH CHECK (
    exists (
      select 1 from public.meal_logs ml
      where ml.id = meal_log_id and ml.user_id = auth.uid()
    )
  );
