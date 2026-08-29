#!/usr/bin/env bash
# PreToolUse guard for the /spec skill: the skill produces a specification and nothing else.
#
# Edit/MultiEdit/NotebookEdit are already gone from the tool pool via the skill's `disallowed-tools`.
# Write has to stay so the document can be produced — this closes the remaining gap by allowing a
# Write only to docs/specs/<name>.md and denying every other path.
#
# Registered from .claude/skills/spec/SKILL.md frontmatter. Claude Code keeps a skill hook
# for the rest of the session, so Writes outside docs/specs/ stay blocked until the session ends.
#
# stdin: PreToolUse event JSON. Denies via hookSpecificOutput.permissionDecision.

set -uo pipefail

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
[ "$tool" = "Write" ] || exit 0

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

# The step gate. A skill's hook is registered when the skill is invoked and stays registered for the
# rest of the session, so running two steps in one session leaves both guards live on every Write.
# Each guard permits its own lane and denies the rest, so together they would permit nothing. The
# marker at .claude/.step names the step currently running: this guard enforces only when the marker
# names spec, and stands aside silently when another step is running. Every skill writes the
# marker as step 0 of its procedure, before it reads anything and long before any Write.
step_marker="$root/.claude/.step"
step="$(head -n 1 "$step_marker" 2>/dev/null | tr -d '[:space:]')"

# Missing or empty marker fails closed. A registered guard means its skill was invoked, and an
# invoked skill sets the marker at step 0 — so an absent marker means step 0 was skipped. Failing
# open here would silently disarm every guard in the repository.
[ -n "$step" ] || deny "BLOCKED by spec-write-guard: the step marker $step_marker is absent or empty, so no step has declared which one is running and no guard can tell whether this Write is its own. A registered guard means its skill was invoked, and an invoked skill writes the marker as its step 0 — a missing marker means step 0 was skipped. Do that now, naming the step actually running: printf 'spec\\n' > \"\$CLAUDE_PROJECT_DIR/.claude/.step\" (the name is one of spec, contract, cover). Deleting .claude/.step is not the fix — an absent marker is exactly the state being rejected. If you are a human working outside the workflow in a session where a skill has already run, the hook stays registered until that session ends: start a fresh session instead."

# Another step is running. This guard has no opinion about its paths — say nothing and let the
# guard that owns this step decide.
[ "$step" = "spec" ] || exit 0

[ -n "$path" ] || deny "BLOCKED by spec-write-guard: Write carried no file_path. The /spec skill may only write docs/specs/<name>.md."

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
