#!/usr/bin/env bash
# Integration tests for FUNC-PUSH-002, TECH-HOOK-001, CONF-PREFIX-001
# Requirements:
#   FUNC-PUSH-002  — only commits not yet on the remote tracking branch are checked
#                    (base branch when there is no upstream)
#   TECH-HOOK-001  — `git push` is detected wherever it runs in the command line,
#                    and not when it is only text (echo argument)
#   CONF-PREFIX-001 — `extra_commit_prefixes` in .rbd/config.yml are accepted
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

# new_repo <name>: bare remote + clone with one pushed commit on main; prints the clone path
new_repo() {
  local d="$WORK/$1"
  git init -q --bare "$d.git"
  git init -q -b main "$d"
  (
    cd "$d" || exit 1
    git config user.email t@t && git config user.name t
    git remote add origin "$d.git"
    git commit -q --allow-empty -m "plan: init rbd project"
    git push -q -u origin main
  )
  printf '%s' "$d"
}

commit() { git -C "$1" commit -q --allow-empty -m "$2"; }

# run_hook <repo> <command>: prints the hook exit code
run_hook() {
  local payload
  payload=$(printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$(printf '%s' "$2" | sed 's/"/\\"/g')")
  rm -f "$1/.rbd/.push-validated"
  (cd "$1" && printf '%s' "$payload" | bash "$HOOK" >/dev/null 2>&1)
  printf '%s' "$?"
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

test_extra_prefix_rejected_without_config
test_extra_prefix_accepted_from_config
test_pushed_commits_not_rechecked
test_branch_without_upstream_checked_against_base
test_push_detected_after_other_commands
test_push_text_not_detected

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
