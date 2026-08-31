---
name: cover
description: Turn a behaviour specification's cases and the declarations /contract produced into failing PHPUnit tests under tests/<Module>/ — red on assertions and on the throwing stubs, never on autoload. Use after /contract and before /build. The guard denies writes outside tests/; implementing behaviour is forbidden by rule, not by the guard.
argument-hint: [path to the spec in docs/specs/, plus the module name whose declarations it was turned into]
disallowed-tools: Edit MultiEdit NotebookEdit
hooks:
  PreToolUse:
    - matcher: Write
      hooks:
        - type: command
          command: "$CLAUDE_PROJECT_DIR/.claude/skills/cover/write-guard.sh"
---

# Cover

The pipeline is `/spec` → `/entity` → `/contract` → `/cover` → `/build`, and `/entity` is
conditional: it runs only where `/spec` produced a schema specification, that is, only where the
source reaches a database. A module that reaches none goes `/spec` → `/contract` → this step, and
nothing about this step changes either way.

`/spec` established **what** a module does and wrote a case table. `/entity`, where it ran, wrote the
Doctrine entities that carry the module's mapping metadata. `/contract` turned the shape that table
describes into declarations whose every method body throws. This step turns those cases into
**PHPUnit tests that fail** — on assertions and on the stubs, never on autoload.

It is the last step before behaviour exists, and the only guarantee that `/build` is finished by
something other than its own opinion. A case with no test is a case `/build` is free to ignore.

## This skill decides nothing

`/contract` is the step with a human in it. This one reads two settled documents — the
specification and the declarations — and mechanically produces tests from them.

If something cannot be expressed against the contracts as they stand, **say so in the report and
stop there.** Do not choose an interpretation, do not adjust the contract to fit, and **do not
write a `docs/todo/` entry** — recording a decision belongs to the step that takes decisions, and a
todo written here would be minutes of a conversation that never happened with a human.

## This skill never implements behaviour

`Edit`, `MultiEdit` and `NotebookEdit` are removed from the tool pool by the front matter, so no
existing file can be modified through them. `Write` stays for test files only.

**The only paths this skill may write are files under `tests/`.** A `PreToolUse` hook enforces it
and denies everything else:

- `src/` is denied outright. This step never touches the module it tests. A stub "helpfully"
  implemented here destroys the only evidence that the tests bite — a green suite over a module
  nobody built.
- `docs/` is denied, `docs/todo/` included: `/spec` owns the specification, `/contract` owns the
  todo trail.
- `config/` and `migrations/` belong to a human.

Inside `tests/`, a file that already exists **may** be overwritten. A step that can only ever add is
a step with one pass, and the ban cost more than it saved: three times the pipeline could not revise
its own output and a human had to delete files so it could regenerate them. What protects the lane
is the lane check; what protects the accounting is step 3 below.

If a write is denied, that is the rule working, not an obstacle to route around. Not with `Bash`,
not by asking for the hook to be lifted. The guards match the editing tools; a shell
command is not something a `PreToolUse` hook can inspect for the files it changes, so what holds
here is the rule, not the hook.

## Procedure

0. **Declare which step is running, before anything else.** The guards that keep each step in its
   lane are `PreToolUse` hooks, and a hook stays registered for the rest of the session once its
   skill has been invoked — so in a session where another step has already run, that step's guard
   is still live and still denying every path that is not its own. The marker at `.claude/.step`
   holds one line, the name of the step currently running; each guard enforces when the marker
   names it and stands aside silently when it names another. Declare this step with an ordinary
   `Write` to `.claude/.step`, whose whole content is the one line:

   ```
   cover
   ```

   Every registered guard allows this Write, because the name is a step that exists — that is
   what lets a second step declare itself in a session where an earlier one already ran. This
   step's own guard does one more thing as it allows it: it records in `.claude/.step.live`
   that it is live in this session. That record is what the other guards read before standing
   aside, so a marker written any other way stands nothing down.

   **This is not a formality and it is not optional.** Do it as the very first action, before
   reading anything and long before any `Write`. A missing or empty marker fails closed: every
   guard denies, and this skill cannot write a single file.

1. **Read the specification, the contracts, and every file under `docs/todo/`.** All three, in
   full, before writing a line of test code.

   - the **specification** is the source of cases;
   - the **contracts** — every file under `src/<Module>/` — are the vocabulary the tests must
     speak: the port signatures, the DTO fields, the exception names, the enum cases;
   - the **`docs/todo/` files** carry behaviour that is deliberately *not* in the spec, because it
     was decided at `/contract`, after the spec was written. A todo that names a test under
     "What would settle it" is stating a case this step owes.

2. **Translate each case into the contracts' vocabulary rather than the original's.** The spec
   describes the source system's result shapes — Supabase rows, nullable join columns, JavaScript
   coalescing. The ports do not. A case survives as **the behaviour it asserts**, expressed through
   the signatures that now exist: a case about a `meal_logs` row with tiers `["low","high"]` becomes
   an entry in the `array<string, FodmapTier[]>` a `LoggedTierProvider` returns.

   Where a case's inputs no longer map onto anything the contracts expose, that is **a finding for
   the report**, not a case to quietly drop.

3. **Account for every case id.** This is the step's contract with the one before it: every id in
   the spec's tables is either **covered by a named test** or **explicitly not covered with a
   stated reason**. There is no third state.

   The accounting is written **in the files, not only in chat** — a class-level docblock in the
   test that covers the ids, and, where a spec's ids span several test classes, one
   `tests/<Module>/CASE-COVERAGE.md` listing every id with either the test that covers it or the
   reason it has none.

   `docs/specs/use-fodmap-streak.md` has the live example of the second kind: **C1–C3 cover
   `pad()` and `toISO()`, which have no counterpart in PHP** — `DateTimeImmutable::format()` does
   that natively, so there is no unit of ours to test. They are not portable behaviour, and that
   sentence belongs in the coverage record verbatim.

   A silently missing case is the failure mode this whole step exists to prevent.

   **When `tests/<Module>/CASE-COVERAGE.md` already exists, read it before writing it.** This step
   may overwrite an existing file in its own lane, so a second pass over a module rewrites the
   coverage record rather than being refused — and a rewrite that quietly drops a case is exactly
   the regression the old refusal was guarding against. So: read the existing record first, then
   **report every case id whose status changed in this run, in both directions** — each id that was
   not covered and now is, and each id that **was covered and is not any more**, naming the test that
   used to cover it and why it no longer does. A case that lost its coverage is named out loud or
   the accounting is worthless. Where nothing changed, say that too.

4. **Add the cases the spec could not contain.** Each `docs/todo/` file states what would settle
   it, and where that includes a test, this step writes it. Those cases get **ids of their own,
   traced to the todo filename** rather than to a spec row — `T:fodmap-streak-fetch-error-handling`,
   not `C33` — so the two sources stay distinguishable to a reader and neither can be mistaken for
   the other later.

5. **Every test names its origin.** The case id goes in the **data provider key** or in the **test
   method name**, so a reader goes from a failing test to the row that demanded it without
   searching:

   ```php
   #[DataProvider('safeDayCases')]
   public function testDayIsSafe(...): void
   ```
   with provider keys `'C16 logged tiers low,low → safe'`, or a method named
   `testC24StreakIsZeroWhenTodayHasNoData()`.

6. **Test conventions come from `.claude/rules/tests.md` and are not negotiable.** Read that file;
   the points this step trips over most:

   - **no mocking framework** — `createMock()`, `createStub()`, `getMockBuilder()`,
     `createPartialMock()`, `prophesize()` are forbidden (rule 1);
   - **a hand-written fake per port**, implementing the Domain interface and passed in through the
     constructor (rule 2) — `InMemory*` when it holds state, `Fake*` when it does not (rule 3);
   - a fake **lives beside the test that uses it**, same folder and namespace, one class per file,
     `final` (rule 4), and **asserts nothing itself** — it exposes observations as query methods
     (rule 5);
   - `Domain` and `Application` tests **extend `PHPUnit\Framework\TestCase`, never
     `KernelTestCase`**, and touch no database, container or network (rule 10);
   - **time comes from a fake clock with a fixed instant** (rule 12) — a fake
     `Symfony\Component\Clock\ClockInterface`, never `new DateTimeImmutable()` in a test body and
     never an assertion with a tolerance window;
   - an expected Domain exception is verified with **`try`/`catch` plus `self::fail()`**, so the
     message and the collaborators' post-state are both asserted (rule 9);
   - **layout mirrors the module** — `tests/<Module>/<Layer>/...` under namespace
     `App\Tests\<Module>\<Layer>\...` (rule 6), test classes `final` and named `{Subject}Test`
     (rule 7).

7. **Run the suite and read what it says.**

   ```bash
   php bin/phpunit
   ```

   It must **execute**: the classes load, the tests run, and they fail.

   - A failure on the `\LogicException` a stub throws is **the expected red** — it proves the test
     reaches the code under test.
   - A failed assertion is equally good red.
   - **A fatal error is not a red test.** `Class not found`, `Too few arguments`, a type error on a
     port signature, `Call to undefined method` — these mean the tests do not compile against the
     contracts, and that is a defect **in this step**, to be fixed before reporting done.

   `phpunit.dist.xml` sets `failOnWarning`, `failOnNotice` and `failOnDeprecation` — a warning,
   notice or deprecation fails the suite too, and is this step's to fix, not `/build`'s.

## Out of scope

- Do not implement anything under `src/`.
- Do not "temporarily" replace a stub to watch a test pass. The stub throwing is the evidence;
  replacing it, even briefly, is exactly the thing this step exists to make impossible.
- Do not edit the spec, and do not edit the contracts. **A contract that turns out to be wrong is a
  finding for the report and goes back to `/contract`** — the shape is an architectural decision
  and was taken with a human.
- Do not write a `docs/todo/` entry (see "This skill decides nothing").
- Do not add a Composer dependency (invariant 31).

## Verify before reporting done

```bash
php bin/phpunit
```
runs, fails, no fatal — every failure is a `\LogicException` from a stub or a failed assertion.

```bash
git status --short
```
shows nothing outside `tests/`.

## Report

- the **file list** — every path written;
- the **case-id accounting in full** — every id from the spec's tables, covered or not, with the
  test that covers it or the reason it has none, plus the todo-derived ids from step 4;
- where a `CASE-COVERAGE.md` was already there, **every id whose status changed in this run, in both
  directions** — gained coverage, and lost it — or a plain statement that none did;
- every **existing file overwritten**, by path, and what the new version changed;
- the **phpunit summary line**, verbatim;
- anything **the contracts could not express** — a case whose inputs have no counterpart in the
  declared signatures, stated as a finding for `/contract`, not resolved here.

## Boundaries

- Do not commit.
- Do not touch another module's folder (invariant 2).
- If an invariant or a rule in `.claude/rules/tests.md` blocks a test you believe is correct, stop
  and propose a wording change citing the number — never route around it silently (`AGENTS.md`,
  "When a rule blocks the task").
- **A denied Write is a limitation to report, not an obstacle to route around.** The guard refuses
  every path outside `tests/`; say so, name the file, and stop. Do not reach for `Bash` to write it
  anyway and do not ask for the hook to be lifted. The guard matches the editing tools, so `Bash`
  is not a wall this step meets — it is a rule this step keeps.
- **Inside `tests/`, rewrite the file rather than growing a parallel one.** A second pass over a
  module updates the test it wrote before and rewrites `CASE-COVERAGE.md` in place. Never an
  addendum, a `-v2`, a `-part2` or any other file carrying what the existing one should have
  carried: split accounting is worse than missing accounting, because a reader who finds one
  coverage record has no way to know a second exists. The price of being allowed to overwrite is the
  status-change report in step 3 — a rewrite without it is the defect the old refusal prevented.
