# fodmap-streak-fetch-error-handling

**Decided:** a fetch failure from either `PlannedTierProvider` or `LoggedTierProvider` throws
`FodmapDataFetchException` and aborts the whole `GetFodmapStreak` query — no partial streak is
computed from whichever source still succeeded.

**From:** `docs/specs/use-fodmap-streak.md`, Open question "Should a Supabase fetch error abort
the computation... instead of being treated as an empty result set?" (also Discrepancies, "Query
failures are never surfaced").

**Why:** the original discards every Supabase `error` field via `?? []`/`?? null`, making a failed
fetch indistinguishable from "no history" (C26). Invariant 37 forbids silencing a failure into a
`null`/empty return, so this port is deliberately **not equivalent** to the original at this point
— reproducing the discard would violate 37. Aborting the whole query (rather than degrading
per-source) was the human's choice over a partial-data alternative, made at `/contract`.

**What still has to be done:** `/build` implements `DoctrinePlannedTierProvider` and
`DoctrineLoggedTierProvider` (`src/Fodmap/Infrastructure/DB/`) so that a failed underlying query
throws `FodmapDataFetchException` (`src/Fodmap/Domain/FodmapDataFetchException.php`) rather than
returning an empty array; `ApiGetFodmapStreakController::__invoke()` catches it and maps it to a
5xx `JsonResponse` per invariant 29.

**What would settle it:** the throwing stubs in
`DoctrinePlannedTierProvider`/`DoctrineLoggedTierProvider` are replaced with real
implementations that throw on a DBAL error, and `/cover` has a test asserting
the controller returns a 5xx (not a `0` streak) when a provider throws.
