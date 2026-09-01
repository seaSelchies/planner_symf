# use-day-tags-schema

## Purpose

The Postgres table behind `useDayTags.ts` (via Supabase): `day_tags`, one row per
user/date/tag marker with an optional free-text note. Two related tables, `user_tags` and
`tag_settings`, are not read or written by this hook directly but explain what `day_tags.tag`
values actually mean and where they come from — read here for context, not as part of this
hook's own Contract.

Read in full: `docs/reference/supabase/migrations/006_day_tags.sql`,
`015_user_tags.sql`, and `016_seed_builtin_tags.sql` — the three migrations, out of all 28
under `docs/reference/supabase/migrations/`, that touch `day_tags` or the tables its `tag`
column conceptually points to. `day_tags` itself is not the base `schema.sql` file; it does
not appear there at all — the table is created entirely by migration 006.

## Contract

**Table in scope, current effective shape** (after all 28 migrations — `day_tags`'s own DDL
is untouched since migration 006; only the *data* in its `tag` column changes shape, via
migration 016's backfill):

- `day_tags(id uuid PK default gen_random_uuid(), user_id uuid NOT NULL references
  auth.users(id) on delete cascade, date date NOT NULL, tag text NOT NULL, notes text NULL,
  created_at timestamptz default now())`
- `UNIQUE INDEX day_tags_user_date_tag ON day_tags(user_id, date, tag)`
- Row-level security enabled; one policy, `"users manage own tags"`, with no `FOR` clause
  (applies to `SELECT`/`INSERT`/`UPDATE`/`DELETE` alike), `USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id)`.

**Related tables** (not touched by this hook, but referenced below):

- `user_tags(id uuid PK, user_id uuid NOT NULL references auth.users(id), name text NOT
  NULL, emoji text NOT NULL default '🏷️', builtin_key text NULL, created_at timestamptz)` —
  added in migration 015.
- `tag_settings(id uuid PK, user_id uuid NOT NULL, tag_type text NOT NULL, enabled boolean
  default true, goal text default 'maintain', reminder_days int NULL, created_at
  timestamptz, UNIQUE(user_id, tag_type))` — added in migration 014.

**Rule:** every operation on `day_tags` is scoped by RLS to rows where `auth.uid() =
user_id`, both for reading and for writing — the single policy covers all four operations. At
most one row can exist per `(user_id, date, tag)` triple. `tag` is plain text with no foreign
key to `user_tags.id`, even though, as of migration 016, its intended values are precisely
`user_tags.id` values (see Discrepancies).

## Cases

| id | given | expected |
|----|-------|----------|
| S1 | `INSERT INTO day_tags (user_id, date, tag) VALUES (u, '2026-08-31', 'alcohol')` twice, same three values both times | second insert rejected: unique constraint violation on `day_tags_user_date_tag` |
| S2 | a row in `auth.users` referenced by one or more `day_tags` rows is deleted | those `day_tags` rows are deleted too (`ON DELETE CASCADE`) |
| S3 | `INSERT INTO day_tags (user_id, tag) VALUES (u, 'alcohol')` — `date` omitted | rejected: `date` is `NOT NULL` with no default |
| S4 | `INSERT INTO day_tags (user_id, date) VALUES (u, '2026-08-31')` — `tag` omitted | rejected: `tag` is `NOT NULL` with no default |
| S5 | `INSERT INTO day_tags (user_id, date, tag) VALUES (...)` — `notes` omitted | allowed; `notes` is `NULL` (nullable column, no default expression) |
| S6 | `INSERT INTO day_tags (user_id, date, tag) VALUES (...)` — `id` omitted | `id` defaults to `gen_random_uuid()` |
| S7 | `INSERT INTO day_tags (user_id, date, tag) VALUES (...)` — `created_at` omitted | `created_at` defaults to `now()` — server-side, not supplied by any client code |
| S8 | a `SELECT`/`UPDATE`/`DELETE` against `day_tags` by an authenticated user, with no `user_id` filter in the query | RLS restricts the result to rows where `auth.uid() = user_id`, for all three operation kinds under the one policy |
| S9 | an `INSERT` whose `user_id` value does not equal `auth.uid()` | rejected by the policy's `WITH CHECK (auth.uid() = user_id)` |
| S10 | `INSERT INTO day_tags (..., tag) VALUES (..., 'not-a-real-tag-id')` — a `tag` value matching no row in `user_tags.id` and no known built-in key | allowed — no foreign key or check constraint restricts `tag`'s value space at all |
| S11 | two rows, same `(user_id, date)`, different `tag` values | both allowed — the unique index scopes uniqueness to the full triple, not to `(user_id, date)` alone, so a day can carry any number of distinct tags |

## Edge cases

- **`tag`'s value space changed meaning without a schema change.** Migration 006 creates
  `tag` as free text with an inline comment naming three literal values
  (`'alcohol'`, `'workout'`). Migration 016's one-time backfill (a `DO $$ ... $$`
  block, not a repeatable migration path) rewrites every existing `day_tags.tag` value from
  those literal strings to a per-user `user_tags.id` UUID (cast to text), for four built-in
  tags (adding `'intimacy'`, not named in 006's comment). The column's type and constraints
  never change — only a one-time data rewrite changes what the values mean.
- **The backfill in 016 runs once, at migration time, for every `auth.users` row that
  existed then.** A user created after migration 016 ran gets no automatic `user_tags` seed
  rows from anything read here — nothing in these three files re-runs the seeding logic for
  a new signup. Where that seeding now happens (if anywhere) is outside the scope of what
  was read for this specification.
- **No cross-table consistency is enforced between `day_tags.tag`, `user_tags.id`, and
  `tag_settings.tag_type`.** All three are plain `text`/`uuid`-cast-to-`text` values compared
  by the application, never by a database constraint — `015_user_tags.sql`'s own trailing
  comment states this explicitly ("Custom tag IDs are stored as the tag_type value in
  tag_settings and as the tag value in day_tags... both are plain text columns, so no schema
  change needed there").
- **`day_tags` has no relationship, enforced or otherwise, to `meal_plans` or `meal_logs`**
  (the tables behind `useFodmapStreak`, per `docs/specs/use-fodmap-streak-schema.md`) — it is
  an entirely separate feature that happens to also key off `(user_id, date)`.

## Hidden dependencies

- **The authenticated user (`auth.uid()`), enforced by RLS on every operation.** Exactly the
  same shape of finding as `docs/specs/use-fodmap-streak-schema.md`'s primary finding: no
  query in `useDayTags.ts` filters by `user_id` on reads, updates, or deletes (only the two
  insert paths pass one, and only because the insert needs a value to write, not as an
  authorization mechanism) — Postgres RLS supplies the scoping invisibly. A Doctrine-backed
  port has no equivalent, so **every port method this module declares — read, insert,
  update, delete — must take the current user explicitly**, not only the ones whose Supabase
  call happens to already mention a `user_id`.
- **`gen_random_uuid()` and `now()` as column defaults** — row identity and creation
  timestamp are assigned by Postgres itself on insert, not by any application code in this
  hook. A Doctrine entity reproducing this table decides separately (per invariant 22, for
  the timestamp) whether to keep a database-generated default or assign both explicitly at
  the Application layer; the source data does not require either choice.

## Discrepancies

- **Migration 006's own comment contradicts its own constraint.** The comment above the
  `CREATE TABLE` reads "Allow multiple workout entries per day, but not duplicate same
  tag same day" — implying `'workout'` is allowed to repeat while other tags are
  not. The `UNIQUE INDEX day_tags_user_date_tag ON day_tags(user_id, date, tag)` that follows
  two lines later enforces the opposite for every tag value uniformly: **no** tag, including
  `'workout'`, can appear twice for the same user and date (S1). The exception the
  comment describes does not exist in the schema as written.
- **Migration 006's comment naming the tag value space (`'alcohol'`, `'workout'`,) is stale against the schema's own later evolution.** Migration 015/016 expand
  the built-in set to four (`'intimacy'` added) and then, via the 016 backfill, replace all
  of those literal strings with per-user UUIDs — so by the time a fresh database has run all
  28 migrations, no row in `day_tags.tag` is expected to hold any of the three literal
  strings the founding comment names.

## Open questions

- Should a fresh port of this module formalize `day_tags.tag → user_tags.id` as a real
  foreign key (fixing S10's gap), or reproduce the current unconstrained `text` column
  as-is? Invariant 39 puts this choice to a human rather than deciding it here — tightening
  it is a behavior change from what the source schema actually enforces, even if it looks
  like an obvious improvement.
- Is `useDayTags` portable as its own module without also specifying `user_tags` and
  `tag_settings`, given `tag`'s meaning is entirely defined by the former and the latter
  shares its `tag_type`/`tag` value space by convention? Both tables exist in the reference
  schema but neither has a behavior specification of its own yet.
- Where does new-user seeding of the four built-in tags happen going forward, now that
  migration 016's one-time backfill has already run? Nothing read for this specification
  answers this, and a port needs an answer before a new signup can use day tags the way the
  original app intends.
