---
name: entity
description: Write the Doctrine entities that carry a module's mapping metadata under src/<Module>/Domain/, after proposing entity by entity which concepts the module actually owns and waiting for a human answer. Use after /spec and before /contract, and only where /spec produced a schema specification — a module that reaches no database skips this step entirely. The guard denies writes outside src/<Module>/Domain/ and any write that is not an entity, so migrations/ and tests/ are denied; implementing behaviour is forbidden by rule, not by the guard.
argument-hint: [the module name whose entities are to be written, e.g. Fodmap]
disallowed-tools: NotebookEdit
hooks:
  PreToolUse:
    - matcher: Write|Edit|MultiEdit
      hooks:
        - type: command
          command: "$CLAUDE_PROJECT_DIR/.claude/skills/entity/write-guard.sh"
---

# Entity

The pipeline is `/spec` → `/entity` → `/contract` → `/cover` → `/build`, and **this step is the
conditional one**: it runs only where `/spec` produced a schema specification at
`docs/specs/<name>-schema.md` — that is, only where the source reaches a database. A module that
reaches none has no tables to map, so it goes `/spec` → `/contract` → `/cover` → `/build` and this
step never runs at all. Skipping it there is the correct pipeline, not a gap in one.

`/spec` established **what** a module does, and — where the source reaches a database — **what its
storage guarantees and restricts**, at `docs/specs/<name>-schema.md`. `/contract` then declares the
module's shape with a human, `/cover` turns the cases into failing tests, and `/build` replaces the
throws with behaviour.

None of them owns the mapping metadata that tells Doctrine what the module's tables look like.
`/spec` describes the schema in prose, `/contract` declares ports and DTOs, `/cover` cannot reach a
database, and `/build`'s guard denies everything that is not a method body.

**This step is that owner. Its single output is Doctrine entities under `src/<Module>/Domain/`, and
it writes nothing else.**

It sits **after `/spec`**, because an entity is built from the schema specification and the reference
SQL and needs nothing `/contract` produces — and **before `/contract`**, because `/contract` declares
the Infrastructure adapters, and the collaborator those adapters take (a DBAL `Connection` or an ORM
`EntityManager`) cannot be a real choice while no entity exists. That is exactly how
`DoctrinePlannedTierProvider` ended up taking a `Connection` with nobody deciding it.

## This step writes no migration

**`migrations/` is outside this step's lane, and a migration is applied only after a human has
approved it** (invariant 7). No step in this pipeline owns `migrations/` any more, and the guard
here denies it like any other path outside the lane. So:

- do not write a file under `migrations/`;
- do not run one, and do not quote a migration command as this step's own work;
- if the schema a migration would produce from your mapping is wrong, **the entity is wrong** — fix
  the mapping and say so in your report.

## The ownership gate is the point of this skill

For every entity it intends to create, this step must establish whether the concept belongs to
**this module's domain** — and **it does not decide that alone.**

The question is not "does the module need to read this table". It is "**does this module own the
concept**": does it **write** the table, and is the concept named in the module's own language — or
does it only **read** data that another part of the system owns and will one day model itself.
Getting that wrong is not a formatting mistake. A module that maps a table it does not own has
quietly claimed a concept, and the module that should own it inherits a fait accompli.

**Propose, stop, wait, write.** That is the same gate `/contract` uses, for the same reason: a
proposal written to disk before it is confirmed leaves the human reviewing a fait accompli rather
than making a decision. **A gate that proceeds on the model's own judgement is not a gate.** Your
reading of ownership is an input to the human's answer, never a substitute for it.

## The guard

A `PreToolUse` hook matches `Write`, `Edit` and `MultiEdit`, and:

- **Its lane is `src/<Module>/Domain/` and nothing else.** Other layers of the module are
  `/contract`'s declarations and `/build`'s bodies, `src/Shared/` is nobody's at this step,
  `tests/` is `/cover`'s, `docs/` is `/spec`'s, `docs/todo/` is `/contract`'s, and `config/`,
  `migrations/` and the repository root stay a human's. Each denial names the owner of what it
  refused.
- **What you write must BE an entity.** The guard checks the content for a Doctrine mapping
  attribute — `#[ORM\Entity]`, `#[ORM\Embeddable]`, `#[ORM\MappedSuperclass]`. A port, a rule class,
  a DTO or an exception under `Domain/` is `/contract`'s file, whatever folder it lands in.
- **A file that already exists must already be an entity.** A Domain file that is not one is
  another step's file, and this step may not overwrite it with one. **Existing entities may be
  updated** — a column the specification records that the mapping is missing is a legitimate edit —
  which is why `Edit` and `MultiEdit` stay available here rather than being denied outright. An edit
  that strips the mapping attribute back out is denied: a class that stops being an entity is a
  shape decision, and that belongs to `/contract`, with the human.

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
   entity
   ```

   Every registered guard allows this Write, because the name is a step that exists — that is
   what lets a second step declare itself in a session where an earlier one already ran. This
   step's own guard does one more thing as it allows it: it records in `.claude/.step.live`
   that it is live in this session. That record is what the other guards read before standing
   aside, so a marker written any other way stands nothing down.

   **This is not a formality and it is not optional.** Do it as the very first action, before
   reading anything and long before any `Write`. A missing or empty marker fails closed: every guard
   denies, and this skill cannot write a single file.

1. **Read the specifications in full, and the sources around them.**

   - `docs/specs/<name>-schema.md` — **the source of truth for which tables and columns exist**: its
     Contract section gives the current effective shape of every table, its Cases give the
     constraints and foreign keys, its Discrepancies say where the ported code and the database
     disagree.
   - `docs/reference/supabase/` — the verbatim copy of the source project's `schema.sql` and its
     full migration chain, the same primary source `/spec` read, described in
     `docs/reference/README.md`. This is where the **physical column definitions** live — type,
     nullability, default — which the schema specification's Contract section does not carry.
   - `docs/specs/<name>.md` — the behaviour specification, for *why* a column is read at all, and
     for the language the module actually speaks. That language is evidence about ownership.
   - **whatever is under `docs/todo/`, which may be nothing.** Where files are there, they carry
     decisions a human took at `/contract` that the mapping has to accommodate, and divergences the
     port makes deliberately. `docs/todo/` is `/contract`'s output and `/contract` runs **after** this
     step, so on a first pass over a module **no todo exists yet**. That is normal, not a missing
     input: read what is there, and do not wait for a file nobody has written.
   - **the module's existing `src/<Module>/Domain/`, which may be empty or absent.** Where it has
     content, it holds any entity already mapped and any Domain type an earlier pass left. The ports,
     DTOs, rule classes and exceptions there are `/contract`'s, and `/contract` runs after this step,
     so on a first pass **the module's `Domain/` is typically empty and the module folder may not
     exist at all**. Again: normal, not a missing input. An entity is built from the schema
     specification and the reference SQL, and nothing here waits on a port being declared first.

2. **The specification describes the tables as they are TODAY. The ported code's assumptions about
   them are not evidence.** This is the whole reason the schema document exists as a separate
   artefact: the source code names columns the database no longer has.

   `docs/specs/use-fodmap-streak-schema.md` has the live example — cases **S17–S20** record that
   `recipe_ingredients.fodmap_tier`, `recipe_ingredients.ingredient_name`,
   `meal_log_ingredients.fodmap_tier` and `meal_log_ingredients.ingredient_name` were **dropped in
   migration 026**, while the hook still selects them. **Do not map a column back into existence
   because the ported code reads it.** Where the specification and the code disagree, the
   specification wins, and **the disagreement goes in the report** — naming the case id, what the
   code expects, and what the schema actually has.

3. **Work out the full list of entities the module needs, and your reading of who owns each.**

   From the schema specification and the behaviour specification together, list **every** entity —
   not only the obvious ones, and not only the ones a port names directly: a table reached through a
   join is still a table something has to map.

   For each entity, state four things:

   - **the table it maps**, by name;
   - **the Domain sub-namespace it would go in** if the module owns the concept —
     `src/<Module>/Domain/<SubNamespace>/<Entity>.php`, grouped by subdomain as `AGENTS.md` allows
     once a module has more than one subject;
   - **your reading of whether the module owns it**, stated as a reading and not as a fact;
   - **the evidence for that reading** — does the module **write** this table, or only read it, and
     is the concept named in the module's own language or in another part of the system's.

4. **Ask, entity by entity, and stop.**

   Use `AskUserQuestion` if it is available; otherwise ask in plain text. Either way, **write
   nothing until the human has answered** — not one file, not "the entities that are obviously
   owned first". One decision per entity: this module owns the concept, or it does not. If the
   answers change the grouping, revise and confirm the revision before writing.

5. **Only then write the entities, placed by the human's answer.**

   - **Owned by this module** → `src/<Module>/Domain/<SubNamespace>/<Entity>.php`, in the
     sub-namespace the concept belongs to.
   - **Not owned** → `src/<Module>/Domain/Shared/<Entity>.php`, **and one todo per such entity**,
     recording: which table it maps, why the module does not own the concept, that it sits in
     `Shared/` as a consequence, and what would rehome it — the module that owns the concept
     landing, at which point this module reads through **that** module's ports instead of mapping
     the table itself.

   **This step cannot write that todo.** The guard denies `docs/todo/`, which belongs to `/contract`
   — the step with the human in it. So **draft each todo in full in your report, quoted and ready to
   paste**, in the format `AGENTS.md` defines under "The todo trail", and say plainly that the
   `/contract` run which follows this step writes it. Do not attempt the write, and do not route around the guard.

6. **What each entity contains.**

   - **Which columns exist comes from `docs/specs/<name>-schema.md`.** **Do not invent a column the
     specification does not record** — not a convenience `updated_at`, not a soft-delete flag, not
     an index nobody asked for. A column it does record that your mapping omits is a line in the
     report.
   - **Each column's physical definition — type, nullability, default — comes from
     `docs/reference/supabase/`**, read for that exact column. The Contract section records table
     and column *names* and carries no types, so a type taken from anywhere else is one you
     invented. Read the chain, not the first hit: a column's effective shape is its base definition
     in `schema.sql` plus every later alteration in `migrations/`.
   - **Doctrine mapping attributes only.** Invariant 32 makes mapping attributes on entities the one
     piece of framework code `Domain/` is allowed to carry. No Symfony services, no serializer
     attributes, no validation attributes, no HTTP types — and no behaviour beyond what the mapping
     needs.
   - **Non-final**, per invariant 16, so the ORM can proxy the class. This is the **only** exception
     to invariant 16, which otherwise makes every class in `Application/` and `Domain/` final — **say
     so in a comment on each class**, so the next reader does not "fix" it.
   - **Associations reflect the foreign keys the specification's cases record**, with the
     referential actions those cases state — `ON DELETE CASCADE` for S1 and S2, `ON DELETE SET NULL`
     for S3, S4 and S5 — and a unique constraint spans exactly the columns the case names (S8, S9,
     S10).
   - **Where the specification records a constraint no mapping attribute can express** — a Postgres
     `CHECK`, as in S6, S7 and S11 — **that is a line in the report**, named by id, with the reason
     (invariant 39). It is not a silent omission, and it is not a licence to reach for raw SQL.
   - **Where the specification records a foreign key to a table this project does not have** —
     Supabase's `auth.users` — say so in the report and state what you mapped instead. That is a
     shape question for `/contract`, not one this step settles on its own.

7. **Postgres row-level security is not reproduced, and nothing stands in for it.**

   The schema specification's S12–S16 and its Hidden dependencies section record that every table
   except the shared catalogue is restricted to `auth.uid()` by RLS, invisibly, which is why the
   original TypeScript names no user anywhere. **Doctrine has no RLS equivalent, and this step does
   not approximate one** — no filter that reads a session variable, no listener, no base class that
   scopes queries behind the caller's back.

   The decision has already been taken and written down: `docs/todo/fodmap-streak-user-scoping.md`
   records that user scoping becomes an **explicit `string $userId` parameter** on
   `PlannedTierProvider::plannedTiersByDate()`, `LoggedTierProvider::loggedTiersByDate()` and
   `GetFodmapStreakQuery`, and that `/build` owns filtering the Doctrine queries by it. So the
   entities carry the **ownership columns** those filters need — `user_id` where the specification
   records one, and none where it records none, as on the shared `ingredients` catalogue (S16).

   **Say this in the report rather than approximating it.** An entity that quietly adds a scoping
   filter, and one that quietly omits a `user_id` column because "RLS handled it", hide the same
   thing.

8. **This step does not touch `config/`.**

   `AGENTS.md` requires a module with Doctrine entities to register its own mapping section in
   `config/packages/doctrine.yaml`, pointing at that module's `Domain` folder:

   ```yaml
   doctrine:
       orm:
           mappings:
               {Module}:
                   type: attribute
                   is_bundle: false
                   dir: '%kernel.project_dir%/src/{Module}/Domain'
                   prefix: 'App\{Module}\Domain'
   ```

   The guard blocks `config/`, so this skill cannot make that edit — and until it is made, nothing
   reads the mapping these entities carry. **Quote the exact block in your report and leave it to a
   human.** A mapping pointing at a folder that does not exist stops the container building at all,
   so it is a human's edit in both directions.

## Out of scope

- Do not write a migration, and do not run one. `migrations/` is outside this step's lane, and a
  migration is applied only after a human has approved it.
- Do not implement anything outside `src/<Module>/Domain/` — a port, an adapter or a handler the
  mapping turns out to need is a finding for the report — a port or an adapter is `/contract`'s to
  declare, and its body is `/build`'s, both of them after this step.
- Do not write a test. `.claude/rules/tests.md` rule 11 confines DB-touching tests to
  `tests/<Module>/Infrastructure/` against a real test database, and `/cover` owns `tests/`.
- Do not write a `docs/todo/` entry — draft it in the report and leave the write to `/contract`.
- Do not edit the schema specification, the behaviour specification, or a todo.
- Do not add a Composer dependency (invariant 31) — Doctrine is already installed.
- Do not map a table for a module this run was not asked about, and do not place a class in another
  module's folder (invariant 2).

## Verify before reporting done

Run it against **every** file you wrote:

```bash
php -l src/Fodmap/Domain/<SubNamespace>/<Entity>.php
```
no syntax errors, and the class name inside each file matches its own filename exactly (invariant 4).

```bash
git status --short
```
new files under `src/<Module>/Domain/` and nothing else changed — no `migrations/`, no `config/`, no
`docs/`.

**Then run the mapping self-check. This step is required, it runs after the entities are written and
before the report is composed, and its result goes in the report:**

```bash
php .claude/skills/entity/verify-mapping.php <Module>
```

It loads the metadata straight from the attributes on your classes, turns every field mapping into a
DBAL column carrying that mapping's own type, nullability, length, precision, scale and default, and
asks `PostgreSQLPlatform` to render `CREATE TABLE` for it. It needs **no database and no entry in
`config/packages/doctrine.yaml`** — both are outside this step's reach, and a check that needs a
human's edit before it can run is a check that never runs.

**What a zero exit proves:** every mapping this module declares can be turned into a column
definition — no unregistered type, no `decimal` that declares no scale, no field the platform cannot
render.

**What it does not prove:** that the schema matches the real database, that a query returns rows, or
that the associations are the right ones. Those need a running database, and they belong to `/cover`
and `/build`.

**If the script fails, the step did not complete, and the report says so — naming the class, the
field and the exception it printed.** A report that describes entities the script could not render
is a report about files, not about a mapping that works. Fix the mapping and run it again; a
mapping that cannot become a column is not a finding to write up and move past.

Then read your own entities once more against the specification's Contract section: every table
mapped, every column under it, every case id in the tables above — and check that each one sits
where the human's answer put it, owned concepts in their subdomain and unowned ones in `Shared/`.

## Report

- **the ownership proposal exactly as it was shown to the human**, and their answer for each entity;
- **every entity written**, by path, with the table it maps and the sub-namespace it landed in —
  owned concepts and `Shared/` ones listed separately;
- **every column of every entity**, with types, nullability, defaults, unique constraints and
  associations with their referential actions, and where each physical definition came from in
  `docs/reference/supabase/`;
- **the todo text for each unowned entity, quoted in full and ready to paste**, plus the plain
  statement that this step cannot write it and a `/contract` run must;
- **the result of `php .claude/skills/entity/verify-mapping.php <Module>`** — that it exited zero
  and every entity rendered, or, if it did not, that **the step did not complete**, naming the
  class, the field and the exception that failed;
- **which case ids from the schema specification the mapping satisfies**, listed by id;
- **which case ids it cannot satisfy, each with its reason** — a `CHECK` no mapping attribute can
  express, an RLS policy that has no Doctrine equivalent, a foreign key to a table this project does
  not have. **A case the mapping cannot satisfy is a line in the report, never a silent omission**
  (invariant 39);
- **where the specification and the ported code disagree**, and the fact that the specification won
  — naming the case id and both shapes (step 2);
- the statement that **row-level security is not reproduced**, and that user scoping is an explicit
  port parameter instead, citing `docs/todo/fodmap-streak-user-scoping.md`;
- the **`config/packages/doctrine.yaml` mapping block that still needs adding**, stated as a human's
  edit, and the statement that **the migration is outside this step's lane and is applied only after
  a human has approved it** — not written by this step, and not quoted here as work it did.

## Boundaries

- **Do not write to `migrations/`, and do not run a migration.**
- **Do not commit.**
- **Do not report done on a red self-check.** If `verify-mapping.php` exits non-zero, the mapping is
  not finished — say the step did not complete and name what failed.
- **Do not write before the human has answered.** The gate is the point of this skill; an entity on
  disk before the answer is a decision taken without them.
- **A denied write is a limitation to report, not an obstacle to route around.** Not with `Bash`,
  not by asking for the hook to be lifted, not by writing the change somewhere the guard permits.
  The guard matches the editing tools, so `Bash` is not a wall this step meets — it is a rule this
  step keeps.
- **A Domain file that is not already an entity is not this step's to overwrite** — the ports, DTOs,
  rule classes and exceptions there are `/contract`'s, and their bodies are `/build`'s.
- If an invariant or a rule in `.claude/rules/` blocks a mapping you believe is correct, stop and
  propose a wording change citing the number — never route around it silently (`AGENTS.md`, "When a
  rule blocks the task").
