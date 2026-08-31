# use-fodmap-streak

## Purpose

`useFodmapStreak` is a React hook that computes how many consecutive days, ending today,
the user has stayed "FODMAP-safe". It reads two Supabase-backed sources per day — what
the user actually logged eating (`meal_logs` / `meal_log_ingredients`) and, failing that,
what was planned (`meal_plans` → `recipe_ingredients` / `ingredients`) — decides whether
each day is safe, and counts backward from today until it hits the first unsafe or
data-less day.

## Contract

**Input:** none (no arguments). All data comes from Supabase queries against
`meal_plans`, `recipe_ingredients` (joined to `ingredients`), and `meal_logs` (joined to
`meal_log_ingredients`), scoped to the last 16 weeks, plus the caller's system clock.

**Output:** the hook returns `{ streak: number, fetchStreak: () => Promise<void> }`.
`streak` starts at `0` and is only updated as a side effect of calling `fetchStreak()`.

**Rule:** a calendar day (local time) is FODMAP-safe if it has at least one ingredient
tier on record — from a logged meal if one has ingredients, otherwise from a planned
recipe — and none of those tiers is `'moderate'` or `'high'`. A day with no tiers on
record from either source is not safe. `streak` is the count of consecutive safe days
walking backward from today, stopping at the first day that is not safe.

## Cases

Pure helpers:

| id | given | expected |
|----|-------|----------|
| C1 | `pad(3)` | `"03"` |
| C2 | `pad(11)` | `"11"` |
| C3 | `toISO(new Date(2026, 0, 5))` | `"2026-01-05"` |
| C4 | `mealPlanDate("2026-08-24", 0)` (2026-08-24 is a Monday) | `"2026-08-24"` |
| C5 | `mealPlanDate("2026-08-24", 6)` | `"2026-08-30"` |
| C6 | `mealPlanDate("2026-08-24", 7)` — out-of-range `day_of_week`, no validation | `"2026-08-31"` (silently rolls into the next week) |
| C7 | `lastNMondays(1)` when system date is Monday 2026-08-24 | `["2026-08-24"]` |
| C8 | `lastNMondays(1)` when system date is Sunday 2026-08-30 | `["2026-08-24"]` |
| C9 | `lastNMondays(3)` when system date is 2026-08-24..30 | `["2026-08-24", "2026-08-17", "2026-08-10"]` (most recent first) |
| C10 | `isBad("moderate")` | `true` |
| C11 | `isBad("high")` | `true` |
| C12 | `isBad("low")` | `false` |
| C13 | `isBad(null)` | `false` |
| C14 | `isBad(undefined)` | `false` |
| C15 | `isBad("unknown")` | `false` |

`fetchStreak()` / per-day decision (given mocked Supabase responses, "today" = 2026-08-29):

| id | given | expected |
|----|-------|----------|
| C16 | today has a `meal_logs` row with `meal_log_ingredients` tiers `["low","low"]` | today counted safe |
| C17 | today has a `meal_logs` row with tiers `["low","high"]` | today counted unsafe |
| C18 | today has a `meal_logs` row with `meal_log_ingredients: []` and no `meal_plans` row for today | today counted unsafe ("no data") |
| C19 | today has a `meal_logs` row with `meal_log_ingredients: []`, and a `meal_plans` row whose recipe resolves to tiers `["low"]` | today counted safe (falls back to plan; empty log ignored) |
| C20 | today has a `meal_logs` row whose ingredients all have `fodmap_tier: null` | mapped to `["unknown","unknown"]`; today counted safe (`'unknown'` is not bad) |
| C21 | today has a `meal_plans` row for a `recipe_id` that returns zero rows from `recipe_ingredients` | `planTiersByDate` gets `[]` for today; today counted unsafe ("no data" despite a plan existing) |
| C22 | a `meal_plans` row whose computed date is after today | excluded from `planTiersByDate` entirely (`if (date > today) continue`) |
| C23 | today and yesterday safe (logged, `"low"`); day before yesterday has a `"moderate"` tier | `fetchStreak()` → `streak === 2` |
| C24 | today unsafe (no data at all) | `fetchStreak()` → `streak === 0` |
| C25 | every day for the full fetch window (16 weeks of `meal_plans`/`meal_logs`) and beyond is safe | `streak` stops growing at the window boundary (~112–118 days back) once no more fetched data exists — an undocumented implicit cap |
| C26 | Supabase `meal_plans` query returns `{ data: null, error: {...} }` | error is discarded (`plans ?? []`); treated identically to "no plans exist", no exception surfaces |
| C27 | two `meal_plans` rows land on the same date, recipes resolve to tiers `["low"]` and `["moderate"]` | that date's tiers = `["low","moderate"]` (concatenated); day counted unsafe |
| C28 | two `meal_logs` rows land on the same date | their tiers are concatenated; unsafe if either row contributes a `moderate`/`high` tier |

Ingredient tier resolution (Step 2, one `recipe_ingredients` row → one tier string, per
`ing.ingredients?.fodmap_tier ?? ing.fodmap_tier ?? 'unknown'`):

| id | given | expected |
|----|-------|----------|
| C29 | `{ recipe_id: "r1", fodmap_tier: "high", ingredients: { fodmap_tier: "low" } }` — joined tier and column tier both present and different | resolved tier `"low"` (joined `ingredients.fodmap_tier` wins over the `recipe_ingredients.fodmap_tier` column; a precedence reversal would resolve `"high"` instead and fail this case) |
| C30 | `{ recipe_id: "r1", fodmap_tier: "moderate", ingredients: null }` — no joined row | resolved tier `"moderate"` (falls back to the `recipe_ingredients.fodmap_tier` column) |
| C31 | `{ recipe_id: "r1", fodmap_tier: null, ingredients: null }` — neither source present | resolved tier `"unknown"` (last resort) |
| C32 | `{ recipe_id: "r1", fodmap_tier: "low", ingredients: { fodmap_tier: null } }` — joined row present but its `fodmap_tier` is `null` | resolved tier `"low"` (the `null` from the joined row is nullish-coalesced past, falling to the `recipe_ingredients.fodmap_tier` column — **not** straight to `"unknown"`) |

**C29–C32 describe the query as the code names it, not as the live schema can answer it —
see Discrepancies.** `docs/specs/use-fodmap-streak-schema.md` (Cases S17–S20) establishes
that `recipe_ingredients.fodmap_tier` no longer exists in the current schema; these four
cases are still correct statements of what the *code* does, and are exactly the four cases
a faithful port must decide how to treat given that the column they name is gone.

## Edge cases

- **Empty `meal_plans` result:** `plans` is `null`/`[]` → `recipeIds` is `[]` → the
  `recipe_ingredients` query is skipped entirely → `planTiersByDate` stays empty.
- **Empty `meal_logs` result:** `logs` is `null`/`[]` → `logTiersByDate` stays empty.
- **Today has neither a log nor a plan:** `isSafeDay` returns `false` on the very first
  check → `fetchStreak()` sets `streak = 0` without the loop body ever running (C24).
- **Logged meal with zero ingredients:** treated as if not logged at all (`continue`,
  no `logTiersByDate` entry) — falls through to plan data for that date (C18, C19).
- **All-null ingredient tiers:** mapped to `'unknown'`, which `isBad` does not flag —
  such a day is counted safe even though no tier is actually known (C20).
- **Planned recipe with no matching ingredient rows:** produces an explicit empty-array
  entry in `planTiersByDate`, which is treated as "no data" (unsafe), not "safe by
  default" (C21).
- **Joined `ingredients` row present but its `fodmap_tier` is `null`, while the
  `recipe_ingredients.fodmap_tier` column holds a real value:** the resolution does
  *not* jump straight to `'unknown'`. `ing.ingredients?.fodmap_tier` evaluates to
  `null`, which `??` treats as nullish just like `undefined`, so it falls through to
  `ing.fodmap_tier` and resolves to that real column value (C32). `'unknown'` is only
  reached when both the joined tier and the column tier are missing (C31).
- **Duplicate rows for the same date** (two plans, two logs) are merged by
  concatenation, not overwritten or deduplicated (C27, C28). The schema bounds this to
  at most 3 rows per date on each side — one per `meal_type` — per
  `docs/specs/use-fodmap-streak-schema.md` S8/S9, never an unbounded number.
- **Future-dated plan rows** (`date > today`) are explicitly skipped before entering
  `planTiersByDate` (C22).
- **`day_of_week` outside 0–6:** no validation in `mealPlanDate`; it just offsets by that
  many days from `week_start`, silently producing a date outside the intended week (C6).
  The schema *does* validate this at the database boundary — `meal_plans.day_of_week` has
  `CHECK (day_of_week BETWEEN 0 AND 6)` (schema spec S6) — so C6 can only ever be observed
  for a `day_of_week` value the code computed or received in memory, never for one read
  back from a real row in this schema.
- **Implicit lookback window:** `meal_plans` is filtered to the last 16 Mondays
  (`.in('week_start', weekStarts)`) and `meal_logs` to `[today - 112 days, today]`. Both
  windows are ~16 weeks but are computed differently (discrete Monday list vs.
  continuous range), and neither window size is documented or configurable. A streak
  cannot be observed to exceed roughly this window (C25).
- **Query errors are unobserved:** none of the three Supabase calls check the `error`
  field; every result is coalesced with `?? []`/`?? null`, so a failed fetch is
  indistinguishable from "no data" and silently reports a lower (or zero) streak (C26).
- **`meal_plans.is_leftover`** (added to the schema after this hook was last touched;
  `docs/specs/use-fodmap-streak-schema.md` S21) has no corresponding filter anywhere in
  Step 1 — a leftover-flagged plan slot is read and counted identically to any other slot.
- **Timezone/locale dependency:** `toISO`, `lastNMondays`, and the oldest-date
  calculation all use local `Date` accessors (`getFullYear`, `getMonth`, `getDate`,
  `getDay`, `setDate`), so "today" and "this week's Monday" are the browser's local
  calendar day, not UTC. The same underlying data can yield a different streak
  depending on the viewer's timezone, and behavior around a DST transition or exactly at
  local midnight is whatever `Date` arithmetic produces — not specifically handled.
- **Mid-run midnight crossing:** the `today` string used to bound the three queries is
  computed once at the top of `fetchStreak`; the loop in Step 7 starts a fresh
  `new Date()` for its cursor. If the async queries take long enough to cross local
  midnight, the two "today"s can disagree — the query bound stays on the earlier day
  while the count starts from the new day, which has no fetched data and is immediately
  "unsafe".
- **No upper bound / early-exit safeguard on the counting loop** beyond data
  availability — the `while` loop is unbounded in code and only terminates because the
  fetched data windows are finite (see "Implicit lookback window" above).

## Hidden dependencies

- **Supabase client (`../lib/supabase`)** — all three queries (`meal_plans`,
  `recipe_ingredients` joined to `ingredients`, `meal_logs` joined to
  `meal_log_ingredients`) are direct I/O. Must become a Domain port (or ports) —
  e.g. a read port for plan data and a read port for log data — per invariant 9.
- **The authenticated user, enforced by Postgres row-level security, not by anything in
  this file.** No query here names a user anywhere — no `.eq('user_id', ...)` on any of
  the three calls. `docs/specs/use-fodmap-streak-schema.md` establishes that every table
  read (`meal_plans`, `recipe_ingredients`, `meal_logs`, `meal_log_ingredients`) is
  restricted by RLS to `auth.uid()`, invisibly, and that `ingredients` — the one table
  that is not user-scoped — is the exception, not the rule. A Doctrine-backed port has no
  equivalent enforcement: **the current user must become an explicit port parameter**,
  or a provider written against this hook's literal code (no user anywhere) will return
  every user's data. This is a correction to the assumption recorded when this module's
  shape was first proposed at `/contract` — see that step's session for the "user scoping
  is out of scope" note, which this finding supersedes.
- **Current time (`new Date()`)**, used four separate times: computing `today`,
  computing `weekStarts` in `lastNMondays`, computing `oldestDate`, and initializing the
  loop `cursor` in Step 7. Per invariant 22, all of these must come from one injected
  clock — and, per the midnight-crossing edge case above, from a *single* clock read
  reused for the whole operation rather than read repeatedly.
- **React state (`useState`)** — framework-local UI state holding the last computed
  streak. Not a Domain/Infrastructure concern in the target architecture; it is the
  Adapter-side mechanism by which the result reaches the UI, not a port.

## Discrepancies

- The docblock says a safe day requires "None of those ingredients is `'moderate'` or
  `'high'`", implying the day's tiers are known. In practice, a tier that is missing or
  `null` becomes the literal string `'unknown'`, and `'unknown'` is *not* treated as bad
  — so a day whose ingredient tiers are entirely unrecorded is counted safe, not
  excluded as "no data" (C20). This contradicts the "no data → not a FODMAP day" comment
  at Step 6, which only applies when there are zero tiers, not when tiers are present
  but all `'unknown'`.
- The docblock's priority rule ("meal_log_ingredients... what was actually eaten, if
  logged") does not mention that a logged meal with an empty ingredients list is treated
  as *not* logged and silently falls back to plan data (C18, C19) — a meaningful
  behavior not stated in the contract as written.
- Nothing in the docblock or code comments discloses the ~16-week lookback window that
  bounds both queries, even though it caps the maximum reportable streak and silently
  changes behavior for a user with a longer real streak (C25).
- Query failures are never surfaced (no `error` check on any of the three Supabase
  calls) — a network or permissions failure produces the same result as "no history",
  silently underreporting the streak instead of signaling a fetch error (C26).
- **The code's query column references do not match the current schema.** As of
  migration 026 (`docs/specs/use-fodmap-streak-schema.md`, Discrepancies and S17–S20),
  `recipe_ingredients.fodmap_tier`, `recipe_ingredients.ingredient_name`,
  `meal_log_ingredients.fodmap_tier`, and `meal_log_ingredients.ingredient_name` have all
  been dropped from the schema. Step 2's `.select('recipe_id, fodmap_tier,
  ingredients(fodmap_tier)')` and Step 4's `.select('id, date,
  meal_log_ingredients(fodmap_tier)')` each name at least one column that no longer
  exists. Combined with the unchecked `error` field (previous point), this file's C29–C32
  behavior may not be reachable at all against the live database today — see the schema
  spec for exactly what would need confirming to know for certain. This specification
  still records C29–C32 as what the *code* does, per this skill's rule that a branch's
  behavior is recorded even where it may no longer be exercisable; whether a port should
  target this literal (possibly inert) behavior or the schema's actual current shape
  (`ingredient_id` → `ingredients.fodmap_tier` on both `recipe_ingredients` and
  `meal_log_ingredients`) is recorded under Open questions, not decided here.

## Open questions

- Should a logged meal with zero ingredients count as "no data for today" (current
  behavior: falls back silently to the plan) or should it actively invalidate the day
  regardless of any plan? The code picks the former with no stated rationale.
- Should ingredient tiers that are `null`/missing (`'unknown'`) make a day ineligible
  for the streak (treated as unresolved), or is treating `'unknown'` as safe the
  intended, accepted risk? The source does not say.
- Is the ~16-week lookback window a deliberate performance/cost bound, or an
  accidental cap nobody meant to place on the maximum streak? If a module reproduces
  this, should the window become a documented, configurable value?
- Should a Supabase fetch error abort the computation (surface an error to the caller)
  instead of being treated as an empty result set? The current code cannot distinguish
  "no history" from "fetch failed," and it is unclear whether that was intentional.
- What is the intended behavior for a `meal_plans.day_of_week` value outside `0`–6`?
  The code has no guard and silently computes a date outside the plan's week; the schema
  spec (S6) confirms the database itself rejects such a row at write time via a `CHECK`
  constraint, so this branch is reachable only through in-memory values the code
  constructs itself, never through a row actually read back from this schema.
- **Should the ported module target the literal current queries (Step 2/Step 4's named
  columns, several of which are now dropped) or the columns the schema shows are
  actually live (`ingredient_id` → `ingredients.fodmap_tier`)?** This is the single
  highest-stakes open question this specification and its schema companion raise
  together. Reproducing the literal code risks porting behavior that is already inert in
  production; silently "fixing" it to use the live columns is exactly the kind of
  undirected improvement invariant 39 puts to a human rather than to this document.
- **Do the ports this module already declared (`PlannedTierProvider`,
  `LoggedTierProvider`) need a user-identifying parameter added to their signature?**
  The schema shows every table they read is RLS-scoped to the caller; nothing in a
  Doctrine-backed implementation provides that automatically. This changes a shape
  `/contract` already agreed with a human and needs to go back to that step, not be
  decided here.
- Should `meal_plans.is_leftover` slots be excluded from the plan-tier fetch? The schema
  shows the column exists and postdates this hook; the code has no opinion about it one
  way or the other, and neither does anything else read for this specification.
