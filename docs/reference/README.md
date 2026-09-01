# Reference sources

Verbatim snapshots of code being ported into this project. They are here so the
specification and the tests can cite a file that lives in this repository, and so a
reader can check the port against its original without cloning anything.

Nothing here is compiled, executed, or shipped.

## useFodmapStreak.ts

React Native hook from the `planner` app (Expo + Supabase), the source of the
FODMAP streak calculation being ported.

- Source: `src/hooks/useFodmapStreak.ts`
- Commit: `b929a2f` (2026-06-25)
- Copied verbatim on 2026-08-29

## useDayTags.ts

React Native hook from the same app, the source of the day-tags module: reading
tags for a set of dates, creating, toggling, removing, and editing a note.

- Source: `src/hooks/useDayTags.ts`
- Commit: `b929a2f` (2026-06-25)
- Copied verbatim on 2026-08-31

## supabase/

The planner app's database definition, copied whole: `schema.sql` and every file in
`migrations/`. The effective shape of a table is the base definition plus the alterations
that follow it, so the chain is here in full rather than a chosen subset.

- Source: `supabase/`
- Commit: `b929a2f` (2026-06-25)
- Copied verbatim on 2026-08-30
