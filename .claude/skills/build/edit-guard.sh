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
# migrations/ is outside this step's lane, and a migration is applied only after a human has approved
# it (invariant 7). config/ is a deliberate human edit (the Doctrine mapping section AGENTS.md
# requires). src/Shared/ is the CQRS base that already landed.
#
# Each denial names the step or the person that owns the path it refused.
#
# One file inside the lane is only half this step's: an entity. Its methods are this step's to
# change, its mapping is /entity's, and the check below holds the split by comparing the file's
# mapping surface. Two limits are worth stating plainly, because they are the price of a check that
# cannot be talked around: the comparison is TEXTUAL, so a rewrite that means exactly the same thing
# is refused and the same attributes in a different order are read as a change; and Bash is not
# intercepted by this or any lane guard, so what keeps a mapping edit out of a shell command is the
# rule the step keeps, not this hook.
#
# Registered from .claude/skills/build/SKILL.md frontmatter. Claude Code keeps a skill hook for the
# rest of the session, but registered is not the same as enforcing: the marker at .claude/.step
# decides that. These paths are denied while the marker names build, and this guard stands aside,
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
    deny "BLOCKED by build-edit-guard: $tool targets the step marker $abs. The marker is a one-line file naming the step currently running; it is replaced with a Write of that one name, never patched. Write it instead: Write the single line build to .claude/.step, which is the one Write this guard allows outside its lane."
  fi
  declared="$(printf '%s' "$payload" | jq -r '.tool_input.content // empty' | tr -d '[:space:]')"
  case ", $steps_seen," in
    *", $declared,"*) ;;
    *) deny "BLOCKED by build-edit-guard: this Write puts \"$declared\" in the step marker $abs, and no step by that name exists — a step is a directory .claude/skills/<name>/ holding a *-guard.sh. The marker names the step currently running and every registered guard reads it, so a name nothing owns would be honoured by none of them. Write one of: $steps_seen." ;;
  esac
  if [ "$declared" = "build" ]; then
    printf '%s %s\n' "$declared" "$session_id" > "$step_live"
  fi
  exit 0
fi

# The step gate. A skill's hook is registered when the skill is invoked and stays registered for the
# rest of the session, so running two steps in one session leaves both guards live on every edit.
# Each guard permits its own lane and denies the rest, so together they would permit nothing. The
# marker at .claude/.step names the step currently running: this guard enforces only when the marker
# names build, and stands aside silently when the marker names another step that exists. Every
# skill writes the marker as step 0 of its procedure, before it reads anything and long before any
# edit.
step="$(head -n 1 "$step_marker" 2>/dev/null | tr -d '[:space:]')"
step_is_known=1   # 0 once the marker's name matches one of the steps enumerated above
case ", $steps_seen," in
  *", $step,"*) step_is_known=0 ;;
esac

# Missing or empty marker fails closed. A registered guard means its skill was invoked, and an
# invoked skill sets the marker at step 0 — so an absent marker means step 0 was skipped. Failing
# open here would silently disarm every guard in the repository.
[ -n "$step" ] || deny "BLOCKED by build-edit-guard: the step marker $step_marker is absent or empty, so no step has declared which one is running and no guard can tell whether this edit is its own. A registered guard means its skill was invoked, and an invoked skill writes the marker as its step 0 — a missing marker means step 0 was skipped. Do that now, naming the step actually running: Write the single line build to .claude/.step, which is the one Write this guard allows outside its lane (the name is one of $steps_seen). Deleting .claude/.step is not the fix — an absent marker is exactly the state being rejected. If you are a human working outside the workflow in a session where a skill has already run, the hook stays registered until that session ends: start a fresh session instead."

# Another step is running. Standing aside costs this guard its whole lane, so it asks two questions,
# not one. Does that step EXIST — a directory .claude/skills/<name>/ holding a *-guard.sh? And is
# its guard LIVE in this session — has it recorded itself in .claude/.step.live against this session
# id? Existence alone was the old test and it was not enough: a guard is registered only when its
# skill is invoked, so a marker naming a step whose skill never ran would stand every registered
# guard down and leave nothing at all enforcing that step's lane. Only that step's own guard can
# write the record, and it writes it only for its own name, so the record is the one thing here that
# cannot be produced by writing to the marker. Both questions answered, this guard has no opinion
# about that step's paths: say nothing and let the guard that owns them decide.
[ "$step" = "build" ] || {
  [ "$step_is_known" -eq 0 ] || deny "BLOCKED by build-edit-guard: the step marker $step_marker names \"$step\", and no step by that name exists — a step is a directory .claude/skills/<name>/ holding a *-guard.sh, and there is none for \"$step\". A marker naming a step nothing owns is enforced by no guard at all, so honouring it here would stand every guard in the repository down at once; it is rejected exactly as an empty marker is. Write the step actually running: Write the single line build to .claude/.step, which is the one Write this guard allows outside its lane (the name is one of $steps_seen)."
  live="$(head -n 1 "$step_live" 2>/dev/null)"
  live_step="${live%% *}"
  live_session="${live##* }"
  if [ "$live_step" != "$step" ] || [ -z "$session_id" ] || [ "$live_session" != "$session_id" ]; then
    deny "BLOCKED by build-edit-guard: the step marker $step_marker names \"$step\", but no guard for \"$step\" has run in this session — $step_live does not record that name against this session id. A guard is registered only when its skill is invoked, so a marker naming a step whose skill never ran stands every registered guard down and leaves nothing enforcing that step's lane; the marker cannot be honoured on its own word. Only $step's own guard can write that record, and only for its own name, so a marker set by hand or passed along by another guard does not disarm anything. If $step is the step you want, invoke /$step — its step 0 writes the marker and the record together. If build is the step running, write build: Write the single line build to .claude/.step, which is the one Write this guard allows outside its lane."
  fi
  exit 0
}

[ -n "$path" ] || deny "BLOCKED by build-edit-guard: $tool carried no file_path. The /build skill may only touch files under src/<Module>/."

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
  "$root"/migrations/*)
    deny "BLOCKED by build-edit-guard: $abs is under migrations/, which is outside this step's lane — no step in this pipeline owns it. A migration is applied only after a human has approved it (invariant 7), and invariant 8 makes an existing one append-only. A schema change this step turns out to need is a finding for your report and goes back to /entity, not a file you write here." ;;
  "$root"/config/*)
    deny "BLOCKED by build-edit-guard: $abs is under config/, which a human owns. AGENTS.md requires a module's Doctrine mapping to be registered by hand. The same goes for a service alias binding a Domain port to its implementation: quote the exact block that needs adding and leave it to a human. Do not paper over a missing alias by constructing an implementation with 'new' inside a handler (invariant 15). And phpunit.dist.xml is not a way to make a failing test stop running." ;;
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

# --- The entity split ---------------------------------------------------------------------------
#
# src/<Module>/Domain/ is inside this step's lane, and /entity's files sit in it. The METHODS of an
# entity are this step's: a getter, a derived value, a question the class can answer. The MAPPING is
# /entity's. This step writes the Infrastructure adapters that read these tables through DQL, and
# when a query will not build, the shortest fix is to widen a column, add an association or relax a
# property type — which silently changes the schema the database is required to have, with no
# migration, no /entity run, no ownership gate and no todo. Nothing in the suite touches a database,
# so nothing would notice. /contract's guard already makes the mirror refusal; this is /build's.
#
# The MAPPING SURFACE of a file is, taken together:
#   - every line carrying a Doctrine mapping attribute, #[ORM\...] in any form, including the
#     fully-qualified #[\Doctrine\ORM\Mapping\...];
#   - every typed property declaration line. A property's type is part of the mapping in practice:
#     private string $nameEn and private ?string $nameEn hydrate differently, with no attribute
#     touched.
#
# Three honest limits, stated rather than hidden:
#   - The comparison is TEXTUAL. A semantically identical rewrite is refused, and a reordering is
#     read as a change. That is the trade for a check that cannot be talked around.
#   - It recognises `private` and `protected` properties, the form every entity in this repository
#     uses. A public typed property would not be seen.
#   - Bash is not intercepted by this or any lane guard. What keeps a mapping edit out of a shell
#     command is the rule the step keeps, not this hook.
attr='#\[[[:space:]]*\\?(ORM|Doctrine\\ORM\\Mapping)\\(Entity|Embeddable|MappedSuperclass)'
map_attr='#\[[[:space:]]*\\?(ORM|Doctrine\\ORM\\Mapping)\\'
prop='(private|protected)[[:space:]]+[^();=]*\$[A-Za-z_]'
surface_re="^[[:space:]]*($map_attr|$prop)"

content="$(printf '%s' "$payload" | jq -r '.tool_input.content // empty')"

if [ -e "$abs" ] && grep -Eq "$attr" "$abs" 2>/dev/null; then

  # Edit and MultiEdit carry a fragment, not the file, so the surface cannot be compared at all.
  if [ "$tool" != "Write" ]; then
    deny "BLOCKED by build-edit-guard: $abs is an entity — the file on disk carries a Doctrine mapping attribute — and $tool carries only a fragment of it, so its mapping surface cannot be compared. The methods of an entity are this step's to change; its mapping is /entity's. Replace the whole file with Write instead, which is checked precisely: leave every mapping attribute and every typed property declaration exactly as they are and the write goes through."
  fi

  # A mapping attribute that runs onto a second line would put a change on a continuation line the
  # line-based comparison never looks at. Every entity in this repository is single-line today.
  unclosed="$(printf '%s\n' "$content" | grep -E "^[[:space:]]*$map_attr" | awk '{ if (gsub(/\[/, "[") != gsub(/\]/, "]")) { print; exit } }')"
  if [ -n "$unclosed" ]; then
    deny "BLOCKED by build-edit-guard: this write puts a Doctrine mapping attribute on $abs that does not close on its own line: $unclosed. The mapping surface is compared line by line, so an attribute spread over several lines would let a change on a continuation line pass unseen. Every entity in this repository is single-line today and this keeps it that way. Write the attribute on one line — and if it genuinely cannot be, that is a finding for your report and a change for /entity, which owns this mapping."
  fi

  disk_surface="$(grep -E "$surface_re" "$abs" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"
  new_surface="$(printf '%s\n' "$content" | grep -E "$surface_re" | sed -E 's/[[:space:]]+/ /g; s/^ //; s/ $//')"

  if [ "$disk_surface" != "$new_surface" ]; then
    n=1
    while :; do
      was="$(printf '%s\n' "$disk_surface" | sed -n "${n}p")"
      now="$(printf '%s\n' "$new_surface" | sed -n "${n}p")"
      [ -z "$was" ] && [ -z "$now" ] && break
      [ "$was" != "$now" ] && break
      n=$((n + 1))
    done
    [ -n "$was" ] || was="(nothing — the surface ends here)"
    [ -n "$now" ] || now="(nothing — the surface ends here)"
    deny "BLOCKED by build-edit-guard: this write changes the mapping surface of $abs, which is an entity. Entry $n of the surface differs — on disk: $was — written: $now. The mapping surface is every Doctrine mapping attribute line plus every typed property declaration line, and this step may change an entity's methods but not its mapping: a column, a type, an association or a constraint is /entity's, and changing it here would change the schema the database is required to have with no migration and no ownership gate. Add your method and leave the surface untouched. If the mapping genuinely cannot carry the query you are writing, that is a finding for your report and a reason to run /entity, not an edit made here. Note the comparison is textual: a rewrite that means the same thing, or the same attributes in a different order, is refused too."
  fi

  exit 0
fi

# The file is not an entity, and this step may not make it one — the same refusal /contract's guard
# makes. Everything else about a non-entity file is unchanged: stubs and implementations as before.
if [ -n "$content" ] && printf '%s' "$content" | grep -Eq "$attr"; then
  deny "BLOCKED by build-edit-guard: the content written to $abs carries a Doctrine entity mapping attribute — #[ORM\\Entity], #[ORM\\Embeddable] or #[ORM\\MappedSuperclass] — and the file is not an entity today. Turning a class into an entity is a shape decision and a schema decision at once: /entity takes the ownership question to a human concept by concept, and builds the mapping from the schema specification and the reference SQL. This step implements declared behaviour. If the module needs this table mapped, say so in your report and run /entity."
fi

exit 0
