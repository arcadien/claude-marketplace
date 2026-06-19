#!/usr/bin/env bash
# Integration tests for FUNC-METRICS-002
# Requirement: Opt-in req-to-green latency per requirement
#
# When invoked with the --latency flag, rbd-metrics traverses the git log to
# compute, for each validated requirement, the elapsed time between the
# req(ID): commit timestamp and the first test(ID): commit timestamp.
# Requirements with no test commit are shown as "pending". Results are
# displayed as a latency column appended to the ASCII structured list
# produced by FUNC-METRICS-001. The computation is strictly read-only.
#
# Production side must provide:
#   - skills/rbd-metrics/SKILL.md  -- must declare all behaviors listed below:
#       * supports a --latency flag
#       * traverses git log to find req(ID): commit timestamps
#       * traverses git log to find test(ID): commit timestamps (for latency)
#       * computes elapsed time (latency) between req commit and first test commit
#       * shows "pending" for requirements with no test commit
#       * appends a latency column to the ASCII structured list from FUNC-METRICS-001
#       * the computation is strictly read-only (no file written)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/rbd-metrics/SKILL.md"

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

  if grep -q $grep_flag -- "$pattern" "$file" 2>/dev/null; then
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
# FUNC-METRICS-002: Opt-in req-to-green latency per requirement
# ---------------------------------------------------------------------------

test_latency_skill_file_exists() {
  echo "test_latency_skill_file_exists"
  # @req: FUNC-METRICS-002

  # Given
  # FUNC-METRICS-002 extends the rbd-metrics skill introduced by
  # FUNC-METRICS-001. The skill entry-point is skills/rbd-metrics/SKILL.md.

  # When
  # We check that skills/rbd-metrics/SKILL.md is present on the filesystem.

  # Then
  assert_file_exists \
    "skills/rbd-metrics/SKILL.md exists" \
    "$SKILL_FILE"
}

test_latency_skill_declares_latency_flag() {
  echo "test_latency_skill_declares_latency_flag"
  # @req: FUNC-METRICS-002

  # Given
  # FUNC-METRICS-002 requires the --latency flag to activate latency mode.
  # The skill definition must document this flag so the agent knows when to
  # trigger the latency computation path instead of the standard report.

  # When
  # We inspect the skill definition for an explicit declaration of the
  # --latency flag.

  # Then
  assert_contains \
    "rbd-metrics skill declares --latency flag support" \
    "$SKILL_FILE" \
    "--latency"
}

test_latency_skill_traverses_req_commit_timestamps() {
  echo "test_latency_skill_traverses_req_commit_timestamps"
  # @req: FUNC-METRICS-002

  # Given
  # FUNC-METRICS-002 requires the skill to find, for each validated requirement,
  # the timestamp of the commit whose message matches the prefix req(ID):.
  # This timestamp marks when the requirement entered the codebase.

  # When
  # We inspect the skill definition for a declaration that it reads the git log
  # to extract req(ID): commit timestamps.

  # Then
  assert_contains \
    "rbd-metrics skill declares traversal of git log for req(ID): commit timestamps" \
    "$SKILL_FILE" \
    -E "req\(.*\).*timestamp|req\(.*\).*commit|timestamp.*req\(|commit.*req\("
}

test_latency_skill_traverses_test_commit_timestamps() {
  echo "test_latency_skill_traverses_test_commit_timestamps"
  # @req: FUNC-METRICS-002

  # Given
  # FUNC-METRICS-002 requires the skill to find, for each validated requirement,
  # the timestamp of the first commit whose message matches the prefix test(ID):.
  # This timestamp marks when the first test was committed for that requirement.

  # When
  # We inspect the skill definition for a declaration that it reads the git log
  # to extract test(ID): commit timestamps in the context of latency computation.

  # Then
  assert_contains \
    "rbd-metrics skill declares traversal of git log for test(ID): commit timestamps (latency)" \
    "$SKILL_FILE" \
    -E "test\(.*\).*timestamp|test\(.*\).*commit.*timestamp|timestamp.*test\(|latency.*test\("
}

test_latency_skill_computes_elapsed_time() {
  echo "test_latency_skill_computes_elapsed_time"
  # @req: FUNC-METRICS-002

  # Given
  # FUNC-METRICS-002 requires the skill to compute the elapsed time between
  # the req(ID): commit and the first test(ID): commit for each validated
  # requirement. This duration is the "req-to-green latency".

  # When
  # We inspect the skill definition for a declaration that it computes an
  # elapsed time, duration, or latency between the two commit timestamps.

  # Then
  assert_contains \
    "rbd-metrics skill declares elapsed time computation between req and test commits" \
    "$SKILL_FILE" \
    -E "elapsed|duration|latency.*between|req-to-green|time between"
}

test_latency_skill_shows_pending_for_no_test_commit() {
  echo "test_latency_skill_shows_pending_for_no_test_commit"
  # @req: FUNC-METRICS-002

  # Given
  # FUNC-METRICS-002 requires that validated requirements for which no
  # test(ID): commit exists are shown as "pending" in the latency column,
  # rather than a numeric duration or an error.

  # When
  # We inspect the skill definition for a declaration that the output shows
  # "pending" for requirements with no test commit.

  # Then
  assert_contains \
    "rbd-metrics skill declares 'pending' for requirements with no test commit" \
    "$SKILL_FILE" \
    "pending"
}

test_latency_skill_appends_latency_column_to_ascii_list() {
  echo "test_latency_skill_appends_latency_column_to_ascii_list"
  # @req: FUNC-METRICS-002

  # Given
  # FUNC-METRICS-002 requires the latency data to be appended as an additional
  # column to the ASCII structured list produced by FUNC-METRICS-001. The
  # existing tree structure must remain intact; the latency column extends it.

  # When
  # We inspect the skill definition for a declaration that a latency column
  # is appended to the ASCII structured list.

  # Then
  assert_contains \
    "rbd-metrics skill declares latency column appended to ASCII structured list" \
    "$SKILL_FILE" \
    -E "latency column|column.*latency|append.*latency|latency.*append|latency.*ASCII|ASCII.*latency"
}

test_latency_skill_is_read_only() {
  echo "test_latency_skill_is_read_only"
  # @req: FUNC-METRICS-002

  # Given
  # FUNC-METRICS-002 states explicitly: "The computation is strictly read-only."
  # No file may be created, modified, or deleted when running in latency mode.

  # When
  # We inspect the skill definition for a declaration of its read-only nature
  # in the context of the latency computation.

  # Then
  assert_contains \
    "rbd-metrics skill declares latency computation is read-only" \
    "$SKILL_FILE" \
    -E "read-only|read only|never write|never modif|no file.*writ|strictly read"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== FUNC-METRICS-002: Opt-in req-to-green latency per requirement ==="
echo ""

test_latency_skill_file_exists
test_latency_skill_declares_latency_flag
test_latency_skill_traverses_req_commit_timestamps
test_latency_skill_traverses_test_commit_timestamps
test_latency_skill_computes_elapsed_time
test_latency_skill_shows_pending_for_no_test_commit
test_latency_skill_appends_latency_column_to_ascii_list
test_latency_skill_is_read_only

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
