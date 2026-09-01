# day-tags-write-failure-signalling

**Decided:** `Tag` module's ports throw a Domain exception on every failure the source silently
absorbs, instead of reproducing the silent no-op: `DayTagProvider` throws `DayTagDataFetchException`
on a failed read; `DayTagRepository::create()` throws `DayTagAlreadyExistsException` on a duplicate
`(userId, date, tag)`; `DayTagRepository::updateNotes()` and `::delete()` throw
`DayTagNotFoundException` when the target row doesn't exist or doesn't belong to the caller.

**From:** `docs/specs/use-day-tags.md`'s Discrepancies section — every one of `useDayTags.ts`'s five
functions treats a Supabase failure as a silent no-op: `fetchTags` discards `error`/missing `data`
(C3, C4), `toggleTag`'s and `removeTag`'s delete calls never inspect their result (C6, C17),
`toggleTag`'s and `upsertTag`'s insert calls leave state untouched on `error` with no signal beyond
that (C9), and `updateNote` does nothing further when `error` is set. Not one of the five throws,
returns an error value, or logs anything.

**Why:** invariant 37 forbids exactly this pattern — silencing a failure instead of surfacing it as
a thrown Domain exception. Invariant 39 requires this divergence to be recorded rather than either
reproduced silently or fixed without saying so: reproducing the source's silence would violate 37 in
a fresh module; porting it unchanged was rejected at `/contract` in favor of the same choice already
made for `Fodmap`'s read side (`FodmapDataFetchException`, `docs/specs/use-fodmap-streak.md` C26),
extended here to the write side as well, since `Tag` is this project's first module with any write
path at all.

**What still has to be done:** `/build`'s Doctrine implementations of `DayTagProvider` and
`DayTagRepository` translate the underlying failure into the right exception — a fetch/connection
failure into `DayTagDataFetchException`, a unique-constraint violation on `day_tags_user_date_tag`
into `DayTagAlreadyExistsException`, and a zero-row `UPDATE`/`DELETE` into `DayTagNotFoundException`
— and each of the five `Tag` controllers catches the exceptions its use case can throw and maps them
to an HTTP response (`DayTagDataFetchException` → 503, `DayTagAlreadyExistsException` → 409,
`DayTagNotFoundException` → 404), matching `ApiGetFodmapStreakController`'s existing
`FodmapDataFetchException` → 503 mapping.

**What would settle it:** an `Infrastructure` integration test per operation demonstrating the
translation (duplicate insert raises `DayTagAlreadyExistsException`, update/delete of a missing or
foreign row raises `DayTagNotFoundException`), and each controller's exception-to-status mapping
covered by an `Adapter` test.
