#!/usr/bin/env bash
# Integration tests for FUNC-PUSH-001, FUNC-PUSH-002, TECH-HOOK-001, TECH-HOOK-002, CONF-PREFIX-001, CONF-DRAFT-001
# Requirements:
#   FUNC-PUSH-001  — open findings in the latest audit (by file name) block the push
#   FUNC-PUSH-002  — only commits not yet on the remote tracking branch are checked
#                    (base branch when there is no upstream)
#   TECH-HOOK-001  — `git push` is detected wherever it runs in the command line,
#                    and not when it is only text (echo argument)
#   TECH-HOOK-002  — the repository being pushed is checked, only when it holds an RBD project
#   CONF-PREFIX-001 — `extra_commit_prefixes` in .rbd/config.yml are accepted
#   CONF-DRAFT-001  — prefixes in `draft_ok_prefixes` may cite draft requirements
#
# Each case builds a throwaway repository with a bare remote and runs the real
# hook script on a PreToolUse JSON payload. Exit code 0 = allowed, 2 = blocked.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
HOOK="$REPO_ROOT/hooks/rbd-pre-push-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0
PUSH_CMD="git push origin HEAD"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# new_repo <name> [rbd_dir]: bare remote + clone with one pushed commit on main; prints the clone path.
# The RBD project (.rbd/config.yml) sits in rbd_dir, relative to the root (default: root; "none": no RBD).
new_repo() {
  local d="$WORK/$1" rbd="${2:-.}"
  git init -q --bare "$d.git"
  git init -q -b main "$d"
  (
    cd "$d" || exit 1
    git config user.email t@t && git config user.name t
    git remote add origin "$d.git"
    if [ "$rbd" != none ]; then
      mkdir -p "$rbd/.rbd" && printf 'linter:\n  command: "true"\n' > "$rbd/.rbd/config.yml"
      git add . && git commit -q -m "plan: init rbd project"
    else
      git commit -q --allow-empty -m "init"
    fi
    git push -q -u origin main
  )
  printf '%s' "$d"
}

commit() { git -C "$1" commit -q --allow-empty -m "$2"; }

# run_hook <session_dir> <command>: runs the hook from the session directory (process cwd and
# payload cwd), prints the hook exit code
run_hook() {
  local payload
  payload=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$(printf '%s' "$2" | sed 's/"/\\"/g')")
  (cd "$1" && printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1)
  printf '%s' "$?"
}

# hook_stderr <session_dir> <command>: prints what the hook writes to stderr
hook_stderr() {
  local payload
  payload=$(printf '{"tool_name":"Bash","cwd":"%s","tool_input":{"command":"%s"}}' "$1" "$2")
  (cd "$1" && printf '%s' "$payload" | bash "$HOOK" 2>&1 >/dev/null)
}

assert_contains() {
  local description="$1" needle="$2" haystack="$3"
  case "$haystack" in
    *"$needle"*) echo "  PASS: $description"; PASS=$((PASS + 1)) ;;
    *) echo "  FAIL: $description (no '$needle' in '$haystack')"; FAIL=$((FAIL + 1)) ;;
  esac
}

assert_rc() {
  local description="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description (expected exit $expected, got $actual)"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# CONF-PREFIX-001: project-specific extra commit prefixes
# ---------------------------------------------------------------------------

test_extra_prefix_rejected_without_config() {
  echo "test_extra_prefix_rejected_without_config"
  # @req: CONF-PREFIX-001
  # Given a repository without extra_commit_prefixes and an unpushed hw: commit
  local r; r=$(new_repo no_cfg)
  git -C "$r" switch -q -c work
  commit "$r" "hw: change the enclosure"
  # When the hook sees a push
  # Then the push is blocked: hw is not a built-in prefix
  assert_rc "hw: blocked when not declared" 2 "$(run_hook "$r" "$PUSH_CMD")"
}

test_extra_prefix_accepted_from_config() {
  echo "test_extra_prefix_accepted_from_config"
  # @req: CONF-PREFIX-001
  # Given .rbd/config.yml declares extra_commit_prefixes: [hw, cad]
  local r; r=$(new_repo cfg)
  mkdir -p "$r/.rbd" && printf 'linter:\n  command: "true"\nextra_commit_prefixes: [hw, cad]\n' > "$r/.rbd/config.yml"
  git -C "$r" switch -q -c work
  commit "$r" "hw: change the enclosure"
  commit "$r" "cad(case): new lid"
  # When the hook sees a push
  # Then both extra prefixes are accepted, and a wrong prefix is still blocked
  assert_rc "hw: and cad(...): allowed when declared" 0 "$(run_hook "$r" "$PUSH_CMD")"
  commit "$r" "wip: something"
  assert_rc "undeclared prefix still blocked" 2 "$(run_hook "$r" "$PUSH_CMD")"
}

# ---------------------------------------------------------------------------
# FUNC-PUSH-002: only commits about to be pushed are checked
# ---------------------------------------------------------------------------

test_pushed_commits_not_rechecked() {
  echo "test_pushed_commits_not_rechecked"
  # @req: FUNC-PUSH-002
  # Given a bad commit already on the remote tracking branch, and a good new one
  local r; r=$(new_repo pushed)
  git -C "$r" switch -q -c work
  commit "$r" "wip: published before the gate"
  git -C "$r" push -q -u origin work
  commit "$r" "docs: new change"
  # When the hook sees a push
  # Then only the new commit is checked: the push is allowed
  assert_rc "published bad commit ignored" 0 "$(run_hook "$r" "$PUSH_CMD")"
}

test_requirement_ids_checked() {
  echo "test_requirement_ids_checked"
  # @req: FUNC-PUSH-002
  # Given requirements FUNC-A-001 and TECH-B-001 validated, FUNC-C-001 still draft, FUNC-D-001 deprecated
  local r; r=$(new_repo ids)
  mkdir -p "$r/requirements"
  printf '%s\n' '### FUNC-A-001' '**Status:** validated  ' '' '### FUNC-C-001' '**Status:** draft  ' '' '### FUNC-D-001' '**Status:** deprecated  ' > "$r/requirements/functional.md"
  printf '%s\n' '### TECH-B-001' '**Title:** t  ' '**Status:** validated  ' > "$r/requirements/technical.md"
  git -C "$r" add . && git -C "$r" commit -q -m "plan: requirements" && git -C "$r" push -q origin main
  git -C "$r" switch -q -c work
  # When a branch carries one commit with this message, Then the hook exits with the expected code
  local expected msg
  while IFS='|' read -r expected msg; do
    git -C "$r" reset -q --hard main
    commit "$r" "$msg"
    assert_rc "$msg" "$expected" "$(run_hook "$r" "$PUSH_CMD")"
  done <<'CASES'
0|feat(FUNC-A-001): validated FUNC id
0|feat(TECH-B-001): validated TECH id
0|test(FUNC-A-001,TECH-B-001): two validated ids
2|feat(TECH-ZZZ-999): unknown TECH id
2|feat(FUNC-A-001,TECH-ZZZ-999): unknown second id
2|feat(FUNC-C-001): id not validated
0|test(FUNC-D-001): remove tests of a deprecated requirement
2|test(FUNC-C-001): draft id without draft_ok_prefixes
2|feat(foo): no id in scope
2|feat: no id at all
0|req(FUNC-NEW-001): new requirement, not looked up
2|req: no id
0|fix: no id needed
CASES
}

test_draft_ok_prefixes() {
  echo "test_draft_ok_prefixes"
  # @req: CONF-DRAFT-001
  # Given FUNC-A-001 validated, FUNC-C-001 draft, and draft_ok_prefixes: [test]
  local r; r=$(new_repo draftok)
  mkdir -p "$r/requirements"
  printf '%s
' '### FUNC-A-001' '**Status:** validated  ' '' '### FUNC-C-001' '**Status:** draft  ' > "$r/requirements/functional.md"
  printf 'linter:
  command: "true"
draft_ok_prefixes: [test]
' > "$r/.rbd/config.yml"
  git -C "$r" add . && git -C "$r" commit -q -m "plan: requirements" && git -C "$r" push -q origin main
  git -C "$r" switch -q -c work
  # When a branch carries one commit with this message, Then the hook exits with the expected code
  local expected msg
  while IFS='|' read -r expected msg; do
    git -C "$r" reset -q --hard main
    commit "$r" "$msg"
    assert_rc "$msg" "$expected" "$(run_hook "$r" "$PUSH_CMD")"
  done <<'CASES'
0|test(FUNC-C-001): bench sheet of a draft requirement
0|test(FUNC-A-001,FUNC-C-001): validated and draft ids
2|feat(FUNC-C-001): feat still needs a validated requirement
2|test(FUNC-ZZZ-999): unknown id still blocked
2|test: no id still blocked
CASES
}

test_latest_audit_chosen_by_name() {
  echo "test_latest_audit_chosen_by_name"
  # @req: FUNC-PUSH-001
  # Given a clean recent audit, and an older audit with open findings but a newer mtime
  local r; r=$(new_repo audit)
  mkdir -p "$r/audits"
  printf '| F1 | x | **Status:** resolved |\n' > "$r/audits/2026-02-01-audit.md"
  printf '| F1 | x | **Status:** open |\n' > "$r/audits/2026-01-01-audit.md"
  touch -d '2026-01-01' "$r/audits/2026-02-01-audit.md"
  git -C "$r" switch -q -c work
  commit "$r" "docs: change"
  # When the hook sees a push, Then only the latest by name counts
  assert_rc "old open audit ignored" 0 "$(run_hook "$r" "$PUSH_CMD")"
  # Given the latest audit by name has open findings, Then the push is blocked
  printf '| F2 | x | **Status:** open |\n' > "$r/audits/2026-03-01-audit.md"
  touch -d '2026-01-01' "$r/audits/2026-03-01-audit.md"
  assert_rc "latest open audit blocks" 2 "$(run_hook "$r" "$PUSH_CMD")"
}

test_merge_commits_not_checked() {
  echo "test_merge_commits_not_checked"
  # @req: FUNC-PUSH-002
  # Given a work branch that merged main after main moved on
  local r; r=$(new_repo merge)
  git -C "$r" switch -q -c work
  commit "$r" "docs: on work"
  git -C "$r" switch -q main
  commit "$r" "docs: on main"
  git -C "$r" switch -q work
  git -C "$r" merge -q --no-edit main
  # When the hook sees a push
  # Then the "Merge branch ..." commit is not checked: the push is allowed
  assert_rc "merge commit allowed" 0 "$(run_hook "$r" "$PUSH_CMD")"
}

test_branch_without_upstream_checked_against_base() {
  echo "test_branch_without_upstream_checked_against_base"
  # @req: FUNC-PUSH-002
  # Given a new local branch with no upstream and a bad commit
  local r; r=$(new_repo no_upstream)
  git -C "$r" switch -q -c work
  commit "$r" "wip: never pushed"
  # When the hook sees a push
  # Then commits since the base branch are checked: the push is blocked
  assert_rc "bad commit on a new branch blocked" 2 "$(run_hook "$r" "$PUSH_CMD")"
}

# ---------------------------------------------------------------------------
# TECH-HOOK-001: git push detection
# ---------------------------------------------------------------------------

test_push_detected_after_other_commands() {
  echo "test_push_detected_after_other_commands"
  # @req: TECH-HOOK-001
  # Given an unpushed bad commit
  local r; r=$(new_repo detect)
  git -C "$r" switch -q -c work
  commit "$r" "wip: bad"
  # When git push runs after cd &&, after ;, or as git -C <dir> push
  # Then the hook intercepts each of them
  assert_rc "cd dir && git push" 2 "$(run_hook "$r" "cd $r && $PUSH_CMD")"
  assert_rc "git status; git push" 2 "$(run_hook "$r" "git status; $PUSH_CMD")"
  assert_rc "git -C dir push" 2 "$(run_hook "$r" "git -C $r push origin HEAD")"
}

test_hook_runs_from_plugin() {
  echo "test_hook_runs_from_plugin"
  # @req: TECH-HOOK-001
  # Given the plugin's hook registration and init instructions
  # When they are read
  # Then the hook runs from the plugin directory, and init copies nothing to ~/.claude/hooks
  assert_contains "hooks.json uses CLAUDE_PLUGIN_ROOT" '${CLAUDE_PLUGIN_ROOT}/hooks/rbd-pre-push-check.sh' "$(cat "$REPO_ROOT/hooks/hooks.json")"
  if grep -q "claude/hooks" "$REPO_ROOT/skills/rbd/SKILL.md"; then
    echo "  FAIL: init still installs a copy in ~/.claude/hooks"; FAIL=$((FAIL + 1))
  else
    echo "  PASS: init installs no copy"; PASS=$((PASS + 1))
  fi
}

test_block_reason_on_stderr() {
  echo "test_block_reason_on_stderr"
  # @req: TECH-HOOK-001
  # Given an unpushed commit with a bad prefix and quotes in its message
  local r; r=$(new_repo reason)
  git -C "$r" switch -q -c work
  commit "$r" 'wip: the "quoted" change'
  # When the hook blocks the push
  # Then the reason, naming the commit, is on stderr
  assert_contains "stderr names the bad commit" 'wip: the "quoted" change' "$(hook_stderr "$r" "$PUSH_CMD")"
}

test_push_text_not_detected() {
  echo "test_push_text_not_detected"
  # @req: TECH-HOOK-001
  # Given an unpushed bad commit
  local r; r=$(new_repo text)
  git -C "$r" switch -q -c work
  commit "$r" "wip: bad"
  # When the words only appear as text in another command
  # Then the hook lets it run
  assert_rc "echo \"git push\" not intercepted" 0 "$(run_hook "$r" "echo \"$PUSH_CMD later\"")"
  assert_rc "git status not intercepted" 0 "$(run_hook "$r" "git status")"
}

# ---------------------------------------------------------------------------
# TECH-HOOK-002: the repository being pushed is the one checked
# ---------------------------------------------------------------------------

test_target_repo_checked_not_session_repo() {
  echo "test_target_repo_checked_not_session_repo"
  # @req: TECH-HOOK-002
  # Given a session started in repo A, and another repo B
  local a b; a=$(new_repo session_a); b=$(new_repo target_b)
  git -C "$a" switch -q -c work; git -C "$b" switch -q -c work
  commit "$b" "wip: bad commit in B"
  # When the push goes to B through cd, a relative cd, or git -C
  # Then B's bad commit blocks it
  assert_rc "cd B && git push blocked by B" 2 "$(run_hook "$a" "cd $b && $PUSH_CMD")"
  assert_rc "cd ../B && git push blocked by B" 2 "$(run_hook "$a" "cd ../target_b && $PUSH_CMD")"
  assert_rc "git -C B push blocked by B" 2 "$(run_hook "$a" "git -C $b push origin HEAD")"
  # Given now the bad commit is only in A, and B is clean
  git -C "$b" reset -q --hard main
  commit "$a" "wip: bad commit in A"
  # Then pushing B is allowed, pushing from A still blocked
  assert_rc "cd B && git push ignores A" 0 "$(run_hook "$a" "cd $b && $PUSH_CMD")"
  assert_rc "plain git push checks A" 2 "$(run_hook "$a" "$PUSH_CMD")"
}

test_non_rbd_repo_not_checked() {
  echo "test_non_rbd_repo_not_checked"
  # @req: TECH-HOOK-002
  # Given a repository without .rbd/config.yml and a bad commit
  local r; r=$(new_repo plain none)
  git -C "$r" switch -q -c work
  commit "$r" "wip: not an rbd project"
  # When the hook sees a push, Then it lets it through
  assert_rc "non-RBD repo allowed" 0 "$(run_hook "$r" "$PUSH_CMD")"
  # And a directory outside any git repository is allowed too
  mkdir -p "$WORK/no_git"
  assert_rc "outside git allowed" 0 "$(run_hook "$WORK/no_git" "$PUSH_CMD")"
}

test_rbd_project_in_subdirectory() {
  echo "test_rbd_project_in_subdirectory"
  # @req: TECH-HOOK-002
  # Given a monorepo whose RBD project lives in plugins/p, declaring extra prefix hw
  local r; r=$(new_repo mono plugins/p)
  printf 'linter:\n  command: "true"\nextra_commit_prefixes: [hw]\n' > "$r/plugins/p/.rbd/config.yml"
  git -C "$r" switch -q -c work
  commit "$r" "hw: from the subproject config"
  # When the hook sees a push, Then the subproject config applies
  assert_rc "subproject extra prefix allowed" 0 "$(run_hook "$r" "$PUSH_CMD")"
  commit "$r" "wip: bad"
  assert_rc "bad commit in monorepo blocked" 2 "$(run_hook "$r" "$PUSH_CMD")"
}

test_target_repo_checked_not_session_repo
test_non_rbd_repo_not_checked
test_rbd_project_in_subdirectory
test_extra_prefix_rejected_without_config
test_extra_prefix_accepted_from_config
test_pushed_commits_not_rechecked
test_branch_without_upstream_checked_against_base
test_merge_commits_not_checked
test_latest_audit_chosen_by_name
test_requirement_ids_checked
test_draft_ok_prefixes
test_push_detected_after_other_commands
test_push_text_not_detected
test_block_reason_on_stderr
test_hook_runs_from_plugin

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
