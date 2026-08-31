# Fodmap case coverage

Accounting for every case id in `docs/specs/use-fodmap-streak.md`, plus the todo-derived cases
from `docs/todo/`. "Covered" links to the test; "Not covered" states the reason.

## Pure helpers

| id | status |
|----|--------|
| C1 | **Not covered.** `pad(3)` has no PHP counterpart — `DateTimeImmutable::format('Y-m-d')` zero-pads natively. Not portable behavior. |
| C2 | **Not covered.** Same reason as C1. |
| C3 | **Not covered.** `toISO()` has no PHP counterpart, same reason as C1. |
| C4 | Covered — `tests/Fodmap/Domain/MealPlan/MealPlanDateTest::testResolve` (`'C4 ...'`). |
| C5 | Covered — `MealPlanDateTest::testResolve` (`'C5 ...'`). |
| C6 | Covered — `MealPlanDateTest::testResolve` (`'C6 ...'`). |
| C7 | Covered — `tests/Fodmap/Domain/MealPlan/RecentMondaysTest::testLastN` (`'C7 ...'`). |
| C8 | Covered — `RecentMondaysTest::testLastN` (`'C8 ...'`). |
| C9 | Covered — `RecentMondaysTest::testLastN` (`'C9 ...'`). |
| C10 | Covered — `tests/Fodmap/Domain/Tier/FodmapTierTest::testIsBad` (`'C10 ...'`). |
| C11 | Covered — `FodmapTierTest::testIsBad` (`'C11 ...'`). |
| C12 | Covered — `FodmapTierTest::testIsBad` (`'C12 ...'`). |
| C13 | **Not covered.** `isBad(null)` has no counterpart: `FodmapTier::isBad()` takes an already-resolved `FodmapTier`, never a nullable raw value. A missing/null tier is normalized to `FodmapTier::Unknown` before `isBad()` is ever called — that normalization is exactly what C15 asserts. |
| C14 | **Not covered.** Same reason as C13 (`isBad(undefined)`). |
| C15 | Covered — `FodmapTierTest::testIsBad` (`'C15 ...'`). |

## `fetchStreak()` / per-day decision

| id | status |
|----|--------|
| C16 | Covered — `tests/Fodmap/Domain/Streak/FodmapStreakCalculatorTest::testStreak` (`'C16 ...'`). |
| C17 | Covered — `FodmapStreakCalculatorTest::testStreak` (`'C17 ...'`). |
| C18 | Covered — `FodmapStreakCalculatorTest::testStreak` (`'C18 ...'`). |
| C19 | Covered — `FodmapStreakCalculatorTest::testStreak` (`'C19 ...'`). |
| C20 | Covered — `FodmapStreakCalculatorTest::testStreak` (`'C20 ...'`). |
| C21 | Covered — `FodmapStreakCalculatorTest::testStreak` (`'C21 ...'`). |
| C22 | **Not covered.** "A `meal_plans` row whose computed date is after today is excluded from `planTiersByDate` entirely" is Infrastructure map-construction behavior (deciding whether a date-key gets created at all before `FodmapStreakCalculator` ever sees the map). No Domain counterpart is contracted for it — it lives inside `DoctrinePlannedTierProvider::plannedTiersByDate()`, still a throwing stub, and rule 11 (`.claude/rules/tests.md`) restricts DB-touching tests to `tests/{Module}/Infrastructure/`, against a real Postgres, which needs a migration that doesn't exist yet. `FodmapStreakCalculator`'s declared shape stays unchanged. This case can only be tested once the provider is implemented and a migration exists. |
| C23 | Covered — `FodmapStreakCalculatorTest::testStreak` (`'C23 ...'`). |
| C24 | Covered — `FodmapStreakCalculatorTest::testStreak` (`'C24 ...'`). |
| C25 | **Partially covered.** The mechanism — the streak stops the instant a day is absent from both maps — is covered by `FodmapStreakCalculatorTest::testStreak` (`'C25 mechanism: ...'`). The ~112–118 day magnitude itself is an Infrastructure window-size detail (see `docs/todo/fodmap-streak-lookback-window.md`) with no Domain counterpart to assert a specific day count against. |
| C26 | **Not covered as originally stated.** The original discards the Supabase `error` field; this port deliberately does not reproduce that (invariant 37; see `docs/todo/fodmap-streak-fetch-error-handling.md`). Superseded by `T:fodmap-streak-fetch-error-handling` below. |
| C27 | **Partially covered.** The day-safety half — a date's tier list already containing `["low","moderate"]` is unsafe — is covered by `FodmapStreakCalculatorTest::testStreak` (`'C27 ...'`). The "two `meal_plans` rows land on the same date and get concatenated" half is Infrastructure map-construction behavior, same reason as C22: no Domain counterpart, needs a real Postgres integration test once `/build` implements the provider. |
| C28 | **Partially covered**, same split as C27: day-safety half covered by `FodmapStreakCalculatorTest::testStreak` (`'C28 ...'`); the "two `meal_logs` rows get concatenated" half is Infrastructure map-construction behavior, not covered here, same reason as C22. |

## Ingredient tier resolution (Step 2)

| id | status |
|----|--------|
| C29 | Covered — `tests/Fodmap/Domain/Tier/FodmapTierTest::testOrUnknown` (`'C29 a tier on record is returned unchanged'`). `orUnknown(Low) = Low`, matching the spec's expected `"low"`. |
| C30 | **Not covered — the spec's expected result is no longer producible by this port.** The spec (C30) expects `"moderate"`, resolved in the original via the `recipe_ingredients.fodmap_tier` column fallback. That column is dropped (migration 026); C30's only realizable input under the single-source shape is "no catalogue link" (`catalogueTier = null`), and `FodmapTier::orUnknown(null)` returns `Unknown`, never `Moderate` — there is nothing left in the schema to recover `"moderate"` from. This is a recorded, deliberate divergence, not an oversight: `docs/todo/fodmap-streak-ingredient-tier-precedence.md` ("Behavior comparison, case by case") documents it explicitly, including that it **crosses `isBad()`'s boundary** (`Moderate` = unsafe → `Unknown` = safe) — a real difference in the resulting streak count for a day whose only tier evidence takes this shape, not merely a relabeling. `FodmapTierTest::testOrUnknown`'s `null → Unknown` entry (labeled for C31) exercises the same input C30 now maps to, but its output does not match what C30's spec row expects, so it does not cover C30. |
| C31 | Covered — `FodmapTierTest::testOrUnknown` (`'C31 nothing on record resolves to unknown ...'`). `orUnknown(null) = Unknown`, matching the spec's expected `"unknown"`. |
| C32 | **Not covered — the case's premise is unrealizable, and its nearest analog doesn't match the spec's expected result either.** C32's premise (a linked catalogue row whose own `fodmap_tier` is `null`) cannot occur against the live schema: `docs/specs/use-fodmap-streak-schema.md` S11 records `ingredients.fodmap_tier` as `NOT NULL DEFAULT 'unknown'`. The nearest realizable analog — a linked row whose tier is the literal string `'unknown'` — gives `orUnknown(Unknown) = Unknown`, against the spec's expected `"low"` (again via the dropped column). Unlike C30, this one does **not** cross `isBad()`'s boundary (`isBad(Low) = isBad(Unknown) = false`), so it has no streak-count effect — but the resolved value still doesn't match what C32's spec row expects, so per the no-third-state rule it is Not covered, not Covered. See `docs/todo/fodmap-streak-ingredient-tier-precedence.md` for the full comparison. No additional test is needed to demonstrate this: the underlying "non-null input returned unchanged" branch is already exercised by the C29 entry. |

## Todo-derived cases

| id | status |
|----|--------|
| `T:fodmap-streak-fetch-error-handling` | Covered at two layers. Application: `tests/Fodmap/Application/Query/GetFodmapStreak/GetFodmapStreakHandlerTest::testFetchFailureFromPlannedProviderPropagatesUncaught` and `::testFetchFailureFromLoggedProviderPropagatesUncaught` assert `FodmapDataFetchException` propagates out of the handler uncaught. Adapter: `tests/Fodmap/Adapter/Http/Controllers/ApiGetFodmapStreakControllerTest::testFetchFailureMapsToA5xxResponseNotAZeroStreak` asserts the controller maps it to a 5xx JSON body. |
| `T:fodmap-streak-lookback-window` | **Not covered.** `docs/todo/fodmap-streak-lookback-window.md` asks for a test showing both providers' windows agree "for a given fixed clock," but the todo explicitly defers deciding the shared window definition's shape to `/build`. No shared window class or constant exists anywhere in `src/Fodmap/` to write an assertion against. |
| `T:fodmap-streak-user-scoping` | **Partially covered.** Application-layer passthrough — the handler must forward `$query->userId` to both providers unchanged — is covered by `GetFodmapStreakHandlerTest::testBothProvidersReceiveTheSameUserIdAndTheSameInstantFromASingleClockRead`. The Infrastructure-layer half `docs/todo/fodmap-streak-user-scoping.md` actually asks to settle it — a real Postgres query demonstrably scoped to the passed `$userId` — is not covered: same reason as C22, an `Infrastructure` integration test needs a test database and migration that don't exist yet (rule 11). |

## Additional coverage not tied to a spec Case id or todo

- **Single clock read, reused for the whole operation** (Hidden dependencies section of the spec, not a numbered case) — `GetFodmapStreakHandlerTest::testBothProvidersReceiveTheSameUserIdAndTheSameInstantFromASingleClockRead` asserts both providers receive the exact same `$today` instant from one `FakeClock`.
- **Happy-path controller → JSON mapping** (invariants 28, 30, not a numbered case) — `ApiGetFodmapStreakControllerTest::testReturnsTheStreakAsJson`.

## Status changes in this run

**Correction to the previous record.** The prior version of this file claimed C29, C30 and C32
were "behaviorally identical" and jointly covered by one `FodmapTierTest::testOrUnknown` entry
with input `FodmapTier::Low`. That claim was wrong: `FodmapTier::Low` is C29's realizable input,
not C30's (which is `null`) or C32's (whose premise isn't realizable at all). The entry never
exercised C30 or C32's actual inputs, so it never covered them — it only ever covered C29.

- **C29:** stays Covered. Test entry relabeled from the collapsed claim to name only C29.
- **C31:** stays Covered, unaffected.
- **C30: was marked Covered, now marked Not covered.** No test was removed — the coverage claim
  itself was incorrect and is corrected here. C30's spec-expected result (`"moderate"`) is not
  producible by `FodmapTier::orUnknown()` at all; see the Cases table above and
  `docs/todo/fodmap-streak-ingredient-tier-precedence.md` for why, and for the finding that this
  crosses `isBad()`'s boundary.
- **C32: was marked Covered, now marked Not covered**, same kind of correction, different reason:
  its premise is unrealizable against the live schema, and its nearest analog doesn't match the
  spec's expected `"low"` either (though this one has no `isBad()` boundary effect).

Everything else in this file — C1–C28, `T:fodmap-streak-fetch-error-handling`,
`T:fodmap-streak-lookback-window`, `T:fodmap-streak-user-scoping` — is unchanged from the previous
run.
