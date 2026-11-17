#!/usr/bin/env bash
# Contract tests for skill and agent instructions.
#
# Skills and agents are prompts: their behaviour is the text Claude follows. Each case
# checks that the instruction file of a requirement states that behaviour.
# Case format: ID|file relative to the plugin|extended regex (no '|' inside)

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

# check_cases: reads cases on stdin, one PASS/FAIL line per case
check_cases() {
  local id file pattern
  while IFS='|' read -r id file pattern; do
    [ -z "$id" ] && continue
    if grep -qE -- "$pattern" "$REPO_ROOT/$file" 2>/dev/null; then
      echo "  PASS: $id — $file states /$pattern/"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: $id — $file does not state /$pattern/"
      FAIL=$((FAIL + 1))
    fi
  done
}

test_audit_reports() {
  echo "test_audit_reports"
  # @req: FUNC-AUDIT-001
  # @req: FUNC-AUDIT-014
  # @req: FUNC-REVIEW-007
  # @req: FUNC-AUDIT-017
  # @req: FUNC-AUDIT-018
  # @req: FUNC-AUDIT-019
  # @req: FUNC-AUDIT-020
  # @req: FUNC-PUSH-005
  # Given the audit and review instruction files
  # When they are searched for each behaviour of the audit reports
  # Then every behaviour is stated
  check_cases <<'CASES'
FUNC-AUDIT-014|skills/rbd-audit/SKILL.md|git rev-parse HEAD
FUNC-AUDIT-014|skills/rbd-audit/SKILL.md|Audited commit: <full hash>
FUNC-AUDIT-014|skills/rbd-audit/SKILL.md|YYYY-MM-DD-audit-2\.md
FUNC-AUDIT-001|skills/rbd-audit/SKILL.md|-audit-10\.md. comes after .-audit-2\.md
FUNC-REVIEW-007|skills/rbd-review/SKILL.md|Reviewed commit: <full hash>
FUNC-AUDIT-017|skills/rbd-audit/SKILL.md|/rbd-audit since-last
FUNC-AUDIT-017|skills/rbd-audit/SKILL.md|git diff <hash>\.\.<audited>
FUNC-AUDIT-017|agents/audit-traceability.md|since-last
FUNC-AUDIT-017|agents/audit-coherence.md|since-last
FUNC-AUDIT-018|skills/rbd-audit/SKILL.md|git worktree add --detach
FUNC-AUDIT-018|skills/rbd-audit/SKILL.md|git worktree remove
FUNC-AUDIT-018|agents/audit-traceability.md|git log <hash>
FUNC-AUDIT-018|agents/audit-coherence.md|audited tree
FUNC-AUDIT-019|skills/rbd-audit/SKILL.md|share a check and a cause
FUNC-AUDIT-019|skills/rbd-audit/SKILL.md|## Info \(no action required\)
FUNC-AUDIT-019|skills/rbd-audit/SKILL.md|raw entries merged into
FUNC-AUDIT-019|skills/rbd-audit/references/checklist.md|"info"
FUNC-AUDIT-020|skills/rbd-audit/SKILL.md|/rbd-audit status <n>
FUNC-AUDIT-020|skills/rbd-audit/SKILL.md|--ref <EXCLUSION-ID>
FUNC-AUDIT-020|skills/rbd-audit/SKILL.md|table and the details agree
FUNC-PUSH-005|skills/rbd/SKILL.md|baseRefName
FUNC-PUSH-005|skills/rbd-review/SKILL.md|baseRefName
FUNC-PUSH-005|skills/rbd-review/SKILL.md|git merge-base --is-ancestor
CASES
}

test_audit_checks() {
  echo "test_audit_checks"
  # @req: FUNC-AUDIT-008
  # @req: FUNC-AUDIT-005
  # @req: FUNC-AUDIT-007
  # @req: FUNC-AUDIT-009
  # @req: FUNC-AUDIT-010
  # @req: FUNC-AUDIT-011
  # @req: FUNC-AUDIT-012
  # @req: FUNC-AUDIT-021
  # @req: CONF-RULES-001
  # @req: FUNC-PUSH-002
  # Given the traceability agent and the audit checklist
  # When they are searched for each rule of the traceability checks
  # Then every rule is stated
  check_cases <<'CASES'
FUNC-AUDIT-008|agents/audit-traceability.md|Verification:.* is not .test.
FUNC-AUDIT-008|agents/audit-traceability.md|bench \(pending\)
FUNC-AUDIT-008|skills/rbd-audit/references/checklist.md|Verification:.* is not .test.
FUNC-AUDIT-010|agents/audit-traceability.md|needs only the implementation commit
FUNC-AUDIT-010|agents/audit-traceability.md|tag-only
FUNC-AUDIT-010|skills/rbd-audit/references/checklist.md|tag-only
FUNC-AUDIT-009|agents/audit-traceability.md|tag citing a .draft. requirement
FUNC-AUDIT-005|agents/audit-coherence.md|depends on a .draft.
FUNC-AUDIT-011|agents/audit-traceability.md|accepted_prefixes
FUNC-AUDIT-011|skills/rbd/references/formats.md|accepted_prefixes:
FUNC-AUDIT-007|agents/audit-coherence.md|restates the requirement differently
FUNC-AUDIT-021|agents/audit-traceability.md|### T8
FUNC-AUDIT-021|agents/audit-traceability.md|rbd_links\.py --check
CONF-RULES-001|agents/audit-coherence.md|non_technical_without_code
CONF-RULES-001|skills/rbd/references/formats.md|non_technical_without_code
FUNC-LINKS-001|skills/rbd-links/SKILL.md|rbd_links\.py
FUNC-AUDIT-012|agents/audit-traceability.md|docs/architecture.md.* in .accepted_prefixes
FUNC-PUSH-002|agents/audit-traceability.md|FUNC-X-001\.\.015
FUNC-PUSH-002|skills/rbd-review/SKILL.md|Expand ID ranges
CASES
}

test_requirement_lifecycle() {
  echo "test_requirement_lifecycle"
  # @req: FUNC-ARCH-001
  # @req: FUNC-REQ-005
  # @req: FUNC-REQ-008
  # @req: FUNC-TEST-006
  # Given the workflow agents and the format reference
  # When they are searched for each rule of the requirement lifecycle
  # Then every rule is stated
  check_cases <<'CASES'
FUNC-ARCH-001|agents/requirement-analyst.md|re-read its row
FUNC-REQ-005|agents/requirement-analyst.md|User validation:
FUNC-REQ-005|agents/requirement-analyst.md|identical to the validated text
FUNC-REQ-005|skills/rbd/SKILL.md|User validation:
FUNC-REQ-008|skills/rbd/references/formats.md|\*\*Verification:\*\* test
FUNC-REQ-008|skills/rbd/references/formats.md|bench \(pending\)
FUNC-REQ-008|agents/requirement-analyst.md|\*\*Verification:\*\*
FUNC-TEST-006|agents/test-builder.md|NO NATIVE TEST: <reason>
FUNC-TEST-006|skills/rbd/SKILL.md|NO NATIVE TEST: <reason>
FUNC-TEST-006|agents/code-builder.md|No test: <reason>
CASES
}

test_audit_reports
test_audit_checks
test_requirement_lifecycle

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
