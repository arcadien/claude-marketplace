#!/usr/bin/env bash
# Integration tests for FUNC-IMPL-006 and FUNC-ORCH-005
#
# FUNC-IMPL-006: Architectural boundary check before writing any code
# FUNC-ORCH-005: Orchestrator handles ARCH MISMATCH signal from code-builder
#
# Production side must provide:
#   - agents/code-builder.md  — must declare arch read, file-plan check,
#                               ARCH MISMATCH signal, and stop-without-writing
#   - skills/rbd/SKILL.md     — must declare ARCH MISMATCH handling, two-option
#                               routing, and re-dispatch of requirement-analyst

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILDER_FILE="$REPO_ROOT/agents/code-builder.md"
ORCH_FILE="$REPO_ROOT/skills/rbd/SKILL.md"

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
# FUNC-IMPL-006 — code-builder reads architecture.md before writing
# ---------------------------------------------------------------------------

test_cb_file_exists() {
  echo "test_cb_file_exists"
  # @req: FUNC-IMPL-006

  # Given
  # The code-builder agent must be declared in the agents/ directory alongside
  # other agent definitions.

  # When
  # We check that agents/code-builder.md is present on the filesystem.

  # Then
  assert_file_exists \
    "agents/code-builder.md exists" \
    "$BUILDER_FILE"
}

test_cb_reads_architecture_before_writing() {
  echo "test_cb_reads_architecture_before_writing"
  # @req: FUNC-IMPL-006

  # Given
  # FUNC-IMPL-006 mandates that code-builder reads docs/architecture.md before
  # writing or modifying any file.

  # When
  # We inspect the agent definition for an explicit declaration that it reads
  # docs/architecture.md as a pre-write step.

  # Then
  assert_contains \
    "code-builder declares it reads docs/architecture.md before writing" \
    "$BUILDER_FILE" \
    "architecture.md"
}

test_cb_checks_planned_files_against_components() {
  echo "test_cb_checks_planned_files_against_components"
  # @req: FUNC-IMPL-006

  # Given
  # FUNC-IMPL-006 requires code-builder to verify that every planned file
  # belongs to a component declared in architecture.md.

  # When
  # We inspect the agent definition for a declaration of this mapping/check step
  # (patterns: "component", "declared", "map", "plan").

  # Then
  assert_contains \
    "code-builder declares file-to-component mapping check" \
    "$BUILDER_FILE" \
    -E "component|declared|plan"
}

test_cb_emits_arch_mismatch_signal() {
  echo "test_cb_emits_arch_mismatch_signal"
  # @req: FUNC-IMPL-006

  # Given
  # FUNC-IMPL-006 specifies the exact signal code-builder must emit when a
  # planned file cannot be mapped to any declared component.

  # When
  # We inspect the agent definition for the literal signal string "ARCH MISMATCH".

  # Then
  assert_contains \
    "code-builder declares ARCH MISMATCH signal" \
    "$BUILDER_FILE" \
    "ARCH MISMATCH"
}

test_cb_stops_on_mismatch_no_writes() {
  echo "test_cb_stops_on_mismatch_no_writes"
  # @req: FUNC-IMPL-006

  # Given
  # FUNC-IMPL-006 mandates that code-builder stops — no file is written — when
  # an architectural mismatch is detected.

  # When
  # We inspect the agent definition for a declaration that it halts without
  # writing when a mismatch is found (patterns: "stop", "no file", "halt",
  # "abort", "must not write", "without writing").

  # Then
  assert_contains \
    "code-builder declares it stops without writing on ARCH MISMATCH" \
    "$BUILDER_FILE" \
    -E "stop|no file|halt|abort|without writing|MUST NOT write|must not write"
}

# ---------------------------------------------------------------------------
# FUNC-ORCH-005 — orchestrator skill handles ARCH MISMATCH
# ---------------------------------------------------------------------------

test_orch_file_exists() {
  echo "test_orch_file_exists"
  # @req: FUNC-ORCH-005

  # Given
  # The orchestrator skill for the rbd workflow must exist at skills/rbd/SKILL.md.

  # When
  # We check that the file is present on the filesystem.

  # Then
  assert_file_exists \
    "skills/rbd/SKILL.md exists" \
    "$ORCH_FILE"
}

test_orch_handles_arch_mismatch_signal() {
  echo "test_orch_handles_arch_mismatch_signal"
  # @req: FUNC-ORCH-005

  # Given
  # FUNC-ORCH-005 requires the orchestrator to explicitly handle the ARCH MISMATCH
  # return signal from code-builder.

  # When
  # We inspect the skill definition for the literal string "ARCH MISMATCH".

  # Then
  assert_contains \
    "orchestrator declares handling of ARCH MISMATCH signal" \
    "$ORCH_FILE" \
    "ARCH MISMATCH"
}

test_orch_presents_two_options() {
  echo "test_orch_presents_two_options"
  # @req: FUNC-ORCH-005

  # Given
  # FUNC-ORCH-005 requires the orchestrator to present two options to the user
  # when an ARCH MISMATCH occurs: update the architecture, or revise the
  # requirement.

  # When
  # We inspect the skill definition for a declaration that two options or choices
  # are presented to the user (patterns: "option", "choice", "two").

  # Then
  assert_contains \
    "orchestrator declares two-option routing on ARCH MISMATCH" \
    "$ORCH_FILE" \
    -E "option|choice|two"
}

test_orch_option_updates_architecture() {
  echo "test_orch_option_updates_architecture"
  # @req: FUNC-ORCH-005

  # Given
  # FUNC-ORCH-005 option (a): the orchestrator re-dispatches requirement-analyst
  # to update docs/architecture.md after which code-builder may be resumed.

  # When
  # We inspect the skill definition for a declaration linking the ARCH MISMATCH
  # path to updating architecture.md.

  # Then
  assert_contains \
    "orchestrator declares option to update architecture.md" \
    "$ORCH_FILE" \
    "architecture"
}

test_orch_option_revises_requirement() {
  echo "test_orch_option_revises_requirement"
  # @req: FUNC-ORCH-005

  # Given
  # FUNC-ORCH-005 option (b): the orchestrator re-dispatches requirement-analyst
  # for a requirement update or split.

  # When
  # We inspect the skill definition for a declaration that the requirement can be
  # revised or split as an alternative to updating the architecture.

  # Then
  assert_contains \
    "orchestrator declares option to revise or split the requirement" \
    "$ORCH_FILE" \
    -E "revise|split|update.*requirement|requirement.*update"
}

test_orch_redispatches_requirement_analyst() {
  echo "test_orch_redispatches_requirement_analyst"
  # @req: FUNC-ORCH-005

  # Given
  # FUNC-ORCH-005 requires the orchestrator to re-dispatch requirement-analyst
  # for both resolution options.

  # When
  # We inspect the skill definition for an explicit reference to the
  # requirement-analyst agent in the context of ARCH MISMATCH handling.

  # Then
  assert_contains \
    "orchestrator declares re-dispatch of requirement-analyst on ARCH MISMATCH" \
    "$ORCH_FILE" \
    "requirement-analyst"
}

test_orch_code_builder_gated_until_arch_updated() {
  echo "test_orch_code_builder_gated_until_arch_updated"
  # @req: FUNC-ORCH-005

  # Given
  # FUNC-ORCH-005 states that code-builder is NOT resumed until option (a)
  # (architecture update) completes.

  # When
  # We inspect the skill definition for a declaration that code-builder is
  # blocked or gated pending the architecture update (patterns: "not resumed",
  # "gated", "blocked", "until", "after").

  # Then
  assert_contains \
    "orchestrator declares code-builder is gated until architecture is updated" \
    "$ORCH_FILE" \
    -E "not resumed|gated|blocked|until|after.*arch|arch.*complet"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== FUNC-IMPL-006: Architectural boundary check before writing any code ==="
echo ""
test_cb_file_exists
test_cb_reads_architecture_before_writing
test_cb_checks_planned_files_against_components
test_cb_emits_arch_mismatch_signal
test_cb_stops_on_mismatch_no_writes
echo ""

echo "=== FUNC-ORCH-005: Orchestrator handles ARCH MISMATCH signal from code-builder ==="
echo ""
test_orch_file_exists
test_orch_handles_arch_mismatch_signal
test_orch_presents_two_options
test_orch_option_updates_architecture
test_orch_option_revises_requirement
test_orch_redispatches_requirement_analyst
test_orch_code_builder_gated_until_arch_updated
echo ""

echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
