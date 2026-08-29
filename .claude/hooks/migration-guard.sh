#!/usr/bin/env bash
# PreToolUse guard: a Doctrine migration that reached the shared branch is append-only.
#
# "Shared" = the path exists in origin/main or in the local main branch. A migration that
# lives only on a feature branch, or is not committed at all, stays freely editable.
# Falls back to "tracked in git" when neither ref exists.
#
# Works for both agent clients:
#   Claude Code : Edit, MultiEdit, Write, NotebookEdit, Bash
#   Copilot     : insert_edit_into_file, replace_string_in_file, apply_patch, create_file,
#                 str_replace_editor, bash, runInTerminal, run_in_terminal, local_shell, powershell
#
# stdin: PreToolUse event JSON. Blocks with exit code 2, reason on stderr.

set -uo pipefail

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty')"
[ -n "$cwd" ] || cwd="$PWD"
root="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)" || root="$cwd"

deny() {
  printf 'BLOCKED by migration-guard: %s\n' "$1" >&2
  printf 'This migration is already on the shared branch, so other environments may have it recorded in doctrine_migration_versions. Rewriting it makes fresh databases build a different schema than migrated ones — drift that tests and CI still report as green.\nFix forward: add a NEW migration that alters the schema.\n' >&2
  exit 2
}

abs_path() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$cwd" "${1#./}" ;;
  esac
}

# Present on a shared branch?
is_shared() {
  local abs="$1" rel ref found_ref=0
  rel="${abs#"$root"/}"
  for ref in origin/main main; do
    git -C "$cwd" rev-parse --verify --quiet "$ref" >/dev/null 2>&1 || continue
    found_ref=1
    git -C "$cwd" cat-file -e "$ref:$rel" 2>/dev/null && return 0
  done
  [ "$found_ref" -eq 0 ] && git -C "$cwd" ls-files --error-unmatch -- "$abs" >/dev/null 2>&1
}

guard_path() {
  local abs
  abs="$(abs_path "$1")"
  case "$abs" in
    */migrations/*|*/migration/doctrine/*)
      is_shared "$abs" && deny "$tool would rewrite $(basename "$abs"), a migration already on the shared branch"
      ;;
  esac
}

case "$tool" in
  # ---- shell, both clients -------------------------------------------------
  Bash|bash|powershell|local_shell|runInTerminal|run_in_terminal)
    cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // .tool_input.commandLine // empty')"
    [ -n "$cmd" ] || exit 0

    if printf '%s' "$cmd" | grep -Eq 'migrations:(rollup|dump-schema)'; then
      deny "the command collapses existing migration history ($cmd)"
    fi

    printf '%s' "$cmd" | grep -Eq 'migrations/|migration/doctrine/' || exit 0
    printf '%s' "$cmd" | grep -Eq '(^|[;&|[:space:]])(rm|mv|cp|truncate|tee|dd|install)([[:space:]]|$)|sed[[:space:]]+-[^[:space:]]*i|perl[[:space:]]+-[^[:space:]]*i|>>?[[:space:]]*[^[:space:]]*migration' || exit 0

    for token in $(printf '%s' "$cmd" | tr -s " \t'\"|;&()<>" '\n' | grep -E 'migrations/|migration/doctrine/'); do
      abs="$(abs_path "$token")"
      if [ -f "$abs" ] && is_shared "$abs"; then
        deny "the command would modify or remove $(basename "$abs"), a migration already on the shared branch ($cmd)"
      fi
    done
    exit 0
    ;;

  # ---- file edits, both clients -------------------------------------------
  Edit|MultiEdit|Write|NotebookEdit|insert_edit_into_file|replace_string_in_file|create_file|str_replace_editor|apply_patch)
    # Known path keys across both clients.
    for key in file_path filePath path notebook_path notebookPath; do
      p="$(printf '%s' "$payload" | jq -r --arg k "$key" '.tool_input[$k] // empty')"
      [ -n "$p" ] && guard_path "$p"
    done
    # apply_patch keeps paths in patch headers. Only headers are inspected: a file whose
    # *content* mentions a migration path must not be blocked.
    if [ "$tool" = "apply_patch" ]; then
      for p in $(printf '%s' "$payload" \
                 | jq -r '.tool_input | to_entries[] | .value | select(type == "string")' \
                 | grep -E '^[[:space:]]*(\*\*\* (Update|Delete|Add) File:|---|\+\+\+|diff --git)' \
                 | grep -oE '[A-Za-z0-9_./-]*(migrations/|migration/doctrine/)[A-Za-z0-9_.-]+' \
                 | sort -u); do
        guard_path "$p"
      done
    fi
    exit 0
    ;;
esac

exit 0
