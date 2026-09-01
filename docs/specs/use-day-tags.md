# use-day-tags

## Purpose

`useDayTags` is a React hook that manages a user's per-day "day tags" — free-form markers
like alcohol, workout, or a user-defined custom tag, one optional free-text note per
tag per day. It fetches tags for a set of dates, and exposes create/toggle/update/remove
operations against Supabase's `day_tags` table, keeping local component state in sync with
each write.

## Contract

**Input:** no hook arguments. Each exposed function takes its own arguments (a list of date
strings to fetch; a `date`/`tagType` pair to toggle, upsert, or remove; a row `id` and
`notes` to update).

**Output:** `{ tagsByDate, fetchTags, toggleTag, updateNote, upsertTag, removeTag }`.
`tagsByDate` is `Record<string, DayTag[]>`, starting `{}`, updated only as a side effect of
calling one of the five functions.

**Rule:** `fetchTags(dates)` replaces the entire `tagsByDate` state with exactly what
Supabase returns for those dates (or `{}` for an empty `dates` list) — it does not merge with
whatever was fetched before. `toggleTag` adds a tag if the date has no row with that `tag`
value yet, or removes the existing one if it does. `upsertTag` is `toggleTag`'s add path plus
an update path: it updates notes on an existing row instead of no-op'ing when one is found.
`removeTag` only removes. Every write function that doesn't find what it's looking for is a
silent no-op — no error is thrown or returned anywhere in this file.

## Cases

| id | given                                                                                                                                                                                                         | expected                                                                                                                                                      |
|----|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| C1 | `fetchTags([])`                                                                                                                                                                                               | `tagsByDate` set to `{}`; no Supabase call is made at all                                                                                                     |
| C2 | `fetchTags(['2026-08-31'])`, Supabase returns `{ data: [{id:'t1', date:'2026-08-31', tag:'alcohol', notes:null, user_id:'u1', created_at:'...'}], error: null }`                                              | `tagsByDate` set to `{'2026-08-31': [t1]}`                                                                                                                    |
| C3 | `fetchTags(['2026-08-31'])`, Supabase returns `{ data: null, error: {message:'boom'} }`                                                                                                                       | `tagsByDate` unchanged from whatever it was before the call — no exception, no error surfaced                                                                 |
| C4 | `fetchTags(['2026-08-31'])`, Supabase returns `{ data: null, error: null }`                                                                                                                                   | `tagsByDate` unchanged (same `error \|\| !data` branch as C3)                                                                                                 |
| C5 | `fetchTags(['2026-08-31','2026-09-01'])`, Supabase returns one row dated `2026-08-31` and none dated `2026-09-01`                                                                                             | `tagsByDate` set to `{'2026-08-31': [row]}` — `'2026-09-01'` gets no key at all, not an empty array                                                           |
| C6 | `toggleTag('2026-08-31','alcohol')`, `tagsRef.current['2026-08-31']` contains a row `{id:'t1', tag:'alcohol', ...}`                                                                                           | state optimistically drops `t1` from that date's array immediately; `supabase.from('day_tags').delete().eq('id','t1')` is called, its result never inspected  |
| C7 | `toggleTag('2026-08-31','workout')`, no row in `tagsRef.current['2026-08-31']` has `tag === 'workout'`, `supabase.auth.getUser()` resolves to `{ data: { user: null } }`                                      | function returns before any insert call; state unchanged                                                                                                      |
| C8 | `toggleTag('2026-08-31','workout')`, no matching row, `getUser()` resolves to `{id:'u1'}`, insert succeeds returning `{id:'t2', date:'2026-08-31', tag:'workout', ...}`                                       | `t2` appended to `tagsByDate['2026-08-31']` (array created via `prev[date] ?? []` if the key was absent)                                                      |
| C9 | same as C8 but the insert call returns `{ data: null, error: {...} }`                                                                                                                                         | `tagsByDate` unchanged — no optimistic add on this branch (unlike the delete branch, C6, which is optimistic)                                                 |
| C10 | `updateNote('t1', '')`                                                                                                                                                                                        | payload sent to Supabase is `{ notes: null }`, not `{ notes: '' }` (`'' \|\| null` coerces the empty string)                                                  |
| C11 | `updateNote('t1', 'felt bloated')`, update succeeds returning `{id:'t1', date:'2026-08-31', tag:'alcohol', notes:'felt bloated', ...}`, and `tagsByDate['2026-08-31']` already holds an entry with `id: 't1'` | that entry is replaced in place with the full returned row; other entries for the date are untouched                                                          |
| C12 | same update succeeds, but `tagsByDate['2026-08-31']` has no entry at all (the date was never fetched)                                                                                                         | `setTags`'s updater returns `prev` unchanged — the successful write is never reflected in state                                                               |
| C13 | `upsertTag('2026-08-31','note text')`, `tagsRef.current['2026-08-31']` already has a row with `tag === 'alcholo'` (`id:'t3'`)                                                                                 | delegates entirely to `updateNote('t3', 'note text')` — goes through C10's `notes \|\| null` coercion                                                         |
| C14 | `upsertTag('2026-08-31','')`, no existing row, `getUser()` resolves to `{id:'u1'}`, insert succeeds                                                                                                           | inserted payload is `{ user_id:'u1', date:'2026-08-31', tag:'alcohol', notes:'' }` — the empty string is sent as-is, **not** coerced to `null` (contrast C10) |
| C15 | `upsertTag('2026-08-31','x')`, no existing row, `getUser()` resolves to `{ data: { user: null } }`                                                                                                            | returns before any insert call; state unchanged                                                                                                               |
| C16 | `removeTag('2026-08-31','alcohol')`, no row in `tagsRef.current['2026-08-31']` has `tag === 'alcohol'`                                                                                                        | returns immediately; no state change, no Supabase call of any kind                                                                                            |
| C17 | `removeTag('2026-08-31','alcohol')`, a matching row `{id:'t1', ...}` exists                                                                                                                                   | state optimistically drops `t1`; `supabase.from('day_tags').delete().eq('id','t1')` is called, its result never inspected (same shape as C6's delete branch)  |

## Edge cases

- **`fetchTags([])` wipes existing state, it does not no-op.** Any tags previously loaded for
  other dates are replaced with `{}` (C1) — a caller that fetches a subset of dates after
  fetching a superset loses the rest, since every `fetchTags` call fully replaces
  `tagsByDate` rather than merging into it (C5).
- **Missing vs. empty date key.** A date present in the `dates` argument but with zero
  matching rows gets no key at all in the resulting map (C5), distinct from an explicit `[]`
  — most call sites read `tagsByDate[date] ?? []`, which treats the two the same, but
  `updateNote`'s state update (C12) does not use that fallback and so behaves differently for
  a missing key than for an empty array.
- **Ordering within a date's tag array is unspecified.** The Supabase query
  (`select('*').in('date', dates)`) has no `order by`, so the order tags appear in for a date
  with more than one row is whatever Postgres/PostgREST happens to return.
- **Delete failures are never checked, on either delete path.** `toggleTag`'s remove branch
  (C6) and `removeTag` (C17) both apply the state removal optimistically and then fire the
  `delete()` call without awaiting-and-checking its result — a failed delete leaves the UI
  showing the tag as gone while the database row still exists, with nothing to reconcile it.
- **`notes` coercion is inconsistent between the create and update paths.** `updateNote`
  coerces a falsy `notes` value to `null` before sending it (C10); `upsertTag`'s own insert
  branch (when no existing row is found) sends the raw `notes` value unchanged, including an
  empty string (C14). The same conceptual data (an empty note) is stored differently
  depending on which path created the row.
- **No user identity check on read, update, or delete.** `fetchTags` never names a user in
  its query; `updateNote` and the delete calls in `toggleTag`/`removeTag` filter only by row
  `id`. All three rely entirely on the caller only ever holding IDs for their own rows (via
  `tagsRef`, itself populated only by `fetchTags`/insert responses) plus whatever server-side
  scoping the database applies — nothing in this file enforces it. Only the two insert paths
  (`toggleTag`'s add branch, `upsertTag`'s add branch) explicitly pass a `user_id`, and only
  because they need one to build the row at all — not as an authorization check.
- **`tagsRef` vs. `tagsByDate`.** All lookups in `toggleTag`, `upsertTag`, and `removeTag`
  read `tagsRef.current`, not the `tagsByDate` state value, specifically so these callbacks
  don't need `tagsByDate` in their dependency array. The two stay in sync only because every
  mutation goes through `setTags`, which updates `tagsRef.current` synchronously inside the
  same `setState` updater.
- **No client-side validation of `tagType`** in any function — any string is accepted and
  compared/stored as-is; nothing checks it against a known set of tags.

## Hidden dependencies

- **Supabase client (`../../../../planner/src/lib/supabase`)** — every function performs
  direct I/O: `fetchTags` reads, `toggleTag`/`upsertTag`/`removeTag` write and delete,
  `updateNote` writes. Must become Domain ports per invariant 9 — a read port and a write
  port kept separate per invariant 10, since read and write operations here have materially
  different shapes (a read scoped by date list; writes keyed by row id or by
  `date`+`tag`).
- **`supabase.auth.getUser()`** — resolves the current authenticated user, called only from
  the insert branches of `toggleTag` and `upsertTag` (never from `fetchTags`, `updateNote`,
  or `removeTag`). This is a distinct hidden dependency from the Supabase data client itself
  and must become an explicit port parameter (the current user), since a Doctrine-backed
  implementation has no equivalent to Supabase Auth session lookup.
- **The file this hook was read from could not fully resolve two of its own imports**: the
  `DayTag` type (`'../../../../planner/src/types'`) and the `supabase` client module itself
  are both outside `docs/reference/` and were not read as part of this specification — the
  row shape used throughout the Cases table above (`id`, `user_id`, `date`, `tag`, `notes`,
  `created_at`) is inferred from how the code uses each field and from
  `docs/specs/use-day-tags-schema.md`'s `day_tags` table, not from the type definition
  itself.
- **React state (`useState`, `useRef`, `useCallback`)** — framework-local UI state and
  memoization. Not a Domain/Infrastructure concern; this is the Adapter-side mechanism by
  which results reach the UI, not a port.
- **Row creation timestamp (`created_at`)** is never set by this file — it comes from the
  database's own `default now()` (see schema spec), not from any clock read in this code.
  Invariant 22 requires an injected clock only for a *current time read in business logic*;
  nothing in this hook reads the current time at all, so there is no clock dependency to
  port from this file itself — only from whatever Application-layer code eventually issues
  the equivalent write and needs to set a timestamp explicitly.

## Discrepancies

- The comment on `tagsRef` says it exists "so `toggleTag` / `updateNote` always see the
  latest state without needing `tagsByDate` in their dependency arrays." In fact
  `updateNote` never reads `tagsRef` at all — it operates purely on the `id` it's given. The
  functions that actually read `tagsRef` are `toggleTag`, `upsertTag`, and `removeTag`; the
  comment names one of these three correctly and substitutes `updateNote` for the other two.
- `updateNote` and `upsertTag`'s own insert branch handle an empty-string `notes` value
  differently — the former stores `null`, the latter stores `''` — with nothing in the code
  or comments acknowledging the two paths diverge (C10, C14).
- No function in this file surfaces a fetch, insert, update, or delete failure to its caller
  in any form — not a thrown exception, not a returned error, not even a console log. Every
  failure branch is a silent no-op (C3, C4, C9, and both unchecked deletes), the same class
  of gap invariant 37 would flag if reproduced as-is in this codebase.

## Open questions

- Should a failed fetch (C3/C4), a failed write (C9), or a failed delete (C6/C17, result
  never even checked) surface as a Domain exception in the ported module, or is silently
  treating failure as "nothing happened" the behavior to reproduce? Invariant 39 puts this to
  a human rather than deciding it here, the same way it was put to a human for
  `useFodmapStreak`.
- Should `fetchTags`'s full-replace semantics (C1, C5) be reproduced as-is in a query use
  case, or does the query-per-request shape of a Symfony query handler make this concern moot
  (each call already returns exactly what was asked for, with no client-side cache to
  overwrite)? If some Adapter-side cache is introduced later, this is worth revisiting.
- Should the `notes` coercion inconsistency between `updateNote` and `upsertTag`'s insert
  branch (C10 vs. C14) be reproduced literally, or unified to one rule? The source gives no
  indication either was deliberate.
- The current-user dependency (`supabase.auth.getUser()`) presumes an `Auth` module that
  isn't on `main` yet (it lives on `feat/auth`, per `AGENTS.md`). Does a `DayTags` module's
  `/contract` step block on `Auth` landing, or does it declare its own placeholder user port
  in the meantime?
- Is the `tag` value meant to be validated against `user_tags` (see
  `docs/specs/use-day-tags-schema.md`) at the Domain level, given the database itself
  enforces no such reference? Nothing in this file's behavior settles it — it treats `tag` as
  an opaque string throughout.
