---
name: spec
description: Establish what an unfamiliar module or file actually does by reading it in full, and write the result as a behaviour specification at docs/specs/<name>.md that the next step turns into failing tests. Use before porting, reworking, or replacing code whose real behaviour has not been established — never for changing code, which this skill cannot do.
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

Read the target and establish what it **does** — not what its author says it does. The output is
one specification document precise enough that the next step turns its case table into failing
tests without interpreting anything further.

## This skill never changes code

`Edit`, `MultiEdit` and `NotebookEdit` are removed from the tool pool by the front matter.
`Write` stays available for exactly one reason: the document.

**The only path this skill may write is `docs/specs/<name>.md`.** No file under `src/`, `tests/`,
`config/`, `migrations/`, or anywhere else. A `PreToolUse` hook enforces this and denies any other
`Write`; if a write is denied, that is the rule working, not an obstacle to route around.

`<name>` is a kebab-case name for the subject under investigation — the module, class, or file
being read (`docs/specs/legacy-slug-builder.md`). If a spec of that name already exists, read it
first and say in the report that this run replaces it.

## Procedure

1. **Read the source in full.** Every file in scope, top to bottom, including the ones the entry
   point calls. Never characterise code from a `grep` hit or a partial read — a `grep` locates
   code, it does not tell you what the code does. If a file is too large to read at once, read it
   in consecutive chunks until it is fully covered; do not sample it.

2. **Separate claims from behaviour.** Docblocks, comments, names, README text and commit messages
   are *claims*. The branches are *behaviour*. Where the two disagree, the branch wins and the
   disagreement is a finding for the Discrepancies section — never smoothed over, never silently
   resolved in favour of the nicer-sounding claim.

3. **Enumerate inputs and outputs, then every branch.** For each branch: the condition that selects
   it and the result it produces. A branch you did not account for is a case the tests will miss.

   An expression that picks between sources is a branch too, even though it is not an `if`:
   a `??` or `||` chain, a coalescing fallback, a ternary, a default parameter, a lookup with a
   default. Give each level of the chain its own case, and add one where two levels hold
   *different* values — that is the only case a reversed precedence fails. Read as a detail of the
   query it sits in, such a chain is easy to describe in prose and leave out of the table.

4. **Enumerate edge cases explicitly.** Walk the list rather than waiting for one to occur to you:
   empty input, absent or missing data, boundary values (zero, one, first, last, max), ordering,
   duplicates, `null`, and anything dependent on the current time, timezone, locale, or encoding.
   For each, record what the current code actually does — including "crashes", "returns silently",
   and "undefined, no branch covers it".

5. **Name the hidden dependencies.** Anything the code reaches for that is not an argument: I/O
   (database, filesystem, HTTP, mail), the current time, randomness, environment, global or static
   state. These decide which ports the future module needs — every one of them becomes a Domain
   interface implemented under `Infrastructure/` (invariant 9), and current time in particular comes
   from an injected clock (invariant 22). Say which of them must become a port.

6. **Separate what the code settles from what it leaves ambiguous.** Anything the source itself
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

## Boundaries

- Do not propose an implementation, sketch classes or interfaces, name future handlers, or write
  PHP. The job ends at the specification.
- Do not "fix" what you find. A bug is recorded under Discrepancies, not corrected.
- State plainly what you could not determine — unreadable file, behaviour that depends on data you
  cannot see, a code path whose outcome is genuinely unclear. An honest "undetermined: <what and
  why>" is a correct result; an invented one silently becomes a wrong test.
