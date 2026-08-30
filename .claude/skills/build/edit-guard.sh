#!/usr/bin/env bash
# PreToolUse guard for the /build skill: the skill implements the stubs under src/<Module>/ and
# touches nothing else.
#
# This is the one step that edits files that already exist — replacing a stub body is its job — so
# Edit and MultiEdit stay in the tool pool and this guard cannot ask "may this file be created".
# It asks the other question: may this file be touched at all. The answer is src/<Module>/ and
# nothing else, for Write, Edit and MultiEdit alike.
#
# tests/ is denied, and that is the point of the step: a step that can edit the tests it is judged
# by can always turn them green, and the green would mean nothing. docs/ is denied because a todo is
# closed by deleting its file in the commit that finishes the work, and this step does not commit.
# config/ and migrations/ are deliberate human edits (invariant 7, and the Doctrine mapping section
# AGENTS.md requires). src/Shared/ is the CQRS base that already landed.
#
# Each denial names the step or the person that owns the path it refused.
#
# Registered from .claude/skills/build/SKILL.md frontmatter. Claude Code keeps a skill hook for the
# rest of the session, so these paths stay blocked until the session ends.
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

# The step gate. A skill's hook is registered when the skill is invoked and stays registered for the
# rest of the session, so running two steps in one session leaves both guards live on every edit.
# Each guard permits its own lane and denies the rest, so together they would permit nothing. The
# marker at .claude/.step names the step currently running: this guard enforces only when the marker
# names build, and stands aside silently when another step is running. Every skill writes the
# marker as step 0 of its procedure, before it reads anything and long before any edit.
step_marker="$root/.claude/.step"
step="$(head -n 1 "$step_marker" 2>/dev/null | tr -d '[:space:]')"

# Missing or empty marker fails closed. A registered guard means its skill was invoked, and an
# invoked skill sets the marker at step 0 — so an absent marker means step 0 was skipped. Failing
# open here would silently disarm every guard in the repository.
[ -n "$step" ] || deny "BLOCKED by build-edit-guard: the step marker $step_marker is absent or empty, so no step has declared which one is running and no guard can tell whether this edit is its own. A registered guard means its skill was invoked, and an invoked skill writes the marker as its step 0 — a missing marker means step 0 was skipped. Do that now, naming the step actually running: printf 'build\\n' > \"\$CLAUDE_PROJECT_DIR/.claude/.step\" (the name is one of spec, contract, cover, build). Deleting .claude/.step is not the fix — an absent marker is exactly the state being rejected. If you are a human working outside the workflow in a session where a skill has already run, the hook stays registered until that session ends: start a fresh session instead."

# Another step is running. This guard has no opinion about its paths — say nothing and let the
# guard that owns this step decide.
[ "$step" = "build" ] || exit 0

[ -n "$path" ] || deny "BLOCKED by build-edit-guard: $tool carried no file_path. The /build skill may only touch files under src/<Module>/."

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

# Outside src/ entirely — name the step, or the person, that owns the path.
case "$abs" in
  "$src"/*) ;;
  "$root"/tests/*|"$root"/tests)
    deny "BLOCKED by build-edit-guard: $abs is under tests/, which belongs to the /cover step and is the specification this step is judged against. A step that can edit the tests it is judged by can always turn them green, and the green would mean nothing. If an expectation looks wrong, stop and say which and why — the cases were verified by executing the original, so an expectation that looks wrong is very unlikely to be wrong. The same applies to tests/<Module>/CASE-COVERAGE.md: a case whose status genuinely changed is a line for your report, not an edit you make here." ;;
  "$root"/docs/todo/*|"$root"/docs/todo)
    deny "BLOCKED by build-edit-guard: $abs is under docs/todo/, which belongs to the /contract step. A todo is closed by DELETING its file in the commit that finishes the work (AGENTS.md, 'The todo trail'), and this step does not commit. Report which todos your work now satisfies and leave the deletion to a human. A todo that turns out to be wrong, or only half-decided, is a finding for your report — not a record you rewrite." ;;
  "$root"/docs/*|"$root"/docs)
    deny "BLOCKED by build-edit-guard: $abs is under docs/, which belongs to the /spec step. The specification is this step's input: a spec that turns out to be wrong is a finding for your report, not an edit you make here." ;;
  "$root"/config/*|"$root"/migrations/*)
    deny "BLOCKED by build-edit-guard: $abs is under config/ or migrations/, which a human owns. Invariant 7 requires a hand-written migration guarded by an existence check, invariant 8 makes an existing one append-only, and AGENTS.md requires a module's Doctrine mapping to be registered by hand. The same goes for a service alias binding a Domain port to its implementation: quote the exact block that needs adding and leave it to a human. Do not paper over a missing alias by constructing an implementation with 'new' inside a handler (invariant 15). And phpunit.dist.xml is not a way to make a failing test stop running." ;;
  *)
    deny "BLOCKED by build-edit-guard: $abs is outside src/, and the /build skill may only touch files under src/<Module>/. tests/ belongs to /cover and is what this step is judged by, docs/ to /spec, docs/todo/ to /contract, config/ and migrations/ to a human. The repository root — composer.json, phpunit.dist.xml, AGENTS.md — is a human's too: a Composer dependency is forbidden by invariant 31, and a test configuration change is a way of arranging for a test not to run." ;;
esac

rel="${abs#"$src"/}"

# Must be src/<Module>/<file> — a module folder, then a file below it.
case "$rel" in
  */*) ;;
  *)   deny "BLOCKED by build-edit-guard: $abs sits directly in src/, not under a module. A module keeps its four layer folders under its own src/{Module}/ root (invariants 1, 2), so every file this step touches has the form src/<Module>/<Layer>/...php." ;;
esac

module="${rel%%/*}"

if [ "$module" = "Shared" ]; then
  deny "BLOCKED by build-edit-guard: $abs is under src/Shared/, the CQRS base that already landed. This step implements a module AGAINST that base — its markers, its buses — and does not change the base itself. If the shared base genuinely needs a different contract, that is a separate change for a human, and it lands before the module that needs it."
fi

case "$abs" in
  *.php) ;;
  *) deny "BLOCKED by build-edit-guard: $abs is not a .php file. This step replaces the throwing stubs /contract declared with real PHP behaviour. Configuration, documentation, fixtures and test data are owned by other steps or by a human." ;;
esac

exit 0
