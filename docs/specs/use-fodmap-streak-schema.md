# use-fodmap-streak-schema

## Purpose

The Postgres schema behind `useFodmapStreak.ts` (via Supabase): the tables that hold a user's
recipes, their per-ingredient FODMAP tiers, the user's weekly meal plan, and the user's meal log —
plus a separately-added shared ingredient catalogue. Every table the hook queries is scoped
per-user by Postgres row-level security (RLS), invisibly to the client code; one table, the shared
catalogue, deliberately is not.

Read in full: `docs/reference/supabase/schema.sql` and all 28 files under
`docs/reference/supabase/migrations/`, applied in order. The *effective* shape of a table is the
base definition plus every migration that touched it since — several tables described here look
nothing like their `schema.sql` definition by the last migration.

## Contract

**Tables in scope, current effective shape** (after all 28 migrations):

- `recipes(id, user_id, name, description, servings, created_at)`
- `recipe_ingredients(id, recipe_id, amount, unit, ingredient_id)` — **not** what the hook expects;
  see Discrepancies.
- `meal_plans(id, user_id, week_start, day_of_week, meal_type, recipe_id, created_at, is_leftover,
  leftover_source_id)`
- `meal_logs(id, user_id, date, meal_type, notes, created_at)`
- `meal_log_ingredients(id, meal_log_id, ingredient_id)` — **not** what the hook expects; see
  Discrepancies.
- `ingredients(id, name_en, name_ru, fodmap_tier, notes_en, notes_ru, created_at)` — a shared,
  non-user-scoped catalogue; supersedes `fodmap_ingredients`, dropped in migration 027.

**Rule:** every table above except `ingredients` is restricted by RLS to rows where the
authenticated caller (`auth.uid()`) is the owner, directly or via a join to an owning row.
`ingredients` has no ownership column and no RLS scoping on `SELECT` — every authenticated user
reads every row.

## Cases

| id | given | expected |
|----|-------|----------|
| S1 | `recipe_ingredients.recipe_id` references `recipes(id)`, and the referenced recipe is deleted | the `recipe_ingredients` row is deleted too (`ON DELETE CASCADE`) |
| S2 | `meal_log_ingredients.meal_log_id` references `meal_logs(id)`, and the referenced log is deleted | the `meal_log_ingredients` row is deleted too (`ON DELETE CASCADE`) |
| S3 | `meal_plans.recipe_id` references `recipes(id)`, and the referenced recipe is deleted | `meal_plans.recipe_id` becomes `NULL` on that row (`ON DELETE SET NULL`); the plan slot itself survives |
| S4 | `recipe_ingredients.ingredient_id` references `ingredients(id)`, and the referenced ingredient is deleted | `recipe_ingredients.ingredient_id` becomes `NULL` (`ON DELETE SET NULL`) |
| S5 | `meal_log_ingredients.ingredient_id` references `ingredients(id)`, and the referenced ingredient is deleted | `meal_log_ingredients.ingredient_id` becomes `NULL` (`ON DELETE SET NULL`) |
| S6 | `INSERT INTO meal_plans (..., day_of_week) VALUES (..., 7)` | rejected: `CHECK (day_of_week BETWEEN 0 AND 6)` — a `day_of_week` of 7 can never exist as a stored row, though `mealPlanDate()` in the hook computes a date for it anyway if a caller passed 7 in memory (behaviour-spec C6) |
| S7 | `INSERT INTO meal_plans (..., meal_type) VALUES (..., 'brunch')` | rejected: `CHECK (meal_type IN ('breakfast','lunch','dinner'))` |
| S8 | two `meal_plans` rows for the same `(user_id, week_start, day_of_week)` with different `meal_type` | both allowed — `UNIQUE (user_id, week_start, day_of_week, meal_type)` scopes uniqueness to the triple *plus* meal type, so up to 3 rows (breakfast/lunch/dinner) can share one calendar date, never more; this is the concrete bound behind behaviour-spec C27 |
| S9 | two `meal_logs` rows for the same `(user_id, date)` with different `meal_type` | both allowed — `UNIQUE (user_id, date, meal_type)`, same 3-row cap; the bound behind behaviour-spec C28 |
| S10 | a second `meal_plans` row inserted with the same `(user_id, week_start, day_of_week, meal_type)` as an existing one | rejected: unique constraint violation |
| S11 | `ingredients.fodmap_tier` omitted on insert | defaults to `'unknown'`, `NOT NULL` — every row always has one of exactly `low`/`moderate`/`high`/`unknown`, matching `FodmapTier`'s four cases with no fifth possibility |
| S12 | a `SELECT` against `meal_plans` by an authenticated user with no `WHERE user_id = ...` clause | Postgres RLS silently restricts the result to rows where `auth.uid() = user_id` — the hook's query carries no user filter anywhere and relies entirely on this |
| S13 | a `SELECT` against `recipe_ingredients` with no explicit filter | RLS restricts to rows whose `recipe_id` resolves (via a subquery to `recipes`) to a recipe owned by `auth.uid()` — ownership is one join away, not a column on the table itself |
| S14 | a `SELECT` against `meal_logs` with no explicit filter | RLS restricts to `auth.uid() = user_id` |
| S15 | a `SELECT` against `meal_log_ingredients` with no explicit filter | RLS restricts via a subquery to the owning `meal_logs` row's `user_id` |
| S16 | a `SELECT` against `ingredients` by any authenticated user, regardless of who created any referencing recipe/log | **not** restricted — `USING (true)` on the `SELECT` policy returns every row to every authenticated caller |
| S17 | a query selects `recipe_ingredients.fodmap_tier` | **the column does not exist** — dropped in migration 026; see Discrepancies |
| S18 | a query selects `recipe_ingredients.ingredient_name` | **the column does not exist** — dropped in migration 026 |
| S19 | a query selects `meal_log_ingredients.fodmap_tier` | **the column does not exist** — dropped in migration 026; see Discrepancies |
| S20 | a query selects `meal_log_ingredients.ingredient_name` | **the column does not exist** — dropped in migration 026 |
| S21 | a `meal_plans` row has `is_leftover = true` | no schema-level distinction excludes it from an ordinary `SELECT` — a plain query returns leftover and non-leftover slots identically |

## Edge cases

- **`recipes.servings`, `description`** and other columns not read by the hook exist but are out of
  scope for the streak calculation; not exercised by any Case above.
- **`auth.users` deletion**: every user-owned table cascades on `ON DELETE CASCADE` from
  `auth.users(id)` — deleting an account deletes all of that user's recipes, plans, logs, and log
  ingredients. Not reachable from the hook's read-only queries, but relevant if a future port ever
  models account deletion.
- **`meal_plans` ↔ `meal_logs` has no foreign key.** They correlate only by the application computing
  the same `(user_id, date, meal_type)` triple on both sides — `meal_plans.week_start + day_of_week`
  versus `meal_logs.date` directly. Migration 017's cleanup script treats this correlation as
  load-bearing (it deletes logs whose computed plan-date no longer has a matching plan), but the
  database itself enforces nothing between the two tables.
- **`fodmap_ingredients.tier`** (the table's predecessor, dropped in migration 027) had a narrower
  check than every table that replaced or referenced it: `CHECK (tier IN ('low','moderate','high'))`
  — no `'unknown'` allowed at the source. `'unknown'` only ever entered the system as a fallback
  value in application code or in `ingredients`/`recipe_ingredients`/`meal_log_ingredients`'s own
  (wider) check constraints, never as something the catalogue itself asserted about an ingredient.

## Hidden dependencies

- **The authenticated user (`auth.uid()`), enforced by RLS on every table except `ingredients`.**
  This is the single most consequential hidden dependency in the whole port. `useFodmapStreak.ts`
  never mentions a user anywhere — no `.eq('user_id', ...)` on any of its three queries — because
  Postgres RLS injects that filter invisibly on every `SELECT`. **This must become an explicit
  parameter on both Domain ports** (`PlannedTierProvider::plannedTiersByDate()` and
  `LoggedTierProvider::loggedTiersByDate()`), since Doctrine/DBAL has no RLS equivalent — a query
  without an explicit `WHERE user_id = ?` returns *every* user's data, not just the caller's. As
  currently declared (see `src/Fodmap/Domain/MealPlan/PlannedTierProvider.php` and
  `src/Fodmap/Domain/MealLog/LoggedTierProvider.php`), **neither port takes a user identifier at
  all** — this is a real gap in the already-declared shape, not a hypothetical one; see
  Discrepancies and Open questions.
- **The `ingredients` catalogue is the one table genuinely not user-scoped** — its `SELECT` RLS
  policy is `USING (true)` for any authenticated caller. A future `IngredientTierPrecedence`-adjacent
  port reading this table correctly takes no user parameter for that specific read, in contrast to
  every other port in this module.

## Discrepancies

- **The hook's literal column references do not exist in the current schema.** As of migration 026:
  - `recipe_ingredients.fodmap_tier` — the column `ing.fodmap_tier` falls back to in Step 2
    (`ing.ingredients?.fodmap_tier ?? ing.fodmap_tier ?? 'unknown'`) — is dropped.
  - `recipe_ingredients.ingredient_name` is dropped.
  - `meal_log_ingredients.fodmap_tier` — the column Step 5 reads directly
    (`i.fodmap_tier ?? 'unknown'`) — is dropped.
  - `meal_log_ingredients.ingredient_name` is dropped.

  Both remaining live columns the hook could still reach are `recipe_ingredients.ingredient_id` and
  `meal_log_ingredients.ingredient_id` (both added in migration 021), each pointing at the new
  `ingredients` catalogue. The hook was never updated after migrations 021/026 to use them — it
  still queries `.select('recipe_id, fodmap_tier, ingredients(fodmap_tier)')` and
  `.select('id, date, meal_log_ingredients(fodmap_tier)')`, both of which name at least one column
  that no longer exists.

  **I could not execute these queries against a live Supabase instance, so I cannot confirm exactly
  how PostgREST responds to a `SELECT` naming a dropped column** — whether it rejects the whole
  request with an error, or silently omits the missing field. But given `docs/specs/use-fodmap-streak.md`
  C26's finding that every one of the hook's three queries discards its `error` field
  unconditionally (`?? []` / `?? null`), *either* outcome is silently absorbed the same way: a
  rejected request looks exactly like "no data," and the resulting `recipeTiersMap` stays empty for
  every recipe, every time. If PostgREST rejects the whole request, the practical consequence is
  that the plan-fallback path of the streak calculation (C19, C21 in the behaviour spec) cannot
  currently produce a non-empty tier list from `recipe_ingredients` at all, in production, against
  this schema — not a hypothetical edge case but the schema's present state.

- **`meal_log_ingredients` never had the same catalogue-precedence structure the plan side has.**
  Even before migration 026 dropped the columns, the hook's Step 5 read
  `meal_log_ingredients.fodmap_tier` directly with no join to any catalogue — there was never an
  `ing.ingredients?.fodmap_tier ?? ...` equivalent on the log side, only on the plan side (Step 2).
  Migration 021 added `meal_log_ingredients.ingredient_id` alongside
  `recipe_ingredients.ingredient_id`, giving both tables the same shape — but the hook's log-reading
  code was never extended to follow it. The retired `IngredientTierPrecedence` was
  correctly scoped to the plan side only, based on the *hook's* text; this
  schema shows that decision also matches the *table* shape at the time the hook was written, even
  though both tables now carry the same `ingredient_id` FK.

- **`meal_plans.is_leftover` (migration 013) postdates the hook's Step 1 query, which has no
  `is_leftover` filter.** A leftover-flagged plan slot is included in `planTiersByDate` exactly like
  any other slot. The migration's own comment ("Leftover slots are excluded from the shopping list
  ingredient fetch") states a guarantee for a *different* feature; nothing excludes them here.
  Whether that's an intentional inclusion or a gap nobody revisited when leftovers were added is not
  determinable from the code or schema alone.

## Open questions

- **Does a `SELECT` naming a dropped column error the whole request, or silently return partial
  data?** This determines whether the plan-fallback path is completely inert in production today or
  only degraded. Settling it needs either a live query against the current Supabase schema or
  someone who has observed the app's actual behavior recently.
- **Should the port read `ingredient_id → ingredients(fodmap_tier)` instead of the dropped columns
  the hook names?** If a human wants the port to reproduce *working* behavior rather than the
  literal (now partially non-functional) source text, invariant 39 puts that choice to a human: the
  `ingredient_id` FK exists on both `recipe_ingredients` and `meal_log_ingredients` and could feed
  `IngredientTierPrecedence` symmetrically on both sides, which is a materially different port shape
  than the one already declared (plan-side only, via `recipe_ingredients.fodmap_tier`/
  `ingredients.fodmap_tier`).
- **Do `PlannedTierProvider`/`LoggedTierProvider` need a user parameter added to their already-declared
  signatures?** Every table they read is RLS-scoped to `auth.uid()` with no equivalent enforcement
  mechanism in this project's Doctrine-based stack. This is a signature change to an existing
  `/contract` decision, not something this document can make on its own.
- **Should `is_leftover` slots be excluded from the plan-tier fetch?** The schema shows the flag
  exists and is unfiltered by the hook; whether that's deliberate is undetermined from the sources
  read here.
