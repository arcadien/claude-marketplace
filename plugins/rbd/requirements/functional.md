# Functional Requirements

---

## Orchestrator (ORCH)

### FUNC-ORCH-001
**Title:** Phase detection at invocation
**Status:** validated
**Dependencies:** CONF-IDLVL-001
**Description:** At every `/rbd` skill invocation, the system checks whether `.rbd/config.yml` exists. If absent, it starts Phase 1 (Init). If present, it determines the current phase from the last commit, pending files, and the user's stated intent.

### FUNC-ORCH-002
**Title:** Ambiguous phase resolution
**Status:** validated
**Dependencies:** FUNC-ORCH-001
**Description:** If the current phase cannot be determined automatically, the system asks the user what they want to work on before proceeding.

### FUNC-ORCH-003
**Title:** Inter-phase routing via agent return signals
**Status:** validated
**Dependencies:** FUNC-ORCH-001
**Description:** The orchestrator routes progression between phases solely through agent return signals (`REQUIREMENT VALIDATED`, `TESTS COMMITTED`, `IMPLEMENTATION COMMITTED`, `TOO_LARGE`, `SCOPE TOO WIDE`, `SPLIT REQUIRED`). The orchestrator contains no business logic.

### FUNC-ORCH-004
**Title:** Exclusive delegation to specialized agents
**Status:** validated
**Dependencies:** FUNC-ORCH-003
**Description:** Each phase is fully delegated to a dedicated agent. The orchestrator provides context (requirement ID, config files, test files) and routes the return signal. It makes no domain decisions.

---

## Initialization (INIT)

### FUNC-INIT-001
**Title:** Interactive ID format negotiation
**Status:** validated
**Dependencies:** CONF-IDLVL-001
**Description:** During Phase 1, the system asks the user which intermediate levels they want in requirement IDs (e.g. `domain`, `feature`). It displays a resulting example ID for each category (FUNC, TECH, PERF, UI, CONF) and confirms the format with the user.

### FUNC-INIT-002
**Title:** Test framework and language elicitation
**Status:** validated
**Dependencies:** CONF-TAG-001
**Description:** During Phase 1, the system asks for the project's language and test framework (needed for the tagging convention). It offers to defer if the stack is not yet decided.

### FUNC-INIT-003
**Title:** Linter command elicitation
**Status:** validated
**Dependencies:** CONF-LINT-001
**Description:** During Phase 1, the system asks for the linting command to use (e.g. `ruff check .`, `eslint .`).

### FUNC-INIT-004
**Title:** Creation of all project files and initial commit
**Status:** validated
**Dependencies:** FUNC-INIT-001, FUNC-INIT-002, FUNC-INIT-003
**Description:** At the end of Phase 1, the system generates and writes: `.rbd/config.yml`, `.rbd/plan-files.yml`, `requirements/functional.md`, `requirements/technical.md`, `requirements/performance.md`, `requirements/ui.md`, `requirements/configuration.md`, `audits/exclusions.yml`. All files are committed with the message `plan: init rbd project`.

---

## Requirement Management (REQ)

### FUNC-REQ-001
**Title:** Requirement elicitation via dialogue
**Status:** validated
**Dependencies:** FUNC-INIT-004
**Description:** The `requirement-analyst` agent engages in dialogue with the user to elicit a new requirement: title, category (FUNC/TECH/PERF/UI/CONF), target component, and full description. It also handles update and deletion of existing requirements.

### FUNC-REQ-002
**Title:** Requirement size challenge
**Status:** validated
**Dependencies:** FUNC-REQ-001
**Description:** Before validation, the agent challenges any requirement whose scope exceeds what can be tested in a single coherent test suite (e.g. "CRUD for the entire module"). If too large, it emits a `SPLIT REQUIRED` signal with a reason and cleans up the draft.

### FUNC-REQ-003
**Title:** Semantic overlap challenge
**Status:** validated
**Dependencies:** FUNC-REQ-001
**Description:** The agent verifies that the new requirement does not semantically overlap with any existing validated requirement. If overlap is detected, it informs the user and asks for confirmation or reformulation.

### FUNC-REQ-004
**Title:** Consistency challenge
**Status:** validated
**Dependencies:** FUNC-REQ-001
**Description:** The agent verifies the new requirement is consistent with the existing requirement set (no contradictions, valid dependencies). It flags any inconsistency to the user before validation.

### FUNC-REQ-005
**Title:** User validation before commit
**Status:** validated
**Dependencies:** FUNC-REQ-002, FUNC-REQ-003, FUNC-REQ-004
**Description:** A requirement is committed only on explicit user confirmation after the challenge. The commit follows the format `req(ID): <title>`.

### FUNC-REQ-006
**Title:** Requirement splitting when too large
**Status:** validated
**Dependencies:** FUNC-REQ-002
**Description:** On a `SPLIT REQUIRED` signal, the orchestrator re-dispatches `requirement-analyst` for each identified sub-requirement, providing the split reason as context.

### FUNC-REQ-007
**Title:** Requirement deletion
**Status:** validated
**Dependencies:** FUNC-REQ-001
**Description:** The `requirement-analyst` agent handles deletion of an existing requirement. It emits the signal `REQUIREMENT DELETED: <ID>`. The workflow cycle ends and the user is informed.

---

## Architecture (ARCH)

### FUNC-ARCH-001
**Title:** Component assignment for each requirement
**Status:** validated
**Dependencies:** FUNC-REQ-005
**Description:** For every validated requirement, the `requirement-analyst` agent identifies the responsible architectural component(s) and updates the traceability table in `docs/architecture.md`.

### FUNC-ARCH-002
**Title:** DI constraint identification -> TECH requirement creation
**Status:** validated
**Dependencies:** FUNC-ARCH-001
**Description:** If a requirement introduces a new injectable dependency, the agent automatically creates a corresponding TECH requirement capturing the DI constraint, and updates the DI map in `docs/architecture.md`.

### FUNC-ARCH-003
**Title:** docs/architecture.md update with arch(ID) commit
**Status:** validated
**Dependencies:** FUNC-ARCH-001
**Description:** Every modification to `docs/architecture.md` produces a distinct commit in the format `arch(ID): <description>` where `ID` is the triggering requirement.

### FUNC-ARCH-004
**Title:** Architecture coherence gate before tests
**Status:** validated
**Dependencies:** FUNC-ARCH-001, FUNC-ARCH-003
**Description:** The `requirement-analyst` agent must complete Phase 3 (architecture coherence) before the test-builder can be dispatched. No tests are written until the architecture document is up to date.

---

## Test Generation (TEST)

### FUNC-TEST-001
**Title:** Integration test generation with GWT structure
**Status:** validated
**Dependencies:** FUNC-ARCH-004
**Description:** The `test-builder` agent generates integration tests (not unit tests) following the Given/When/Then structure. Each test contains exactly one action (When). If two actions are needed, they become two separate tests.

### FUNC-TEST-002
**Title:** Mandatory requirement ID tag on every test function
**Status:** validated
**Dependencies:** FUNC-TEST-001, TECH-TAG-001
**Description:** Every test function carries a requirement ID tag using the convention defined in `.rbd/config.yml`. Missing tag is a hard gate: the commit is rejected.

### FUNC-TEST-003
**Title:** Parametrized tests for multiple cases
**Status:** validated
**Dependencies:** FUNC-TEST-001
**Description:** When a requirement covers multiple input/output cases, `test-builder` generates a parametrized test (case table) rather than duplicated functions. The tag is placed on the parametrized function, not on individual cases.

### FUNC-TEST-004
**Title:** TOO_LARGE signal when requirement is too large to test
**Status:** validated
**Dependencies:** FUNC-TEST-001
**Description:** If `test-builder` cannot design a coherent test suite for a requirement, it emits the signal `TOO_LARGE: <reason>`. The orchestrator then re-dispatches `requirement-analyst` for splitting, providing the reason as context.

### FUNC-TEST-005
**Title:** Test file linting before commit
**Status:** validated
**Dependencies:** FUNC-TEST-001, CONF-LINT-001
**Description:** Before committing tests, `test-builder` runs the configured linting command. The commit is blocked if the linter fails.

---

## Implementation (IMPL)

### FUNC-IMPL-001
**Title:** Design pattern analysis with alternative proposals
**Status:** validated
**Dependencies:** FUNC-TEST-005
**Description:** The `code-builder` agent reads test files to understand the contracts, then analyzes existing design patterns in the project. For non-trivial choices, it proposes at least two alternatives to the user before implementing.

### FUNC-IMPL-002
**Title:** Production code implementation
**Status:** validated
**Dependencies:** FUNC-IMPL-001
**Description:** `code-builder` implements the production code required to make the requirement's tests pass. It only writes production code — it never modifies test files.

### FUNC-IMPL-003
**Title:** Full test suite green gate before commit
**Status:** validated
**Dependencies:** FUNC-IMPL-002, TECH-SEP-002
**Description:** Before committing the implementation, `code-builder` runs the full test suite. The commit is blocked if any single test fails.

### FUNC-IMPL-004
**Title:** Production code linting before commit
**Status:** validated
**Dependencies:** FUNC-IMPL-002, CONF-LINT-001
**Description:** Before committing the implementation, `code-builder` runs the configured linting command. The commit is blocked if the linter fails.

### FUNC-IMPL-005
**Title:** SCOPE TOO WIDE signal when implementation exceeds the requirement
**Status:** validated
**Dependencies:** FUNC-IMPL-002
**Description:** If `code-builder` detects that the necessary implementation exceeds the requirement's scope (typically > 500-600 lines or modifications to unplanned components), it emits the signal `SCOPE TOO WIDE: <reason>`. The orchestrator asks the user to split the requirement or justify an exception.

---

## Audit (AUDIT)

### FUNC-AUDIT-001
**Title:** Block audit if open findings exist
**Status:** validated
**Dependencies:** FUNC-AUDIT-014
**Description:** At the start of an audit (`/rbd-audit`), the system checks whether the last audit report contains findings with status `open`. If so, it blocks and informs the user that existing findings must be resolved or excluded before launching a new audit.

### FUNC-AUDIT-002
**Title:** Parallel dispatch of coherence and traceability agents
**Status:** validated
**Dependencies:** PERF-AUDIT-001
**Description:** The `rbd-audit` skill dispatches `audit-coherence` and `audit-traceability` simultaneously. Both agents run in parallel and each return a JSON array of findings.

### FUNC-AUDIT-003
**Title:** C1 check — semantic overlap between requirements
**Status:** validated
**Dependencies:** FUNC-AUDIT-002
**Description:** `audit-coherence` verifies that validated requirements do not semantically overlap. Any identified overlap generates a C1 finding listing the two requirement IDs involved.

### FUNC-AUDIT-004
**Title:** C2 check — requirement precision and testability
**Status:** validated
**Dependencies:** FUNC-AUDIT-002
**Description:** `audit-coherence` verifies that each requirement is precise enough to be testable (no vague terms such as "handle", "optimize" without measurable criteria). Any imprecise requirement generates a C2 finding.

### FUNC-AUDIT-005
**Title:** C3 check — dependency validity
**Status:** validated
**Dependencies:** FUNC-AUDIT-002
**Description:** `audit-coherence` verifies that every ID referenced in a requirement's `Dependencies` field exists in the requirement files with status `validated`. Any invalid reference generates a C3 finding.

### FUNC-AUDIT-006
**Title:** C4 check — circular dependency detection
**Status:** validated
**Dependencies:** FUNC-AUDIT-005
**Description:** `audit-coherence` detects cycles in the dependency graph between requirements. Any cycle generates a C4 finding listing the involved IDs.

### FUNC-AUDIT-007
**Title:** C5 check — architecture coherence
**Status:** validated
**Dependencies:** FUNC-AUDIT-002
**Description:** `audit-coherence` verifies that each requirement is assigned to an existing component in `docs/architecture.md`. Any requirement without a valid component generates a C5 finding.

### FUNC-AUDIT-008
**Title:** T1 check — test coverage per requirement
**Status:** validated
**Dependencies:** FUNC-AUDIT-002
**Description:** `audit-traceability` verifies that every `validated` requirement has at least one corresponding test commit in the format `test(ID):`. Any requirement without tests generates a T1 finding.

### FUNC-AUDIT-009
**Title:** T2 check — tag validity in tests
**Status:** validated
**Dependencies:** FUNC-AUDIT-002
**Description:** `audit-traceability` verifies that every ID referenced in test tags exists in the requirement files with status `validated`. Any orphan tag generates a T2 finding.

### FUNC-AUDIT-010
**Title:** T3 check — implementation coverage
**Status:** validated
**Dependencies:** FUNC-AUDIT-008
**Description:** `audit-traceability` verifies that every requirement with tests also has a corresponding implementation commit (`feat/tech/perf/ui/conf`(ID):). Any requirement with tests but no implementation generates a T3 finding.

### FUNC-AUDIT-011
**Title:** T4 check — plan file coverage
**Status:** validated
**Dependencies:** FUNC-AUDIT-002
**Description:** `audit-traceability` verifies that every file listed in `.rbd/plan-files.yml` has been covered by a `plan:` commit at creation or modification. Any uncovered plan file generates a T4 finding.

### FUNC-AUDIT-012
**Title:** T5 check — architecture document currency
**Status:** validated
**Dependencies:** FUNC-AUDIT-002
**Description:** `audit-traceability` verifies that `docs/architecture.md` exists, that every validated requirement appears in the traceability table, that the DI map is valid, and that every modification has an `arch(ID):` commit. Any gap generates a T5 finding.

### FUNC-AUDIT-013
**Title:** T6 check — test structure conventions
**Status:** validated
**Dependencies:** FUNC-AUDIT-002
**Description:** `audit-traceability` verifies that all test functions carry a requirement tag (T6a) and that the GWT structure (Given/When/Then) is present (T6b). Any non-conforming test generates a T6 finding.

### FUNC-AUDIT-014
**Title:** Timestamped audit report generation
**Status:** validated
**Dependencies:** FUNC-AUDIT-003, FUNC-AUDIT-013
**Description:** After merging and deduplicating findings from both agents, `rbd-audit` generates a report `audits/YYYY-MM-DD-audit.md` containing a summary table and the detail of each finding with its status (open/excluded).

### FUNC-AUDIT-015
**Title:** Finding resolution with the user
**Status:** validated
**Dependencies:** FUNC-AUDIT-014
**Description:** After report generation, `rbd-audit` works through each open finding with the user: direct fix or addition of a justified entry in `audits/exclusions.yml`.

---

## MR Review (REVIEW)

### FUNC-REVIEW-001
**Title:** Manual review trigger by MR number or URL
**Status:** validated
**Dependencies:** FUNC-INIT-004
**Description:** The user can trigger `/rbd-review` by providing an MR/PR number or URL. The skill fetches the associated commits and diffs for analysis.

### FUNC-REVIEW-003
**Title:** R1 check — requirement coverage in commits
**Status:** validated
**Dependencies:** FUNC-REVIEW-001
**Description:** `rbd-review` verifies that every ID referenced in commit prefixes (`feat(ID)`, `tech(ID)`, etc.) corresponds to an existing requirement with status `validated`.

### FUNC-REVIEW-004
**Title:** R2 check — uncovered behaviors via inference
**Status:** validated
**Dependencies:** FUNC-REVIEW-001
**Description:** `rbd-review` analyzes diffs by inference to detect new behaviors in the code that are not referenced by any requirement. Any uncovered behavior generates an R2 finding.

### FUNC-REVIEW-005
**Title:** R3 check — commit prefix consistency
**Status:** validated
**Dependencies:** FUNC-REVIEW-001
**Description:** `rbd-review` verifies that all commits in the MR use valid RBD prefixes (feat/tech/perf/ui/conf/arch/test/plan/req). Any commit without a valid prefix generates an R3 finding.

### FUNC-REVIEW-006
**Title:** R4 check — test presence for each implementation commit
**Status:** validated
**Dependencies:** FUNC-REVIEW-001
**Description:** `rbd-review` verifies that every implementation commit (`feat/tech/perf/ui/conf`(ID):) has a corresponding test commit (`test(ID):`) in the MR or in the branch history.

### FUNC-REVIEW-007
**Title:** Review report generation
**Status:** validated
**Dependencies:** FUNC-REVIEW-003, FUNC-REVIEW-004, FUNC-REVIEW-005, FUNC-REVIEW-006
**Description:** `rbd-review` generates a report `audits/YYYY-MM-DD-review-<branch>.md` and emits the signal `REVIEW PASSED` or `REVIEW FAILED`.

---

## Pre-push Control (PUSH)

### FUNC-PUSH-001
**Title:** Block push if open audit findings exist
**Status:** validated
**Dependencies:** TECH-HOOK-001, FUNC-AUDIT-014
**Description:** Before any `git push`, the hook checks the latest audit report. If any findings have status `open`, the push is blocked and the user is informed of the findings to resolve.

### FUNC-PUSH-002
**Title:** Commit alignment validation
**Status:** validated
**Dependencies:** TECH-HOOK-001, TECH-FMT-001
**Description:** The hook checks all commits on the current branch not present on the base branch: `prefix(ID):` format compliance, existence of the ID in requirements with status `validated`, and absence of code file modifications outside a properly prefixed commit.

### FUNC-PUSH-003
**Title:** rbd-review safety net trigger when remote MR exists
**Status:** validated
**Dependencies:** TECH-HOOK-001, FUNC-REVIEW-001
**Description:** If a remote MR/PR exists for the current branch at push time, the hook triggers `rbd-review` for analysis. This acts as a safety net for pushes made outside the RBD workflow, ensuring that any code reaching the remote is reviewed against requirements even when the developer did not go through the standard RBD cycle. If no MR exists yet, this step is skipped (rbd-review will be triggered at merge time).
