---
name: spec
description: Establish what an unfamiliar module or file actually does by reading it in full, and write the result as a behaviour specification at docs/specs/<name>.md that the next step turns into failing tests. Use before porting, reworking, or replacing code whose real behaviour has not been established. The guard denies every write outside docs/specs/ and the editing tools are out of the pool; changing code is otherwise forbidden by rule.
argument-hint: [path or module to investigate]
disallowed-tools: Edit MultiEdit NotebookEdit
hooks:
  PreToolUse:
    - matcher: Write
      hooks:
        - type: command
          command: "$CLAUDE_PROJECT_DIR/.claude/skills/spec/write-guard.sh"
---

# Spec

Read the target and establish what it **does** — not what its author says it does. The output is a
specification precise enough that the next step turns its case table into failing tests without
interpreting anything further — one document per source read: the code, and the schema behind it
where the code reaches a database.

## This skill never changes code

`Edit`, `MultiEdit` and `NotebookEdit` are removed from the tool pool by the front matter.
`Write` stays available for exactly one reason: the document.

**The only paths this skill may write are `docs/specs/<name>.md` and, where the source reaches a
database, `docs/specs/<name>-schema.md`.** No file under `src/`, `tests/`, `config/`, `migrations/`,
or anywhere else. A `PreToolUse` hook enforces this and denies any other `Write`; if a write is
denied, that is the rule working, not an obstacle to route around. Not with `Bash`, not by asking
for the hook to be lifted. The guards match the editing tools; a shell command is not
something a `PreToolUse` hook can inspect for the files it changes, so what holds here is the rule,
not the hook.

`<name>` is a kebab-case name for the subject under investigation — the module, class, or file
being read (`docs/specs/legacy-slug-builder.md`), and the schema document is that same name with a
`-schema` suffix. If a spec of that name already exists, read it first and say in the report that
this run replaces it.

## Procedure

0. **Declare which step is running, before anything else.** The guards that keep each step in its
   lane are `PreToolUse` hooks, and a hook stays registered for the rest of the session once its
   skill has been invoked — so in a session where another step has already run, that step's guard
   is still live and still denying every path that is not its own. The marker at `.claude/.step`
   holds one line, the name of the step currently running; each guard enforces when the marker
   names it and stands aside silently when it names another. Declare this step with an ordinary
   `Write` to `.claude/.step`, whose whole content is the one line:

   ```
   spec
   ```

   Every registered guard allows this Write, because the name is a step that exists — that is
   what lets a second step declare itself in a session where an earlier one already ran. This
   step's own guard does one more thing as it allows it: it records in `.claude/.step.live`
   that it is live in this session. That record is what the other guards read before standing
   aside, so a marker written any other way stands nothing down.

   **This is not a formality and it is not optional.** Do it as the very first action, before
   reading anything and long before any `Write`. A missing or empty marker fails closed: every
   guard denies, and this skill cannot write a single file.

1. **Read the source in full.** Every file in scope, top to bottom, including the ones the entry
   point calls. Never characterise code from a `grep` hit or a partial read — a `grep` locates
   code, it does not tell you what the code does. If a file is too large to read at once, read it
   in consecutive chunks until it is fully covered; do not sample it.

2. **When the source reaches a database, read the schema too.** A query builder, an ORM, a client
   library, raw SQL — any of them makes the storage a second source, and it is read in full the way
   the code was: migrations, DDL, row-level-security policies, triggers, defaults, constraints,
   foreign keys, uniqueness. Part of the contract lives there and is invisible at the call site.

   `useFodmapStreak` is the standing example. `meal_logs.user_id` references `auth.users(id)` and a
   Supabase row-level-security policy scopes every read to `auth.uid()`, so the TypeScript mentions
   no user anywhere. A specification derived from the code alone loses the scoping silently, the
   ports derived from that specification take no user either, and a provider written against them
   returns every user's rows with no test noticing — the fakes return whatever they are given.

   **Each source gets its own specification document.** One for what the code does, another for
   what the storage guarantees and restricts. A schema document is also what makes `/entity` run at
   all: the pipeline is `/spec` → `/entity` → `/contract` → `/cover` → `/build`, `/entity` is
   conditional on a schema document existing, and a source that reaches no database goes straight
   from here to `/contract`. Where one does exist, `/entity` builds the module's Doctrine entities
   from it and `/contract` derives the ports from both documents.
   Do not fold a schema into a behaviour spec: the two are read differently, they are wrong in
   different ways, and a storage rule buried in a behaviour table is a rule nobody ever checks
   against the database.

   If the schema cannot be reached — the DDL is not in this repository, the policies live in a
   console you cannot read — say so under Open questions and name exactly what is missing. An
   unread schema is an undetermined contract, not an absent one.

3. **Separate claims from behaviour.** Docblocks, comments, names, README text and commit messages
   are *claims*. The branches are *behaviour*. Where the two disagree, the branch wins and the
   disagreement is a finding for the Discrepancies section — never smoothed over, never silently
   resolved in favour of the nicer-sounding claim.

4. **Enumerate inputs and outputs, then every branch.** For each branch: the condition that selects
   it and the result it produces. A branch you did not account for is a case the tests will miss.

   An expression that picks between sources is a branch too, even though it is not an `if`:
   a `??` or `||` chain, a coalescing fallback, a ternary, a default parameter, a lookup with a
   default. Give each level of the chain its own case, and add one where two levels hold
   *different* values — that is the only case a reversed precedence fails. Read as a detail of the
   query it sits in, such a chain is easy to describe in prose and leave out of the table.

5. **Enumerate edge cases explicitly.** Walk the list rather than waiting for one to occur to you:
   empty input, absent or missing data, boundary values (zero, one, first, last, max), ordering,
   duplicates, `null`, and anything dependent on the current time, timezone, locale, or encoding.
   For each, record what the current code actually does — including "crashes", "returns silently",
   and "undefined, no branch covers it".

6. **Name the hidden dependencies.** Anything the code reaches for that is not an argument: I/O
   (database, filesystem, HTTP, mail), the current time, randomness, environment, global or static
   state. These decide which ports the future module needs — every one of them becomes a Domain
   interface implemented under `Infrastructure/` (invariant 9), and current time in particular comes
   from an injected clock (invariant 22). Say which of them must become a port.

7. **Separate what the code settles from what it leaves ambiguous.** Anything the source itself
   cannot answer — intent, whether a behaviour is deliberate or a bug, what should happen in a case
   no branch covers — goes to Open questions for a human. Never to a guess.

## Output: `docs/specs/<name>.md`

Exactly these sections, in this order:

```markdown
# <name>

## Purpose
One paragraph: what this code exists to do, in behavioural terms.

## Contract
Inputs, outputs, and the rule in one sentence.

## Cases
| id | given | expected |
|----|-------|----------|
| C1 | <concrete input values> | <concrete result> |

## Edge cases
Each edge case, with what the current code does about it.

## Hidden dependencies
Each one, and whether it must become a port.

## Discrepancies
Where the stated contract and the real behaviour disagree.

## Open questions
What a human has to decide.
```

**The Cases table is the interface to the next step; everything else is context.** Each row must be
concrete enough to drop into a PHPUnit data provider with no further thought: literal input values,
a literal expected result or a named expected exception — never "valid input", "an error", or
"handles it correctly". One row per branch and per edge case, each with a stable `id` the tests can
cite.

### The schema document

A source that reaches a database produces a second document, `docs/specs/<name>-schema.md`, with the
same skeleton read against the storage rather than the code:

- **Purpose** — what this storage holds.
- **Contract** — the tables, columns and types in scope.
- **Cases** — one row per rule the storage enforces: constraint, foreign key, uniqueness, default,
  trigger, row-level-security policy — each with the condition that selects it and what the database
  does when it is violated, concrete enough to become a test or a port parameter.
- **Edge cases**, **Hidden dependencies**, **Discrepancies** — where schema and code disagree, such
  as a column the code never sets or a policy the code silently relies on — and **Open questions**.

`/entity` builds the module's entities from this document and the reference SQL, and `/contract`
then reads both documents and derives the ports from both. Never fold one into the other.


## Boundaries

- Do not propose an implementation, sketch classes or interfaces, name future handlers, or write
  PHP. The job ends at the specification.
- Do not "fix" what you find. A bug is recorded under Discrepancies, not corrected.
- State plainly what you could not determine — unreadable file, behaviour that depends on data you
  cannot see, a code path whose outcome is genuinely unclear. An honest "undetermined: <what and
  why>" is a correct result; an invented one silently becomes a wrong test.
