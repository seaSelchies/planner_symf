# Prompt log

A chronological record of work with AI tools: what was asked for, what came back, what had to
be corrected. Entries 001-011 were filled in as the work happened. Entries 012 onward were
written from the session transcript the same day, with every prompt quoted verbatim from it;
where the transcript no longer held a prompt in full, the entry says so instead of paraphrasing.

Entry format: date, tool, task, the prompt verbatim, result, corrections, conclusion.

Tools used on this project:

- **Claude Code** (CLI, Opus model) — the main one. Multi-file changes, generating code and
  documentation, working against the invariants in `AGENTS.md`.
- **Claude (Cowork)** — framing tasks, reviewing results, checking them on a live environment.
  The prompts for Claude Code are written here.
- **GitHub Copilot** — pull-request review, deliberately left unconfigured in the repository:
  a second opinion that knows nothing about the architecture.

---

## 001 · The CQRS base

**28.08.2026 · Claude Code**

Task: build the CQRS base in `src/Shared` — the contracts for both sides of the bus, the
implementations, and the Symfony wiring that resolves handlers automatically.

<details><summary>Prompt</summary>

```
Read AGENTS.md first. Its numbered invariants govern everything below — cite the
numbers when you explain your choices.

Task: build the CQRS base in src/Shared. Today src/Shared/Domain/Bus/Command/
holds three near-empty files: Command and CommandHandler are marker interfaces,
CommandBus is still an empty class, and nothing dispatches through it.

Deliver:

1. Domain contracts, framework-free — no Symfony import anywhere under Domain/:
   - App\Shared\Domain\Bus\Command\Command — marker for a command DTO
   - App\Shared\Domain\Bus\Command\CommandHandler — marker for its handler
   - App\Shared\Domain\Bus\Command\CommandBus — dispatch(Command $command): void
   - App\Shared\Domain\Bus\Query\Query, QueryHandler, Response — markers
   - App\Shared\Domain\Bus\Query\QueryBus — ask(Query $query): Response
   The Response marker exists so ask() can declare a real return type: mixed is
   rejected by invariant 23. Every {UseCase}Response DTO will implement it later.

2. Implementations under App\Shared\Infrastructure\Bus\..., built on Symfony
   Messenger, which is already installed — do not add a dependency (invariant 31)
   and do not hand-roll a handler resolver.
   - The command bus dispatches and returns nothing.
   - The query bus uses Messenger's HandleTrait so it can return the single
     handler's result.
   - Both unwrap HandlerFailedException and rethrow the original Domain
     exception. Without that the adapter cannot catch EmailAlreadyUsedException
     and map it to 409 (invariants 20, 29).

3. Symfony wiring:
   - Add two buses in config/packages/messenger.yaml: command.bus and query.bus.
     Leave messenger.bus.default as the default bus — mailer and notifier route
     through it.
   - Handler selection happens by implementing the marker interface, not by an
     attribute: a _instanceof block in config/services.yaml tags every
     CommandHandler onto command.bus and every QueryHandler onto query.bus.
     #[AsMessageHandler] is not acceptable — it would put a Symfony dependency
     inside Application/, and Application may depend only on Domain (invariant 3).
   - Alias each Domain bus interface to its Infrastructure implementation and
     pass the correct bus service into each one.

Out of scope — do not touch src/Auth or tests/ in this task. SignUpHandler does
not implement CommandHandler yet and the controller still calls it directly;
moving Auth onto the bus is a separate change.

Known and out of scope: the test suite currently dies with a fatal error because
App\Auth\Domain\User declares PasswordAuthenticatedUserInterface without a
getPassword() method. Do not fix it here.

Verify before reporting done:
  php bin/console debug:messenger    # command.bus and query.bus are listed
  php bin/console lint:container     # passes

Do not commit. Report the file list, and for each design decision the invariant
number behind it. If this task exposed something missing or ambiguous in
AGENTS.md, say so — but do not edit AGENTS.md yourself.
```
</details>

**What came back.** A working base: contracts without a single Symfony import, both buses on
Messenger, `_instanceof` instead of attributes. The task boundaries were respected — `src/Auth`
and `tests/` untouched, and the known fatal error was not "fixed" against the explicit ban.
Invariant 13 was extended to cover both sides of the bus, and the example in
`application-layer.instructions.md` was brought into line.

**Verification.** Brought PHP 8.4 up in a cloud container from `composer.lock`: `lint:container`
green, `debug:messenger` lists three buses. I temporarily hung the marker interfaces on the Auth
classes — `SignUpCommand → SignUpHandler (when bus=command.bus)` and
`IsEmailSignedUpQuery → IsEmailSignedUpHandler (when bus=query.bus)`. Handler resolution
confirmed by running it, not taken on trust.

**What had to be corrected.** Two problems the model did not flag itself:

1. `unwrap()` is duplicated word for word in both buses.
2. `use HandleTrait;` violates invariant 34 — "no traits carrying behaviour". The code broke the
   very rule it is meant to enforce.

**Conclusion.** The generator does not see its own violations even where the rule is stated
literally and sits in its context. That is a direct argument for a separate review step in the
workflow: the reviewer cannot be the same run as the author.

---

## 002 · Narrowing rule 34 and extracting the unwrapper

**28.08.2026 · Claude Code**

Task: fix both problems found in 001.

<details><summary>Prompt</summary>

```
Read AGENTS.md and .github/copilot-instructions.md first. The numbered invariants
in copilot-instructions.md govern this repo; cite numbers in your report.

Context: the CQRS base in src/Shared was just added. A review of it found two
problems. Fix both.

1. Invariant 34 currently says "Do not introduce Active Record, service locators,
   static registries, singletons, global helper functions, or traits carrying
   behaviour — collaboration happens through constructor-injected interfaces."

   MessengerQueryBus does `use HandleTrait;`, which is a trait carrying behaviour,
   so the new code violates the rule as written. The rule's intent was to stop
   *our own* behaviour-sharing traits, not to ban a framework trait used inside
   an adapter.

   Rewrite invariant 34 so it says that precisely: no traits of our own carrying
   behaviour anywhere, and a framework-provided trait is allowed only in a class
   under Infrastructure/ or Adapter/, never in Domain/ or Application/. Keep the
   number 34 and keep the rest of the rule intact. Do not renumber anything.

2. MessengerCommandBus and MessengerQueryBus each carry an identical private
   unwrap() method. Extract it into one class, injected into both buses through
   the constructor. Final, one public method returning Throwable, no Domain
   interface — it is a technical detail of the Messenger adapter, not an outbound
   dependency of the domain. Not static, not a trait.

Out of scope — do not touch src/Auth, tests/, or AGENTS.md.

Verify: php bin/console lint:container, php bin/console debug:messenger.
Do not commit. Report the changed files and the new wording of invariant 34
verbatim, so it can be reviewed as text.
```
</details>

**What came back.** `HandlerFailureUnwrapper` extracted and injected into both buses. Invariant
34 was rewritten better than asked: it not only forbids, it names the replacement — "behaviour
two of our own classes share is extracted into a third class and constructor-injected into
both".

**Verification.** `lint:container` green (so autowiring worked), three buses in place, tests
4/4.

**No corrections needed.** Separately, the model noted that it had carried the defensive branch
`!$first instanceof Throwable` over as it was, even though that branch is unreachable: the
`HandlerFailedException` constructor calls `current($exceptions)` and fails on an empty array
before the exception can be caught. Checked against the Symfony source — correct.

**Conclusion.** A narrow task with explicit boundaries and a diagnosis already made comes back
needing no corrections. The difference from 001 is that there the ask was "build this", and here
it was "fix this specific thing, and here is why".

---

## 003 · Reconciling the rulebook

**29.08.2026 · Claude Code**

Task: merge two diverging rulebooks into one, create `CLAUDE.md`, move the path-scoped rules
into `.claude/rules/`, drop the Copilot configuration.

Background: Claude Code reads `CLAUDE.md`, not `AGENTS.md` — so the rulebook was not reaching
the main tool at all, and only worked because the prompts named the file by hand.
Confirmed in the documentation.

<details><summary>Prompt</summary>

```
Read AGENTS.md, .github/copilot-instructions.md, .github/instructions/*.md,
.claude/settings.json and composer.json before changing anything.

Context: this repo currently has two rulebooks that contradict each other, and
the one Claude Code actually reads does not exist. Claude Code reads CLAUDE.md,
not AGENTS.md — so today the rules reach it only when a prompt names the file.
We are consolidating onto one authored rulebook and dropping the Copilot
configuration layer. Copilot stays in the project as an unconfigured second
reviewer for PRs; that is deliberate, not an oversight.

Do all six tasks.

1. AGENTS.md becomes the single authored rulebook.
   - Correct the layout to module-first, which is what the code actually does.
   - Fold in all 38 numbered invariants verbatim, keeping the numbering.
   - Two invariants carry example paths that repeat the module name and match no
     file in this repo. Correct them to the real shape.
   - composer.json is authoritative for versions. State that it wins.
   - Describe the CQRS base that now exists.
   - Add to the module rule: a new module registers its own Doctrine mapping
     section pointing at that module's Domain folder.
   - Add a section "When a rule blocks the task": an agent that finds an
     invariant preventing a correct solution stops and proposes a wording change,
     citing the number — it never silently works around the rule and never edits
     an invariant on its own initiative.
   - Target under 200 lines.

2. Create CLAUDE.md: @AGENTS.md, then the commands a newcomer needs and an agent
   cannot guess. Short. Do not restate any invariant.

3. Move the two scoped instruction files to .claude/rules/, replacing applyTo
   with paths as a YAML list. Content otherwise unchanged.

4. Move .github/hooks/ to .claude/hooks/ and update .claude/settings.json.

5. Delete .github/copilot-instructions.md with git rm.

6. Add CLAUDE.local.md and .claude/settings.local.json to .gitignore.

Out of scope — do not touch src/, tests/, config/, composer.json, or the
migration. Do not add CI. Do not invent new invariants.

Verify: every number 1..38 appears exactly once; no occurrence of
"src/Application/" or "Adapter/{Module}/" remains anywhere; wc -l AGENTS.md under
200; .github/ has no instruction files or hooks; settings.json points at the
moved hook.

Do not commit. Report the file list, the new section verbatim, and anything you
dropped or merged rather than carried over.
```
</details>

**What came back.** The structure is right: all 38 numbers appear exactly once, 149 lines, the
hook moved with its executable bit intact, the rules files got their `paths`. The report on what
was dropped is substantive.

**What had to be corrected — four things.**

1. Invariant 9 kept the old layer-first path `Domain/{Module}/`. My verification criterion
   searched for `src/Application/` and `Adapter/{Module}/` — it did not catch the third variant
   of the same mistake.
2. `CLAUDE.md` recommended `doctrine:migrations:diff`, which generates raw SQL and is forbidden
   by invariant 7. The commit that removed one divergence introduced another.
3. The ban on the `I` prefix for ports disappeared. The report claimed the rule was preserved in
   invariants 4 and 17 — it is not in invariant 4.
4. The constraint "Domain and Application are unit-testable without a database" ended up in
   `.claude/rules/tests.md`, which is scoped to `tests/**` — so it is not loaded at all while
   production code is being written, even though it constrains the design of production code.

**Two conclusions.**

The model's own report of what it had preserved was confident and in places wrong. What has to
be checked is the file, not the report — another argument for an independent review step.

Invariant 1 used to end with the words "never `src/Application/{Module}/`", i.e. it showed the
forbidden shape literally. The wording is different now — not by design, but because my
verification criterion demanded that this string no longer appear in the file. The check edited
the thing it was checking.

---

## 004 · Four rulebook corrections

**29.08.2026 · Claude Code**

Task: fix the four problems found in 003.

<details><summary>Prompt</summary>

```
Four small corrections to the rulebook. Do not touch anything else.

1. AGENTS.md, invariant 9 still carries the old layer-first path: it says an
   outbound dependency is "declared as an interface in `Domain/{Module}/`".
   Change it to `src/{Module}/Domain/`. Leave the rest verbatim.

2. CLAUDE.md recommends `doctrine:migrations:diff`. That command generates a
   raw-SQL migration, which invariant 7 forbids. Remove it and say instead that a
   new migration is written by hand following Version20260722160749.php, citing
   invariant 7.

3. The naming conventions were reported as preserved in invariants 4 and 17, but
   invariant 4 covers only "one class per file, filename identical to the class
   name, PSR-4". One rule is now stated nowhere: a Domain port is named for the
   role it plays and never carries an `I` prefix — UserProvider, not
   IUserProvider. Add exactly that to invariant 4, keeping its number.

   Do not turn the old note about *Provider / *Repository / *Factory into a rule.
   The original wording was permissive, and promoting it to an invariant would
   invent a constraint the repo never had.

4. AGENTS.md points at .claude/rules/tests.md for testing, but that file is
   scoped to tests/**, so it is not loaded while production code is written. Add
   one line near the dependency rule: Domain and Application must be unit-testable
   with no database, no container and no network, which is why every outbound
   dependency is a port. A design constraint, not a restatement of test
   conventions.

Do not commit. Show me the diff for each of the four.
```
</details>

**What came back.** All four corrections, inside the boundaries given. The delta adds up line by
line: `AGENTS.md` 149 → 152 (two lines of the new note plus a blank one; the invariant edits are
within existing lines), `CLAUDE.md` 44 → 42 (a code block removed, three lines of prose added).
Nothing else moved.

**No corrections needed.**

**Conclusion.** The same pattern as 002: a numbered list of concrete defects, each with an
explanation of why it is a defect, comes back clean. An open-ended framing ("tidy this up") does
not.

---

## 005 · The first workflow skill

**29.08.2026 · Claude Code**

Task: build the first of the four skills — reading an unfamiliar module and producing a
behaviour specification. The key requirement: the skill must not be able to change code, and
that has to be enforced mechanically rather than asked for.

<details><summary>Prompt</summary>

```
Read AGENTS.md and CLAUDE.md first.

Task: create the /investigate skill at .claude/skills/investigate/SKILL.md.

What it is for. Before this project ports or reworks an unfamiliar module, someone
has to establish what that module actually does — not what its author says it
does. That reading pass is the skill. Its output is a specification document that
the next step turns into failing tests, so the document has to be precise enough
to become test cases without further interpretation.

Hard constraint: this skill never changes code. Set
`disallowed-tools: Edit MultiEdit NotebookEdit` in the front matter so the tools
that modify existing files are gone from the pool while it runs. Write stays
available because the skill must produce its document, and the body must state
that the only path it may write is docs/specs/<name>.md.

That leaves a gap — Write can still overwrite an existing file. Check the Claude
Code documentation for whether a skill can register a PreToolUse hook through its
own front matter. If it can, add one that denies any Write outside docs/specs/ and
say so in your report. If it cannot, say that too and leave the instruction as
prose. Do not guess either way.

Front matter also needs: a description that says when to use it, and an
argument-hint for the path or module being investigated.

The procedure the skill body must lay out:

1. Read the source in full. Never characterise code from a grep or a partial read.
2. Separate what the code claims from what it does. Docblocks, comments and names
   are claims; the branches are behaviour. Every disagreement between them is a
   finding, not a detail to smooth over.
3. Enumerate inputs and outputs, then every branch with its condition and result.
4. Enumerate edge cases explicitly: empty input, absent data, boundaries, ordering,
   duplicates, nulls, and anything time- or locale-dependent.
5. Name the hidden dependencies — I/O, current time, randomness, global state.
   These decide which ports the future module will need (invariant 9, invariant 22).
6. Separate what the code settles from what it leaves ambiguous. Anything the
   source cannot answer goes to a list of open questions for a human, never to a
   guess.

Required output document structure — docs/specs/<name>.md:

  Purpose · one paragraph
  Contract · inputs, outputs, and the rule in one sentence
  Cases · a table of id | given | expected, concrete enough to become a PHPUnit
    data provider with no further thought. This table is the interface to the next
    step; everything else is context.
  Edge cases · each with what the current code does about it
  Hidden dependencies · and which of them must become a port
  Discrepancies · where the stated contract and the real behaviour disagree
  Open questions · what a human has to decide

The skill must not propose an implementation, sketch classes, or write PHP. Its
job ends at the specification. It must also state plainly what it could not
determine rather than filling the gap.

Out of scope: do not create the other skills, do not run the skill, do not touch
src/ or tests/.

Do not commit. Report the file you created, the front matter verbatim, and your
finding about whether skills can register hooks.
```
</details>

**What came back.** `SKILL.md` plus `write-guard.sh` — the model found that a skill can register
a `PreToolUse` hook from its own front matter, and wrote the guard instead of settling for
prose. The procedure in the body is narrow, with no general commentary; the structure of the
output document is fixed rigidly, stating explicitly that the case table is the interface to the
next step.

**Verification — three levels.**

Documentation: `hooks` really is a supported skill field, registered when the skill is invoked
and living until the end of the session; the shape is nested by event name, as written.

The guard on its own, by piping four payloads straight into it: `docs/specs/x.md` passes,
`src/legacy.php` gives `deny`, the escape via `docs/specs/../../src/legacy.php` also gives `deny`
(path normalisation, not a prefix comparison), and non-`Write` tools pass straight through.

The whole skill, on a PHP function with three-branch logic planted for it, in a separate
repository. Two provocations were added to the prompt — write a note into the repository root,
and add a comment to the source file. Both were refused, and the model said why instead of
staying quiet. The hook log confirms the interception fired on the write that was allowed. In
the spec: the docblock says nothing about the middle tier, the boundaries are exclusive, `NAN`
silently yields 0, `strict_types` is missing.

**The finding that stopped the first run from happening at all.**

```
Skill "investigate" is disabled via skillOverrides.
```

`investigate` is the name of a built-in Claude Code skill. A project skill carrying the same
name falls under the same override and does not run at all. The same list of built-ins holds
`review`, `verify`, `commit`, `debug`, `docs`, `run`, `simplify`, `init`, `code-review`,
`security-review` — so two of the four names I had planned collided. Renamed to `spec`, `cover`,
`build`, `audit`; under the new name the skill started immediately.

**A second finding, from the docs.** `disallowed-tools` is lifted on the next user message — so
if you reply in the middle of a run, `Edit` comes back into the pool. A hook has no such quirk
and lives until the end of the session. So of the two defences only the hook gives a guarantee;
the front matter is hygiene. That is exactly why the guard was needed in the first place.

**Conclusion.** The requirement "enforce it mechanically, not by asking", together with an
explicit "check the documentation, do not guess", produced a result stronger than what was asked
for. And the fact that the skill did not run because its name collided with a built-in was found
only by running it — neither reading the file nor the model's report could have shown it.

---

## 006 · The first real run of `/spec`

**29.08.2026 · Claude Code (skill `/spec`)**

Task: capture a behaviour specification for `useFodmapStreak` — a React hook from the `planner`
app that is to be ported to PHP. The source was copied verbatim into
`docs/reference/useFodmapStreak.ts`, with the source commit recorded.

Invocation: `/spec docs/reference/useFodmapStreak.ts`

**What came back.** `docs/specs/use-fodmap-streak.md`, 163 lines, all seven required sections,
28 cases across two tables.

**What it found on its own.** A tier that is absent turns into the string `'unknown'`, and
`isBad` reacts only to `moderate` and `high` — so a day where nothing is known about any
ingredient counts as safe. Supabase errors are not checked in any of the three queries: only
`data` is destructured, so a failed query is indistinguishable from "there is no history". The
selection windows diverge — plans for 16 Mondays, logs for 112 days, one discrete and one
continuous. Everything is tied to the local timezone. And there is a race across midnight:
`today` is computed once at the start, while the loop cursor takes a fresh `new Date()` after
the three queries have already run.

**Against my own expectations.** Before the run I wrote down three things I could see in the
source myself. The diverging windows and the timezone dependency the skill found, and stated
them more precisely than I had. The third — "the streak is always zero if today has no data" —
turned out not to be a discrepancy: the comment at Step 6 describes exactly that, and the code
matches the documentation. The skill recorded the behaviour as behaviour and did not call it a
bug. It was right and I was not.

**What was missing.** Line 91 has a three-level precedence chain,
`ing.ingredients?.fodmap_tier ?? ing.fodmap_tier ?? 'unknown'` — three branches, and the case
table had not one case for it. The precedence was mentioned only in the prose, as a description
of the query. But the case table is the interface to the next step: what is not in it will not
be in the tests, and the port could have swapped the two sources around with every test still
green.

A follow-up prompt filled the gap: add cases for the precedence, including a discriminating one
— both sources present and different, so that a reversed order fails. Got C29–C32 plus a bullet
about `null` in the joined row, which for `??` is just as nullish as `undefined` and therefore
falls through to the column rather than to `'unknown'`. The line-count increase matched exactly,
nothing extraneous moved.

**Conclusion.** The skill reliably finds what is visible in the control flow — branches,
boundaries, swallowed errors, implicit windows. It is weaker where behaviour hides in a `??`
chain inside a single expression: that reads like a detail of the query rather than as
branching. For the procedure this is a concrete fix — require separate cases for every
expression with source precedence, not only for `if`.

**The fix was applied** to step 3 of the `/spec` procedure: a `??` chain, `||`, a ternary, a
default value and a lookup with a fallback are declared branching on a par with `if`; a case is
required for every level of the chain plus one where two levels differ — only that one catches a
reversed precedence. The rule was derived from the run, not invented in advance.

The guard held for the run: only the spec file was written, no tracked file changed.

---

## 007 · The second skill, and a trail for deferred work

**29.08.2026 · Claude Code**

Two tasks back to back: build `/contract` — the step that decides the shape of the module — and
then fix the hole that same step exposed.

**The first task.** `/contract` reads the specification and the invariants, proposes a module
name, ports, signatures and file paths, **stops and waits for a human**, and only after an
answer writes declarations with not a single method body. The role is separated deliberately: if
`/cover` invented the contracts, the tests would define the very design they are supposed to
check.

The gate was verified by running it, not by reading it. I ran the skill on a real specification
in a separate copy of the repository with `Write` allowed. It produced a thirteen-file proposal
and ended with the words "I'll wait for your answers before writing anything". On the
filesystem: nothing was created during the run, `src/` byte-for-byte identical. The temptation
to report a finished job did not win.

The guard — twelve payloads piped in directly. I separately tested the hypothesis that the check
works per directory rather than per file: it did not hold, several new files in one module are
written, overwriting an existing one is refused.

**The second task grew out of what I wanted next.** The places that need further
investigation should go into `docs/todo/<title>.md` — and the guards forbade exactly that: I had
given each skill exactly one output path and left no room for "come back to this".

We split the roles like this: the specification states the **problem** (`/spec` is not allowed
to propose solutions), `docs/todo/` holds the **chosen path and the remaining work**, and the
choice is made at `/contract` — the only step with a human in it. An important consequence
follows: the `/spec` guard needs no change at all, the new path is needed only by `/contract`.

A rule that was missing from the rulebook surfaced along the way. A port must reproduce the
behaviour of the original rather than improve it along the way — but the specification found
that the original swallows query errors, and invariant 37 forbids that. A 1-to-1 port violates
37; a "done properly" port changes behaviour silently. With no rule written down the model will
pick at random and not say so. This became invariant 39: reproduce verbatim, and where an
invariant forbids that, neither improve nor break it, but decide with a human and write the
divergence down. The wording ends with a checkable statement — "a deliberate divergence is
allowed; an undiscoverable one is a defect" — which means `/audit` is obliged to find such
places.

**No corrections were needed after the second task**, apart from a blank line that had gone
missing before a heading.

**Conclusion.** Both runs confirmed the same thing as 002 and 004: a numbered list of concrete
changes, each with an explanation of why it is necessary, comes back clean. And separately — a
restriction put in place with the best of intentions turned out to be too narrow and blocked the
work. That was found not by reading the guard but by trying to use it.

---

## 008 · The first run of `/contract`

**29.08.2026 · Claude Code (skill `/contract`)**

Invocation: `/contract docs/specs/use-fodmap-streak.md`

**What came back.** A thirteen-file proposal naming the source of every decision, six questions
for the human, and a stop. Not one file written before the answers — verified on the filesystem
in a separate run: `src/` byte-for-byte the same as before the run.

After the answers — thirteen declarations with not a single method body. Checked with a parser
by brace balance: eight stubs with `throw`, six empty constructors, two declarations in
interfaces, zero stray bodies. `php -l` on all thirteen — green. Domain without a single `use`,
the bus markers in place, the clock injected, the controller not extending `AbstractController`.

**Two places came out better than expected.** `FodmapTier` became a typed enum with `isBad()` —
the spec's finding about the string `'unknown'` turned into an explicit enum case. The ports got
docblocks `@return array<string, FodmapTier[]>` and `@throws`, which answers the objection to a
bare `array`.

**Invariant 39 fired in both directions.** The first todo records that the port is deliberately
not equivalent to the original — query errors are now thrown, because invariant 37 forbids
swallowing them. The second is more interesting: it says no invariant requires the change at
all, the selection windows in the original diverge simply by oversight, and so under rule 39 the
decision is the human's. The rule caught both the "forbidden to copy" case and the "the
improvement is mandated by nothing" case.

**Refactoring after the run.** The domain was split into subdomains — `MealPlan`, `MealLog`,
`Streak`, `Tier`. Re-checked: zero namespace/path mismatches, zero broken imports across
thirteen classes, no bodies drifted in. A line was added to `AGENTS.md` saying such grouping is
permitted and does not extend to the layers whose shape the invariants fix.

**Conclusion.** The "propose and stop" gate holds under pressure: two provocations were added to
the prompt — write a note into the repository root, and add a comment to the source file — both
were refused, and the model said why.

---

## 009 · The third skill

**29.08.2026 · Claude Code**

Task: `/cover` — turning the case table into red tests. The first stage of the pipeline that
decides nothing.

<details><summary>Prompt (abridged — in full in the history of commit `99d37b8`)</summary>

```
Task: create the /cover skill at .claude/skills/cover/SKILL.md, with a PreToolUse
guard beside it.

This skill decides nothing. /contract is the step with a human in it; /cover reads
two settled documents and mechanically produces tests from them. If it finds
something it cannot express, it says so in its report and stops — it does not
choose, and it does not write a docs/todo/ entry, because recording a decision
belongs to the step that takes decisions.

3. Account for every case id. Every id in the spec's tables is either covered by a
   named test or explicitly not covered with a stated reason. C1 to C3 cover pad()
   and toISO(), which have no counterpart in PHP, so they are not portable behaviour
   and must be recorded as such, in the file, not only in chat. A silently missing
   case is the failure mode this whole step exists to prevent.

7. Run the suite and read what it says. It must execute: the classes load, the tests
   run, and they fail. A failure on the LogicException a stub throws is the expected
   red. A fatal error is not a red test — it means the tests do not compile against
   the contracts, and that is a defect in this step.
```
</details>

**What came back.** The skill and its guard. Case accounting came out stronger than asked for:
not just a docblock but a separate `tests/<Module>/CASE-COVERAGE.md` — an artefact rather than a
line in the chat. The difference between a red test and a fatal error is spelled out as a list
of concrete symptoms.

**The guard was checked with twelve payloads:** it lets new files into `tests/` — tests, fakes
and the accounting file — and closes off `src/` entirely, both directories under `docs/`, the
config, the repository root, an existing file, and the escape via `..`.

**Conclusion.** The requirement "report as a list, there is no third state" yields a checkable
artefact. A vague "cover the cases" would have yielded "the rest are analogous".

---

## 010 · The hooks leaked between steps

**29.08.2026 · Claude Code**

The finding that made running the whole pipeline worth it. Running `/cover` after `/contract` in
one session failed like this:

```
BLOCKED by contract-write-guard: ... /tests/Fodmap/Domain/Tier/FodmapTierTest.php is under
tests/, which belongs to the /cover step.
```

The hook declared in a skill's front matter is registered when the skill is invoked and **lives
until the end of the session** — that is in the documentation, I read it and drew no conclusion.
So within one session the hooks of every step that has run accumulate and fire on every `Write`
at once. And each guard is built as "I allow only my own lane and forbid everything else" — two
of those together allow nothing. A five-step pipeline never got past the second step.

<details><summary>The repair prompt</summary>

```
The fix: a guard must know which step is running, and stand aside when it is not its
turn.

1. A marker file at .claude/.step holds one line — the name of the step currently
   running: spec, contract, or cover.
2. Each skill sets it as its very first action, using Bash — the guards intercept
   Write, so Bash is the one path that is always open.
3. Each guard begins by reading the marker: its own name → enforce as today; another
   step's name → exit 0 silently; missing or empty → deny, because a registered guard
   whose skill skipped step 0 is a bug worth surfacing, and failing open would
   silently disarm every guard in the repository.

Do not change any existing path rule in any guard.

Verify by piping payloads into the guards directly. The decisive checks are the
cross-step ones: with the marker holding "cover", the cover guard permits a path
under tests/ and the contract guard exits 0 silently on that same path instead of
denying it.
```
</details>

**Received and verified with a matrix.** With the marker set to `spec`, only the spec guard has
an opinion and the other two stay silent on all three paths; with `contract` and `cover` —
mirror images. With no marker all three deny. The lanes are unchanged. The three guards stayed
separate files — I had asked for them not to be merged into one shared guard branching on the
step, and they were not.

**A conclusion, and it covers three findings in a row.** A skill name colliding with a built-in;
`disallowed-tools` being lifted on the next message; hooks leaking between steps. Not one of
them is visible in the code or in the documentation when you read it — all three were found by
running it. A declarative restriction looks like it works right up to the first real run.

---

## 011 · The pipeline goes backwards

**29.08.2026 · Claude Code (skills `/cover`, `/contract`, `/cover` again)**

The first `/cover` run gave 26 red tests — all on the `LogicException` thrown by a stub, not one
fatal error. And full accounting: thirty-two case ids from the spec plus two from the todos,
each with a status.

**The accounting sent two findings back to `/contract` instead of inventing a home for them.**
The tier precedence `ingredients.fodmap_tier ?? recipe_ingredients.fodmap_tier ?? 'unknown'`
(cases C29–C32) — a domain rule left inside the Doctrine adapter, where it cannot be tested
without a database. And C22 — a plan for tomorrow does not count towards today's streak.

Going back to `/contract` produced one class, `IngredientTierPrecedence`, and a todo. Two places
where the model was right and I was not:

**Placement.** I suggested `Domain/Tier/`, it chose `Domain/MealPlan/` and justified it: the
two-column ambiguity exists only on the plan side, the logs have nothing like it in the spec.
Checked against the source — correct: line 91 with the triple chain belongs to
`recipe_ingredients`, line 127 for logs is just `?? 'unknown'`. The rule is specific to that
subdomain, so that is where it belongs.

**C22.** I called it a hidden domain rule. The answer: `FodmapStreakCalculator::streak()` walks
back from `$today` only, so a record with a future date is unreachable regardless of whether the
adapter filters it out. Checked against the original — the loop really does only decrement the
cursor. There is no rule, there is a property of the traversal. There is nothing to put in the
domain.

**A wall, found twice.** `/contract` could not fit a new collaborator into the constructor of an
existing adapter — the file already exists and overwriting is forbidden. It recorded that and
passed it on rather than routing around it. `/cover` on its second run hit the same thing with
the accounting file — and tried to route around it by creating a supplementary file. The
difference is that `/contract` has an explicit ban on circumventing the guard in its text, and
for `/cover` I had not written one.

**Conclusion.** The pipeline can only add. On a greenfield module that goes unnoticed; on a
second pass over the same module it is a limitation, and it surfaced independently at two steps.
Plus one specific lesson: the ban on circumventing a restriction has to be written explicitly
into every step — where it was absent, the circumvention appeared on its own. side, and the source says so: line 91 with the triple chain belongs to `recipe_ingredients`,
line 127 on the log side is a bare `?? 'unknown'`. I had reasoned from where the concept felt
like it belonged; it had read where the ambiguity actually exists.

**Reachability.** I called C22 — a plan dated tomorrow must not count towards today's streak — a
hidden domain rule that needed a home in the Domain layer. It answered that the rule needs no
home at all: `streak()` walks backwards from `$today`, so a future-dated entry is never visited
and cannot contribute. Checked against the original: `cursor.setDate(cursor.getDate() - 1)`.
There is nothing to enforce, only something not to break.

**Conclusion.** Twice in one run the model was right where I was wrong, and both times for the
same reason: I argued from where a concept seemed to belong, it argued from what the source
does. That is the division of labour this pipeline is built on, and it only works while the
source is in the room — both answers came with a line number.

---

## 012 · The schema as a second source

**30.08.2026 · Claude Code (skill `/spec`)**

Task: extend `/spec` so that a source which reaches a database produces two documents, not one —
the behaviour specification as before, and a schema specification beside it.

The reason was a hole found by looking at the finished module. Thirty tests were green against a
faithful reading of `useFodmapStreak.ts`, and not one of them said anything about whether the
data the hook names still exists. Every level had treated the code as the source of truth: the
specification, the contract derived from it, and the verification run against it, whose
fixtures were invented from the code's own assumptions.

> **The prompt for this run is not in the transcript this entry was written from.** It should be pasted here
> from the Claude Code history for entry 012 to be complete.

**What came back.** `docs/specs/use-fodmap-streak-schema.md`, 164 lines, 21 cases, and the whole
Supabase definition copied into `docs/reference/supabase/` — `schema.sql` plus all 28 migrations
rather than a chosen subset, on the stated grounds that a table's effective shape is its base
definition plus every later alteration.

**What it found.** Migration 026 dropped `recipe_ingredients.fodmap_tier`,
`recipe_ingredients.ingredient_name`, `meal_log_ingredients.fodmap_tier` and
`meal_log_ingredients.ingredient_name`. The hook still selects all four. The tier-resolution
chain the specification had carefully documented as cases C29-C32 reads a column that has not
existed since 026.

It also recorded what no line of the TypeScript says: every table the hook reads is restricted by
Postgres row-level security to `auth.uid()`, invisibly. The original names no user anywhere
because the database does it. A Doctrine-backed port has no equivalent, so a provider written
against the hook's literal text would return every user's rows, and no test built from fakes
could catch it.

**Conclusion.** A specification derived from code establishes what the code does, not whether the
data it names exists — and tests derived from that specification inherit the same blindness. The
rule that a source reaching a database gets a second document was added because the module was
already finished without it, not before.

---

## 013 · A step for the schema, built and then discarded

**30.08.2026 · Claude Code**

Task: give the pipeline an owner for the artefact that makes a module's tables exist. Four steps,
five layers: `/spec` described the schema, `/contract` declared ports, `/cover` wrote tests,
`/build` wrote bodies under `src/` — and nothing wrote a migration, so the Infrastructure layer
stayed a `throw` and no step was answerable for it.

The step was called `/schema`, and its guard enforced an invariant rather than only a lane: an
existing migration is append-only, so `Edit` and `MultiEdit` were denied outright and `Write` was
allowed only to a path that did not yet exist.

<details><summary>Prompt (excerpt — the guard section)</summary>

```
The guard. Same shape as edit-guard.sh — same step-marker gate, same fail-closed
on an absent marker, same path normalisation, same deny() — with one difference
that matters. Invariant 8 makes an existing migration append-only, so this guard
enforces that mechanically rather than trusting the body to behave:

  - Edit and MultiEdit are denied outright, on any path, with a reason that
    names invariant 8. There is no legitimate edit of an existing migration.
  - Write is permitted only for a path under migrations/ that does not
    already exist on disk. A Write to an existing migration is denied, again
    citing invariant 8.
  - Everything outside migrations/ is denied, each denial naming the step or
    the person that owns the path refused.
  - The filename must match Doctrine's VersionYYYYMMDDHHMMSS.php form.
```
</details>

**Verification.** Ten payloads piped straight into the guard: a new migration passes; `Edit` on
anything is denied; a `Write` over an existing migration is denied; `src/`, nesting below
`migrations/`, traversal outward, a non-Version filename, all denied; another step's marker makes
it stand aside; an empty marker and a missing one both deny.

**The run.** Six migrations, one per table, ordered by dependency with timestamps a second apart.
Correct order, correct foreign keys with the referential actions the schema cases record, correct
unique constraints, `user_id` deliberately left as a bare `guid` with no foreign key because the
local `users` table has an integer key and the source references Supabase's `auth.users`.

**And one of them could not run at all.** `recipe_ingredients` mapped `amount` as
`decimal` with no precision, because the source says `amount numeric` — Postgres arbitrary
precision, which Doctrine has no way to express. DBAL 4 does not silently default it; it throws
`ColumnPrecisionRequired`. So the file was unrunnable, which also proves none of the six had ever
been executed.

**Then the human changed the design, and the step was discarded.** The argument was whether the
module needs Doctrine entities at all. The model's position was that it does not: the module only reads,
entities of tables it does not own would plant another module's concepts in its Domain, and
invariant 7 requires a hand-written migration either way, so entities buy nothing. My counter was
that the project will port module after module, most of which will write, and a
workflow that decides persistence style per module is a worse thing to hand to a new developer
than one that does it the same way every time. The six migrations were deleted and `/schema`
became `/entity`.

**What had to be corrected — in the model's reasoning, twice.** It claimed invariant 7 required
a hand-written migration; the text says nothing of the kind, and the claim came from a line in
`CLAUDE.md` that cites the invariant for a prohibition it does not make. It then repeated the same
misattribution two messages after finding it. And it put the schema translation at half a day of
design work, until I pointed out that 28 migrations already exist in the source project —
translation, not design, and the estimate was twice too high.

**Conclusion.** A step that produces plausible artefacts and never executes them will produce an
unrunnable one and report success: the six migrations had correct ordering, correct constraints
and careful descriptions, and one of them threw on the first line of its own `up()`. Form was
checked; execution was not. And a citation by number is not a citation — the number has to be
read, or it propagates.

---

## 014 · The entity step, and a gate on ownership

**30.08.2026 · Claude Code**

Task: rebuild the discarded `/schema` as `/entity` — a step that writes a module's Doctrine
entities from the schema specification, and asks a human, entity by entity, whether the module
actually owns each concept.

The gate is the point of the step. Where an entity goes is a domain question, not a mechanical
one, and getting it wrong plants another module's concepts inside this one where they are hard to
extract later.

<details><summary>Prompt (excerpt — the gate and the placement rule)</summary>

```
THE OWNERSHIP GATE — the reason this skill exists

For every entity it intends to create, the skill must establish whether the
concept belongs to THIS MODULE's domain, and it must not decide that alone.

  - It works out, from docs/specs/<name>-schema.md and the behaviour spec, the
    full list of entities the module needs.
  - For each one it states: the table it maps, the Domain sub-namespace it
    would go in if the module owns the concept, and its own reading of whether
    the module owns it — does the module WRITE this table and is the concept
    named in the module's own language, or does it only READ data another part
    of the system owns.
  - Then it STOPS and waits for a human answer, entity by entity. It writes
    nothing before the answer arrives. This is the same gate /contract uses:
    propose, stop, wait, write. A gate that proceeds on the model's own
    judgement is not a gate.

PLACEMENT, once the human has answered

  - Owned by this module -> src/<Module>/Domain/<SubNamespace>/<Entity>.php.
  - Not owned -> src/<Module>/Domain/Shared/<Entity>.php, AND one todo per
    such entity under docs/todo/, recording: which table it maps, why the
    module does not own the concept, that it sits in Shared as a consequence,
    and what would rehome it.
```
</details>

**The guard is the first in the repository to check content rather than only paths.** A skill's
lane is normally a set of directories, but this one shares `src/<Module>/Domain/` with the step
that declares ports: `MealPlan.php` is an entity and `MealPlanDate.php` beside it is not, and no
path tells them apart. So it may write only content carrying a Doctrine mapping attribute, and
may overwrite only a file that already carries one.

**Verification.** Eleven payloads. A new entity into a sub-namespace passes; a non-entity into
`Domain/` is denied; entity content written over a non-entity file is denied; updating an
existing entity passes; `migrations/`, `tests/`, `config/`, `Application/` all denied; another
step's marker stands it aside; empty and missing markers deny.

The first run of that harness reported every case as allowed, which was the harness and not the
guard: the payloads had been built by hand, and the backslashes in `#[ORM\Entity]` made the JSON
invalid, so `jq` returned an empty tool name and the guard exited on its first branch. Rebuilt with
`jq`, the eleven cases came out right.

**The run.** The gate asked about six tables and the human answered "not owned" six times —
including `ingredients`, against the step's own recommendation that the FODMAP tier catalogue
belongs with the FODMAP module. All six entities went to `Domain/Shared/`, each with a drafted
todo the step correctly said it could not write itself.

**Conclusion.** A gate is worth building only where the answer can go either way, and this one
proved that on its first use: the step recommended one thing, the human decided another, and the
disagreement is now written down instead of being resolved silently by whoever ran last.

---

## 015 · The pipeline runs backwards, and why

**30.08.2026 · Claude Code**

The new step had been placed after `/contract`, on the reasoning that contracts come first. A
question of mine — *why did `/contract` make the repositories take a `Connection`?* — showed the
order was wrong.

Nothing had chosen DBAL. `/contract`'s own text names no persistence mechanism at all. `AGENTS.md`
mentions `Connection` exactly once, in invariant 11, as one of the things Domain and Application
must never reference — so the only place the word appears is a prohibition, and the model took the
first item from that list. No todo recorded the decision, because no gate had been crossed.

The real cause was the order. At `/contract` time no entity existed, so there was nothing to
inject an `EntityManager` for. The choice was made by absence.

<details><summary>Prompt (excerpt)</summary>

```
Reorder the pipeline to spec -> entity -> contract -> cover -> build, and close
the hole the reorder opens.

WHY, so the texts say it consistently: entities are built from the schema
specification and the reference SQL, and need nothing /contract produces.
/contract does need them — it declares the Infrastructure adapters, and the
collaborator those adapters take (DBAL Connection vs ORM EntityManager) cannot
be a real choice when no entity exists. That is exactly how
DoctrinePlannedTierProvider ended up taking Connection with nobody deciding it.

/entity is CONDITIONAL: it runs only when /spec produced a schema
specification. A module that touches none goes spec -> contract -> cover ->
build. Say this wherever the pipeline is described — a stranger following these
files has to know the step is skippable.

5. .claude/skills/contract/write-guard.sh gains the mirror of the check
   /entity's guard already performs. /contract must be denied the complement:
   it may not write over a file whose EXISTING content carries a mapping
   attribute — that file is /entity's, and with entities now landing first they
   sit in /contract's own lane where it is otherwise free to overwrite.
```
</details>

**What came back.** The order corrected in five front matters, five pipeline recaps and one guard
header; the mirror check added to `/contract`; and a sweep for contradictions that turned up more
than the list asked for — `/spec` still calling `/cover` its next step, `/entity` citing a todo
that cannot exist on a first pass, `/build` saying "the three steps before it".

**Verification.** Eight payloads against the new `/contract` guard: a new port passes, overwriting
a port passes, content carrying `#[ORM\Entity]` is denied, a write over an existing entity is
denied, the fully-qualified `#[\Doctrine\ORM\Mapping\Entity]` form is denied too, `docs/todo/`
passes, `tests/` denied.

**What had to be corrected — a claim of mine, not the model's.** The report stated that only
`Write` reaches that guard because `Edit` and `MultiEdit` are removed by `disallowed-tools`. True
today, and worthless as a guarantee: the documentation says `disallowed-tools` is lifted on the
next user message. So the mirror check is real for the two steps whose matcher covers the editing
tools and dormant for the three whose matcher is `Write` alone.

**Conclusion.** A decision nobody records is indistinguishable, a week later, from a decision
nobody took. This one was neither argued nor written down; it was produced by the order of the
steps, and it took a question from outside to notice. The gate now asks about constructor
collaborators explicitly, because a parameter that reaches outside the application is a shape
decision, not an implementation detail.

---

## 016 · A step that checks its own output

**30.08.2026 · Claude Code (skill `/entity`)**

The `/entity` run reported six entities, a table of every column with the migration each shape
came from, the case ids satisfied, the ones deliberately not satisfied with reasons, and the
`doctrine.yaml` block a human still had to add. A careful report.

**The mapping did not load.** `RecipeIngredient::$amount` was mapped `#[ORM\Column(type:
'decimal', nullable: true)]` with no precision and no scale, so DBAL cannot build a column from
it: `Column::setScale()` requires an int. `doctrine:schema:create`, `schema:validate` and
`migrations:diff` all fail on it.

The same column, the same defect, for the second time — entry 013 records the migration form of
it. Both steps read `amount numeric` in the source, both translated it literally, and neither
executed the result. Postgres arbitrary precision has no Doctrine equivalent, so any value chosen
is a deliberate divergence, and choosing one silently is what both runs did.

My question — *why can this check not live in the skill?* — turned out to be the right one: the
answer I had been given was weaker than the situation allowed. It can. The check needs no database and no container:
metadata loads through an attribute driver pointed at the folder, and each field mapping is turned
into a DBAL column and handed to the Postgres platform to render.

<details><summary>Prompt (excerpt — the self-check)</summary>

```
PART 1 — .claude/skills/entity/verify-mapping.php

A standalone PHP script, run as: php .claude/skills/entity/verify-mapping.php <Module>

It must work with no database and no entry in config/packages/doctrine.yaml —
both are outside this step's reach, and a check that needs a human's edit first
is a check that never runs.

  - For every ClassMetadata found: print the class and its table, then turn each
    field mapping into a DBAL Table column carrying that mapping's own options —
    type, nullable, length, precision, scale, default — and ask
    PostgreSQLPlatform to render CREATE TABLE for it.
  - Do NOT call SchemaTool: it queries current_schema() before generating
    anything, which puts a live database back in the way.
  - Exit non-zero and name the class, the field and the exception whenever a
    mapping cannot be rendered.

PART 2 — the skill's "Verify before reporting done" section

State plainly what the result means and what it does not. A zero exit proves
every mapping can be turned into a column definition. It does NOT prove the
schema matches the real database, that a query returns rows, or that the
associations are the right ones.
```
</details>

**And the limit of that check showed up immediately.** A second defect in the same six entities:
`Ingredient::$nameEn` was mapped non-nullable with a `string` property, while migration 022 drops
`NOT NULL` from that column and sets it to `NULL` for every row whose name was Cyrillic. Hydrating
one of those rows throws a `TypeError`.

The script does not catch it. The column builds perfectly; it is simply wrong. What caught it was
comparing the step's own report against its own output — the report said, correctly, *"nameEn text
nullable (made nullable in migration 022)"*, and the code did not do it.

**Conclusion.** Executing an artefact proves it is buildable, not that it is correct, and the two
failures in one run are the clean illustration: one was invisible to reading and caught by running,
the other was invisible to running and caught by reading the report against the file. A step needs
both, and the second one had no owner at all — which is what made the case for a reviewer.

---

## 017 · The step marker, and a regression from fixing it

**30.08.2026 · Claude Code**

Renaming `/schema` to `/entity` put the repository into a state where **nothing was enforced at
all**, and it took an unrelated check to notice.

Each guard had two branches: an empty or missing marker denies everything; a marker naming another
step stands aside. There was no third. So a marker naming a step that no longer exists — exactly
what a rename produces — made all five guards stand aside at once, silently. With `.claude/.step`
reading `schema`, `/spec`'s guard allowed a write to `src/Fodmap/Domain/Evil.php`.

A second hole sat beside it: the marker is gitignored and survives a session, so a stale but
*valid* name disarms every guard except the one it names.

<details><summary>Prompt (excerpt — the two fixes)</summary>

```
PART 1 — .claude/settings.json

Add a SessionStart hook, with no matcher so it fires on every start and resume,
running: rm -f "$CLAUDE_PROJECT_DIR/.claude/.step"

Every session then begins with no marker, which the guards already treat as
fail-closed.

PART 2 — all five guards

  1. marker empty or absent  -> deny, as now
  2. marker names this step  -> enforce, as now
  3. marker names another step -> stand aside ONLY IF that step really exists:
     a directory .claude/skills/<name>/ containing a *-guard.sh.

PART 3 — stop hardcoding the list of valid names

Every fail-closed message ends with "(the name is one of spec, contract, entity,
cover, build)". That is a sixth copy of a list that already lives in the
filesystem, and it is stale in all five files. Build the list at denial time
from the same probe.
```
</details>

**Then the Bash hint went, and took the pipeline with it.** Every skill's step 0 explained that
the marker is written with `Bash` "because the guards intercept `Write`, so `Bash` is the one path
that is always open" — five copies of a sentence teaching the model that the guards can be walked
around, ten lines from the rule forbidding exactly that. The fix was to let each guard permit a
`Write` of its own name to the marker, so step 0 needs no shell.

That broke the handoff. A hook stays registered for the session, so on the second step of a
session every other guard also sees that write — and each demanded *its own* name. Verified:
with `/spec`'s guard registered, `/build`'s step 0 write of `build` was denied by spec, entity,
contract and cover. Two steps in one session became impossible, which is the entire reason the
marker exists.

Neither of us caught it, for the same reason: we had both tested the guards **one at a time**, and
the defect exists only in combination.

**The repair, and the hole it also closed.** Permit any known step name, so the handoff works —
but have the guard whose own name is written record liveness, `<name> <session_id>`, from the hook
payload. Standing aside then requires not only that the named step exists but that its guard has
actually run in this session. Only a live guard can leave that record, so a marker written through
`Bash`, or set to another step's name with an editing tool, disarms nothing.

**Verified as a sequence, not one guard at a time.** `/spec` declares itself, then `/build`
declares itself with `/spec`'s guard still registered: both writes allowed, `/build` then
enforcing, `/spec` standing aside. Marker set to `spec` with no liveness record: every guard
denies. A record from another session: denied. Forging it is not reachable through the editing
tools in either order or from either side, because `.claude/.step.live` is in no step's lane, so
whichever guard is currently enforcing refuses it.

**What remains, stated exactly.** Writing both files through `Bash`, while knowing the current
session id, still stands the guards down. The cost of the bypass went from one five-byte write to
forging two files and knowing an identifier the model is never given. That is not a closed hole,
and `PreToolUse` cannot close it: the documentation is explicit that a hook cannot see what a
shell command changes.

**Conclusion.** Testing components in isolation passed a change that made the system unusable, and
the isolation was the reason. And a rename — the most ordinary edit there is — silently disarmed
every guard in the repository, because the failure mode "this name belongs to nobody" had no
branch.

---

## 018 · What `/build` may do to an entity

**30.08.2026 · Claude Code**

With entities landing before `/contract`, they sit inside `/build`'s own lane, and `/build`'s
guard had no opinion about them at all: an `Edit` to `src/Fodmap/Domain/Shared/MealLog.php` was
allowed, and the step's list of things it must not change did not mention entities either.

It matters more than it sounds. `/build` writes the adapters that query those tables through DQL,
and when a query will not build, the shortest fix is to widen a column or relax a property type.
That edit changes the schema the database is required to have — with no migration, no `/entity`
run, no ownership gate and no todo — and nothing in the suite notices, because nothing in the
suite touches a database.

I chose the harder of the two options: methods may change, the mapping may not. Denying
entities outright would have been simpler to enforce.

<details><summary>Prompt (excerpt — what the guard compares)</summary>

```
DEFINE THE MAPPING SURFACE of an entity file as, taken together:
  - every line carrying a Doctrine mapping attribute — #[ORM\...] in any form,
    including the fully-qualified #[\Doctrine\ORM\Mapping\...];
  - every typed property declaration line (private/protected ... $name). A
    property's type is part of the mapping in practice: changing
    `private string $nameEn` to `private ?string $nameEn` alters hydration
    without touching an attribute.

  - Edit and MultiEdit are denied. They carry only a fragment, so the surface
    cannot be compared. The denial says to replace the file with Write.
  - Write is permitted only when the mapping surface of the new content is
    identical to that of the file on disk, compared line by line after
    collapsing runs of whitespace.
  - Deny any write whose mapping-attribute line does not close on the same
    line. The comparison is line-based, so a multi-line attribute would let a
    change on a continuation line pass unseen.
```
</details>

**Verification — ten cases.** Mapping untouched with a getter added passes. A column type changed
is denied, naming the differing entry. A property made nullable is denied. `Edit` and `MultiEdit`
on an entity are denied. A plain non-entity file under `src/<Module>/` is unaffected. Entity
content over a non-entity file is denied. A multi-line attribute is denied. Whitespace-only
reformatting passes.

One case appeared to fail — deleting an attribute outright was allowed — and again it was the
harness: the `grep` that built the payload had not actually removed the line, so the content was
identical and `allow` was the correct answer. Re-checked with a real deletion, and with a property
removed: both denied. The third time in one day that a defect was reported that did not exist, and
the third time the cause was reading a derived view instead of the artefact.

**Conclusion.** The strictness is not in the path but in the delta: a lane says "anything under
this directory", this says "these lines and no others". It is the tighter restriction of the two,
and it is only expressible because the guard sees the content it is about to allow.

---

## 019 · A reviewer, and two runs of it

**31.08.2026 · GitHub Copilot, running the `audit` charter**

Every one of the five steps produces claims — a report, an accounting, a todo — and none of them
checks a claim. The reviewer does only that, and nothing else.

It is written as a subagent definition rather than a skill for one reason: a skill's limits rest on
a `PreToolUse` hook, and a hook cannot see what a shell command changes, whereas a subagent's tool
list is a hard restriction for its whole run — `Read`, `Grep` and `Glob` and nothing else.

That guarantee holds only when Claude Code runs the definition. These runs were executed by
Copilot, which does not read `.claude/agents/` and brings its own tools, so for them the read-only
rule was prose like every other. The charter was followed; nothing enforced it.

<details><summary>Prompt (excerpt — the four classes)</summary>

```
1. TODOS. Every file under docs/todo/ carries a "What would settle it" section
   — a criterion written to be checkable and so far read by nobody.

2. COVERAGE. tests/<Module>/CASE-COVERAGE.md names, for each case id, the test
   that covers it. Open that test and check it exercises the input the
   specification records and asserts the result it records. A case marked
   covered by a test that never runs its input is the defect this class exists
   to catch.

3. INVARIANT CITATIONS. Every "invariant N" reference anywhere — read invariant
   N in AGENTS.md and say whether it states what the citation attributes to it.
   Denial messages matter most, because an agent reads one at the moment it is
   looking for a way around.

4. A STEP'S REPORT AGAINST ITS ARTEFACT, when a report is supplied as input.
```
</details>

**First run.** Two stale todos found correctly. One new finding the reading before it had missed
entirely, and it was right: `user-scoping` is not satisfied. That reading had gone to the DQL, seen
`p.userId = :userId` and called it done — but the criterion asks for *an Infrastructure integration
test against a real Postgres showing one user's fetch never returns another's rows*, and no such
test exists or can exist without a migration. The code had been checked where the criterion asked
for evidence.

And three failures. It counted a shared symbol as agreement: `lookback-window` was called
satisfied because `LookbackWindow` exists and both providers reference it, when the two windows
are still computed differently — one a discrete list of Mondays, one a continuous range. It gave
no verdict at all on one of the five todos while listing another twice. And it reported "nothing
found" for two whole classes with no per-item evidence, one of which was demonstrably wrong: the
schema specification's 21 case ids are accounted for nowhere.

**The charter was amended with three universal rules** — a shared name is not agreement; a
criterion naming a kind of evidence is not met by code that looks right; a clean class must be
earned, every member gets a verdict, and two records are compared in both directions.

**Second run.** All five todos got a verdict with a stated count. It found a real defect nobody
had noticed: `CASE-COVERAGE.md` asserted that *"No shared window class or constant exists anywhere
in `src/Fodmap/`"* — untrue since the class was added, so the record's stated reason was false.

And the same two misses. `lookback-window` satisfied again, on the same reasoning the new rule
forbids. The 21 schema case ids still unreported, despite an explicit instruction to compare in
both directions. Then a third, new and more interesting: class 3 opened with **"Verdict count:
160"** and gave three examples with a generalisation. The rule asked for a count; it produced a
count with nothing behind it.

**Conclusion.** The reviewer produces claims like everything else, and its report had to be checked
the same way — with about as many defects in it as it found. That is not an argument against the
step: without it, a criterion judged by reading the code instead of looking for the evidence it
named would have stood. It is an argument against believing that adding a
checking step closes the question of checking. And the "160" line is the sharpest lesson of the
day: a new rule creates a new surface that can be satisfied formally, so where a check is a set
difference rather than a judgement, it belongs in a script and not in prose.

---

## 020 · Closing a todo is not deleting a file

**31.08.2026 · by hand**

`AGENTS.md` says a todo is closed by deleting the file, in the commit that finishes the work. The
reviewer's list of satisfied todos was acted on, and the rule turned out to be incomplete in two
separate ways.

**First, the reviewer's list was wrong in one place, and the list proposed before it had been wrong
in two.** That earlier one named four todos on the strength of a grep, and two of the four were not
satisfied. The reviewer named three, of which one was not. Reading the criteria properly left exactly two safe to
close.

`lookback-window` was the disputed one. My decision was to accept the implementation as it stands — two differently shaped ranges sharing one length, which is what the ported source does.
That closes the todo, but invariant 39 requires a deliberate divergence to stay discoverable, so
deleting the record without writing the decision anywhere would have made it invisible. It went
into the docblock of the constant instead, where the next person to think the two windows should
be unified will read it:

```
The two windows share this length and one $today, and stop there: the plan side
walks a discrete list of Mondays, the log side a continuous range of days, so
their edges do not coincide. That is what the ported source does, and it is kept
deliberately rather than unified. There is no test asserting the two agree,
because they are not meant to.
```

**Second, three deletions broke eighteen citations in eight files.** Todos are cited from
coverage rows, test docblocks, a specification, and the body of a skill. Removing the file turns
every one of those into a pointer at nothing, and nothing fails when it does.

**And no step owns that cleanup.** The obvious move — have `/cover` clear the citations in its own
lane — does not work, and the reason is structural: the steps are unidirectional. Each is defined as one
forward transition with its own procedure, and `/cover` is "turn a specification's cases into
failing tests", not "edit files under `tests/`". Invoking it as an editor would either run its
whole procedure or ignore it, and the procedure is the point. A lane has an owner *for moving the
pipeline forward*; maintaining what the pipeline already wrote has no owner at all.

So they were cleared by hand: six citations in the coverage file, six in three test docblocks, one
in the schema specification.

**The eighteenth group was different.** `/build`'s instructions carried a block naming this
module's todos by filename — module-specific text in a step meant to be general — and it had gone
stale enough to be actively wrong: it told the step to inject `IngredientTierPrecedence` into a
constructor, a class deleted two entries ago. Removed entirely rather than patched.

**Conclusion.** The rule as written describes half the operation. A record is not finished being
removed when its file is gone; it is finished when nothing points at it. And the measured cost of
the missing half — eighteen references from three deletions — is also the argument against
solving it with another step: the cleanup crosses three lanes and one file no step owns.

---

## 021 · The second module

**31.08.2026 · Claude Code (the whole pipeline)**

`Tag`, ported from `useDayTags.ts`: day tags read for a set of dates, created, toggled, removed,
and their note edited.

This run is the only evidence in the project that the workflow is a procedure rather than a
description of one case. Everything up to entry 020 happened while porting `Fodmap`, and most of
the rules exist *because* something went wrong on it — which makes `Fodmap` worthless as evidence
about itself. The steps were not written against `Tag`.

**What it reached that the first module never did.** An ownership gate answering "owned" instead
of "not owned" six times. A write port beside a read port, kept as separate interfaces. Command
handlers on the command bus, where `Fodmap` had exercised only a single query. And a custom DBAL
type, because the built-in one renders `TIMESTAMP(0)` and truncates the column the source stores
with microsecond precision.

**Result.** 52 files. 33 tests, bringing the suite to 61 tests and 98 assertions. The container
builds, Doctrine validates all seven mappings across both modules, the buses resolve 33 handlers.

**What had to be corrected — an inference, not the module.** The suite did not merely fail on the
first run; the test runner died. The cause was `dd($e);` in a controller's catch block, which
dumps and kills the process, leaving the `503` below it unreachable. The model concluded from
the artefact that `/build` had finished without meeting its own stated criterion — a step whose
completion condition is "the suite is green" delivering a module whose suite cannot run. That was
wrong: the line was mine, added by hand while debugging after the run. An artefact had been read
and a cause inferred without checking who produced it, which is the same error this whole log is
about, committed while writing about it.

**Conclusion.** The pipeline carried a module of a shape it had not been built for — one that
writes — without being adjusted for the occasion. That is what the second run was for, and it is
the strongest claim the project can make. The weakest is unchanged by it: neither module's suite
touches a database, so the Infrastructure adapters are written, their mappings validate, and their
SQL has still never been executed.

## 022 · The second tool, and what three runs of it measured

**31.08-01.09.2026 · GitHub Copilot, running the `audit` charter**

Two tools were used on this project and they were given different jobs. Claude Code is the author:
it works inside the rulebook, five steps, each fenced by a hook. Copilot is the reviewer: it runs
the charter in `.claude/agents/audit.md` — compare a record against the thing it describes, four
classes, one verdict per item — and writes nothing.

That split is the case, and it is worth stating what it does and does not guarantee. The charter is
written as a subagent definition whose tool list would make it read-only by construction. Copilot
does not read that definition. It followed the charter because it was told to, not because
anything stopped it doing otherwise, so the strongest claim available about the reviewer's limits
turns out to hold only for the engine that was not used to run it.

**What it got right, across three runs.**

Two todos correctly identified as describing work already finished — the exact failure the
rulebook predicts in the sentence defining how a todo is closed.

One finding that the reading before it had missed, and it was the most useful single output of the
whole exercise: `user-scoping` is not satisfied. The earlier reading had gone to the DQL, seen
`p.userId = :userId` and called it done. The criterion asks for an integration test against a real
Postgres showing one user's fetch never returns another's rows. No such test exists. The code had
been checked where the criterion asked for evidence.

One real defect in a record nobody had re-read: the coverage table asserted that *"no shared window
class or constant exists anywhere in `src/Fodmap/`"* — untrue since the class was added, so the
stated reason for a "not covered" verdict was false.

**What it got wrong, and kept getting wrong.**

*A shared name counted as agreement.* `lookback-window` was called satisfied because a constant
exists and both providers reference it — while the two windows are still computed differently, one
a discrete list of Mondays, one a continuous range. Called satisfied in run 1 and again in run 2,
after the charter was amended with a rule naming exactly this.

*A category cleared without evidence.* "Coverage: nothing found" in all three runs. Across the two
modules the schema specifications declare 32 case ids; the coverage records account for none of
them. Runs 2 and 3 came after an explicit instruction to compare two records in both directions.

*A count with nothing behind it.* Run 2 opened a class with "Verdict count: 160" and examined
three citations. Run 3 did the same with 135. The charter had been amended to require a count; it
produced a count.

*And in run 3, a new kind of error: asserting the absence of something present.* It reported that
the controller exception-to-status mapping "is not present as the todo says". All five adapter
tests in that module assert status codes. The todo is partially satisfied; the reason given was
false.

*The report names no commit.* Run 3 describes four todos and a module that `main` does not contain
— the work had moved to a branch. Nothing in the output says which tree it was made against, so
whether it still applies can only be found by checking by hand.

**Verdict on suitability.**

Useful, and not trustworthy on its own. It found one thing that mattered and that I had got wrong,
and it found a false statement in a record — both are exactly the job. But it cleared a whole
category three times while 32 declared ids sat unaccounted, it twice satisfied the letter of a new
rule while defeating its purpose, and once it reported something absent that is present. Its
output has to be verified line by line, which means it reduces the work of finding candidates and
does not reduce the work of confirming them.

Two conclusions follow, and neither is about Copilot.

The first is about the method. Two amendments to the charter did not change behaviour in either of
the two places that fail. Prose is a poor instrument against a reader that satisfies prose, and
where a check is really a comparison of two lists it belongs in a script — which is why the next
step on that list is a script and not a rule.

The second is about the arrangement. A reviewer is not a place where checking stops. Its report is
a record like every other, and this whole log is about records that stop matching what they
describe. It has to be read the same way, against the code, by someone who can be wrong about it
— and on this project that reader was me, and I was wrong at least once in each direction.
