-- ============================================================
-- FODMAP Meal Planner — Supabase Schema
-- Run this in your Supabase project: SQL Editor → New query → Run
-- ============================================================

-- Enable UUID extension (already enabled on Supabase by default, but safe to re-run)
create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- profiles
-- Extends auth.users with display name and preferences.
-- A row is created automatically via trigger on sign-up.
-- ------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at   timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "Users can view their own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update their own profile"
  on public.profiles for update
  using (auth.uid() = id);

create policy "Users can insert their own profile"
  on public.profiles for insert
  with check (auth.uid() = id);

-- Auto-create a profile row when a new user signs up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, new.raw_user_meta_data ->> 'display_name');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ------------------------------------------------------------
-- recipes
-- ------------------------------------------------------------
create table if not exists public.recipes (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  name        text not null,
  description text,
  servings    int not null default 2,
  created_at  timestamptz not null default now()
);

alter table public.recipes enable row level security;

create policy "Users can view their own recipes"
  on public.recipes for select
  using (auth.uid() = user_id);

create policy "Users can insert their own recipes"
  on public.recipes for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own recipes"
  on public.recipes for update
  using (auth.uid() = user_id);

create policy "Users can delete their own recipes"
  on public.recipes for delete
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- recipe_ingredients
-- ------------------------------------------------------------
create table if not exists public.recipe_ingredients (
  id              uuid primary key default uuid_generate_v4(),
  recipe_id       uuid not null references public.recipes(id) on delete cascade,
  ingredient_name text not null,
  amount          numeric,
  unit            text,
  fodmap_tier     text check (fodmap_tier in ('low', 'moderate', 'high', 'unknown'))
                       not null default 'unknown'
);

alter table public.recipe_ingredients enable row level security;

-- Access via recipe ownership
create policy "Users can view ingredients for their recipes"
  on public.recipe_ingredients for select
  using (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.user_id = auth.uid()
    )
  );

create policy "Users can insert ingredients for their recipes"
  on public.recipe_ingredients for insert
  with check (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.user_id = auth.uid()
    )
  );

create policy "Users can update ingredients for their recipes"
  on public.recipe_ingredients for update
  using (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.user_id = auth.uid()
    )
  );

create policy "Users can delete ingredients for their recipes"
  on public.recipe_ingredients for delete
  using (
    exists (
      select 1 from public.recipes r
      where r.id = recipe_id and r.user_id = auth.uid()
    )
  );

-- ------------------------------------------------------------
-- meal_plans
-- day_of_week: 0 = Monday … 6 = Sunday
-- meal_type: 'breakfast' | 'lunch' | 'dinner'
-- ------------------------------------------------------------
create table if not exists public.meal_plans (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  week_start   date not null,
  day_of_week  int  not null check (day_of_week between 0 and 6),
  meal_type    text not null check (meal_type in ('breakfast', 'lunch', 'dinner')),
  recipe_id    uuid references public.recipes(id) on delete set null,
  created_at   timestamptz not null default now(),
  unique (user_id, week_start, day_of_week, meal_type)
);

alter table public.meal_plans enable row level security;

create policy "Users can view their own meal plans"
  on public.meal_plans for select
  using (auth.uid() = user_id);

create policy "Users can insert their own meal plans"
  on public.meal_plans for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own meal plans"
  on public.meal_plans for update
  using (auth.uid() = user_id);

create policy "Users can delete their own meal plans"
  on public.meal_plans for delete
  using (auth.uid() = user_id);

-- ------------------------------------------------------------
-- weight_logs (optional — for future iterations)
-- ------------------------------------------------------------
create table if not exists public.weight_logs (
  id        uuid primary key default uuid_generate_v4(),
  user_id   uuid not null references auth.users(id) on delete cascade,
  weight_kg numeric not null,
  logged_at timestamptz not null default now()
);

alter table public.weight_logs enable row level security;

create policy "Users can view their own weight logs"
  on public.weight_logs for select
  using (auth.uid() = user_id);

create policy "Users can insert their own weight logs"
  on public.weight_logs for insert
  with check (auth.uid() = user_id);

create policy "Users can delete their own weight logs"
  on public.weight_logs for delete
  using (auth.uid() = user_id);
