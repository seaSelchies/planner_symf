#!/usr/bin/env bash
# PreToolUse guard for the /cover skill: the skill writes failing tests and nothing else.
#
# Edit/MultiEdit/NotebookEdit are already gone from the tool pool via the skill's `disallowed-tools`,
# so no existing file can be modified through them. Write has to stay so the tests can be produced —
# this closes the remaining gap by allowing a Write only to a NEW file under tests/ and denying every
# other path.
#
# src/ is denied outright: this step never touches the module it tests. A stub "helpfully"
# implemented here destroys the only evidence that the tests bite. docs/ is denied too, docs/todo/
# included — recording a decision belongs to /contract, the step that takes decisions.
#
# Each denial names the step that owns the path it refused: src/ declarations are /contract's and
# their bodies /build's, docs/ is /spec's, docs/todo/ is /contract's, and config/ + migrations/
# belong to a human.
#
# Registered from .claude/skills/cover/SKILL.md frontmatter. Claude Code keeps a skill hook for the
# rest of the session, so these paths stay blocked until the session ends.
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
# names cover, and stands aside silently when another step is running. Every skill writes the
# marker as step 0 of its procedure, before it reads anything and long before any Write.
step_marker="$root/.claude/.step"
step="$(head -n 1 "$step_marker" 2>/dev/null | tr -d '[:space:]')"

# Missing or empty marker fails closed. A registered guard means its skill was invoked, and an
# invoked skill sets the marker at step 0 — so an absent marker means step 0 was skipped. Failing
# open here would silently disarm every guard in the repository.
[ -n "$step" ] || deny "BLOCKED by cover-write-guard: the step marker $step_marker is absent or empty, so no step has declared which one is running and no guard can tell whether this Write is its own. A registered guard means its skill was invoked, and an invoked skill writes the marker as its step 0 — a missing marker means step 0 was skipped. Do that now, naming the step actually running: printf 'cover\\n' > \"\$CLAUDE_PROJECT_DIR/.claude/.step\" (the name is one of spec, contract, cover, build). Deleting .claude/.step is not the fix — an absent marker is exactly the state being rejected. If you are a human working outside the workflow in a session where a skill has already run, the hook stays registered until that session ends: start a fresh session instead."

# Another step is running. This guard has no opinion about its paths — say nothing and let the
# guard that owns this step decide.
[ "$step" = "cover" ] || exit 0

[ -n "$path" ] || deny "BLOCKED by cover-write-guard: Write carried no file_path. The /cover skill may only write new files under tests/."

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

tests="$root/tests"

# Outside tests/ entirely — name the step that owns the path.
case "$abs" in
  "$tests"/*) ;;
  "$root"/src/*|"$root"/src)
    deny "BLOCKED by cover-write-guard: $abs is under src/, which this step never touches. The declarations there are /contract's and their bodies are /build's. A stub implemented here — even a trivial one, even 'just to see the test go green' — destroys the only evidence that these tests bite: a failure on the \\LogicException a stub throws is the expected red. If a contract is wrong, that is a finding for your report and goes back to /contract." ;;
  "$root"/docs/todo/*|"$root"/docs/todo)
    deny "BLOCKED by cover-write-guard: $abs is under docs/todo/, which belongs to the /contract step. The todo trail records a decision a human took and the work it leaves behind; this step decides nothing. Something you cannot express against the contracts is a finding for your report — not a decision to record." ;;
  "$root"/docs/*|"$root"/docs)
    deny "BLOCKED by cover-write-guard: $abs is under docs/, which belongs to the /spec step. The specification is this step's input, and its case table is what your tests must account for: a spec that turns out to be wrong is a finding for your report, not an edit you make here." ;;
  "$root"/config/*|"$root"/migrations/*)
    deny "BLOCKED by cover-write-guard: $abs is under config/ or migrations/, which a human owns. Invariant 7 requires a hand-written migration and AGENTS.md requires the module's Doctrine mapping to be registered by hand. A Domain or Application test needs neither — it runs with no database and no container (.claude/rules/tests.md, rule 10)." ;;
  *)
    deny "BLOCKED by cover-write-guard: $abs is outside tests/, and the /cover skill may only write new test files under tests/. src/ belongs to /contract and /build, docs/ to /spec, docs/todo/ to /contract, config/ and migrations/ to a human." ;;
esac

if [ -e "$abs" ]; then
  deny "BLOCKED by cover-write-guard: $abs already exists, and this step may only create new files. Overwriting it would erase tests someone else wrote for cases you may not have read. Put the new tests in a file of their own — the layout mirrors the module, tests/{Module}/{Layer}/... (.claude/rules/tests.md, rule 6), and a fake lives beside the test that uses it, one class per file (rule 4)."
fi

exit 0
