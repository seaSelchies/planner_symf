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
| C22 | **Not covered.** "A `meal_plans` row whose computed date is after today is excluded from `planTiersByDate` entirely" is Infrastructure map-construction behavior (deciding whether a date-key gets created at all before `FodmapStreakCalculator` ever sees the map). No Domain counterpart is contracted for it — it lives inside `DoctrinePlannedTierProvider::plannedTiersByDate()`, still a throwing stub, and rule 11 (`.claude/rules/tests.md`) restricts DB-touching tests to `tests/{Module}/Infrastructure/`, against a real Postgres, which needs a migration that doesn't exist yet. Finding for `/contract`/`/build`: this case can only be tested once the provider is implemented and a migration exists. |
| C23 | Covered — `FodmapStreakCalculatorTest::testStreak` (`'C23 ...'`). |
| C24 | Covered — `FodmapStreakCalculatorTest::testStreak` (`'C24 ...'`). |
| C25 | **Partially covered.** The mechanism — the streak stops the instant a day is absent from both maps — is covered by `FodmapStreakCalculatorTest::testStreak` (`'C25 mechanism: ...'`). The ~112–118 day magnitude itself is an Infrastructure window-size detail (see `docs/todo/fodmap-streak-lookback-window.md`) with no Domain counterpart to assert a specific day count against. |
| C26 | **Not covered as originally stated.** The original discards the Supabase `error` field; this port deliberately does not reproduce that (invariant 37; see `docs/todo/fodmap-streak-fetch-error-handling.md`). Superseded by `T:fodmap-streak-fetch-error-handling` below. |
| C27 | **Partially covered.** The day-safety half — a date's tier list already containing `["low","moderate"]` is unsafe — is covered by `FodmapStreakCalculatorTest::testStreak` (`'C27 ...'`). The "two `meal_plans` rows land on the same date and get concatenated" half is Infrastructure map-construction behavior, same reason as C22: no Domain counterpart, needs a real Postgres integration test once `/build` implements the provider. |
| C28 | **Partially covered**, same split as C27: day-safety half covered by `FodmapStreakCalculatorTest::testStreak` (`'C28 ...'`); the "two `meal_logs` rows get concatenated" half is Infrastructure map-construction behavior, not covered here, same reason as C22. |

## Ingredient tier resolution (Step 2)

| id | status |
|----|--------|
| C29 | **Not covered.** `ing.ingredients?.fodmap_tier ?? ing.fodmap_tier ?? 'unknown'` precedence has no Domain counterpart — `/contract` did not declare a class for this resolution; it is implicitly left inside `DoctrinePlannedTierProvider`/`DoctrineLoggedTierProvider`, both throwing stubs, and needs a real Postgres integration test once implemented (rule 11). **Finding for `/contract`:** this precedence rule is real, spec-mandated business logic (C29–C32 all target it directly) but currently has no unit-testable home; consider whether it deserves its own Domain class the way `MealPlanDate`/`RecentMondays` do, so it can be tested without a database. |
| C30 | **Not covered.** Same reason as C29. |
| C31 | **Not covered.** Same reason as C29. |
| C32 | **Not covered.** Same reason as C29. |

## Todo-derived cases

| id | status |
|----|--------|
| `T:fodmap-streak-fetch-error-handling` | Covered at two layers. Application: `tests/Fodmap/Application/Query/GetFodmapStreak/GetFodmapStreakHandlerTest::testFetchFailureFromPlannedProviderPropagatesUncaught` and `::testFetchFailureFromLoggedProviderPropagatesUncaught` assert `FodmapDataFetchException` propagates out of the handler uncaught. Adapter: `tests/Fodmap/Adapter/Http/Controllers/ApiGetFodmapStreakControllerTest::testFetchFailureMapsToA5xxResponseNotAZeroStreak` asserts the controller maps it to a 5xx JSON body, exactly what `docs/todo/fodmap-streak-fetch-error-handling.md`'s "What would settle it" asks for. |
| `T:fodmap-streak-lookback-window` | **Not covered.** `docs/todo/fodmap-streak-lookback-window.md` asks for a test showing both providers' windows agree "for a given fixed clock," but the todo explicitly defers deciding the shared window definition's shape to `/build` ("not decided by this todo"). No shared window class or constant exists anywhere in `src/Fodmap/` to write an assertion against. Finding for `/contract`: this case has no contract to test until that shared definition is declared. |

## Additional coverage not tied to a spec Case id or todo

- **Single clock read, reused for the whole operation** (Hidden dependencies section of the spec, not a numbered case) — `GetFodmapStreakHandlerTest::testBothProvidersReceiveTheSameInstantFromASingleClockRead` asserts both providers receive the exact same `$today` instant from one `FakeClock`.
- **Happy-path controller → JSON mapping** (invariants 28, 30, not a numbered case) — `ApiGetFodmapStreakControllerTest::testReturnsTheStreakAsJson`.
