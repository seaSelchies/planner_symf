#!/usr/bin/env bash
# PreToolUse guard for the /spec skill: the skill produces a specification and nothing else.
#
# Edit/MultiEdit/NotebookEdit are already gone from the tool pool via the skill's `disallowed-tools`.
# Write has to stay so the document can be produced — this closes the remaining gap by allowing a
# Write only to docs/specs/<name>.md and denying every other path.
#
# Registered from .claude/skills/spec/SKILL.md frontmatter. Claude Code keeps a skill hook for the
# rest of the session, but registered is not the same as enforcing: the marker at .claude/.step
# decides that. Writes outside docs/specs/ are denied while the marker names spec, and this guard
# stands aside, without looking at the path at all, while the marker names another step that exists.
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
    deny "BLOCKED by spec-write-guard: $tool targets the step marker $abs. The marker is a one-line file naming the step currently running; it is replaced with a Write of that one name, never patched. Write it instead: Write the single line spec to .claude/.step, which is the one Write this guard allows outside its lane."
  fi
  declared="$(printf '%s' "$payload" | jq -r '.tool_input.content // empty' | tr -d '[:space:]')"
  case ", $steps_seen," in
    *", $declared,"*) ;;
    *) deny "BLOCKED by spec-write-guard: this Write puts \"$declared\" in the step marker $abs, and no step by that name exists — a step is a directory .claude/skills/<name>/ holding a *-guard.sh. The marker names the step currently running and every registered guard reads it, so a name nothing owns would be honoured by none of them. Write one of: $steps_seen." ;;
  esac
  if [ "$declared" = "spec" ]; then
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
# names spec, and stands aside silently when the marker names another step that exists. Every
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
[ -n "$step" ] || deny "BLOCKED by spec-write-guard: the step marker $step_marker is absent or empty, so no step has declared which one is running and no guard can tell whether this Write is its own. A registered guard means its skill was invoked, and an invoked skill writes the marker as its step 0 — a missing marker means step 0 was skipped. Do that now, naming the step actually running: Write the single line spec to .claude/.step, which is the one Write this guard allows outside its lane (the name is one of $steps_seen). Deleting .claude/.step is not the fix — an absent marker is exactly the state being rejected. If you are a human working outside the workflow in a session where a skill has already run, the hook stays registered until that session ends: start a fresh session instead."

# Another step is running. Standing aside costs this guard its whole lane, so it asks two questions,
# not one. Does that step EXIST — a directory .claude/skills/<name>/ holding a *-guard.sh? And is
# its guard LIVE in this session — has it recorded itself in .claude/.step.live against this session
# id? Existence alone was the old test and it was not enough: a guard is registered only when its
# skill is invoked, so a marker naming a step whose skill never ran would stand every registered
# guard down and leave nothing at all enforcing that step's lane. Only that step's own guard can
# write the record, and it writes it only for its own name, so the record is the one thing here that
# cannot be produced by writing to the marker. Both questions answered, this guard has no opinion
# about that step's paths: say nothing and let the guard that owns them decide.
[ "$step" = "spec" ] || {
  [ "$step_is_known" -eq 0 ] || deny "BLOCKED by spec-write-guard: the step marker $step_marker names \"$step\", and no step by that name exists — a step is a directory .claude/skills/<name>/ holding a *-guard.sh, and there is none for \"$step\". A marker naming a step nothing owns is enforced by no guard at all, so honouring it here would stand every guard in the repository down at once; it is rejected exactly as an empty marker is. Write the step actually running: Write the single line spec to .claude/.step, which is the one Write this guard allows outside its lane (the name is one of $steps_seen)."
  live="$(head -n 1 "$step_live" 2>/dev/null)"
  live_step="${live%% *}"
  live_session="${live##* }"
  if [ "$live_step" != "$step" ] || [ -z "$session_id" ] || [ "$live_session" != "$session_id" ]; then
    deny "BLOCKED by spec-write-guard: the step marker $step_marker names \"$step\", but no guard for \"$step\" has run in this session — $step_live does not record that name against this session id. A guard is registered only when its skill is invoked, so a marker naming a step whose skill never ran stands every registered guard down and leaves nothing enforcing that step's lane; the marker cannot be honoured on its own word. Only $step's own guard can write that record, and only for its own name, so a marker set by hand or passed along by another guard does not disarm anything. If $step is the step you want, invoke /$step — its step 0 writes the marker and the record together. If spec is the step running, write spec: Write the single line spec to .claude/.step, which is the one Write this guard allows outside its lane."
  fi
  exit 0
}

[ -n "$path" ] || deny "BLOCKED by spec-write-guard: Write carried no file_path. The /spec skill may only write docs/specs/<name>.md."

allowed="$root/docs/specs"

case "$abs" in
  "$allowed"/*.md)
    case "${abs#"$allowed"/}" in
      */*) deny "BLOCKED by spec-write-guard: $abs is nested below docs/specs/. The specification is a single file, docs/specs/<name>.md." ;;
    esac
    exit 0
    ;;
esac

deny "BLOCKED by spec-write-guard: the /spec skill may only write docs/specs/<name>.md, and this Write targets $abs. Investigation establishes what code does; it never changes code. Record what you found in the specification — a bug goes under Discrepancies, an unanswerable question under Open questions — and leave the source untouched."
