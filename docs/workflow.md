# The workflow

This is the porting procedure for this repository, written to be handed to
someone who has not seen it before. It is five scripted steps plus a reviewer.
You run them in order; each writes to one place and is stopped from writing
anywhere else.

The rules the steps enforce live in `AGENTS.md`, numbered. Steps cite those
numbers when they refuse something, so a refusal can be looked up.

## The order

```
/spec  →  /entity  →  /contract  →  /cover  →  /build
                                                  audit (any time)
```

`/entity` runs only where `/spec` produced a schema specification — that is,
only where the source reaches a database. A module that touches none goes
`/spec → /contract → /cover → /build`.

`/entity` comes before `/contract` for a concrete reason: `/contract` declares
the Infrastructure adapters, and the collaborator those adapters take cannot be
a real choice while no mapping exists. Run it after, and the choice gets made by
default rather than decided.

## The steps

**`/spec <target>`** reads the source in full and writes what it *does*, not
what its author says it does, to `docs/specs/<name>.md` — a table of numbered
cases precise enough that the next steps need no further interpretation. Where
the source reaches a database it writes a second document beside it,
`docs/specs/<name>-schema.md`: the tables as they are now, their constraints,
and a Discrepancies section naming every place the code and the schema disagree.
Two documents because they are wrong in different ways and a storage rule buried
in a behaviour table is a rule nobody checks.

**`/entity <Module>`** writes the module's Doctrine entities under
`src/<Module>/Domain/`. Before writing anything it proposes, entity by entity,
whether the module actually owns each concept — then stops and waits. What the
module owns goes in the sub-namespace it belongs to; what it only reads goes
aside, with a todo drafted for the step that can write one. It finishes by
running its own check: a script that loads the mapping it just wrote and renders
it as DDL, so a mapping that cannot become a column fails here rather than at
the database.

**`/contract <spec> <Module>`** turns the specification into the module's
declared shape: ports, DTOs, exceptions, and method bodies that are a single
`throw`. It proposes that shape and waits for a human. Every decision the human
takes that leaves work behind becomes a file in `docs/todo/`, with what was
decided, why, what remains, and what would settle it.

**`/cover <spec> <Module>`** turns the specification's cases into tests that
fail — red on assertions and on the throwing stubs, never on autoload. It
accounts for every case id in `tests/<Module>/CASE-COVERAGE.md`: each one is
covered by a named test or explicitly not covered with a reason. 

**`/build <Module>`** replaces the throws with behaviour until the suite is
green, and changes nothing else. It is the only step whose finish line was drawn
by an earlier step, in files it cannot reach.

**`audit`** is a subagent, not a step. It compares a record against the thing it
describes — a todo's settling criterion against the code, a coverage entry
against the test it names, an `invariant N` citation against invariant N — and
reports where they disagree. It has `Read`, `Grep` and `Glob` and no write tool
of any kind, so it cannot change what it judges.

## Who may write where

| step | writes | asks a human |
|---|---|---|
| `/spec` | `docs/specs/` | no |
| `/entity` | `src/<M>/Domain/`, entities only | yes, per entity |
| `/contract` | `src/<M>/` declarations, `docs/todo/` | yes, on shape |
| `/cover` | `tests/<M>/` | no |
| `/build` | `src/<M>/` bodies | no |
| `audit` | nothing | no |
| a human | `config/`, `migrations/`, `AGENTS.md`, `composer.json`, commits | — |

Reading is not restricted for anyone. A step has to read the other steps'
output to build on it.

## How the boundaries hold

Each step registers a `PreToolUse` hook when it is invoked. The hook sees the
path a write is aimed at and denies anything outside that step's lane, naming
the step or the person who owns what it refused.

A hook stays registered for the rest of the session, so several are live at once
after a few steps. A marker file, `.claude/.step`, names the step currently
running; each hook enforces when the marker names it and stands aside when it
names another. Every step writes that marker as its first action, as an ordinary
write of its own name, which its own hook permits by name.

Three things keep the marker honest. A missing or empty marker denies
everything, so a step that skips declaring itself can write nothing. A marker
naming a step that does not exist is refused rather than honoured, and the list
of valid names is read from the filesystem instead of repeated in each hook.
And standing aside requires evidence that the named step's hook is actually live
in this session — evidence only a running hook can leave — so a marker written
by any other means disarms nothing. `SessionStart` deletes both files, so a
session always begins closed.

**What this does not cover.** A hook is given the name of the tool and its
arguments. For a shell command that is the command string, and no path check can
tell what a shell command will change, so the lanes are enforced against the
editing tools and not against `Bash`. Keeping out of another step's lane with a
shell command is a rule the step keeps, not a wall it meets. The reviewer is the
exception, and only because it has no shell at all.

## Running it

```bash
/spec docs/reference/useDayTags.ts
/entity Tag                 # proposes ownership, stops, waits
/contract docs/specs/use-day-tags.md Tag   # proposes shape, stops, waits
/cover docs/specs/use-day-tags.md Tag
/build Tag
```

Then, as a human: register the module's mapping section in
`config/packages/doctrine.yaml`, write the migration, and commit. Those three
are deliberately outside every step.

Check the result:

```bash
php bin/phpunit
php bin/console cache:clear
php bin/console doctrine:mapping:info
php bin/console debug:messenger
```

## What it has been used on

Two modules, and they were not the same kind of exercise.

**`Fodmap` is where the workflow was built.** The steps, the rules and the guards
were written while porting it, and most of them were written *because* something
went wrong on it. That makes it poor evidence about itself: a procedure cannot be
judged by the case it was shaped against, any more than a specification can be
judged by the code it was derived from. Everything here fits Fodmap because
Fodmap is what it was fitted to.

A read-only streak calculation over six tables the module does not own. Its
ownership gate answered "not owned" six times, so its entities sit apart with a
todo each. 28 tests.

**`Tag` is where it was checked.** The steps were not written against it, so what
it shows is whether the rules describe a procedure or describe one case.

Day tags: four commands and one query, and the first module that writes. Read and
write ports stay separate interfaces. It reached what the first never did — an
ownership gate answering "owned", a write port beside a read port, command
handlers on the command bus, and a custom DBAL type where the built-in one
truncated the column. 33 tests.

61 tests together, and neither suite touches a database: both use hand-written
fakes.
