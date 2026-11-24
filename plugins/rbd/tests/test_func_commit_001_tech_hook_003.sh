#!/usr/bin/env bash
# Integration tests for FUNC-COMMIT-001, TECH-HOOK-003
# Requirements:
#   FUNC-COMMIT-001 — a commit changing a plan file needs plan: or a prefix accepted_prefixes: allows for it;
#                     the refusal names the files and their allowed prefixes; merge commits are not checked
#   TECH-HOOK-003   — one script, two entry points: PreToolUse on `git commit -m` (exit 2) and git
#                     commit-msg hook (exit 1)
#
# Each case builds a throwaway RBD repository whose plan files are requirements/*.md (accepted: req) and
# audits/exclusions.yml, then runs the real script.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/rbd-plan-file-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# new_repo <name> [rbd_dir]: repository with one commit; the RBD project sits in rbd_dir (default: root,
# "none": no RBD project). Prints the repository path.
new_repo() {
  local d="$WORK/$1" rbd="${2:-.}"
  git init -q -b main "$d"
  (
    cd "$d" || exit 1
    git config user.email t@t && git config user.name t
    local files="$rbd"; [ "$rbd" = none ] && files=.
    mkdir -p src "$files/requirements" "$files/audits"
    echo a > "$files/requirements/functional.md"
    echo a > "$files/audits/exclusions.yml"
    echo a > src/main.c
    if [ "$rbd" != none ]; then
      mkdir -p "$rbd/.rbd"
      printf 'linter:\n  command: "true"\n' > "$rbd/.rbd/config.yml"
      cat > "$rbd/.rbd/plan-files.yml" <<'YAML'
plan_files:
  - requirements/*.md   # every category file
  - audits/exclusions.yml

accepted_prefixes:
  requirements/*.md: [req]
YAML
    fi
    git add . && git commit -q --no-verify -m "plan: init rbd project"
  )
  printf '%s' "$d"
}

touch_file() { echo "$RANDOM" >> "$1/$2"; }

# commit_msg_rc <repo> <subject>: runs the commit-msg entry on a message file, prints the exit code
commit_msg_rc() {
  printf '%s\n\nbody\n' "$2" > "$WORK/msg"
  (cd "$1" && bash "$HOOK" "$WORK/msg" >/dev/null 2>&1)
  printf '%s' "$?"
}

# pretool <session_dir> <command>: runs the PreToolUse entry on a JSON payload, exit code then stderr
pretool() {
  local payload
  payload=$(python3 -c 'import json,sys; print(json.dumps({"tool_name":"Bash","cwd":sys.argv[1],"tool_input":{"command":sys.argv[2]}}))' "$1" "$2")
  (cd "$1" && printf '%s' "$payload" | bash "$HOOK" 2>"$WORK/err" >/dev/null)
  printf '%s' "$?"
}

assert_rc() {
  local description="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $description"; PASS=$((PASS + 1))
  else
    echo "  FAIL: $description (expected exit $expected, got $actual)"; FAIL=$((FAIL + 1))
  fi
}

assert_contains() {
  local description="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) echo "  PASS: $description"; PASS=$((PASS + 1)) ;;
    *) echo "  FAIL: $description (no '$needle' in '$haystack')"; FAIL=$((FAIL + 1)) ;;
  esac
}

# ---------------------------------------------------------------------------
# FUNC-COMMIT-001: which prefix may change which file (commit-msg entry)
# ---------------------------------------------------------------------------

test_prefix_per_plan_file() {
  echo "test_prefix_per_plan_file"
  # @req: FUNC-COMMIT-001
  # @req: TECH-HOOK-003
  local n=0 file subject expected r
  # file | subject | expected exit (0 accepted, 1 refused)
  while IFS='|' read -r file subject expected; do
    n=$((n + 1))
    # Given a staged change to <file>
    r=$(new_repo "case$n")
    touch_file "$r" "$file" && git -C "$r" add "$file"
    # When the commit-msg entry sees <subject>
    # Then the commit is accepted or refused
    assert_rc "$subject on $file" "$expected" "$(commit_msg_rc "$r" "$subject")"
  done <<'CASES'
requirements/functional.md|docs: reword|1
requirements/functional.md|test(FUNC-A-001): change a requirement in a test commit|1
requirements/functional.md|feat(FUNC-A-001): add the feature|1
audits/exclusions.yml|req(FUNC-A-001): exclude a finding|1
requirements/functional.md|req(FUNC-A-001): new requirement|0
requirements/functional.md|plan: reformat|0
audits/exclusions.yml|plan: exclude a finding|0
src/main.c|feat(FUNC-A-001): add the feature|0
CASES
}

test_refusal_names_files_and_prefixes() {
  echo "test_refusal_names_files_and_prefixes"
  # @req: FUNC-COMMIT-001
  # Given staged changes to a requirement file and to exclusions.yml
  local r; r=$(new_repo names)
  touch_file "$r" requirements/functional.md && touch_file "$r" audits/exclusions.yml && git -C "$r" add .
  # When a docs: commit is attempted
  printf 'docs: x\n' > "$WORK/msg"
  local err; err=$(cd "$r" && bash "$HOOK" "$WORK/msg" 2>&1 >/dev/null)
  # Then the reason names each file with its allowed prefixes
  assert_contains "names the requirement file and req" "requirements/functional.md (plan, req)" "$err"
  assert_contains "names exclusions.yml and plan" "audits/exclusions.yml (plan)" "$err"
}

test_real_commits_through_shim() {
  echo "test_real_commits_through_shim"
  # @req: FUNC-COMMIT-001
  # @req: TECH-HOOK-003
  # Given the commit-msg hook installed as a shim calling the plugin script
  local r; r=$(new_repo shim)
  printf '#!/bin/sh\nexec bash "%s" "$1"\n' "$HOOK" > "$r/.git/hooks/commit-msg"
  chmod +x "$r/.git/hooks/commit-msg"
  touch_file "$r" requirements/functional.md && git -C "$r" add .
  # When git commit runs
  # Then a docs: commit is refused and a req(ID): commit goes through
  git -C "$r" commit -q -m "docs: reword" 2>/dev/null
  assert_rc "docs: refused by git" 1 "$?"
  git -C "$r" commit -q -m "req(FUNC-A-001): reword" 2>/dev/null
  assert_rc "req(ID): accepted by git" 0 "$?"
  # And a merge commit that brings a plan file change is not checked
  git -C "$r" switch -q -c side
  touch_file "$r" requirements/functional.md && git -C "$r" add . && git -C "$r" commit -q -m "plan: side"
  git -C "$r" switch -q main
  touch_file "$r" src/main.c && git -C "$r" add . && git -C "$r" commit -q -m "fix: main"
  git -C "$r" merge -q --no-ff --no-edit side 2>/dev/null
  assert_rc "merge commit not checked" 0 "$?"
}

# ---------------------------------------------------------------------------
# TECH-HOOK-003: PreToolUse entry
# ---------------------------------------------------------------------------

test_pretool_commands() {
  echo "test_pretool_commands"
  # @req: TECH-HOOK-003
  # @req: FUNC-COMMIT-001
  local n=0 stage cmd expected r
  # stage (yes: the requirement change is staged before the command) | command | expected exit (2 blocked)
  while IFS='|' read -r stage cmd expected; do
    n=$((n + 1))
    # Given an RBD repository with a changed requirement file, staged or not
    r=$(new_repo "pre$n")
    touch_file "$r" requirements/functional.md
    [ "$stage" = yes ] && git -C "$r" add .
    cmd=${cmd//@R@/$r}
    # When Claude runs <command>
    # Then the hook blocks or allows it
    assert_rc "$cmd" "$expected" "$(pretool "$r" "$(printf '%b' "$cmd")")"
  done <<'CASES'
yes|git commit -m "docs: reword"|2
yes|git commit -m 'docs: reword'|2
yes|git commit -q -m "plan: reword"|0
yes|git commit -m "req(FUNC-A-001): reword"|0
no|git add requirements/functional.md && git commit -m "docs: reword"|2
no|git add -A && git commit -m "plan: reword"|0
no|git commit -am "docs: reword"|2
no|git commit -m "docs: reword"|0
yes|git commit -m "$(cat <<'EOF'\ndocs: reword\n\nbody\nEOF\n)"|2
yes|git commit -m "$(cat <<'EOF'\nplan: reword\n\nbody\nEOF\n)"|0
yes|echo git commit -m "docs: reword"|0
yes|git status|0
yes|cd /tmp && cd @R@ && git commit -m "docs: reword"|2
yes|git -C @R@ commit -m "docs: reword"|2
CASES
}

test_pretool_block_reason_on_stderr() {
  echo "test_pretool_block_reason_on_stderr"
  # @req: TECH-HOOK-003
  # Given a staged requirement change
  local r; r=$(new_repo stderr)
  touch_file "$r" requirements/functional.md && git -C "$r" add .
  # When a docs: commit is attempted through Claude
  pretool "$r" 'git commit -m "docs: x"' >/dev/null
  # Then the reason is on stderr
  assert_contains "reason on stderr" "requirements/functional.md (plan, req)" "$(cat "$WORK/err")"
}

test_pretool_repositories() {
  echo "test_pretool_repositories"
  # @req: TECH-HOOK-003
  # Given a repository with no RBD project and a staged change
  local r; r=$(new_repo plain none)
  touch_file "$r" requirements/functional.md && git -C "$r" add .
  # Then it is not checked
  assert_rc "non-RBD repository not checked" 0 "$(pretool "$r" 'git commit -m "docs: x"')"
  # Given an RBD project in a subdirectory (monorepo)
  r=$(new_repo mono plugins/p)
  touch_file "$r" plugins/p/requirements/functional.md && git -C "$r" add .
  # Then plan file paths are relative to the RBD project
  assert_rc "subproject plan file checked" 2 "$(pretool "$r" 'git commit -m "docs: x"')"
  assert_contains "subproject path named" "plugins/p/requirements/functional.md" "$(cat "$WORK/err")"
}

test_hook_registered_for_bash() {
  echo "test_hook_registered_for_bash"
  # @req: TECH-HOOK-003
  # Then hooks.json runs the script from the installed plugin
  assert_contains "registered in hooks.json" '${CLAUDE_PLUGIN_ROOT}/hooks/rbd-plan-file-check.sh' \
    "$(cat "$REPO_ROOT/hooks/hooks.json")"
}

test_prefix_per_plan_file
test_refusal_names_files_and_prefixes
test_real_commits_through_shim
test_pretool_commands
test_pretool_block_reason_on_stderr
test_pretool_repositories
test_hook_registered_for_bash

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
