#!/usr/bin/env bash
# PreToolUse guard for the /contract skill: the skill declares a new module's shape and nothing else.
#
# Edit/MultiEdit/NotebookEdit are already gone from the tool pool via the skill's `disallowed-tools`,
# so no existing file can be modified through them. Write has to stay so the declarations can be
# produced — this closes the remaining gap by allowing a Write only to a NEW file under
# src/<Module>/ and denying every other path.
#
# One path outside src/ is allowed with it: docs/todo/<title>.md, the record of a decision the human
# took at this step and the work it leaves behind (AGENTS.md, "The todo trail").
#
# Each denial names the step that owns the path it refused: the rest of docs/ is /spec's, tests/ is
# /cover's, an existing file under src/ is /build's, and config/ + migrations/ belong to a human.
#
# Registered from .claude/skills/contract/SKILL.md frontmatter. Claude Code keeps a skill hook for
# the rest of the session, so these paths stay blocked until the session ends.
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

[ -n "$path" ] || deny "BLOCKED by contract-write-guard: Write carried no file_path. The /contract skill may only write new files under src/<Module>/, plus docs/todo/<title>.md."

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
    if [ -e "$abs" ]; then
      deny "BLOCKED by contract-write-guard: $abs already exists, and this step may only create new files. That topic already has a record; overwriting it would erase the decision and the remaining work it holds. A todo is closed by deleting the file in the commit that finishes the work, and editing one is a change for a human to make — if this decision is genuinely a different topic, give it its own title."
    fi
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
    deny "BLOCKED by contract-write-guard: $abs is under config/ or migrations/, which a human owns at this step. AGENTS.md requires the new module to register its Doctrine mapping in config/packages/doctrine.yaml, and invariant 7 requires a hand-written migration — both are deliberate human edits. Report the exact block that needs adding and leave it to them." ;;
  *)
    deny "BLOCKED by contract-write-guard: $abs is outside src/, and the /contract skill may only write new declaration files under src/<Module>/. tests/ belongs to /cover, docs/ to /spec, config/ and migrations/ to a human." ;;
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

if [ -e "$abs" ]; then
  deny "BLOCKED by contract-write-guard: $abs already exists, and this step may only create new files. Overwriting it would destroy work that belongs to another step — an implemented body belongs to /build, and an existing declaration is changed by proposing the change to a human first. If the shape you agreed really requires a different file, pick a new path or take it back to the human."
fi

exit 0
