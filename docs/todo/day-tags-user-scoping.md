# day-tags-user-scoping

**Decided:** `DayTagProvider::tagsForDates()`, `DayTagProvider::findByUserDateTag()`, and every
`DayTagRepository` method (`create`, `updateNotes`, `delete`) all take a `string $userId` parameter
(plain scalar, not a Domain value object); every Command and the one Query in `Tag/Application/`
carry a `userId` property for the same reason.

**From:** `docs/specs/use-day-tags-schema.md`, Cases S8–S9, and `docs/specs/use-day-tags.md`'s
Hidden dependencies section: `day_tags` carries one row-level-security policy scoping every
`SELECT`/`INSERT`/`UPDATE`/`DELETE` to `auth.uid() = user_id`, invisibly — `useDayTags.ts` never
names a user on its read, update, or delete calls (only the two insert paths pass one, and only
because the insert needs a value to write).

**Why:** invariant 9 — an outbound dependency is a Domain port, and the port has to carry what the
real contract needs, not just what's visible at the call site. Doctrine has no RLS equivalent: a
`DoctrineDayTagRepository`/`DoctrineDayTagProvider` written against a userless signature would read
or mutate every user's rows on every call, silently, with no test catching it the same way
`docs/todo/fodmap-streak-user-scoping.md` already found for `Fodmap`. A plain `string` was chosen
over a dedicated `UserId` value object for the same reason recorded there: no `Auth` module exists
on `main` yet, and inventing one inside `Tag` would misattribute a concept this module doesn't own.

**What still has to be done:** `/build` has `DoctrineDayTagProvider`/`DoctrineDayTagRepository`
filter every query by `user_id = ?` using the passed-in `$userId`. The five controllers under
`src/Tag/Adapter/Http/Controllers/` each carry a `PLACEHOLDER_USER_ID` constant in place of a real
current-user resolution — the same real, unresolved gap `fodmap-streak-user-scoping.md` names for
`ApiGetFodmapStreakController`: nothing in this application yet resolves "the current authenticated
user," so none of these five controllers can construct a real Command/Query with a real `$userId`
until an authentication mechanism lands.

**What would settle it:** `DoctrineDayTagProvider` and `DoctrineDayTagRepository` demonstrably scope
every operation to the passed `$userId` (an `Infrastructure` integration test against a real test
Postgres, per `.claude/rules/tests.md` rule 11, showing one user's read/write never touches another
user's rows), and all five `Tag` controllers have a real source for `$userId` to build their
Command/Query with.
