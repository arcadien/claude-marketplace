#!/usr/bin/env bash
# Integration tests for FUNC-ANALYZE-002, FUNC-ANALYZE-003, FUNC-ANALYZE-004,
# and TECH-ANALYST-001.
#
# Production side must provide:
#   - agents/arch-analyst.md  (the arch-analyst agent definition)
#
# This file does not yet exist; tests will fail (TDD Red) until code-builder
# creates it with the required contracts.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
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

assert_not_contains() {
  local description="$1"
  local file="$2"
  local pattern="$3"

  if grep -q "$pattern" "$file" 2>/dev/null; then
    echo "  FAIL: $description"
    echo "        file    : $file"
    echo "        pattern : $pattern  (must NOT appear)"
    FAIL=$((FAIL + 1))
  else
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  fi
}

# ---------------------------------------------------------------------------
# FUNC-ANALYZE-002: global Mermaid diagram declaration
# The agent must declare it produces a global diagram using graph LR,
# classDiagram, or graph TD.
# ---------------------------------------------------------------------------

test_agent_declares_global_diagram_type() {
  echo "test_agent_declares_global_diagram_type"
  # @req: FUNC-ANALYZE-002

  # Given
  # The arch-analyst agent definition file is present at agents/arch-analyst.md.

  # When
  # We inspect its content for an explicit declaration that it produces a global
  # Mermaid diagram using one of the accepted diagram types: graph LR,
  # classDiagram, or graph TD.

  # Then
  assert_contains \
    "agent declares global diagram type (graph LR / classDiagram / graph TD)" \
    "$AGENT_FILE" \
    -E "graph LR|classDiagram|graph TD"
}

test_agent_declares_global_diagram_purpose() {
  echo "test_agent_declares_global_diagram_purpose"
  # @req: FUNC-ANALYZE-002

  # Given
  # The arch-analyst agent definition is present.

  # When
  # We inspect its content for a statement that the global diagram covers
  # software components and their relationships (architectural coherence).

  # Then
  assert_contains \
    "agent mentions component relationships in global diagram" \
    "$AGENT_FILE" \
    -E "component|relationship|global"
}

# ---------------------------------------------------------------------------
# FUNC-ANALYZE-003: per-component diagrams and 1+N output structure
# The agent must declare it produces both flowchart and stateDiagram types,
# and must mention the 1+N (one global + N per-component) structure.
# ---------------------------------------------------------------------------

test_agent_declares_flowchart_type() {
  echo "test_agent_declares_flowchart_type"
  # @req: FUNC-ANALYZE-003

  # Given
  # The arch-analyst agent definition is present.

  # When
  # We inspect its content for an explicit reference to the flowchart diagram
  # type used for process or algorithm components.

  # Then
  assert_contains \
    "agent declares flowchart diagram type for process components" \
    "$AGENT_FILE" \
    "flowchart"
}

test_agent_declares_state_diagram_type() {
  echo "test_agent_declares_state_diagram_type"
  # @req: FUNC-ANALYZE-003

  # Given
  # The arch-analyst agent definition is present.

  # When
  # We inspect its content for an explicit reference to the stateDiagram type
  # used for stateful components.

  # Then
  assert_contains \
    "agent declares stateDiagram type for stateful components" \
    "$AGENT_FILE" \
    "stateDiagram"
}

test_agent_declares_one_plus_n_structure() {
  echo "test_agent_declares_one_plus_n_structure"
  # @req: FUNC-ANALYZE-003

  # Given
  # FUNC-ANALYZE-003 requires the agent to document the 1+N output structure:
  # one global diagram plus one diagram per identified component.

  # When
  # We inspect the agent definition for an explicit mention of this structure
  # (patterns: "1+N", "one global", "per-component", or "per component").

  # Then
  assert_contains \
    "agent describes 1+N diagram output structure" \
    "$AGENT_FILE" \
    -E "1\+N|one global|per.component"
}

# ---------------------------------------------------------------------------
# FUNC-ANALYZE-004: code-vs-architecture coherence scan
# The agent must declare it reads source code and cross-references it against
# requirements and architecture to detect structural mismatches.
# ---------------------------------------------------------------------------

test_agent_declares_source_code_scan() {
  echo "test_agent_declares_source_code_scan"
  # @req: FUNC-ANALYZE-004

  # Given
  # The arch-analyst agent definition is present.

  # When
  # We inspect its content for a declaration that it scans source code files
  # in the target project.

  # Then
  assert_contains \
    "agent declares it scans source code files" \
    "$AGENT_FILE" \
    -E "source code|scan"
}

test_agent_declares_unmapped_element_detection() {
  echo "test_agent_declares_unmapped_element_detection"
  # @req: FUNC-ANALYZE-004

  # Given
  # FUNC-ANALYZE-004 requires the agent to report code elements that cannot be
  # mapped to any component in architecture.md or any validated requirement.

  # When
  # We inspect the agent definition for a reference to this unmapped-element
  # finding category (patterns: "unmapped", "cannot be mapped", "not found in").

  # Then
  assert_contains \
    "agent declares detection of unmapped code elements" \
    "$AGENT_FILE" \
    -E "unmapped|cannot be mapped|not found in"
}

test_agent_declares_missing_dependency_detection() {
  echo "test_agent_declares_missing_dependency_detection"
  # @req: FUNC-ANALYZE-004

  # Given
  # FUNC-ANALYZE-004 requires the agent to detect component dependencies
  # declared in architecture.md that are not reflected in actual code imports,
  # instantiations, or inheritance.

  # When
  # We inspect the agent definition for a reference to this missing-dependency
  # finding category.

  # Then
  assert_contains \
    "agent declares detection of declared-but-missing dependencies" \
    "$AGENT_FILE" \
    -E "import|instantiation|inheritance|dependency"
}

test_agent_omits_scan_section_when_no_source() {
  echo "test_agent_omits_scan_section_when_no_source"
  # @req: FUNC-ANALYZE-004

  # Given
  # FUNC-ANALYZE-004 states the coherence-scan section is omitted when no
  # source code files are found in the target project.

  # When
  # We inspect the agent definition for this conditional-omission rule.

  # Then
  assert_contains \
    "agent states scan section is omitted when no source code is present" \
    "$AGENT_FILE" \
    -E "omit|no source|if no"
}

# ---------------------------------------------------------------------------
# TECH-ANALYST-001: arch-analyst write access restrictions
# The agent must explicitly prohibit writes to requirements/*.md,
# docs/architecture.md, and source code files; only docs/analysis-YYYY-MM-DD.md
# is permitted.
# ---------------------------------------------------------------------------

test_agent_prohibits_writing_requirements() {
  echo "test_agent_prohibits_writing_requirements"
  # @req: TECH-ANALYST-001

  # Given
  # TECH-ANALYST-001 forbids the agent from writing to any requirements/*.md
  # file.

  # When
  # We inspect the agent definition for an explicit prohibition or "must not"
  # clause referencing requirements files.

  # Then
  assert_contains \
    "agent explicitly prohibits writes to requirements/*.md" \
    "$AGENT_FILE" \
    -E "requirements/\*\.md|requirements/.*\.md|must not.*requirement|MUST NOT.*requirement"
}

test_agent_prohibits_writing_architecture_doc() {
  echo "test_agent_prohibits_writing_architecture_doc"
  # @req: TECH-ANALYST-001

  # Given
  # TECH-ANALYST-001 forbids the agent from writing to docs/architecture.md.

  # When
  # We inspect the agent definition for an explicit prohibition referencing
  # architecture.md.

  # Then
  assert_contains \
    "agent explicitly prohibits writes to docs/architecture.md" \
    "$AGENT_FILE" \
    -E "architecture\.md"
}

test_agent_prohibits_writing_source_code() {
  echo "test_agent_prohibits_writing_source_code"
  # @req: TECH-ANALYST-001

  # Given
  # TECH-ANALYST-001 forbids the agent from writing to any source code file of
  # the target project.

  # When
  # We inspect the agent definition for an explicit prohibition referencing
  # source code files.

  # Then
  assert_contains \
    "agent explicitly prohibits writes to source code files" \
    "$AGENT_FILE" \
    -E "source code|MUST NOT.*source|must not.*source"
}

test_agent_declares_only_permitted_write() {
  echo "test_agent_declares_only_permitted_write"
  # @req: TECH-ANALYST-001

  # Given
  # TECH-ANALYST-001 states the only permitted write is to
  # docs/analysis-YYYY-MM-DD.md.

  # When
  # We inspect the agent definition for a declaration that the output document
  # docs/analysis- is the sole permitted write target.

  # Then
  assert_contains \
    "agent declares docs/analysis-YYYY-MM-DD.md as only permitted write" \
    "$AGENT_FILE" \
    "docs/analysis-"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== FUNC-ANALYZE-002: arch-analyst global Mermaid diagram ==="
echo ""
test_agent_declares_global_diagram_type
test_agent_declares_global_diagram_purpose
echo ""

echo "=== FUNC-ANALYZE-003: arch-analyst per-component diagrams and 1+N structure ==="
echo ""
test_agent_declares_flowchart_type
test_agent_declares_state_diagram_type
test_agent_declares_one_plus_n_structure
echo ""

echo "=== FUNC-ANALYZE-004: arch-analyst code-vs-architecture coherence scan ==="
echo ""
test_agent_declares_source_code_scan
test_agent_declares_unmapped_element_detection
test_agent_declares_missing_dependency_detection
test_agent_omits_scan_section_when_no_source
echo ""

echo "=== TECH-ANALYST-001: arch-analyst write access restrictions ==="
echo ""
test_agent_prohibits_writing_requirements
test_agent_prohibits_writing_architecture_doc
test_agent_prohibits_writing_source_code
test_agent_declares_only_permitted_write
echo ""

echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
