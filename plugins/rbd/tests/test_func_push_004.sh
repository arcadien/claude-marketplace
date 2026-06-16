#!/usr/bin/env bash
# Integration tests for FUNC-PUSH-004
# Requirement: Pre-push validation state caching via dotfile
#
# After all pre-push checks pass, the orchestrator writes .rbd/.push-validated
# containing the output of `git rev-parse HEAD`. On the next push, the hook
# reads the file first: if the hash matches it allows the push and deletes the
# file; if the file is absent or the hash differs it runs the full check
# sequence. The file must be listed in .gitignore.
#
# Production side must provide:
#   - skills/rbd/SKILL.md       — must declare: writing .rbd/.push-validated
#                                 with HEAD hash after checks pass
#   - hooks/hooks.json          — hook prompt must declare: reading
#                                 .rbd/.push-validated first, allowing push on
#                                 hash match, deleting the file, and running
#                                 full checks when file is absent or hash differs
#   - .gitignore                — must list .rbd/.push-validated

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/rbd/SKILL.md"
HOOK_FILE="$REPO_ROOT/hooks/hooks.json"
GITIGNORE_FILE="$REPO_ROOT/.gitignore"

PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

assert_contains() {
  local description="$1"
  local file="$2"
  local grep_flag=""
  local pattern="$3"
  if [ "$3" = "-E" ]; then
    grep_flag="-E"
    pattern="$4"
  fi

  if grep -q $grep_flag "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    echo "        file    : $file"
    echo "        pattern : $pattern"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local description="$1"
  local file="$2"

  if [ -f "$file" ]; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    echo "        expected file: $file"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# FUNC-PUSH-004: Pre-push validation state caching via dotfile
# ---------------------------------------------------------------------------

test_orch_writes_push_validated_after_success() {
  echo "test_orch_writes_push_validated_after_success"
  # @req: FUNC-PUSH-004

  # Given
  # FUNC-PUSH-004 requires the orchestrator to write .rbd/.push-validated
  # after all pre-push checks complete successfully.

  # When
  # We inspect the rbd skill definition for a declaration that it writes
  # (or creates) the .rbd/.push-validated file on successful check completion.

  # Then
  assert_contains \
    "orchestrator declares it writes .rbd/.push-validated after checks pass" \
    "$SKILL_FILE" \
    ".push-validated"
}

test_push_validated_contains_head_hash() {
  echo "test_push_validated_contains_head_hash"
  # @req: FUNC-PUSH-004

  # Given
  # FUNC-PUSH-004 specifies that the file must contain the output of
  # `git rev-parse HEAD` — the current HEAD commit hash.

  # When
  # We inspect the rbd skill definition for a reference to git rev-parse HEAD,
  # confirming that the HEAD hash is the content written to the dotfile.

  # Then
  assert_contains \
    "orchestrator declares HEAD hash as dotfile content (git rev-parse HEAD)" \
    "$SKILL_FILE" \
    -E "rev-parse|HEAD hash|HEAD commit"
}

test_hook_reads_push_validated_first() {
  echo "test_hook_reads_push_validated_first"
  # @req: FUNC-PUSH-004

  # Given
  # FUNC-PUSH-004 requires the hook to read .rbd/.push-validated before
  # running the full pre-push check sequence.

  # When
  # We inspect the hook prompt for a declaration that .rbd/.push-validated
  # is read (or checked) as the very first step of push handling.

  # Then
  assert_contains \
    "hook declares reading .rbd/.push-validated before running checks" \
    "$HOOK_FILE" \
    ".push-validated"
}

test_hook_allows_push_on_hash_match() {
  echo "test_hook_allows_push_on_hash_match"
  # @req: FUNC-PUSH-004

  # Given
  # FUNC-PUSH-004 requires the hook to allow the push without running checks
  # when the dotfile exists and its content matches the current HEAD hash.

  # When
  # We inspect the hook prompt for a declaration that a matching hash results
  # in the push being allowed (patterns: "match", "allow", "skip").

  # Then
  assert_contains \
    "hook declares allowing push when cached hash matches HEAD" \
    "$HOOK_FILE" \
    -E "match|allow.*push|skip.*check|push.*allow"
}

test_hook_deletes_file_after_match() {
  echo "test_hook_deletes_file_after_match"
  # @req: FUNC-PUSH-004

  # Given
  # FUNC-PUSH-004 specifies that the hook deletes the dotfile after a
  # successful hash match, since the file is ephemeral one-time-use state.

  # When
  # We inspect the hook prompt for a declaration that the file is deleted
  # (or removed) after the hash matches and the push is allowed.

  # Then
  assert_contains \
    "hook declares deleting .push-validated after hash match" \
    "$HOOK_FILE" \
    -E "delet|remov"
}

test_hook_runs_full_check_on_hash_mismatch() {
  echo "test_hook_runs_full_check_on_hash_mismatch"
  # @req: FUNC-PUSH-004

  # Given
  # FUNC-PUSH-004 requires the hook to run the full check sequence when the
  # dotfile exists but its content does not match the current HEAD hash.

  # When
  # We inspect the hook prompt for a declaration that a hash mismatch triggers
  # the full pre-push checks (patterns: "mismatch", "differ", "does not match",
  # "full check", "proceed with").

  # Then
  assert_contains \
    "hook declares running full checks when cached hash does not match HEAD" \
    "$HOOK_FILE" \
    -E "mismatch|differ|does not match|full check|proceed with"
}

test_hook_runs_full_check_when_file_absent() {
  echo "test_hook_runs_full_check_when_file_absent"
  # @req: FUNC-PUSH-004

  # Given
  # FUNC-PUSH-004 requires the hook to run the full check sequence when the
  # dotfile is absent (no cached validation state).

  # When
  # We inspect the hook prompt for a declaration that the absence of the file
  # causes the full check sequence to run (patterns: "absent", "missing",
  # "does not exist", "not found", "not present").

  # Then
  assert_contains \
    "hook declares running full checks when .push-validated is absent" \
    "$HOOK_FILE" \
    -E "absent|missing|does not exist|not found|not present|no file"
}

test_push_validated_in_gitignore() {
  echo "test_push_validated_in_gitignore"
  # @req: FUNC-PUSH-004

  # Given
  # FUNC-PUSH-004 explicitly states: "The file .rbd/.push-validated must be
  # listed in .gitignore — it is ephemeral state and must never be committed."

  # When
  # We check that .gitignore exists and contains .rbd/.push-validated (or
  # a glob pattern that covers it).

  # Then
  assert_file_exists \
    ".gitignore exists" \
    "$GITIGNORE_FILE"
  assert_contains \
    ".gitignore contains .push-validated entry" \
    "$GITIGNORE_FILE" \
    ".push-validated"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== FUNC-PUSH-004: Pre-push validation state caching via dotfile ==="
echo ""

test_orch_writes_push_validated_after_success
test_push_validated_contains_head_hash
test_hook_reads_push_validated_first
test_hook_allows_push_on_hash_match
test_hook_deletes_file_after_match
test_hook_runs_full_check_on_hash_mismatch
test_hook_runs_full_check_when_file_absent
test_push_validated_in_gitignore

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
