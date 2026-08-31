-- ============================================================
-- Migration 007: Shopping checks
-- Tracks which ingredients the user already has for a given date.
-- ============================================================

CREATE TABLE IF NOT EXISTS public.shopping_checks (
  id              uuid primary key default uuid_generate_v4(),
  user_id         uuid not null references auth.users(id) on delete cascade,
  for_date        date not null,
  ingredient_name text not null,
  checked         boolean not null default true,
  created_at      timestamptz not null default now(),
  UNIQUE (user_id, for_date, ingredient_name)
);

ALTER TABLE public.shopping_checks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage their own shopping checks"
  ON public.shopping_checks FOR ALL
  USING  (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
