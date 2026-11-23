#!/usr/bin/env bash
# Contract tests for skill and agent instructions.
#
# Skills and agents are prompts: their behaviour is the text Claude follows. Each case
# checks that the instruction file of a requirement states that behaviour.
# Case format: ID|file relative to the plugin|extended regex (no '|' inside); a leading '!' means the file must not state it

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

# check_cases: reads cases on stdin, one PASS/FAIL line per case
check_cases() {
  local id file pattern expected found
  while IFS='|' read -r id file pattern; do
    [ -z "$id" ] && continue
    expected=states
    case "$pattern" in '!'*) expected="does not state"; pattern=${pattern#!} ;; esac
    found="does not state"
    grep -qE -- "$pattern" "$REPO_ROOT/$file" 2>/dev/null && found=states
    if [ "$found" = "$expected" ]; then
      echo "  PASS: $id — $file $found /$pattern/"
      PASS=$((PASS + 1))
    else
      echo "  FAIL: $id — $file $found /$pattern/"
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
FUNC-AUDIT-017|skills/rbd-audit/SKILL.md|By default, .?/rbd-audit.? audits what changed since the latest report
FUNC-AUDIT-017|skills/rbd-audit/SKILL.md|/rbd-audit --full
FUNC-AUDIT-017|skills/rbd-audit/SKILL.md|Mode: since <hash>
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
  # @req: FUNC-ORCH-006
  # @req: FUNC-REQ-009
  # @req: FUNC-REQ-008
  # @req: FUNC-TEST-006
  # @req: FUNC-REQ-007
  # @req: FUNC-AUDIT-004
  # Given the workflow agents and the format reference
  # When they are searched for each rule of the requirement lifecycle
  # Then every rule is stated
  check_cases <<'CASES'
FUNC-ARCH-001|agents/requirement-analyst.md|re-read its row
FUNC-REQ-005|agents/requirement-analyst.md|User validation:
FUNC-REQ-005|agents/requirement-analyst.md|identical to the validated text
FUNC-REQ-005|skills/rbd/SKILL.md|User validation:
FUNC-ORCH-006|skills/rbd/SKILL.md|Resume after an interrupted Phase 5
FUNC-ORCH-006|agents/code-builder.md|resume mode
FUNC-ORCH-006|agents/code-builder.md|Checks: lint
FUNC-REQ-009|agents/requirement-analyst.md|observable from outside the unit
FUNC-REQ-009|agents/requirement-analyst.md|survives a refactor
FUNC-REQ-009|agents/requirement-analyst.md|states its reason
FUNC-REQ-009|agents/requirement-analyst.md|verifiable on its own
FUNC-REQ-009|agents/requirement-analyst.md|the how .* goes to .docs/architecture\.md.
FUNC-REQ-009|agents/requirement-analyst.md|no test information
FUNC-REQ-009|agents/requirement-analyst.md|Examples:
FUNC-REQ-009|agents/requirement-analyst.md|no TECH requirement per helper
FUNC-REQ-009|skills/rbd/references/formats.md|\*\*Examples:\*\*
FUNC-REQ-008|skills/rbd/references/formats.md|\*\*Verification:\*\* build
FUNC-REQ-008|skills/rbd/references/formats.md|!bench \(pending\)
FUNC-REQ-008|agents/requirement-analyst.md|\*\*Verification:\*\* build
FUNC-REQ-008|agents/requirement-analyst.md|!bench \(pending\)
FUNC-REQ-008|agents/audit-traceability.md|Verification:.* is .build. or .inspection.
FUNC-REQ-008|agents/audit-traceability.md|!bench \(pending\)
FUNC-REQ-008|skills/rbd-audit/references/checklist.md|Verification:.* is .build. or .inspection.
FUNC-REQ-008|skills/rbd-audit/references/checklist.md|!bench \(pending\)
FUNC-TEST-006|agents/test-builder.md|NO NATIVE TEST: <reason>
FUNC-TEST-006|skills/rbd/SKILL.md|NO NATIVE TEST: <reason>
FUNC-TEST-006|agents/code-builder.md|No test: <reason>
FUNC-REQ-007|skills/rbd/references/formats.md|\*\*Superseded by:\*\*
FUNC-REQ-007|agents/requirement-analyst.md|\*\*Superseded by:\*\*
FUNC-AUDIT-004|agents/audit-coherence.md|Verified by
FUNC-AUDIT-004|agents/audit-coherence.md|Acceptance:
FUNC-AUDIT-004|agents/audit-coherence.md|only names the code behind another requirement
FUNC-AUDIT-004|skills/rbd-audit/references/checklist.md|Verified by
FUNC-AUDIT-004|agents/audit-coherence.md|other than .test., .build. or .inspection.
CASES
}

test_bench_sheets() {
  echo "test_bench_sheets"
  # @req: FUNC-TEST-007
  # @req: CONF-BENCH-001
  # @req: FUNC-AUDIT-008
  # @req: FUNC-AUDIT-009
  # @req: FUNC-AUDIT-010
  # @req: FUNC-AUDIT-013
  # @req: FUNC-METRICS-001
  # @req: FUNC-RELEASE-001
  # @req: FUNC-ORCH-003
  # Given the workflow, audit and metrics instruction files
  # When they are searched for each rule about bench sheets
  # Then every rule is stated
  check_cases <<'CASES'
FUNC-TEST-007|agents/test-builder.md|<!-- @req <ID> -->
FUNC-TEST-007|agents/test-builder.md|bring-up\.md
FUNC-TEST-007|agents/code-builder.md|does not run bench sheets
FUNC-TEST-007|skills/rbd/references/formats.md|## Bench sheet
FUNC-TEST-007|skills/rbd/references/formats.md|Date . Release \(tag / commit\) . measurements . Pass . By . Notes
FUNC-TEST-007|skills/rbd/references/formats.md|release checklist
CONF-BENCH-001|skills/rbd/references/formats.md|bench_sheets: "tests/bench/\{id\}\.md"
CONF-BENCH-001|agents/test-builder.md|bench_sheets
CONF-BENCH-001|agents/audit-traceability.md|bench_sheets
FUNC-AUDIT-008|agents/audit-traceability.md|tagged bench sheet covers
FUNC-AUDIT-008|agents/audit-traceability.md|latest release tag
FUNC-AUDIT-008|agents/audit-traceability.md|never a finding
FUNC-AUDIT-008|skills/rbd-audit/references/checklist.md|tagged bench sheet covers
FUNC-AUDIT-009|agents/audit-traceability.md|sheet tag citing a .deprecated.
FUNC-AUDIT-009|agents/audit-traceability.md|sheet tag citing a .draft. requirement → an .info. entry
FUNC-AUDIT-009|skills/rbd-audit/references/checklist.md|sheet tag citing a .draft. requirement → .info.
FUNC-AUDIT-009|skills/rbd-audit/references/checklist.md|!citing a .draft. or .deprecated. requirement → warning
FUNC-ORCH-003|skills/rbd/SKILL.md|REQUIREMENT DELETED: <ID>
FUNC-ORCH-003|skills/rbd/SKILL.md|REVIEW PASSED
FUNC-ORCH-003|skills/rbd/SKILL.md|REVIEW FAILED
CONF-BENCH-001|agents/audit-traceability.md|.\{id\}. read as .\*.
FUNC-AUDIT-010|agents/audit-traceability.md|only tagged test files are bench sheets needs no implementation commit
FUNC-RELEASE-001|skills/rbd/SKILL.md|at least 7 characters
FUNC-AUDIT-010|agents/audit-traceability.md|adds or changes a bench sheet
FUNC-AUDIT-010|skills/rbd-audit/references/checklist.md|adds or changes a bench sheet
FUNC-AUDIT-010|agents/audit-traceability.md|needs only the implementation commit
FUNC-AUDIT-010|agents/audit-traceability.md|feat/tech/perf/ui/conf/plat
FUNC-AUDIT-010|agents/audit-traceability.md|Superseded by:.* names
FUNC-AUDIT-010|skills/rbd-audit/references/checklist.md|Superseded by:.* names
FUNC-AUDIT-013|agents/audit-traceability.md|bench sheet without a .<!-- @req
FUNC-METRICS-001|skills/rbd-metrics/SKILL.md|\(N bench\)
FUNC-METRICS-001|skills/rbd-metrics/SKILL.md|"bench":
FUNC-RELEASE-001|skills/rbd/SKILL.md|/rbd release <tag>
FUNC-RELEASE-001|skills/rbd/SKILL.md|order of .bring-up\.md.
FUNC-RELEASE-001|skills/rbd/SKILL.md|creates no tag
FUNC-RELEASE-001|skills/rbd/SKILL.md|git tag <tag>
CASES
}

test_workflow_contracts() {
  echo "test_workflow_contracts"
  # @req: CONF-IDLVL-001
  # @req: CONF-TAG-001
  # @req: CONF-LINT-001
  # @req: FUNC-INIT-001
  # @req: FUNC-INIT-002
  # @req: FUNC-INIT-003
  # @req: FUNC-INIT-004
  # @req: FUNC-ORCH-001
  # @req: FUNC-ORCH-002
  # @req: FUNC-ORCH-004
  # @req: TECH-AGENT-001
  # @req: FUNC-REQ-001
  # @req: FUNC-REQ-002
  # @req: FUNC-REQ-003
  # @req: FUNC-REQ-004
  # @req: FUNC-REQ-006
  # @req: FUNC-ARCH-002
  # @req: FUNC-ARCH-003
  # @req: FUNC-ARCH-004
  # @req: FUNC-TEST-001
  # @req: FUNC-TEST-002
  # @req: FUNC-TEST-003
  # @req: FUNC-TEST-004
  # @req: FUNC-TEST-005
  # @req: TECH-SEP-001
  # @req: TECH-SEP-002
  # @req: FUNC-IMPL-001
  # @req: FUNC-IMPL-002
  # @req: FUNC-IMPL-003
  # @req: FUNC-IMPL-004
  # @req: FUNC-IMPL-005
  # Given the orchestrator, the workflow agents and the format reference
  # When they are searched for each rule of init, elicitation, tests and implementation
  # Then every rule is stated
  check_cases <<'CASES'
CONF-IDLVL-001|skills/rbd/SKILL.md|intermediate classification levels
CONF-IDLVL-001|skills/rbd/references/formats.md|levels: \[
CONF-TAG-001|skills/rbd/references/formats.md|convention: .*\{id\}
CONF-TAG-001|agents/test-builder.md|test tagging convention
CONF-LINT-001|skills/rbd/references/formats.md|^linter:
CONF-LINT-001|agents/test-builder.md|Run the linter command
CONF-LINT-001|agents/code-builder.md|linter command
FUNC-INIT-001|skills/rbd/SKILL.md|FUNC, TECH, PERF, UI, CONF, PLAT
FUNC-INIT-002|skills/rbd/SKILL.md|language and test framework
FUNC-INIT-002|skills/rbd/SKILL.md|Offer to defer
FUNC-INIT-003|skills/rbd/SKILL.md|What is the linter command
FUNC-INIT-004|skills/rbd/SKILL.md|plan: init rbd project
FUNC-INIT-004|skills/rbd/references/formats.md|platform\.md
FUNC-ORCH-001|skills/rbd/SKILL.md|after .test\(ID\):. with no implementation commit
FUNC-ORCH-002|skills/rbd/SKILL.md|ask the user what they want to work on
FUNC-ORCH-004|skills/rbd/SKILL.md|Dispatch the .test-builder. agent
TECH-AGENT-001|skills/rbd/SKILL.md|does not perform requirement analysis, test writing, or code implementation directly
FUNC-REQ-001|agents/requirement-analyst.md|FUNC/TECH/PERF/UI/CONF/PLAT
FUNC-REQ-002|agents/requirement-analyst.md|> 100 words
FUNC-REQ-002|agents/requirement-analyst.md|SPLIT REQUIRED
FUNC-REQ-003|agents/requirement-analyst.md|Semantic overlap check
FUNC-REQ-004|agents/requirement-analyst.md|Consistency and precision check
FUNC-REQ-006|skills/rbd/SKILL.md|Re-dispatch requirement-analyst for each sub-requirement
FUNC-ARCH-002|agents/requirement-analyst.md|propose a TECH requirement anchoring the DI constraint
FUNC-ARCH-003|agents/requirement-analyst.md|Commit: .arch\(<ID>\):
FUNC-ARCH-004|agents/requirement-analyst.md|Step 5 — Gate
FUNC-TEST-001|agents/test-builder.md|Rule T-GWT
FUNC-TEST-002|agents/test-builder.md|Rule T-TAG
FUNC-TEST-002|agents/test-builder.md|If ANY function is missing its tag: do not commit
FUNC-TEST-003|agents/test-builder.md|Rule T-PARAM
FUNC-TEST-004|agents/test-builder.md|> 400 lines
FUNC-TEST-004|agents/test-builder.md|!300–400
FUNC-TEST-005|agents/test-builder.md|Step 6 — Lint
TECH-SEP-001|agents/test-builder.md|MUST NOT create, modify, or delete any file outside of test directories
TECH-SEP-001|agents/test-builder.md|.test_\*.
TECH-SEP-002|agents/code-builder.md|test files as defined for test-builder
FUNC-IMPL-001|agents/code-builder.md|a different component, design pattern or public interface
FUNC-IMPL-002|agents/code-builder.md|production code
FUNC-IMPL-003|agents/code-builder.md|full test suite
FUNC-IMPL-004|agents/code-builder.md|Run the linter
FUNC-IMPL-005|agents/code-builder.md|> 600 lines added
FUNC-IMPL-005|agents/code-builder.md|!500–600
CASES
}

test_audit_review_contracts() {
  echo "test_audit_review_contracts"
  # @req: FUNC-AUDIT-002
  # @req: PERF-AUDIT-001
  # @req: FUNC-AUDIT-003
  # @req: FUNC-AUDIT-006
  # @req: FUNC-AUDIT-007
  # @req: FUNC-AUDIT-015
  # @req: FUNC-AUDIT-016
  # @req: TECH-AUDIT-001
  # @req: FUNC-REVIEW-001
  # @req: FUNC-REVIEW-003
  # @req: FUNC-REVIEW-004
  # @req: FUNC-REVIEW-005
  # @req: FUNC-REVIEW-006
  # @req: FUNC-PUSH-003
  # @req: TECH-FMT-001
  # @req: UI-DOC-001
  # @req: UI-DOC-003
  # Given the audit and review instruction files and the hook
  # When they are searched for each rule of the audit and the review
  # Then every rule is stated
  check_cases <<'CASES'
FUNC-AUDIT-002|skills/rbd-audit/SKILL.md|Collect their JSON finding arrays
PERF-AUDIT-001|skills/rbd-audit/SKILL.md|Launch both agents simultaneously
FUNC-AUDIT-003|agents/audit-coherence.md|### C1 — Semantic Overlap
FUNC-AUDIT-006|agents/audit-coherence.md|### C4 — Circular Dependencies
FUNC-AUDIT-007|agents/audit-coherence.md|A missing row is reported by T5
FUNC-AUDIT-015|skills/rbd-audit/SKILL.md|Process Findings With the User
FUNC-AUDIT-016|agents/audit-traceability.md|.derives_from:. line in its requirement block
FUNC-AUDIT-016|agents/audit-traceability.md|!frontmatter
TECH-AUDIT-001|agents/audit-traceability.md|You never modify any file
TECH-AUDIT-001|agents/audit-coherence.md|You never modify any file
FUNC-REVIEW-001|skills/rbd-review/SKILL.md|MR number or URL
FUNC-REVIEW-003|skills/rbd-review/SKILL.md|.validated. or .deprecated.
FUNC-REVIEW-003|skills/rbd-review/SKILL.md|draft_ok_prefixes
FUNC-REVIEW-004|skills/rbd-review/SKILL.md|### Check R2: Uncovered Behaviors
FUNC-REVIEW-005|skills/rbd-review/SKILL.md|extra_commit_prefixes
FUNC-REVIEW-005|skills/rbd-review/SKILL.md|at least one ID it cites
FUNC-REVIEW-006|skills/rbd-review/SKILL.md|.build. or .inspection.
FUNC-REVIEW-005|skills/rbd-review/SKILL.md|PLAT-\*. → must use .plat\(ID\)
FUNC-REVIEW-006|skills/rbd-review/SKILL.md|feat/tech/perf/ui/conf/plat
TECH-FMT-001|agents/code-builder.md|plat\(<ID>\)
TECH-FMT-001|skills/rbd/references/formats.md|plat\(PLAT-
UI-DOC-003|skills/rbd/references/formats.md|blank line between fields
UI-DOC-003|agents/requirement-analyst.md|blank line between fields
UI-DOC-003|agents/audit-traceability.md|anywhere between the requirement.s .###. heading
FUNC-PUSH-003|skills/rbd/SKILL.md|first Phase 6 after the MR is opened
FUNC-PUSH-003|skills/rbd/SKILL.md|!triggered at merge time
TECH-FMT-001|hooks/rbd-pre-push-check.sh|plan.chore.fix.docs.style.refactor
UI-DOC-001|agents/requirement-analyst.md|every requirement ID cited
CASES
}

test_audit_reports
test_audit_checks
test_bench_sheets
test_workflow_contracts
test_audit_review_contracts
test_requirement_lifecycle

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
