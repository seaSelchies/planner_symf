# planner — backend

A Symfony backend being ported, module by module, from an existing TypeScript +
Supabase application. Two things live in this repository and both are the point:

- the **backend** itself, hexagonal and module-first, one module landed so far;
- the **workflow** that produces it — a set of rules and five scripted steps that
  a developer runs instead of asking an assistant to "port this file".

The workflow is in `.claude/`. The rules it enforces are in `AGENTS.md`, as 39
numbered invariants; review comments and denial messages cite them by number.

## Running it

Requires PHP 8.4, Composer, and Docker.

```bash
composer install
docker compose up -d database
php bin/console doctrine:migrations:migrate
php bin/phpunit
symfony server:start -d
```

`php bin/phpunit` is the one that matters — it needs no database and no
container, and it is green: 28 tests, 35 assertions.

Environment variables (`DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_HOST`,
`DATABASE_PORT`, `DATABASE_NAME`) come from `.env`, which is untracked. Nothing
is hardcoded in PHP or YAML — invariant 6.

## Layout

```
src/{Module}/Adapter/          inbound: HTTP controllers, DTO mapping
src/{Module}/Application/      use cases: one folder per command or query
src/{Module}/Domain/           ports, value objects, entities — no framework
src/{Module}/Infrastructure/   outbound: Doctrine adapters implementing ports
src/Shared/                    the CQRS base: buses and marker interfaces
```

Module-first, never layer-first. Dependencies point inward only, so nothing
under `Domain/` or `Application/` imports from `Infrastructure/` or `Adapter/`.

Commands and queries travel on two Symfony Messenger buses. A handler is routed
by the marker interface it implements, not by an attribute, so no Symfony class
appears in `Application/`.

## The workflow

Five steps, invoked as slash commands, plus a reviewer. Each writes to one place
and is stopped by a `PreToolUse` hook from writing anywhere else.

| step | writes | asks a human |
|---|---|---|
| `/spec` | `docs/specs/` — what the source does, and what its schema guarantees | no |
| `/entity` | `src/<M>/Domain/` — Doctrine entities; skipped if no database | yes, per entity |
| `/contract` | `src/<M>/` declarations, `docs/todo/` | yes, on shape |
| `/cover` | `tests/<M>/` — failing tests from the spec's cases | no |
| `/build` | `src/<M>/` bodies, until the suite is green | no |
| `audit` | nothing — reads records and reports where they disagree with the code | no |

Two steps stop and wait for an answer before writing. The reviewer is a subagent
with `Read, Grep, Glob` and no write tool at all, so it cannot change what it
judges.

`docs/workflow.md` describes each step in full: what it reads, what it may write, where a
boundary is enforced mechanically and where it is only a rule. `docs/prompts.md` logs every
prompt used to drive this, verbatim, with what came back and what had to be corrected.

## What works and what does not

Green: the Domain, Application and Adapter layers of the `Fodmap` module, its
28 tests, the mapping of six tables (Doctrine validates all six), and the query
bus resolving its handler.

Not proven: **no migration exists for those six tables**, so the SQL in
`src/Fodmap/Infrastructure/DB/` has never executed. The tests use hand-written
fakes and touch no database. Treat the Infrastructure layer as written but
unrun.

Deliberate divergences from the ported source are recorded rather than hidden —
see `tests/Fodmap/CASE-COVERAGE.md`, which accounts for every case in the
specification as covered or explicitly not covered, with a reason.

`docs/analysis.md` is the assessment of the workflow itself: what it gave, what
kept going wrong, what the enforcement cannot do, and what is not proven.

## Branches

- `main` — this.
- `feat/auth` — an earlier `Auth` module, deliberately parked. It predates the
  rules in `AGENTS.md` and is kept as the "before" it can be compared against.
  Its Doctrine mapping was removed from `main` when it moved; leaving it behind
  once stopped the container from building.
