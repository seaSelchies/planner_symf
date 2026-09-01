# Tag case coverage

Accounting for every case id in `docs/specs/use-day-tags.md`, plus the todo-derived cases from
`docs/todo/`. "Covered" links to the test; "Not covered" states the reason.

**One thing still bounds what this run could cover, named once here rather than repeated on every
row:**

- **`docs/specs/use-day-tags.md`'s C13–C15 rows are internally inconsistent with `upsertTag`'s
  real 3-argument signature** on disk right now — C13/C14 call `upsertTag` with two arguments,
  C13 names a tag `'alcholo'` that appears nowhere else in the spec, and C14's expected payload
  hardcodes `tag:'alcohol'` despite no tag argument being passed. This looks like corruption
  (flagged already during this session's `/spec` and `/entity` runs, still present on disk this
  run), not deliberate content, and this step does not guess what the original values were.

The other bound from the previous run — `DayTag` having no constructor, so no test could produce
an instance representing "a row that exists" — is **resolved**: `/entity` added a constructor
(`src/Tag/Domain/DayTag.php`) since the last pass. Every case that was blocked only by that is
covered below; see "Status changes in this run" for the full list.

## Cases

| id | status |
|----|--------|
| C1 | Covered — `tests/Tag/Application/Query/GetDayTags/GetDayTagsHandlerTest::testC1EmptyDatesReturnsEmptyListAndUserIdIsPassedThrough`. |
| C2 | Covered — `GetDayTagsHandlerTest::testC2DataReturnedByTheProviderIsIncludedInTheResponse`. |
| C3 | **Not covered as originally stated.** The source silently ignores a Supabase error; `/contract` diverged (`docs/todo/day-tags-write-failure-signalling.md`) — the port throws `DayTagDataFetchException` instead. Superseded by `T:day-tags-write-failure-signalling`. |
| C4 | **Not covered as originally stated.** Same reason as C3. |
| C5 | **Not covered — no counterpart.** `GetDayTagsResponse` holds a flat `DayTag[]`, not a `Record<string, DayTag[]>` keyed by date — the "missing key vs. empty array" distinction C5 describes doesn't exist in this shape at all, because grouping-by-date was left to whatever consumes this API. Raised with `/contract` in the second `/contract` pass; the human chose to leave the shape as-is, so this stays permanently uncovered rather than pending a decision. |
| C6 | Covered — `tests/Tag/Application/Command/ToggleDayTag/ToggleDayTagHandlerTest::testC6MatchingRowDeletesItAndNeverCreates`. |
| C7 | **Not covered — no counterpart.** "No authenticated user" is not a branch inside this contract: `userId` is a required, always-present parameter on `ToggleDayTagCommand` by the time it reaches the handler. The equivalent concern — nothing yet resolves the real current user before constructing the command — is the controller-level gap `docs/todo/day-tags-user-scoping.md` already names (the `PLACEHOLDER_USER_ID` constant). |
| C8 | Covered — `ToggleDayTagHandlerTest::testC8NoMatchingRowCreatesOneWithNoNotes`. |
| C9 | **Not covered as originally stated.** Superseded by the failure-signalling divergence — `repository->create()` now throws `DayTagAlreadyExistsException` instead of silently leaving state unchanged. Covered instead by `T:day-tags-write-failure-signalling` (`ToggleDayTagHandlerTest::testC9CreateFailurePropagatesUncaught`). |
| C10 | **Not covered as originally stated.** `/contract`'s "normalize" decision means `''` is stored as `''`, not coerced to `null` — the opposite of what C10 expects. The actual (intentional) behavior is covered by `tests/Tag/Application/Command/UpdateDayTagNote/UpdateDayTagNoteHandlerTest::testNotesAreStoredExactlyAsGivenIncludingEmptyString`. |
| C11 | **Not covered — no counterpart.** Purely client-side: replacing one entry of a JS array in React state, in place. `UpdateDayTagNoteCommand`'s handler returns `void` (invariant 24) — there is no server-side aggregate for "other entries" to stay untouched in. |
| C12 | **Not covered — no counterpart.** Same reason as C11 — describes what a client-side cache does when it has no entry for a date; this module has no client-side cache. |
| C13 | **Not covered — spec corruption.** See the note above. The general behavior C13 was illustrating (an existing row → delegate to updating its notes) no longer needs a `DayTag` constructor to test — it now has a dedicated test, `tests/Tag/Application/Command/UpsertDayTag/UpsertDayTagHandlerTest::testExistingRowDelegatesToUpdatingItsNotesAndNeverCreates` — but it is derived from the Contract section's "Rule" paragraph, not from C13's corrupted literal values, so it does not close C13 itself. See "Additional coverage" below. |
| C14 | **Not covered — spec corruption.** See the note above. The behavior it illustrates (no existing row → create, notes stored as given) **is** covered, but by a fresh test derived from the Contract section's intact "Rule" paragraph, not from this row's corrupted literal values — see "Additional coverage" below. |
| C15 | **Not covered — no counterpart, and spec corruption.** Same "no authenticated user" gap as C7, compounded by the note above (the row's `tag` argument is also missing). |
| C16 | **Not covered as originally stated.** Superseded by the failure-signalling divergence — no match now throws `DayTagNotFoundException` instead of silently no-op'ing. Covered instead by `T:day-tags-write-failure-signalling` (`RemoveDayTagHandlerTest::testC16NoMatchingRowThrowsNotFoundAndNeverDeletes`). |
| C17 | Covered — `tests/Tag/Application/Command/RemoveDayTag/RemoveDayTagHandlerTest::testC17MatchingRowDeletesIt`. |

## Todo-derived cases

| id | status |
|----|--------|
| `T:day-tags-user-scoping` | **Partially covered.** Application-layer passthrough — every handler must forward `$command->userId`/`$query->userId` to the ports unchanged — is covered in all five handler tests (e.g. `GetDayTagsHandlerTest::testC1EmptyDatesReturnsEmptyListAndUserIdIsPassedThrough`, `ToggleDayTagHandlerTest::testC8NoMatchingRowCreatesOneWithNoNotes`, `UpsertDayTagHandlerTest::testNoExistingRowCreatesOneWithNotesStoredExactlyAsGiven`, `UpdateDayTagNoteHandlerTest::testNotesAreStoredExactlyAsGivenIncludingEmptyString`, `RemoveDayTagHandlerTest::testC16NoMatchingRowThrowsNotFoundAndNeverDeletes`). The Infrastructure-layer half the todo actually asks to settle — a real Postgres query demonstrably scoped to the passed `$userId` — is not covered: same reason as Fodmap's `T:fodmap-streak-user-scoping`, an `Infrastructure` integration test needs a test database and a migration that don't exist yet (rule 11). |
| `T:day-tags-write-failure-signalling` | **Covered at the Application and Adapter layers, not at Infrastructure.** Application: every handler has a test asserting the relevant exception (`DayTagDataFetchException`, `DayTagAlreadyExistsException`, `DayTagNotFoundException`) propagates uncaught — see each handler test file. Adapter: every controller test asserts the exception-to-status-code mapping the `/contract` proposal declared (503 / 409 / 404). The Infrastructure-layer half — translating a real unique-constraint violation or a zero-row `UPDATE`/`DELETE` into the right exception — is not covered: needs a real test Postgres and a migration, neither of which exist yet. |

## Additional coverage not tied to a spec Case id or todo

- **`UpsertDayTagHandler`'s existing-row branch**, derived from the Contract section's "Rule"
  paragraph (`upsertTag` is `toggleTag`'s add path plus an update path) rather than from C13's
  corrupted literal values — `UpsertDayTagHandlerTest::testExistingRowDelegatesToUpdatingItsNotesAndNeverCreates`.
- **`UpsertDayTagHandler`'s create branch**, same derivation, not C14's corrupted literal values —
  `UpsertDayTagHandlerTest::testNoExistingRowCreatesOneWithNotesStoredExactlyAsGiven`. This also
  demonstrates the notes-normalize decision on the create path (an empty string is stored as `''`,
  matching `UpdateDayTagNoteHandlerTest`'s coverage of the same decision on the update path).
- **`UpdateDayTagNoteHandler` storing `null` notes** — `UpdateDayTagNoteHandlerTest::testNotesNullIsStoredAsNull`
  — not itself a spec case, but the natural complement to the empty-string case above.
- **Happy-path controller → JSON/empty-body mapping** (invariants 28, 30, not a numbered case) —
  one test per controller (e.g. `ApiToggleDayTagControllerTest::testSuccessReturnsAnEmptyBodied200`),
  including a populated-list rendering for the query controller,
  `ApiGetDayTagsControllerTest::testReturnsAPopulatedListAsJson`.

## Status changes in this run

`/entity` added a constructor to `DayTag` since the last pass, and a second `/contract` pass
settled C5 (left as-is, permanently). Both are reflected above; changes in both directions:

- **C2: was Not covered (blocked), now Covered.** New test:
  `GetDayTagsHandlerTest::testC2DataReturnedByTheProviderIsIncludedInTheResponse`.
- **C6: was Not covered (blocked), now Covered.** New test:
  `ToggleDayTagHandlerTest::testC6MatchingRowDeletesItAndNeverCreates`.
- **C17: was Not covered (blocked), now Covered.** New test:
  `RemoveDayTagHandlerTest::testC17MatchingRowDeletesIt`.
- **C13: stays Not covered**, but for a narrower reason — no longer also blocked by the missing
  constructor, only by the spec corruption. Its underlying behavior now has a real test (see
  "Additional coverage"), which was not possible last run.
- **C5: was "Not covered — no counterpart, finding for `/contract`"; now "Not covered — no
  counterpart, decided."** The open finding was taken to a second `/contract` pass; the human chose
  to leave `GetDayTagsResponse` as a flat list, so this is now a settled permanent gap, not a
  pending question.
- No case that was Covered lost its coverage.
