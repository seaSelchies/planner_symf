#!/usr/bin/env bash
# PreToolUse guard for the /entity skill: the skill writes the Doctrine entities that carry a
# module's mapping metadata, and touches nothing else.
#
# The pipeline is /spec -> /entity -> /contract -> /cover -> /build, and this step is the conditional
# one: it runs only where /spec produced a schema specification, that is, only where the source
# reaches a database. A module that reaches none goes /spec -> /contract -> /cover -> /build and this
# step never runs. It sits after /spec because an entity is built from the schema specification and
# the reference SQL and needs nothing /contract produces, and before /contract because /contract
# declares the Infrastructure adapters, and the collaborator those adapters take — a DBAL Connection
# or an ORM EntityManager — cannot be a real choice while no entity exists.
#
# Running first over a module means its src/<Module>/Domain/ is typically empty and docs/todo/ holds
# nothing yet: both are /contract's output. That is the normal first-pass state, not a missing input.
#
# Its lane is src/<Module>/Domain/ and nothing else. migrations/ is denied here as it is everywhere
# now — no step owns it, and a migration is applied only after a human has approved it. Each denial
# names the step, or the person, that owns the path it refused: other layers of the module are
# /contract's and /build's, src/Shared/ is nobody's at this step, tests/ is /cover's, docs/ is
# /spec's, docs/todo/ is /contract's, config/ and the repository root stay a human's, and
# migrations/ is outside every step's lane.
#
# Two checks here have no counterpart in any other guard in this repository, and both look at what
# is being written rather than only at where:
#
#   - The content being written must contain a Doctrine entity mapping attribute. This step creates
#     entities and nothing else, so the guard verifies that what it wrote is one — a port, a rule
#     class or a DTO under Domain/ is /contract's file, not this step's, whatever folder it lands
#     in. Write carries the whole file in tool_input.content and is checked directly; Edit and
#     MultiEdit carry a fragment instead, so for them the same question is answered by the check
#     below, plus a refusal to strip the mapping attribute out of a file that has one.
#   - If the target file already exists, its current content must ALSO contain that attribute. A
#     Domain file that is not already an entity is another step's file, and this step may not
#     overwrite it with one. Existing entities may be updated — a column added later is a
#     legitimate edit — which is why Write, Edit and MultiEdit all stay in the matcher and all pass
#     through both checks rather than Edit being denied outright.
#
# Registered from .claude/skills/entity/SKILL.md frontmatter. Claude Code keeps a skill hook for the
# rest of the session, but registered is not the same as enforcing: the marker at .claude/.step
# decides that. These paths are denied while the marker names entity, and this guard stands aside,
# without looking at the path at all, while the marker names another step that exists.
#
# stdin: PreToolUse event JSON. Denies via hookSpecificOutput.permissionDecision.

set -uo pipefail

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
case "$tool" in
  Write|Edit|MultiEdit) ;;
  *) exit 0 ;;
esac

cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
[ -n "$cwd" ] || cwd="$PWD"
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || root="$cwd"

path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')"

deny() {
  jq -n --arg reason "$1" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Resolve the target to an absolute, collapsed path. This runs before the step marker is read
# because the self-declaration branch below is about one specific path and has to recognise it
# while the marker is still absent. An empty file_path collapses to an empty string here and is
# rejected further down, where the message can say which lane was meant.
case "$path" in
  /*) abs="$path" ;;
  *)  abs="$cwd/${path#./}" ;;
esac

# Collapse . and .. without requiring the file to exist.
norm=""
IFS='/' read -r -a parts <<< "$abs"
for part in "${parts[@]}"; do
  case "$part" in
    ''|'.') ;;
    '..')   norm="${norm%/*}" ;;
    *)      norm="$norm/$part" ;;
  esac
done
abs="$norm"

# Which steps exist is a fact about the filesystem, not a list to keep in step with by hand: a step
# is a directory under .claude/skills/ holding a *-guard.sh. The probe is for that suffix rather
# than a fixed filename because build's guard is edit-guard.sh, not write-guard.sh. Every use of a
# step name below comes from this one enumeration — which names the marker may carry, whether the
# name it does carry is real, and the list every fail-closed message prints — so renaming or adding
# a step keeps them all true without an edit here. Matching a name against the enumeration, rather
# than building a path out of it, also keeps a name reading ../something from reaching outside
# .claude/skills/. The glob yields the names already sorted.
steps_seen=""     # the step names, ", "-joined, for membership tests and the messages
for guard_path in "$root"/.claude/skills/*/*-guard.sh; do
  [ -f "$guard_path" ] || continue
  step_dir="${guard_path%/*}"
  step_name="${step_dir##*/}"
  case ", $steps_seen," in
    *", $step_name,"*) continue ;;
  esac
  steps_seen="${steps_seen:+$steps_seen, }$step_name"
done

step_marker="$root/.claude/.step"
step_live="$root/.claude/.step.live"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // empty')"

# Step 0: a step declares itself by writing its name to the marker, and that Write has to be allowed
# before the marker is read — while it is still absent, which is exactly the state the fail-closed
# branch below rejects.
#
# The name written may be ANY step that exists, not only this guard's own. Hooks stay registered for
# the whole session, so on the second step of a session every guard that has already run also sees
# this Write; a guard that refused every name but its own would refuse the handoff, and two steps
# could never run in one session. A name that is not a step stays denied, and Edit and MultiEdit
# against the marker stay denied — the marker is one line, replaced with Write, never patched.
#
# What this guard alone may do is record that it is LIVE: when the name written is its own, it
# writes "<name> <session id>" to .claude/.step.live before allowing. That record is what the
# stand-aside branch below reads. Only a registered guard can produce it, so a marker set by hand —
# through Bash, or by another step's guard passing this name along — leaves no record and stands
# nothing down. Passing another step's name records nothing.
#
# Whitespace is stripped before the comparison the same way the marker is stripped when it is read,
# so a trailing newline is fine and a second line is not.
if [ "$abs" = "$step_marker" ]; then
  if [ "$tool" != "Write" ]; then
    deny "BLOCKED by entity-write-guard: $tool targets the step marker $abs. The marker is a one-line file naming the step currently running; it is replaced with a Write of that one name, never patched. Write it instead: Write the single line entity to .claude/.step, which is the one Write this guard allows outside its lane."
  fi
  declared="$(printf '%s' "$payload" | jq -r '.tool_input.content // empty' | tr -d '[:space:]')"
  case ", $steps_seen," in
    *", $declared,"*) ;;
    *) deny "BLOCKED by entity-write-guard: this Write puts \"$declared\" in the step marker $abs, and no step by that name exists — a step is a directory .claude/skills/<name>/ holding a *-guard.sh. The marker names the step currently running and every registered guard reads it, so a name nothing owns would be honoured by none of them. Write one of: $steps_seen." ;;
  esac
  if [ "$declared" = "entity" ]; then
    printf '%s %s\n' "$declared" "$session_id" > "$step_live"
  fi
  exit 0
fi

# The step gate. A skill's hook is registered when the skill is invoked and stays registered for the
# rest of the session, so running two steps in one session leaves both guards live on every write.
# Each guard permits its own lane and denies the rest, so together they would permit nothing. The
# marker at .claude/.step names the step currently running: this guard enforces only when the marker
# names entity, and stands aside silently when the marker names another step that exists. Every
# skill writes the marker as step 0 of its procedure, before it reads anything and long before any
# Write.
step="$(head -n 1 "$step_marker" 2>/dev/null | tr -d '[:space:]')"
step_is_known=1   # 0 once the marker's name matches one of the steps enumerated above
case ", $steps_seen," in
  *", $step,"*) step_is_known=0 ;;
esac

# Missing or empty marker fails closed. A registered guard means its skill was invoked, and an
# invoked skill sets the marker at step 0 — so an absent marker means step 0 was skipped. Failing
# open here would silently disarm every guard in the repository.
[ -n "$step" ] || deny "BLOCKED by entity-write-guard: the step marker $step_marker is absent or empty, so no step has declared which one is running and no guard can tell whether this write is its own. A registered guard means its skill was invoked, and an invoked skill writes the marker as its step 0 — a missing marker means step 0 was skipped. Do that now, naming the step actually running: Write the single line entity to .claude/.step, which is the one Write this guard allows outside its lane (the name is one of $steps_seen). Deleting .claude/.step is not the fix — an absent marker is exactly the state being rejected. If you are a human working outside the workflow in a session where a skill has already run, the hook stays registered until that session ends: start a fresh session instead."

# Another step is running. Standing aside costs this guard its whole lane, so it asks two questions,
# not one. Does that step EXIST — a directory .claude/skills/<name>/ holding a *-guard.sh? And is
# its guard LIVE in this session — has it recorded itself in .claude/.step.live against this session
# id? Existence alone was the old test and it was not enough: a guard is registered only when its
# skill is invoked, so a marker naming a step whose skill never ran would stand every registered
# guard down and leave nothing at all enforcing that step's lane. Only that step's own guard can
# write the record, and it writes it only for its own name, so the record is the one thing here that
# cannot be produced by writing to the marker. Both questions answered, this guard has no opinion
# about that step's paths: say nothing and let the guard that owns them decide.
[ "$step" = "entity" ] || {
  [ "$step_is_known" -eq 0 ] || deny "BLOCKED by entity-write-guard: the step marker $step_marker names \"$step\", and no step by that name exists — a step is a directory .claude/skills/<name>/ holding a *-guard.sh, and there is none for \"$step\". A marker naming a step nothing owns is enforced by no guard at all, so honouring it here would stand every guard in the repository down at once; it is rejected exactly as an empty marker is. Write the step actually running: Write the single line entity to .claude/.step, which is the one Write this guard allows outside its lane (the name is one of $steps_seen)."
  live="$(head -n 1 "$step_live" 2>/dev/null)"
  live_step="${live%% *}"
  live_session="${live##* }"
  if [ "$live_step" != "$step" ] || [ -z "$session_id" ] || [ "$live_session" != "$session_id" ]; then
    deny "BLOCKED by entity-write-guard: the step marker $step_marker names \"$step\", but no guard for \"$step\" has run in this session — $step_live does not record that name against this session id. A guard is registered only when its skill is invoked, so a marker naming a step whose skill never ran stands every registered guard down and leaves nothing enforcing that step's lane; the marker cannot be honoured on its own word. Only $step's own guard can write that record, and only for its own name, so a marker set by hand or passed along by another guard does not disarm anything. If $step is the step you want, invoke /$step — its step 0 writes the marker and the record together. If entity is the step running, write entity: Write the single line entity to .claude/.step, which is the one Write this guard allows outside its lane."
  fi
  exit 0
}

[ -n "$path" ] || deny "BLOCKED by entity-write-guard: $tool carried no file_path. The /entity skill may only write a Doctrine entity under src/<Module>/Domain/."

# The lane, and the owner of everything outside it.
case "$abs" in
  "$root"/src/Shared/*|"$root"/src/Shared)
    deny "BLOCKED by entity-write-guard: $abs is under src/Shared/, which holds the CQRS base — plain interfaces and their Messenger implementations — and belongs to nobody at this step. An entity is a module's, and it lives under that module's own src/<Module>/Domain/ (invariants 1, 2). A concept this module does not own goes to src/<Module>/Domain/Shared/ with a todo drafted in your report, not into the shared kernel." ;;
  "$root"/src/*/Domain/*) ;;
  "$root"/src/*/Adapter/*|"$root"/src/*/Application/*|"$root"/src/*/Infrastructure/*)
    deny "BLOCKED by entity-write-guard: $abs is in a layer this step never touches. Declarations under src/ are /contract's and their bodies are /build's; this step writes the entities that carry the module's Doctrine mapping metadata, under src/<Module>/Domain/ only. A port, an adapter or a handler that the mapping turns out to need is a finding for your report, not a file you write here." ;;
  "$root"/src/*|"$root"/src)
    deny "BLOCKED by entity-write-guard: $abs is under src/ but not under a module's Domain/ folder. The /entity skill may only write src/<Module>/Domain/<SubNamespace>/<Entity>.php — module-first, then layer (invariant 1). src/Kernel.php and anything else outside a module's Domain/ is a human's." ;;
  "$root"/migrations/*|"$root"/migrations)
    deny "BLOCKED by entity-write-guard: $abs is under migrations/, which is outside this step's lane — no step owns it, and a migration is applied only after a human has approved it (invariant 7). This step's whole output is the entities the mapping metadata lives on. If the schema a migration would produce from that mapping is wrong, the entity is wrong: fix the mapping and say so in your report. Do not write the migration here, and do not run one." ;;
  "$root"/tests/*|"$root"/tests)
    deny "BLOCKED by entity-write-guard: $abs is under tests/, which belongs to the /cover step. An entity is mapping metadata, verified by the schema its mapping produces, and .claude/rules/tests.md rule 11 confines DB-touching tests to tests/<Module>/Infrastructure/ against a real test database. A constraint the mapping cannot express is a line in your report (invariant 39), not a test you add." ;;
  "$root"/docs/todo/*|"$root"/docs/todo)
    deny "BLOCKED by entity-write-guard: $abs is under docs/todo/, which belongs to the /contract step. An entity this module does not own leaves exactly such a todo behind — but this step does not write it: DRAFT it in full in your report, ready to paste, and a /contract run writes it. The todo trail records a decision a human took, and /contract is the step with the human in it (AGENTS.md, 'The todo trail')." ;;
  "$root"/docs/*|"$root"/docs)
    deny "BLOCKED by entity-write-guard: $abs is under docs/, which belongs to the /spec step. The schema specification is this step's input and its source of truth for which tables and columns exist: where it disagrees with the ported code, the specification wins and the disagreement goes in your report — not into an edit you make here." ;;
  "$root"/config/*)
    deny "BLOCKED by entity-write-guard: $abs is under config/, which a human owns. AGENTS.md requires a module's Doctrine mapping section in config/packages/doctrine.yaml to be registered by hand, and a mapping pointing at a folder that does not exist stops the container building at all. Quote the exact block that needs adding and leave it to a human." ;;
  *)
    deny "BLOCKED by entity-write-guard: $abs is outside src/<Module>/Domain/, the only lane the /entity skill has. Other layers of the module belong to /contract and /build, src/Shared/ to nobody at this step, tests/ to /cover, docs/ to /spec, docs/todo/ to /contract, and config/, migrations/ and the repository root — composer.json, phpunit.dist.xml, AGENTS.md — to a human. A Composer dependency is forbidden by invariant 31, and Doctrine already provides everything an entity needs." ;;
esac

# One class per file, PSR-4 under App\ mapped to src/ (invariant 4).
case "$abs" in
  *.php) ;;
  *) deny "BLOCKED by entity-write-guard: $abs is not a PHP file. This step writes one entity class per file, the filename identical to the class name, PSR-4 under the App\\ prefix (invariant 4)." ;;
esac

# What is being written has to BE an entity. A Doctrine mapping attribute is the one piece of
# framework code Domain/ is allowed to carry (invariant 32), and it is what makes this file this
# step's rather than /contract's.
attr='#\[[[:space:]]*\\?(ORM|Doctrine\\ORM\\Mapping)\\(Entity|Embeddable|MappedSuperclass)'

content="$(printf '%s' "$payload" | jq -r '.tool_input.content // empty')"

if [ -n "$content" ]; then
  printf '%s' "$content" | grep -Eq "$attr" || deny "BLOCKED by entity-write-guard: the content written to $abs carries no Doctrine entity mapping attribute — no #[ORM\\Entity], #[ORM\\Embeddable] or #[ORM\\MappedSuperclass]. This step writes entities and nothing else: a port, a rule class, a DTO or an exception under Domain/ is /contract's file, wherever it lands. If you meant an entity, map it; if you meant a declaration, it belongs to /contract."
fi

# An Edit or a MultiEdit carries a fragment, not the file. It may not take the mapping attribute
# back out: a file that stops being an entity stops being this step's file.
if [ "$tool" = "Edit" ] || [ "$tool" = "MultiEdit" ]; then
  olds="$(printf '%s' "$payload" | jq -r '[ (.tool_input.old_string // empty) ] + [ (.tool_input.edits // [])[].old_string // empty ] | join("\n")')"
  news="$(printf '%s' "$payload" | jq -r '[ (.tool_input.new_string // empty) ] + [ (.tool_input.edits // [])[].new_string // empty ] | join("\n")')"
  old_has=0; printf '%s' "$olds" | grep -Eq "$attr" && old_has=1
  new_has=0; printf '%s' "$news" | grep -Eq "$attr" && new_has=1
  if [ "$old_has" -eq 1 ] && [ "$new_has" -eq 0 ]; then
    deny "BLOCKED by entity-write-guard: this edit removes the Doctrine mapping attribute from $abs and puts nothing mapped back. An entity that loses its mapping stops being an entity, and a Domain file that is not an entity is not this step's to write. If the class should no longer be mapped, that is a shape decision for /contract, with the human — say so in your report."
  fi
fi

# A file that already exists has to be an entity ALREADY. Updating one — a column the specification
# records that the mapping is missing — is legitimate; overwriting somebody else's Domain file with
# an entity is not.
[ -e "$abs" ] || exit 0

grep -Eq "$attr" "$abs" 2>/dev/null || deny "BLOCKED by entity-write-guard: $abs already exists and is NOT an entity — its current content carries no Doctrine mapping attribute. A Domain file that is not already an entity is another step's file, and this step may not overwrite it with one: the ports, DTOs, rule classes and exceptions under Domain/ are /contract's, and their bodies are /build's. If this concept should be an entity, that is a shape decision for /contract, with the human. If you meant a new entity, write it at its own path — one class per file (invariant 4)."

exit 0
