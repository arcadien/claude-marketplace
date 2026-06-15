#!/usr/bin/env bash
# Integration tests for FUNC-ANALYZE-001
# Requirement: rbd-arch-analyze skill triggers the arch-analyst agent
#
# Production side must provide:
#   - skills/rbd-arch-analyze/SKILL.md  (the rbd-arch-analyze skill definition)
#   - agents/arch-analyst.md            (the arch-analyst agent definition)
#
# These files do not yet exist; tests will fail (TDD Red) until code-builder
# creates them with the required contracts.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/rbd-arch-analyze/SKILL.md"
AGENT_FILE="$REPO_ROOT/agents/arch-analyst.md"

PASS=0
FAIL=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

assert_contains() {
  local description="$1"
  local file="$2"
  local pattern="$3"

  if grep -q "$pattern" "$file" 2>/dev/null; then
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
# test_skill_file_exists
# @req: FUNC-ANALYZE-001
# ---------------------------------------------------------------------------
test_skill_file_exists() {
  echo "test_skill_file_exists"
  # @req: FUNC-ANALYZE-001

  # Given
  # The rbd-arch-analyze skill must exist as a SKILL.md inside its own
  # directory, consistent with the layout used by rbd-audit and rbd-review.

  # When
  # We check that the SKILL.md file is present on the filesystem.

  # Then
  assert_file_exists \
    "skills/rbd-arch-analyze/SKILL.md exists" \
    "$SKILL_FILE"
}

# ---------------------------------------------------------------------------
# test_skill_dispatches_arch_analyst
# @req: FUNC-ANALYZE-001
# ---------------------------------------------------------------------------
test_skill_dispatches_arch_analyst() {
  echo "test_skill_dispatches_arch_analyst"
  # @req: FUNC-ANALYZE-001

  # Given
  # The rbd-arch-analyze skill definition file must be present.

  # When
  # We inspect its content for an explicit reference to the arch-analyst agent,
  # confirming that dispatch is declared in the skill contract.

  # Then
  assert_contains \
    "skill references arch-analyst agent" \
    "$SKILL_FILE" \
    "arch-analyst"
}

# ---------------------------------------------------------------------------
# test_skill_provides_requirements_context
# @req: FUNC-ANALYZE-001
# ---------------------------------------------------------------------------
test_skill_provides_requirements_context() {
  echo "test_skill_provides_requirements_context"
  # @req: FUNC-ANALYZE-001

  # Given
  # FUNC-ANALYZE-001 mandates that the skill provides the agent with all
  # requirements/*.md files as context.

  # When
  # We inspect the skill definition for a reference to the requirements files
  # (the skill must state that it passes them to the agent).

  # Then
  assert_contains \
    "skill mentions requirements context" \
    "$SKILL_FILE" \
    "requirements"
}

# ---------------------------------------------------------------------------
# test_skill_provides_architecture_context
# @req: FUNC-ANALYZE-001
# ---------------------------------------------------------------------------
test_skill_provides_architecture_context() {
  echo "test_skill_provides_architecture_context"
  # @req: FUNC-ANALYZE-001

  # Given
  # FUNC-ANALYZE-001 mandates that the skill provides docs/architecture.md of
  # the target project to the agent.

  # When
  # We inspect the skill definition for a reference to architecture.md.

  # Then
  assert_contains \
    "skill mentions architecture.md context" \
    "$SKILL_FILE" \
    "architecture.md"
}

# ---------------------------------------------------------------------------
# test_skill_confirms_output_path
# @req: FUNC-ANALYZE-001
# ---------------------------------------------------------------------------
test_skill_confirms_output_path() {
  echo "test_skill_confirms_output_path"
  # @req: FUNC-ANALYZE-001

  # Given
  # FUNC-ANALYZE-001 mandates that after the agent runs, the skill confirms
  # the output path (docs/analysis-YYYY-MM-DD.md) to the user.

  # When
  # We inspect the skill definition for a reference to the output path pattern
  # docs/analysis- (date-stamped report).

  # Then
  assert_contains \
    "skill confirms output path docs/analysis-" \
    "$SKILL_FILE" \
    "docs/analysis-"
}

# ---------------------------------------------------------------------------
# test_agent_file_exists
# @req: FUNC-ANALYZE-001
# ---------------------------------------------------------------------------
test_agent_file_exists() {
  echo "test_agent_file_exists"
  # @req: FUNC-ANALYZE-001

  # Given
  # The arch-analyst agent must be declared alongside the other agents
  # (audit-coherence.md, audit-traceability.md, etc.) in the agents/ directory.

  # When
  # We check that agents/arch-analyst.md is present on the filesystem.

  # Then
  assert_file_exists \
    "agents/arch-analyst.md exists" \
    "$AGENT_FILE"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== FUNC-ANALYZE-001: rbd-arch-analyze skill triggers the arch-analyst agent ==="
echo ""

test_skill_file_exists
test_skill_dispatches_arch_analyst
test_skill_provides_requirements_context
test_skill_provides_architecture_context
test_skill_confirms_output_path
test_agent_file_exists

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
