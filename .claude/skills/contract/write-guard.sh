#!/usr/bin/env bash
# PreToolUse guard for the /contract skill: the skill declares a new module's shape and nothing else.
#
# Edit/MultiEdit/NotebookEdit are already gone from the tool pool via the skill's `disallowed-tools`,
# so no existing file can be modified through them. Write has to stay so the declarations can be
# produced — this closes the remaining gap by allowing a Write only under src/<Module>/ and denying
# every other path.
#
# One path outside src/ is allowed with it: docs/todo/<title>.md, the record of a decision the human
# took at this step and the work it leaves behind (AGENTS.md, "The todo trail").
#
# Inside those two lanes an existing file may be overwritten: the lane is what this guard protects,
# not the newness of a path. What replaced the old existence ban is the gate in SKILL.md — see the
# notes at each former ban site below.
#
# Each denial names the step that owns the path it refused: the rest of docs/ is /spec's, tests/ is
# /cover's, src/Shared/ is nobody's at this step, and config/ + migrations/ belong to a human.
#
# One owner sits INSIDE this step's own lane, and the last two checks in this file are what keep it
# separate. The pipeline is /spec -> /entity -> /contract -> /cover -> /build, so /entity — which runs
# only where /spec produced a schema specification, that is, only where the source reaches a database
# — has already written the module's Doctrine entities under src/<Module>/Domain/ by the time this
# step runs. A path this step is otherwise free to overwrite therefore holds files that are not its
# own. This guard makes the mirror of the two checks /entity's guard performs, and looks at what is
# being written as well as at where:
#
#   - The content being written must NOT contain a Doctrine entity mapping attribute. Introducing one
#     here would make this step the author of an entity, which is /entity's whole output.
#   - If the target file already exists, its current content must NOT contain that attribute either.
#     A file that is already an entity is /entity's file, and this step may not write over it.
#
# Only Write reaches this guard — Edit/MultiEdit are out of the tool pool — so the whole file arrives
# in tool_input.content and both questions can be answered directly.
#
# Registered from .claude/skills/contract/SKILL.md frontmatter. Claude Code keeps a skill hook for
# the rest of the session, but registered is not the same as enforcing: the marker at .claude/.step
# decides that. These paths are denied while the marker names contract, and this guard stands aside,
# without looking at the path at all, while the marker names another step that exists.
#
# stdin: PreToolUse event JSON. Denies via hookSpecificOutput.permissionDecision.

set -uo pipefail

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
# Edit and MultiEdit are out of this skill's tool pool and off this hook's matcher, so they do not
# arrive here in practice. They are let through the gate anyway so that the self-declaration branch
# below can refuse them against the step marker on its own, rather than relying on that. Every other
# tool is nothing to do with this guard. The Write-only gate is restored once that branch has run.
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
    deny "BLOCKED by contract-write-guard: $tool targets the step marker $abs. The marker is a one-line file naming the step currently running; it is replaced with a Write of that one name, never patched. Write it instead: Write the single line contract to .claude/.step, which is the one Write this guard allows outside its lane."
  fi
  declared="$(printf '%s' "$payload" | jq -r '.tool_input.content // empty' | tr -d '[:space:]')"
  case ", $steps_seen," in
    *", $declared,"*) ;;
    *) deny "BLOCKED by contract-write-guard: this Write puts \"$declared\" in the step marker $abs, and no step by that name exists — a step is a directory .claude/skills/<name>/ holding a *-guard.sh. The marker names the step currently running and every registered guard reads it, so a name nothing owns would be honoured by none of them. Write one of: $steps_seen." ;;
  esac
  if [ "$declared" = "contract" ]; then
    printf '%s %s\n' "$declared" "$session_id" > "$step_live"
  fi
  exit 0
fi

# Past the marker. Everything below concerns this skill's own lane, which only Write reaches.
[ "$tool" = "Write" ] || exit 0

# The step gate. A skill's hook is registered when the skill is invoked and stays registered for the
# rest of the session, so running two steps in one session leaves both guards live on every Write.
# Each guard permits its own lane and denies the rest, so together they would permit nothing. The
# marker at .claude/.step names the step currently running: this guard enforces only when the marker
# names contract, and stands aside silently when the marker names another step that exists. Every
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
[ -n "$step" ] || deny "BLOCKED by contract-write-guard: the step marker $step_marker is absent or empty, so no step has declared which one is running and no guard can tell whether this Write is its own. A registered guard means its skill was invoked, and an invoked skill writes the marker as its step 0 — a missing marker means step 0 was skipped. Do that now, naming the step actually running: Write the single line contract to .claude/.step, which is the one Write this guard allows outside its lane (the name is one of $steps_seen). Deleting .claude/.step is not the fix — an absent marker is exactly the state being rejected. If you are a human working outside the workflow in a session where a skill has already run, the hook stays registered until that session ends: start a fresh session instead."

# Another step is running. Standing aside costs this guard its whole lane, so it asks two questions,
# not one. Does that step EXIST — a directory .claude/skills/<name>/ holding a *-guard.sh? And is
# its guard LIVE in this session — has it recorded itself in .claude/.step.live against this session
# id? Existence alone was the old test and it was not enough: a guard is registered only when its
# skill is invoked, so a marker naming a step whose skill never ran would stand every registered
# guard down and leave nothing at all enforcing that step's lane. Only that step's own guard can
# write the record, and it writes it only for its own name, so the record is the one thing here that
# cannot be produced by writing to the marker. Both questions answered, this guard has no opinion
# about that step's paths: say nothing and let the guard that owns them decide.
[ "$step" = "contract" ] || {
  [ "$step_is_known" -eq 0 ] || deny "BLOCKED by contract-write-guard: the step marker $step_marker names \"$step\", and no step by that name exists — a step is a directory .claude/skills/<name>/ holding a *-guard.sh, and there is none for \"$step\". A marker naming a step nothing owns is enforced by no guard at all, so honouring it here would stand every guard in the repository down at once; it is rejected exactly as an empty marker is. Write the step actually running: Write the single line contract to .claude/.step, which is the one Write this guard allows outside its lane (the name is one of $steps_seen)."
  live="$(head -n 1 "$step_live" 2>/dev/null)"
  live_step="${live%% *}"
  live_session="${live##* }"
  if [ "$live_step" != "$step" ] || [ -z "$session_id" ] || [ "$live_session" != "$session_id" ]; then
    deny "BLOCKED by contract-write-guard: the step marker $step_marker names \"$step\", but no guard for \"$step\" has run in this session — $step_live does not record that name against this session id. A guard is registered only when its skill is invoked, so a marker naming a step whose skill never ran stands every registered guard down and leaves nothing enforcing that step's lane; the marker cannot be honoured on its own word. Only $step's own guard can write that record, and only for its own name, so a marker set by hand or passed along by another guard does not disarm anything. If $step is the step you want, invoke /$step — its step 0 writes the marker and the record together. If contract is the step running, write contract: Write the single line contract to .claude/.step, which is the one Write this guard allows outside its lane."
  fi
  exit 0
}

[ -n "$path" ] || deny "BLOCKED by contract-write-guard: Write carried no file_path. The /contract skill may only write files under src/<Module>/, plus docs/todo/<title>.md."

src="$root/src"
todo="$root/docs/todo"

# The one path outside src/ this step may write: the todo trail. A decision the human took here, and
# the work it leaves behind, is recorded as docs/todo/<title>.md — see AGENTS.md, "The todo trail".
case "$abs" in
  "$todo"/*)
    case "${abs#"$todo"/}" in
      */*) deny "BLOCKED by contract-write-guard: $abs is nested below docs/todo/. The todo trail is one topic per flat file, docs/todo/<title>.md with a kebab-case title — a directory tree under it hides open debt instead of showing it at a glance." ;;
    esac
    case "$abs" in
      *.md) ;;
      *) deny "BLOCKED by contract-write-guard: $abs is not a .md file. A todo is a written record — docs/todo/<title>.md — not code, configuration or data." ;;
    esac
    # An existing todo may be rewritten. What protects it is the gate: nothing is written here until
    # a human has answered, and a proposal that changes what an existing record says shows the old
    # text against the new. A todo is still closed by deleting the file in the commit that finishes
    # the work — rewriting one is for a decision that moved, not a way to retire it.
    exit 0
    ;;
esac


# Outside src/ entirely — name the step that owns the path.
case "$abs" in
  "$src"/*) ;;
  "$root"/tests/*|"$root"/tests)
    deny "BLOCKED by contract-write-guard: $abs is under tests/, which belongs to the /cover step. This step declares the shape the tests will be written against; it does not write the tests. Write the declarations under src/<Module>/ and stop there." ;;
  "$root"/docs/*|"$root"/docs)
    deny "BLOCKED by contract-write-guard: $abs is under docs/, which belongs to the /spec step, and the only docs path this step may write is docs/todo/<title>.md — the decision a human took here and the work it leaves behind. The specification itself is /spec's output and this step's input: a spec that turns out to be wrong is a finding for your report, not an edit you make here." ;;
  "$root"/config/*|"$root"/migrations/*)
    deny "BLOCKED by contract-write-guard: $abs is under config/ or migrations/, neither of which is this step's lane. AGENTS.md requires the new module to register its Doctrine mapping in config/packages/doctrine.yaml — a deliberate human edit — and a migration under migrations/ is applied only after a human has approved it (invariant 7). Report the exact block that needs adding and leave it to them." ;;
  *)
    deny "BLOCKED by contract-write-guard: $abs is outside src/, and the /contract skill may only write declaration files under src/<Module>/. tests/ belongs to /cover, docs/ to /spec, config/ and migrations/ to a human." ;;
esac

rel="${abs#"$src"/}"

# Must be src/<Module>/<file> — a module folder, then a file below it.
case "$rel" in
  */*) ;;
  *)   deny "BLOCKED by contract-write-guard: $abs sits directly in src/, not under a module. A new module reproduces its four layer folders under its own src/{Module}/ root (invariants 1, 2), so every file this step writes has the form src/<Module>/<Layer>/...php." ;;
esac

module="${rel%%/*}"

if [ "$module" = "Shared" ]; then
  deny "BLOCKED by contract-write-guard: $abs is under src/Shared/, the CQRS base that already landed. This step declares a NEW module and implements the existing Shared markers (invariant 13) — it does not extend the shared base. If the base genuinely needs a new contract, that is a separate change for a human."
fi

case "$abs" in
  *.php) ;;
  *) deny "BLOCKED by contract-write-guard: $abs is not a .php file. This step writes PHP declarations only — interfaces, immutable DTOs, exceptions, and stub classes whose every method body throws \\LogicException. Configuration, documentation and fixtures are owned by other steps." ;;
esac

# An existing declaration under src/<Module>/ may be overwritten. A step that can only ever add is a
# step with one pass, and revising its own output meant a human deleting files by hand. What protects
# this step is the thing the others do not have: the gate. It proposes and waits for a human before
# writing anything, and where the proposal changes a declaration that already exists it shows the old
# signature against the new one and names the case or finding that forces the change — the human
# approves a change, not a filename. See SKILL.md, "The gate is the point of this skill".
#
# The one exception is an entity, which is /entity's file and sits inside this lane. The mirror of the
# check /entity's guard performs: what is written here may not carry a Doctrine mapping attribute, and
# a file that already carries one may not be written over.
attr='#\[[[:space:]]*\\?(ORM|Doctrine\\ORM\\Mapping)\\(Entity|Embeddable|MappedSuperclass)'

content="$(printf '%s' "$payload" | jq -r '.tool_input.content // empty')"

if [ -n "$content" ] && printf '%s' "$content" | grep -Eq "$attr"; then
  deny "BLOCKED by contract-write-guard: the content written to $abs carries a Doctrine entity mapping attribute — #[ORM\\Entity], #[ORM\\Embeddable] or #[ORM\\MappedSuperclass]. An entity is /entity's file, not this step's: /entity runs before /contract, builds the mapping from the schema specification and the reference SQL, and takes the ownership question — does this module own the concept, or only read it — to a human entity by entity. This step declares ports, DTOs, exceptions and throwing stubs. If the module needs this table mapped, run /entity; if you meant a declaration, write it without the mapping attribute."
fi

if [ -e "$abs" ] && grep -Eq "$attr" "$abs" 2>/dev/null; then
  deny "BLOCKED by contract-write-guard: $abs already exists and IS an entity — its current content carries a Doctrine mapping attribute. Entities land before this step, so /entity's files sit under src/<Module>/Domain/, inside the lane this step may otherwise overwrite; that does not make them this step's. A column, an association or a constraint the mapping is missing is an edit for /entity, and a class that should stop being an entity is a shape decision to take with the human and then carry out by running /entity. Say so in your report. If you meant a new declaration, write it at its own path — one class per file (invariant 4)."
fi

exit 0
