---
name: contract
description: Turn a behaviour specification into the target module's declared shape — module name, Domain ports, DTOs, exceptions, and throwing stubs under src/<Module>/ — after proposing that shape to a human and waiting for an answer. Use after /entity where the module reaches a database and after /spec where it does not, and before any test is written. The guard denies writes outside src/<Module>/ and docs/todo/; implementing behaviour is forbidden by rule, since no guard can tell a stub from an implementation.
argument-hint: [path to the spec in docs/specs/, plus the module name if you already have one]
disallowed-tools: Edit MultiEdit NotebookEdit
hooks:
  PreToolUse:
    - matcher: Write
      hooks:
        - type: command
          command: "$CLAUDE_PROJECT_DIR/.claude/skills/contract/write-guard.sh"
---

# Contract

The pipeline is `/spec` → `/entity` → `/contract` → `/cover` → `/build`, and `/entity` is the
conditional step: it runs only where `/spec` produced a schema specification — only where the source
reaches a database. A module that reaches none goes `/spec` → `/contract` → `/cover` → `/build`, and
this step follows `/spec` directly. Either way, this step is the third or the second, never the first.

`/spec` established **what** a module does and wrote it to `docs/specs/<name>.md` — plus, where the
source reaches a database, what its storage guarantees and restricts, at `docs/specs/<name>-schema.md`.
Where that schema document exists, `/entity` has already written the module's Doctrine entities under
`src/<Module>/Domain/`, built from the schema specification and the reference SQL. They are the reason
this step runs after it: this step declares the Infrastructure adapters, and the collaborator an
adapter takes — a DBAL `Connection` or an ORM `EntityManager` — cannot be a real choice while no
entity exists. That is exactly how `DoctrinePlannedTierProvider` ended up taking a `Connection` with
nobody deciding it.

This step decides **what shape** that module takes — its name, its ports, its signatures — and writes those
declarations, empty, so the next step has something to compile tests against.

The shape is an architectural decision, and it is not the test step's to make. If `/cover` wrote
its own contracts, the tests would define the design they are supposed to check. That is why the
decision is taken here, with a human, before a single test exists.

## The gate is the point of this skill

Propose, stop, wait. A proposal written to disk before it is confirmed defeats the whole step —
the human is then reviewing a fait accompli, not making a decision.

The gate is also what lets this step write over its own earlier output safely. Every other step is
protected by something appropriate to it — `/cover` by the case-id accounting it has to report,
`/build` by the tests it has to leave green. This step's protection is the gate: nothing reaches
disk until the human has answered. That only works if the proposal says what is *changing*, so:

**A proposal that changes a declaration which already exists must show the old signature and the new
one side by side, and name the case or finding that forces the change.** The human approves a
change, not a filename — "`src/Fodmap/Domain/LoggedTierProvider.php`" tells them nothing, and a
signature they already approved being silently replaced is exactly the failure the old refusal
prevented.

```
LoggedTierProvider — signature changes

  was:  public function loggedTiers(DateTimeImmutable $from, DateTimeImmutable $to): array;
  now:  public function loggedTiers(UserId $user, DateTimeImmutable $from, DateTimeImmutable $to): array;

  forced by: docs/specs/use-fodmap-streak-schema.md, case S4 — meal_logs.user_id references
  auth.users(id) and the row-level-security policy scopes every read to auth.uid(), so the port
  cannot be satisfied without a user.
```

A declaration that is merely being **re-stated unchanged** is not a change. It needs no side-by-side
and no justification — say it is unchanged and move on. Padding a proposal with every file that
happens to be rewritten identically buries the one line the human actually has to read.

## This skill never implements behaviour

`Edit`, `MultiEdit` and `NotebookEdit` are removed from the tool pool by the front matter, so no
existing file can be modified through them. `Write` stays for the declarations only.

**The only paths this skill may write are files under `src/<Module>/`, plus a
`docs/todo/<title>.md` for each decision the human took that still leaves work behind.** A
`PreToolUse` hook enforces it and denies everything else: `tests/` belongs to `/cover`, the rest of
`docs/` to `/spec`, `src/Shared/` to nobody at this step, and `config/` and `migrations/` to a human.
If a write is denied, that is the rule working, not an obstacle to route around. Not with `Bash`,
not by asking for the hook to be lifted. The guards match the editing tools; a shell
command is not something a `PreToolUse` hook can inspect for the files it changes, so what holds
here is the rule, not the hook.

Inside those two lanes, a file that already exists **may** be overwritten — a second pass revises the
shape rather than being refused. What stands in for the old refusal is the gate above: the human sees
the old signature against the new one before anything is written.

**One kind of file inside the lane is not this step's: an entity.** `/entity` runs before this step,
so the classes it wrote sit under `src/<Module>/Domain/`, in the middle of a folder this step is
otherwise free to overwrite. The guard makes the two refusals that keep them apart — it denies a write
over a file whose existing content carries a Doctrine mapping attribute, and it denies a write that
introduces one. A concept that should become an entity, or stop being one, is `/entity`'s work, and
the answer is to run `/entity`, not to write the class here.

## Procedure

0. **Declare which step is running, before anything else.** The guards that keep each step in its
   lane are `PreToolUse` hooks, and a hook stays registered for the rest of the session once its
   skill has been invoked — so in a session where another step has already run, that step's guard
   is still live and still denying every path that is not its own. The marker at `.claude/.step`
   holds one line, the name of the step currently running; each guard enforces when the marker
   names it and stands aside silently when it names another. Declare this step with an ordinary
   `Write` to `.claude/.step`, whose whole content is the one line:

   ```
   contract
   ```

   Every registered guard allows this Write, because the name is a step that exists — that is
   what lets a second step declare itself in a session where an earlier one already ran. This
   step's own guard does one more thing as it allows it: it records in `.claude/.step.live`
   that it is live in this session. That record is what the other guards read before standing
   aside, so a marker written any other way stands nothing down.

   **This is not a formality and it is not optional.** Do it as the very first action, before
   reading anything and long before any `Write`. A missing or empty marker fails closed: every
   guard denies, and this skill cannot write a single file.

1. **Read the specification and derive what the module needs.** Read the whole document, not the
   Cases table alone — and where `/spec` produced a schema document alongside it, read that in full
   too and derive the ports from **both**. A rule the storage enforces is part of the contract even
   though nothing at the call site shows it: a row-level-security policy scoping every read to one
   user is a parameter the port must carry, and a port derived from the behaviour spec alone would
   silently take no user at all. **Hidden dependencies** names the collaborators that must become ports
   (invariant 9) and says whether current time is among them, in which case the clock is injected
   as `Symfony\Component\Clock\ClockInterface` (invariant 22). **Contract** and **Cases** give the
   inputs, outputs and result types the signatures have to carry. **Open questions** are unresolved
   design decisions — carry each one into the proposal as an open choice with your recommendation,
   never silently pick an answer.

   `AGENTS.md` decides the rest of the shape, and every element you propose traces to a rule:

   - module-first layout, four layer folders under `src/{Module}/` (invariants 1, 2)
   - one class per file, filename identical to the class name, a port named for its role with no
     `I` prefix (invariant 4)
   - read and write ports kept as separate interfaces (invariant 10)
   - a command use case is `{UseCase}Command` + `{UseCase}Handler`; a query use case is
     `{UseCase}Query` + `{UseCase}Handler` + `{UseCase}Response` (invariant 12)
   - every use-case class carries its bus marker, both sides (invariant 13)
   - a handler has exactly one public method, `__invoke()`, and takes its collaborators as
     `private readonly` constructor-injected ports (invariants 14, 15)
   - classes in `Application/` and `Domain/` are `final`; the one exception, a Doctrine entity, is
     `/entity`'s file and not written here (invariant 16)
   - a controller is `Api{Action}Controller` under `Adapter/Http/Controllers/` (invariant 17)
   - a business rule lives in a Domain class and fails by throwing a Domain exception — never by
     returning `null`, `false`, or an error string (invariant 21)
   - every method declares an explicit return type; `mixed` is rejected (invariant 23)
   - a command handler returns `void`, a query handler returns its own Response DTO (invariants 24, 25)
   - DTOs are immutable: constructor-promoted `public readonly`, no setters (invariant 26)
   - a fixed set of outcomes uses named static factories over a `private` constructor (invariant 27)
   - ports return Domain types or `null`, never Doctrine or Symfony types (invariant 30)

   `.claude/rules/application-layer.md` holds the shape of both use-case kinds in full. Follow it.

2. **Present the proposal in one message.** Everything the human needs in order to answer, with
   nothing written yet:

   - the **module name**, and why that name
   - every **port**: interface name, full method signatures with parameter and return types, and
     which spec dependency it exists for
   - every **domain class**: name, method signatures, and the fact that it is `final` (invariant 16).
     An entity is not among them — `/entity` wrote the module's entities before this step ran, and the
     guard denies a write that carries a Doctrine mapping attribute
   - every **exception**: name, which SPL exception it extends, which case throws it
   - every **use-case folder** with its Command/Query, Handler and Response classes
   - the **full path each file will take**, and for each path that already exists, that it is being
     rewritten — with the old declaration against the new one where it differs, per "The gate is the
     point of this skill", or marked unchanged where it does not

   For each element, say where it came from — a named section of the spec, an invariant by number,
   or an **open choice** where neither settles it. An open choice is stated as a choice, with your
   recommendation and what the alternative would cost.

3. **Ask, and stop.** Use `AskUserQuestion` if it is available; otherwise ask in plain text. Either
   way, **write nothing until the human has answered.** Not one file, not "the obvious part first".
   If the answer changes part of the shape, revise the proposal and confirm the revision before
   writing.

4. **Only then write the files** — the declarations, and the todo trail.

   Every Open question the human's answer leaves work behind gets one `docs/todo/<title>.md`, in the
   format `AGENTS.md` defines under "The todo trail": what was decided, which spec question it came
   from, why — citing the invariant by number where one drove the decision — what still has to be
   done, and what would settle it. One topic per file, kebab-case title, flat under `docs/todo/`.

   A todo whose topic already has a file is rewritten in place, not duplicated under a second title —
   and, like any other existing declaration, the change goes through the proposal first. A todo is
   still closed by **deleting** the file in the commit that finishes the work; rewriting one records
   a decision that moved, it does not retire one.

   Where `/entity` ran before this step, its report may carry **todos it drafted and could not
   write** — one per entity whose concept the human said this module does not own, sitting in
   `src/<Module>/Domain/Shared/` as a consequence. Its guard denies `docs/todo/`, so this step is
   where those land. Carry each one into the proposal like any other, quoted as drafted, and write it
   after the human has answered — an entity in `Shared/` with no todo behind it is exactly the
   undiscoverable state the trail exists to prevent.

   A question the answer settles completely produces **no file** — the settled shape is already in
   the declarations, and a todo restating it is noise. A todo exists for work that outlived the
   conversation, not as minutes of it.

   Invariant 39 makes one case mandatory: where this module ports behaviour that already exists and
   an invariant forbids reproducing it, the human's ruling is recorded here, naming the invariant and
   stating plainly that the port is deliberately not equivalent at that point. `docs/specs/use-fodmap-streak.md`
   is the live example — the original discards the `error` field of every query, which invariant 37
   forbids. Reproducing it breaks 37, fixing it changes behaviour silently; the decision goes to the
   human and the divergence goes in `docs/todo/`.

   Writing the todo does not move the gate. It happens **after** the human has answered, alongside
   the declarations — never as a way to record a choice you made on your own.

## What this skill may write, and nothing beyond it

- **Interfaces** — Domain ports, and the bus markers a use-case class implements (invariant 13).
- **Immutable DTOs** — constructor-promoted `public readonly` properties, no logic. A Response
  covering a fixed set of outcomes gets its named static factories declared as stubs (invariant 27).
- **Exception classes** extending an SPL exception (`\DomainException`, `\InvalidArgumentException`,
  `\RuntimeException`), `final`, in the module's `Domain/`.
- **Concrete classes** — handlers, rule classes, controllers, adapters — where every
  method body is exactly one statement:

  ```php
  throw new \LogicException(sprintf('%s is not implemented', __METHOD__));
  ```

- **A todo record** at `docs/todo/<title>.md` per step 4 — the only path outside `src/` this skill
  may write, and only after the human has answered.

That last one is deliberate. The concrete class has to exist or the test suite will not load, and a
suite that dies on autoload is not a red test — it is a broken one. A throwing stub makes every
case fail loudly and individually, and leaves each body for `/build` to replace.

**No other body is acceptable.** Not a `return null`, not a default value, not an empty body, not a
one-line implementation "while we are here" because it is obvious. A stub that returns something
makes a test pass for the wrong reason, and a green test nobody wrote an implementation for is
worse than no test at all.

Constructors are the one exception, since a promoted-property constructor *is* the declaration:
a constructor whose body is empty is correct and needs no throw.

## The Doctrine mapping is left to a human

`AGENTS.md` requires every new module to register its own mapping section in
`config/packages/doctrine.yaml`, pointing at that module's `Domain` folder:

```yaml
doctrine:
    orm:
        mappings:
            {NewModule}:
                type: attribute
                is_bundle: false
                dir: '%kernel.project_dir%/src/{NewModule}/Domain'
                prefix: 'App\{NewModule}\Domain'
```

The guard blocks `config/`, so this skill cannot make that edit. **Say so in the report**, quote
the exact block that needs adding, and leave it to a human. Do not work around the guard — not with
`Bash`, not by asking for the hook to be lifted.

## Verify before reporting done

- `php -l` on every file written — a parse error in a declaration breaks the whole next step.
- `git diff` on every path that already existed, to confirm the change on disk is the one the human
  approved and nothing else.
- Confirm nothing outside `src/<Module>/` changed (`git status --short`).

## Report

- the **proposal exactly as it was shown to the human**, plus any revision they asked for
- the **file list**, every path written, marking which were new and which overwrote an existing file
- for every **existing declaration changed**, the old signature and the new one, and the case or
  finding that forced it — the same side-by-side the human approved
- the **source of each decision** — spec section, invariant number, or human's answer to an open choice
- every **`docs/todo/<title>.md` written**, with the Open question each one answers and the
  invariant it cites — and, for any Open question that produced no file, that the answer settled it
- the **Doctrine mapping block that still needs adding**, and that it is a human's edit
- anything the spec left undetermined that the shape had to assume anyway, stated as an assumption

## Boundaries

- Do not write a test, a fixture, or a fake. `/cover` owns `tests/`.
- Do not implement a method body, even a trivial one. `/build` owns behaviour.
- Do not edit the spec. A spec that turns out to be wrong is a finding for the report, and
  `/spec` corrects it. `docs/todo/` is not a way around that: it records a decision and its
  remaining work, never a correction to the specification.
- Do not write a todo for a question the human has not answered. An unanswered question stays an
  Open question in the spec, where `/spec` put it.
- Do not add a Composer dependency (invariant 31), and do not touch another module's folder
  (invariant 2).
- If an invariant blocks a shape you believe is correct, stop and propose a wording change citing
  the number — never route around it silently (`AGENTS.md`, "When a rule blocks the task").
