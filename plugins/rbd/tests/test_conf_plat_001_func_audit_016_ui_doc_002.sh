#!/usr/bin/env bash
# Integration tests for CONF-PLAT-001, FUNC-AUDIT-016, and UI-DOC-002
#
# CONF-PLAT-001: PLAT as a recognized requirement category in config
# FUNC-AUDIT-016: T7 check — derives_from traceability for PLAT requirements
# UI-DOC-002: Markdown hyperlinks for derives_from references in PLAT requirements
#
# Production side must provide:
#   - .rbd/config.yml                  — must list PLAT in categories (alongside
#                                        FUNC, TECH, PERF, UI, CONF)
#   - skills/rbd/SKILL.md              — Phase 1 init must present PLAT as an
#                                        available category during ID negotiation
#   - requirements/platform.md         — must exist as the PLAT requirements file
#   - agents/audit-traceability.md     — must declare the T7 check for PLAT
#                                        derives_from traceability
#   - agents/requirement-analyst.md    — must declare that PLAT requirement blocks
#                                        carry a derives_from: Markdown hyperlink

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/.rbd/config.yml"
SKILL_FILE="$REPO_ROOT/skills/rbd/SKILL.md"
PLATFORM_REQ_FILE="$REPO_ROOT/requirements/platform.md"
AUDIT_AGENT_FILE="$REPO_ROOT/agents/audit-traceability.md"
ANALYST_AGENT_FILE="$REPO_ROOT/agents/requirement-analyst.md"

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
# CONF-PLAT-001 — PLAT as a recognized requirement category in config
# ---------------------------------------------------------------------------

test_config_includes_plat_category() {
  echo "test_config_includes_plat_category"
  # @req: CONF-PLAT-001

  # Given
  # CONF-PLAT-001 requires .rbd/config.yml to list PLAT in its categories array
  # alongside the five pre-existing categories.

  # When
  # We inspect config.yml for the literal string PLAT inside the categories list.

  # Then
  assert_contains \
    ".rbd/config.yml categories list includes PLAT" \
    "$CONFIG_FILE" \
    "PLAT"
}

test_config_retains_all_standard_categories() {
  echo "test_config_retains_all_standard_categories"
  # @req: CONF-PLAT-001

  # Given
  # CONF-PLAT-001 states PLAT is added alongside the existing six categories.
  # All six (FUNC, TECH, PERF, UI, CONF, PLAT) must coexist.

  # When
  # We verify each category keyword is present in the config file.

  # Then
  for cat in FUNC TECH PERF UI CONF PLAT; do
    assert_contains \
      ".rbd/config.yml contains category $cat" \
      "$CONFIG_FILE" \
      "$cat"
  done
}

test_init_skill_presents_plat_in_phase1() {
  echo "test_init_skill_presents_plat_in_phase1"
  # @req: CONF-PLAT-001

  # Given
  # CONF-PLAT-001 requires the init-agent (inline in skills/rbd/SKILL.md Phase 1)
  # to present PLAT as an available category during the ID format negotiation step.

  # When
  # We inspect skills/rbd/SKILL.md for a declaration that PLAT is shown to the
  # user alongside the other categories during Phase 1.

  # Then
  assert_contains \
    "rbd skill Phase 1 references PLAT as an available category" \
    "$SKILL_FILE" \
    "PLAT"
}

test_platform_requirements_file_exists() {
  echo "test_platform_requirements_file_exists"
  # @req: CONF-PLAT-001

  # Given
  # Adding PLAT as a recognized category requires a corresponding requirements
  # file requirements/platform.md, consistent with the convention used by all
  # other categories (functional.md, technical.md, etc.).

  # When
  # We check that requirements/platform.md is present on the filesystem.

  # Then
  assert_file_exists \
    "requirements/platform.md exists" \
    "$PLATFORM_REQ_FILE"
}

# ---------------------------------------------------------------------------
# FUNC-AUDIT-016 — T7 check: derives_from traceability for PLAT requirements
# ---------------------------------------------------------------------------

test_audit_agent_declares_t7_check() {
  echo "test_audit_agent_declares_t7_check"
  # @req: FUNC-AUDIT-016

  # Given
  # FUNC-AUDIT-016 requires audit-traceability to implement a T7 check for
  # PLAT requirement derivation traceability.

  # When
  # We inspect the agent definition for an explicit declaration of the T7 check
  # (patterns: "T7", "derives_from", "PLAT").

  # Then
  assert_contains \
    "audit-traceability agent declares T7 check" \
    "$AUDIT_AGENT_FILE" \
    -E "T7|derives_from"
}

test_audit_agent_reads_plat_requirements() {
  echo "test_audit_agent_reads_plat_requirements"
  # @req: FUNC-AUDIT-016

  # Given
  # FUNC-AUDIT-016 requires the agent to scan PLAT-* requirements. The agent
  # must therefore read requirements/platform.md (or all requirements/*.md).

  # When
  # We inspect the agent definition for a reference to platform.md or to a
  # wildcard pattern that includes it.

  # Then
  assert_contains \
    "audit-traceability agent reads platform requirements" \
    "$AUDIT_AGENT_FILE" \
    -E "platform\.md|requirements/\*\.md|requirements/.*\.md"
}

test_audit_agent_checks_derives_from_field() {
  echo "test_audit_agent_checks_derives_from_field"
  # @req: FUNC-AUDIT-016

  # Given
  # FUNC-AUDIT-016 requires the agent to verify the presence of the derives_from:
  # frontmatter field on every validated PLAT requirement.

  # When
  # We inspect the agent definition for an explicit reference to the derives_from:
  # field as part of the T7 check logic.

  # Then
  assert_contains \
    "audit-traceability agent checks derives_from field" \
    "$AUDIT_AGENT_FILE" \
    "derives_from"
}

test_audit_agent_flags_missing_derives_from() {
  echo "test_audit_agent_flags_missing_derives_from"
  # @req: FUNC-AUDIT-016

  # Given
  # FUNC-AUDIT-016 requires a T7 finding when a PLAT requirement is missing
  # the derives_from: field entirely.

  # When
  # We inspect the agent definition for a declaration that absence of the field
  # produces a finding (patterns: "missing", "absent", "no derives_from",
  # "T7", together with "finding" or "violation").

  # Then
  assert_contains \
    "audit-traceability agent flags missing derives_from as a T7 finding" \
    "$AUDIT_AGENT_FILE" \
    -E "T7|traceability violation|derives_from.*missing|missing.*derives_from"
}

test_audit_agent_flags_invalid_derives_from_target() {
  echo "test_audit_agent_flags_invalid_derives_from_target"
  # @req: FUNC-AUDIT-016

  # Given
  # FUNC-AUDIT-016 requires a T7 finding when derives_from: references an ID
  # that does not exist or has status deprecated.

  # When
  # We inspect the agent definition for a declaration that an invalid or
  # deprecated target in derives_from: also generates a finding (patterns:
  # "non-existent", "deprecated", "does not exist", "not found").

  # Then
  assert_contains \
    "audit-traceability agent flags non-existent or deprecated derives_from target" \
    "$AUDIT_AGENT_FILE" \
    -E "non-existent|deprecated|does not exist|not found|invalid"
}

test_audit_agent_requires_func_or_tech_parent() {
  echo "test_audit_agent_requires_func_or_tech_parent"
  # @req: FUNC-AUDIT-016

  # Given
  # FUNC-AUDIT-016 mandates that the derives_from: target must be a FUNC or
  # TECH requirement. A PLAT deriving from another PLAT (or PERF, UI, CONF)
  # is a traceability violation.

  # When
  # We inspect the agent definition for a declaration that only FUNC or TECH
  # IDs are accepted as derives_from: targets.

  # Then
  assert_contains \
    "audit-traceability agent restricts derives_from targets to FUNC or TECH" \
    "$AUDIT_AGENT_FILE" \
    -E "FUNC|TECH"
}

# ---------------------------------------------------------------------------
# UI-DOC-002 — Markdown hyperlinks for derives_from references in PLAT requirements
# ---------------------------------------------------------------------------

test_analyst_declares_derives_from_field_for_plat() {
  echo "test_analyst_declares_derives_from_field_for_plat"
  # @req: UI-DOC-002

  # Given
  # UI-DOC-002 requires requirement-analyst to produce a derives_from: field
  # in every PLAT requirement block it writes.

  # When
  # We inspect the agent definition for a declaration that PLAT requirement
  # blocks carry the derives_from: field.

  # Then
  assert_contains \
    "requirement-analyst declares derives_from field for PLAT requirement blocks" \
    "$ANALYST_AGENT_FILE" \
    "derives_from"
}

test_analyst_declares_derives_from_as_markdown_link() {
  echo "test_analyst_declares_derives_from_as_markdown_link"
  # @req: UI-DOC-002

  # Given
  # UI-DOC-002 requires the derives_from: value to be a Markdown hyperlink,
  # not a bare ID string. This extends the UI-DOC-001 convention to the
  # PLAT-specific derivation field.

  # When
  # We inspect the agent definition for a declaration that derives_from: uses
  # Markdown hyperlink syntax (patterns: "hyperlink", "Markdown link",
  # "[ID](" bracket-link syntax).

  # Then
  assert_contains \
    "requirement-analyst declares derives_from value must be a Markdown hyperlink" \
    "$ANALYST_AGENT_FILE" \
    -E "hyperlink|Markdown link|\[.*\]\(.*\.md"
}

test_analyst_derives_from_link_uses_anchor_format() {
  echo "test_analyst_derives_from_link_uses_anchor_format"
  # @req: UI-DOC-002

  # Given
  # UI-DOC-002 specifies the hyperlink format: [FUNC-DATA-001](functional.md#func-data-001).
  # The anchor must be the lowercase-hyphenated form of the ID, consistent with
  # the convention established by UI-DOC-001 for Dependencies links.

  # When
  # We inspect the agent definition for a reference to the anchor format
  # (patterns: "#func-", "#tech-", lowercase anchor, or an explicit example
  # following the [ID](file.md#anchor) pattern).

  # Then
  assert_contains \
    "requirement-analyst declares anchor format for derives_from hyperlink" \
    "$ANALYST_AGENT_FILE" \
    -E "#func-|#tech-|functional\.md#|technical\.md#|\[.*\]\(.*\.md#"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== CONF-PLAT-001: PLAT as a recognized requirement category in config ==="
echo ""
test_config_includes_plat_category
test_config_retains_all_standard_categories
test_init_skill_presents_plat_in_phase1
test_platform_requirements_file_exists
echo ""

echo "=== FUNC-AUDIT-016: T7 check — derives_from traceability for PLAT requirements ==="
echo ""
test_audit_agent_declares_t7_check
test_audit_agent_reads_plat_requirements
test_audit_agent_checks_derives_from_field
test_audit_agent_flags_missing_derives_from
test_audit_agent_flags_invalid_derives_from_target
test_audit_agent_requires_func_or_tech_parent
echo ""

echo "=== UI-DOC-002: Markdown hyperlinks for derives_from in PLAT requirements ==="
echo ""
test_analyst_declares_derives_from_field_for_plat
test_analyst_declares_derives_from_as_markdown_link
test_analyst_derives_from_link_uses_anchor_format
echo ""

echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
