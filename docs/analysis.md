# Benefits, limitations and risks

An assessment of the workflow in `.claude/`, from building it and using it on two modules.
Everything below points at something that was run or something a reader can open in this
repository.

## What it gave

**It read the source better than I did.** Before the first run I wrote down three things I could
see in the hook myself. The step found two of them and stated them more precisely. The third — "a
day with no data always gives a zero streak" — it recorded as intended behaviour, not a bug,
because a comment in the source says exactly that. It was right and I was not.

It also found things I had not seen at all: a missing tier becomes the string `unknown`, and the
"is this bad" check ignores `unknown`, so a day where nothing is known counts as a safe day. None
of the three database calls checks its error field, so a failed query looks the same as an empty
history.

**Reading the schema found what green tests could not.** 30 tests passed against a faithful
reading of the source. None of them could say whether the data that source names still exists. It
does not: a migration dropped four of the columns the hook selects. And every table it reads is
restricted to the current user by the database itself, which the code never mentions — so a port
copied from the code would return every user's rows, and no test built on fakes would notice.

**Decisions stopped being silent.** The steps that stop and ask a human leave a file behind
saying what was decided, why, and what would settle it. One of those decisions went against the
step's own recommendation: it proposed one place for an entity, I chose another, and the
disagreement is written down instead of being settled by whoever ran last.

**Running a thing beats reading it.** A mapping that looked correct could not be turned into a
column at all — Doctrine has no way to express a numeric column with no fixed precision, so the
first attempt to render it threw. The same column had already been translated the same way by an
earlier step, so this was the second time that defect shipped.

**A second module went through.** The first module is where the workflow was built; most rules
exist because something went wrong on it, so it proves nothing about itself. The second one — four
commands and a query, the first that writes — went through without the steps being changed for it.
61 tests across the two.

## What kept going wrong

The same thing five times, at five different levels: **a record says one thing, the code says
another, and nobody compares them.**

- A step reported, correctly, that a column is nullable. It then wrote the entity with that column
  not nullable. The report was right; the file was wrong.
- The coverage table said two cases were unchanged. Both had changed their answer, and one of them
  across the line that decides whether a day counts.
- Four files cited invariant 7 for a rule its text does not contain. Fixing the original did not
  fix the copies.
- Four of five todos described work that was already done. The rulebook predicts this in the very
  sentence that says how a todo is closed.
- The reviewer built to catch all of the above reported "verdict count: 160" after examining
  three.

None of these is carelessness. Every record was true when it was written. Nothing re-reads a
record when the thing it describes changes.

## What the enforcement cannot do

**A hook sees the tool call, not the result.** The lanes are enforced against the editing tools,
which carry a file path. A shell command carries a string, and no check on a string can say which
files it will touch. So every "do not go around this with a shell" is a rule the step follows, not
a wall it hits. The reviewer looked like the exception — its definition gives it three read-only
tools — but the runs were executed by a tool that does not read that definition, so there too the
limit was a rule and not a wall.

**One of the two locks opens by itself.** Three steps keep the editing tools out through a
front-matter setting, and the documentation says that setting is dropped as soon as the user sends
another message. Reply mid-run and the tools come back, and those steps' hooks are not watching
for them.

**Testing the parts passed a broken whole.** Each guard was checked on its own and behaved
correctly. Together they did not: because a hook stays registered for the whole session, the
second step of any session had its own start-up write refused by the first step's guard. The
pipeline could not run two steps in a row. Both of us tested the same wrong way.

**Renaming a step turned everything off.** The guards knew "no marker" and "another step's
marker". They had no branch for "a name that belongs to nobody" — which is what a rename produces.
For a while nothing at all was enforced, and it was found by accident.

## What the method cannot do

**The reviewer makes claims too.** Its report had to be checked like everything else, and it
contained about as many mistakes as it found: a criterion it called satisfied because two files
mention the same class, a whole category cleared with no evidence, one item given no answer. It is
still worth having — it caught a criterion I had judged by reading the code when the criterion
asked for a test. But adding a checking step does not end the checking. It moves the unchecked
claim up one level.

**Every new rule is a new thing to satisfy on paper.** We added "state how many items you checked".
The next run stated a number and checked three. That is the coverage table's mistake, reproduced by
the fix meant to prevent it. When a check is really just comparing two lists, it should be a script,
not a sentence.

**Nothing owns cleaning up.** Each step is one move forward, and its lane exists for that move. No
step maintains what the pipeline already wrote. A step cannot be reused as an editor for its own
lane, because it has a procedure and the procedure is the whole point; and a step allowed
everywhere would cancel the lanes. The cost, measured: deleting three records left eighteen
references pointing at nothing, spread across three lanes and one file no step owns.

**The rules had to be broken to write them.** The guard files were edited with the one tool the
guards do not watch, because there is no other way to change a guard while it is running.

## What is not proven

**No database was ever touched.** Both suites run on hand-written fakes. The mappings validate, the
application starts, and a migration now raises the schema — but nothing runs a query against it, so
the adapters' SQL has still never executed. Everything claimed about the storage layer is a claim
about code, not about behaviour.

**One reviewer, two runs.** How accurate it is was measured on one day, in one repository.

**One second module.** Two is better than one, but they are the same kind of work: a React hook
over Postgres.

**The rulebook describes a repository that has moved on.** Two of its statements about what exists
were true when written and are not now.

## What to do next, in order

1. **A `Stop` hook** that compares the working tree against the current step's lane once per turn.
   This is the documented answer to shell writes: it looks at what changed instead of at what was
   requested, and it is the only thing that can catch what the lane guards miss.
2. **A migration and a test database**, so the storage layer is executed instead of described.
3. **A script for the accounting.** Comparing case ids between two documents is a list difference.
   It belongs in the step that writes the accounting, not in an instruction to read carefully.
4. **A step that owns retirement** — find what cites a record, clear it, then remove the record.
   Eighteen broken references show that closing something is a procedure, not a deletion.
