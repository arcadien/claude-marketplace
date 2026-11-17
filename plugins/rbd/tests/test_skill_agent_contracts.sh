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
  # @req: FUNC-AUDIT-014
  # @req: FUNC-REVIEW-007
  # @req: FUNC-AUDIT-017
  # Given the audit and review instruction files
  # When they are searched for each behaviour of the audit reports
  # Then every behaviour is stated
  check_cases <<'CASES'
FUNC-AUDIT-014|skills/rbd-audit/SKILL.md|git rev-parse HEAD
FUNC-AUDIT-014|skills/rbd-audit/SKILL.md|Audited commit: <full hash>
FUNC-REVIEW-007|skills/rbd-review/SKILL.md|Reviewed commit: <full hash>
FUNC-AUDIT-017|skills/rbd-audit/SKILL.md|/rbd-audit since-last
FUNC-AUDIT-017|skills/rbd-audit/SKILL.md|git diff <hash>\.\.<audited>
FUNC-AUDIT-017|agents/audit-traceability.md|since-last
FUNC-AUDIT-017|agents/audit-coherence.md|since-last
CASES
}

test_audit_reports

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
