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
