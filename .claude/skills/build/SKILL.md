---
name: build
description: Replace the throwing stubs /contract declared with real behaviour under src/<Module>/ until the tests /cover wrote are green, and change nothing else. Use after /cover; never for writing or altering a test, a specification, a todo or configuration — none of which this skill can touch.
argument-hint: [the module name whose stubs are to be implemented, e.g. Fodmap]
disallowed-tools: NotebookEdit
hooks:
  PreToolUse:
    - matcher: Write|Edit|MultiEdit
      hooks:
        - type: command
          command: "$CLAUDE_PROJECT_DIR/.claude/skills/build/edit-guard.sh"
---

# Build

The pipeline is `/spec` → `/entity` → `/contract` → `/cover` → `/build`, and `/entity` is
conditional: it runs only where `/spec` produced a schema specification, that is, only where the
source reaches a database. A module that reaches none goes `/spec` → `/contract` → `/cover` → this
step. Either way this step is the last one.

`/spec` established **what** a module does. `/entity`, where it ran, wrote the Doctrine entities that
carry the module's mapping metadata. `/contract` declared **what shape** the module takes, with every
method body a `throw`. `/cover` turned the specification's cases into **tests that fail** on those
throws. This step replaces the throws with **behaviour**, until the suite is green — and changes
nothing else.

It is the last step, and the only one whose output is judged by something written before it. That
is the whole design: the finish line was drawn by `/cover`, in files this step cannot reach.

## This step is the only one that edits existing files

The steps before it create. This one replaces stub bodies, so `Edit` and `MultiEdit` stay in
the tool pool and the guard cannot ask "may this file be created" — it asks **"may this file be
touched at all"**.

The answer is `src/<Module>/` and nothing else. A `PreToolUse` hook matches `Write`, `Edit` and
`MultiEdit`, and denies every other path:

- **`tests/` is denied, and this is the point of the step.** A step that can edit the tests it is
  judged by can always turn them green, and the green would mean nothing. If a test looks wrong,
  that is a **finding to report**, not a file to fix.
- **`docs/` is denied.** A todo is closed by deleting its file in the commit that finishes the work
  (`AGENTS.md`, "The todo trail"), and this step does not commit. Report which todos the work
  satisfies and leave the deletion to a human.
- **`config/`, `migrations/` and the repository root are denied.** `migrations/` is outside this
  step's lane, and a migration is applied only after a human has approved it (invariant 7). The
  Doctrine mapping a new module needs is a deliberate human edit — `AGENTS.md` requires the mapping
  section to be registered by hand.
- **`src/Shared/` is denied.** The CQRS base has already landed; this step implements a module
  against it, not the base itself.

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
   build
   ```

   Every registered guard allows this Write, because the name is a step that exists — that is
   what lets a second step declare itself in a session where an earlier one already ran. This
   step's own guard does one more thing as it allows it: it records in `.claude/.step.live`
   that it is live in this session. That record is what the other guards read before standing
   aside, so a marker written any other way stands nothing down.

   **This is not a formality and it is not optional.** Do it as the very first action, before
   reading anything and long before any edit. **Nothing can be edited before this** — a missing or
   empty marker fails closed: every guard denies, and this skill cannot change a single file.

1. **Read the tests before writing any implementation.** All of them, in full, plus the fakes beside
   them. They are the specification in executable form, and they are the thing that decides whether
   this step is finished.

   **The expectations in them have been verified.** Every case in `docs/specs/use-fodmap-streak.md`
   was run against the original TypeScript by executing it, and all twenty-seven matched — including
   the lookback cap, which the executed run put at 113 days. An expectation that looks wrong is very
   unlikely to be wrong.

   If one still does, **stop and say which and why.** Do not implement what you believe to be
   incorrect behaviour just because a test asks for it, and do not quietly implement something else
   and leave the test failing with a note. Those are the two failure modes; reporting is the third
   option and the only acceptable one.

   Read the specification and every file under `docs/todo/` as well — the spec for the reasoning
   behind a case, the todos for behaviour that is deliberately *not* the original's (step 3).

2. **Signatures are settled.** A declared parameter list or return type is a contract `/contract`
   took with a human, and this step does not renegotiate it. Widening a type, adding a parameter,
   relaxing a return type or adding a public method to a handler (invariant 14) are all the same
   move: changing the agreed shape without the person who agreed it.

   If the shape genuinely cannot carry the behaviour, that is **a finding for `/contract` and a
   reason to stop**, not a reason to edit the declaration. Say which signature, which case it cannot
   express, and what shape would.

   Constructor injection is the one thing that legitimately changes here where a todo says so — see
   step 3 — and even then only as the todo describes it.

   **A new class is the same move by another route.** The guard permits a new file under
   `src/<Module>/`, because a stub and a new declaration share a folder and no guard can tell them
   apart; the rule is what separates them. Adding a class, an interface or an enum nobody agreed to
   extends the module's shape exactly as widening a signature would, and it belongs to `/contract`.
   What does belong here is implementation with no shape of its own: a `private` method on a class
   that is already declared, a local variable, a `match` arm. If the behaviour genuinely needs a new
   collaborator, stop and say which and why — the same finding, the same route back.

   **A mapping that will not carry the query is the same move a third time.** This step writes the
   Infrastructure adapters that read these tables through DQL, and when a query will not build, the
   shortest fix is to widen a column, add an association or relax a property type. That edit changes
   the schema the database is required to have — with no migration, no `/entity` run, no ownership
   gate and no todo — and nothing in the suite would catch it, because nothing in the suite touches
   a database. Say which query, against which mapping, and what the mapping would need. It is a
   finding for your report and a reason to run `/entity`, never a mapping edit made here.

3. **Implement the deliberate divergences as recorded, not as the original had them.** Invariant 39
   allows a port to diverge from the original where an invariant forbids reproducing it, provided
   the divergence was decided with a human and written down. Those decisions are in `docs/todo/`,
   and reverting one here undoes a decision a human took.

   For this module:

   - `docs/todo/fodmap-streak-fetch-error-handling.md` decided that a failed fetch throws
     `FodmapDataFetchException` and aborts the query, rather than being swallowed into an empty
     result the way the original's `?? []` does — because **invariant 37** forbids the original's
     behaviour. The handler lets it propagate (`.claude/rules/application-layer.md`, rule 2); the
     controller is the only layer that maps it, to a 5xx body `{"error": "<message>"}` (invariants
     29, 20).
   - `docs/todo/fodmap-streak-ingredient-tier-precedence.md` decided the catalogue-over-recipe
     precedence rule gets a Domain home, `IngredientTierPrecedence`, instead of staying implicit
     inside the adapter — **invariant 21**. It also states the wiring this step owes: inject it into
     `DoctrinePlannedTierProvider`'s constructor, and convert each raw column with
     `FodmapTier::tryFrom()` before calling `resolve()`.
   - `docs/todo/fodmap-streak-lookback-window.md` decided the plan-side and log-side windows share
     one definition instead of being computed independently — **so far as it is decided**. The todo
     explicitly leaves the window's concrete shape and its configurability open, and says to default
     to the literal 16 Mondays / 112 days or raise configurability with a human. Implement the
     shared definition; do not settle the open half on your own, and say in the report which half you
     implemented and which you left.

4. **Work in small steps and run the suite often.**

   ```bash
   php bin/phpunit
   ```

   One stub at a time, innermost first — the pure Domain classes the others depend on, then the
   handler, then the adapters. A suite run after each replacement tells you which test the change
   was for and whether it broke another.

   **Green is the finish line, and it means green — not skipped, not incomplete, not marked.** Do
   not add `markTestSkipped`, `markTestIncomplete`, a `#[Group]` to exclude something, or a change
   to `phpunit.dist.xml`. You cannot edit the tests, and you must not arrange for them not to run.

   `phpunit.dist.xml` sets `failOnWarning`, `failOnNotice` and `failOnDeprecation` — a warning,
   notice or deprecation fails the suite too, and is this step's to fix.

5. **Some cases cannot go green here, and that is the recorded state, not a failure.**
   `tests/Fodmap/CASE-COVERAGE.md` accounts for every case id, and eight of them have no test at
   all while three more are covered only in part. The reasons are already written down:

   - **C1–C3, C13, C14** have no PHP counterpart — `DateTimeImmutable::format()` zero-pads natively,
     and `FodmapTier::isBad()` takes an already-resolved enum case, never a nullable raw value.
   - **C22**, and the map-construction halves of **C25, C27 and C28**, are Infrastructure behaviour
     that needs a real Postgres and a migration that does not exist. Rule 11 of
     `.claude/rules/tests.md` confines DB-touching tests to `tests/<Module>/Infrastructure/`, against
     a real test database, and the project does not have one.
   - **C26** is superseded by `T:fodmap-streak-fetch-error-handling` — the port deliberately does not
     reproduce it (step 3).
   - **`T:fodmap-streak-lookback-window`** has no contract to assert against until the shared window
     definition exists, which is the open half of that todo.

   **Do not invent an integration test, do not stub a database, and do not change their status.**
   `CASE-COVERAGE.md` lives under `tests/` and the guard denies it in any case; a case whose status
   genuinely changed because of work done here is a line for the report, and a human's edit.

## The container wiring is left to a human

Every class this step implements is reachable from the tests without a container — `Domain` and
`Application` tests extend `PHPUnit\Framework\TestCase` and take hand-written fakes through the
constructor (`.claude/rules/tests.md`, rules 2 and 10). The real application is a different
question: a Domain port is an interface, and `config/services.yaml` has to say which implementation
answers it.

The guard blocks `config/`, so this skill cannot make that edit. **Check whether the module's ports
resolve, and if they do not, say so in the report** — quote the exact block that needs adding and
leave it to a human, the way `/contract` leaves the Doctrine mapping. Do not work around the guard,
and do not paper over a missing alias by constructing an implementation with `new` inside a handler
(invariant 15).

## Out of scope

- Do not touch another module's folder (invariant 2).
- Do not add a Composer dependency (invariant 31) — Symfony 8.1 and Doctrine already provide what
  this module needs, and `symfony/clock` is already installed.
- Do not change a test, a fake, `CASE-COVERAGE.md`, a specification, a todo, or configuration.
- **An entity's methods are this step's; its mapping is `/entity`'s.** A getter, a derived value, a
  question the class can answer — write those. The *mapping surface* is every Doctrine mapping
  attribute line together with every typed property declaration line, and the guard compares it
  between the file on disk and what you write: identical, and the write goes through; an attribute
  added, removed, reordered or altered, or a property retyped, and it is denied. `Edit` and
  `MultiEdit` on an entity are denied outright — a fragment cannot be compared, so replace the whole
  file with `Write`. This step also may not turn a class that is not an entity into one.
- Do not change a declared signature (step 2).
- Do not implement a stub in a module this run was not asked to build.

## Verify before reporting done

```bash
php bin/phpunit
```
green, and read the summary line — the test count, and **no skips, no incomplete, no risky**.

```bash
git status --short
```
nothing changed outside `src/<Module>/`.

## Report

- the **phpunit summary line**, verbatim, with the test count and the absence of skips;
- **every file touched**, with what was implemented in each;
- **which `docs/todo/` entries the work now satisfies**, so a human can delete them in the commit
  that finishes the work — and, for a todo only partly satisfied, which half is left and why;
- the **container wiring block** that still needs adding, if the ports do not resolve, stated as a
  human's edit;
- **anything you had to stop on** — a test whose expectation you believe is wrong, a signature that
  cannot carry its behaviour, a case that cannot be made green. Name it, say why, and leave it.

## Boundaries

- **Do not commit.** A todo is closed by deleting its file in the commit that finishes the work, and
  that commit is a human's.
- **A denied edit is a limitation to report, not an obstacle to route around.** Not with `Bash`, not
  by asking for the hook to be lifted, not by writing the change somewhere the guard permits. The
  guard matches the editing tools, so `Bash` is not a wall this step meets — it is a rule this step
  keeps.
- If an invariant or a rule in `.claude/rules/` blocks an implementation you believe is correct,
  stop and propose a wording change citing the number — never route around it silently
  (`AGENTS.md`, "When a rule blocks the task").
