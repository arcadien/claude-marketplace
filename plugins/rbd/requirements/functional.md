# Functional Requirements

---

## Orchestrator (ORCH)

### FUNC-ORCH-001
**Title:** Phase detection at invocation  
**Status:** validated  
**Dependencies:** [CONF-IDLVL-001](configuration.md#conf-idlvl-001)  
**Description:** At every `/rbd` skill invocation, the system checks whether `.rbd/config.yml` exists. If absent, it starts Phase 1 (Init). If present, it determines the current phase from the last commit, pending files, and the user's stated intent.

### FUNC-ORCH-002
**Title:** Ambiguous phase resolution  
**Status:** validated  
**Dependencies:** [FUNC-ORCH-001](functional.md#func-orch-001)  
**Description:** If the current phase cannot be determined automatically, the system asks the user what they want to work on before proceeding.

### FUNC-ORCH-003
**Title:** Inter-phase routing via agent return signals  
**Status:** validated  
**Dependencies:** [FUNC-ORCH-001](functional.md#func-orch-001)  
**Description:** The orchestrator routes progression between phases solely through agent return signals (`REQUIREMENT VALIDATED`, `TESTS COMMITTED`, `IMPLEMENTATION COMMITTED`, `TOO_LARGE`, `SCOPE TOO WIDE`, `SPLIT REQUIRED`, `ARCH MISMATCH`). The orchestrator contains no business logic.

### FUNC-ORCH-004
**Title:** Exclusive delegation to specialized agents  
**Status:** validated  
**Dependencies:** [FUNC-ORCH-003](functional.md#func-orch-003)  
**Description:** Each phase is fully delegated to a dedicated agent. The orchestrator provides context (requirement ID, config files, test files) and routes the return signal. It makes no domain decisions.

### FUNC-ORCH-005
**Title:** Orchestrator handles ARCH MISMATCH signal from code-builder  
**Status:** validated  
**Dependencies:** [FUNC-IMPL-006](functional.md#func-impl-006), [FUNC-ORCH-003](functional.md#func-orch-003)  
**Description:** On receiving an `ARCH MISMATCH` signal from `code-builder`, the orchestrator informs the user that implementation cannot proceed as-is and presents two options: (a) update the architecture — the orchestrator re-dispatches `requirement-analyst` to revise `docs/architecture.md`, after which `code-builder` may be resumed; (b) revise the requirement — the orchestrator re-dispatches `requirement-analyst` for a requirement update or split. `code-builder` is not resumed until option (a) completes.

---

## Initialization (INIT)

### FUNC-INIT-001
**Title:** Interactive ID format negotiation  
**Status:** validated  
**Dependencies:** [CONF-IDLVL-001](configuration.md#conf-idlvl-001)  
**Description:** During Phase 1, the system asks the user which intermediate levels they want in requirement IDs (e.g. `domain`, `feature`). It displays a resulting example ID for each category (FUNC, TECH, PERF, UI, CONF) and confirms the format with the user.

### FUNC-INIT-002
**Title:** Test framework and language elicitation  
**Status:** validated  
**Dependencies:** [CONF-TAG-001](configuration.md#conf-tag-001)  
**Description:** During Phase 1, the system asks for the project's language and test framework (needed for the tagging convention). It offers to defer if the stack is not yet decided.

### FUNC-INIT-003
**Title:** Linter command elicitation  
**Status:** validated  
**Dependencies:** [CONF-LINT-001](configuration.md#conf-lint-001)  
**Description:** During Phase 1, the system asks for the linting command to use (e.g. `ruff check .`, `eslint .`).

### FUNC-INIT-004
**Title:** Creation of all project files and initial commit  
**Status:** validated  
**Dependencies:** [FUNC-INIT-001](functional.md#func-init-001), [FUNC-INIT-002](functional.md#func-init-002), [FUNC-INIT-003](functional.md#func-init-003)  
**Description:** At the end of Phase 1, the system generates and writes: `.rbd/config.yml`, `.rbd/plan-files.yml`, `requirements/functional.md`, `requirements/technical.md`, `requirements/performance.md`, `requirements/ui.md`, `requirements/configuration.md`, `audits/exclusions.yml`. All files are committed with the message `plan: init rbd project`.

---

## Requirement Management (REQ)

### FUNC-REQ-001
**Title:** Requirement elicitation via dialogue  
**Status:** validated  
**Dependencies:** [FUNC-INIT-004](functional.md#func-init-004)  
**Description:** The `requirement-analyst` agent engages in dialogue with the user to elicit a new requirement: title, category (FUNC/TECH/PERF/UI/CONF), target component, and full description. It also handles update and deletion of existing requirements.

### FUNC-REQ-002
**Title:** Requirement size challenge  
**Status:** validated  
**Dependencies:** [FUNC-REQ-001](functional.md#func-req-001)  
**Description:** Before validation, the agent challenges any requirement whose scope exceeds what can be tested in a single coherent test suite (e.g. "CRUD for the entire module"). If too large, it emits a `SPLIT REQUIRED` signal with a reason and cleans up the draft.

### FUNC-REQ-003
**Title:** Semantic overlap challenge  
**Status:** validated  
**Dependencies:** [FUNC-REQ-001](functional.md#func-req-001)  
**Description:** The agent verifies that the new requirement does not semantically overlap with any existing validated requirement. If overlap is detected, it informs the user and asks for confirmation or reformulation.

### FUNC-REQ-004
**Title:** Consistency challenge  
**Status:** validated  
**Dependencies:** [FUNC-REQ-001](functional.md#func-req-001)  
**Description:** The agent verifies the new requirement is consistent with the existing requirement set (no contradictions, valid dependencies). It flags any inconsistency to the user before validation.

### FUNC-REQ-005
**Title:** User validation before commit  
**Status:** validated  
**Dependencies:** [FUNC-REQ-002](functional.md#func-req-002), [FUNC-REQ-003](functional.md#func-req-003), [FUNC-REQ-004](functional.md#func-req-004)  
**Description:** A requirement is committed only on explicit user confirmation after the challenge. The commit follows the format `req(ID): <title>`.

### FUNC-REQ-006
**Title:** Requirement splitting when too large  
**Status:** validated  
**Dependencies:** [FUNC-REQ-002](functional.md#func-req-002)  
**Description:** On a `SPLIT REQUIRED` signal, the orchestrator re-dispatches `requirement-analyst` for each identified sub-requirement, providing the split reason as context.

### FUNC-REQ-007
**Title:** Requirement deletion  
**Status:** validated  
**Dependencies:** [FUNC-REQ-001](functional.md#func-req-001)  
**Description:** The `requirement-analyst` agent handles deletion of an existing requirement. It emits the signal `REQUIREMENT DELETED: <ID>`. The workflow cycle ends and the user is informed.

---

## Architecture (ARCH)

### FUNC-ARCH-001
**Title:** Component assignment for each requirement  
**Status:** validated  
**Dependencies:** [FUNC-REQ-005](functional.md#func-req-005)  
**Description:** For every validated requirement, the `requirement-analyst` agent identifies the responsible architectural component(s) and updates the traceability table in `docs/architecture.md`.

### FUNC-ARCH-002
**Title:** DI constraint identification -> TECH requirement creation  
**Status:** validated  
**Dependencies:** [FUNC-ARCH-001](functional.md#func-arch-001)  
**Description:** If a requirement introduces a new injectable dependency, the agent automatically creates a corresponding TECH requirement capturing the DI constraint, and updates the DI map in `docs/architecture.md`.

### FUNC-ARCH-003
**Title:** docs/architecture.md update with arch(ID) commit  
**Status:** validated  
**Dependencies:** [FUNC-ARCH-001](functional.md#func-arch-001)  
**Description:** Every modification to `docs/architecture.md` produces a distinct commit in the format `arch(ID): <description>` where `ID` is the triggering requirement.

### FUNC-ARCH-004
**Title:** Architecture coherence gate before tests  
**Status:** validated  
**Dependencies:** [FUNC-ARCH-001](functional.md#func-arch-001), [FUNC-ARCH-003](functional.md#func-arch-003)  
**Description:** The `requirement-analyst` agent must complete Phase 3 (architecture coherence) before the test-builder can be dispatched. No tests are written until the architecture document is up to date.

---

## Test Generation (TEST)

### FUNC-TEST-001
**Title:** Integration test generation with GWT structure  
**Status:** validated  
**Dependencies:** [FUNC-ARCH-004](functional.md#func-arch-004)  
**Description:** The `test-builder` agent generates integration tests (not unit tests) following the Given/When/Then structure. Each test contains exactly one action (When). If two actions are needed, they become two separate tests.

### FUNC-TEST-002
**Title:** Mandatory requirement ID tag on every test function  
**Status:** validated  
**Dependencies:** [FUNC-TEST-001](functional.md#func-test-001), [TECH-TAG-001](technical.md#tech-tag-001)  
**Description:** Every test function carries a requirement ID tag using the convention defined in `.rbd/config.yml`. Missing tag is a hard gate: the commit is rejected.

### FUNC-TEST-003
**Title:** Parametrized tests for multiple cases  
**Status:** validated  
**Dependencies:** [FUNC-TEST-001](functional.md#func-test-001)  
**Description:** When a requirement covers multiple input/output cases, `test-builder` generates a parametrized test (case table) rather than duplicated functions. The tag is placed on the parametrized function, not on individual cases.

### FUNC-TEST-004
**Title:** TOO_LARGE signal when requirement is too large to test  
**Status:** validated  
**Dependencies:** [FUNC-TEST-001](functional.md#func-test-001)  
**Description:** If `test-builder` cannot design a coherent test suite for a requirement, it emits the signal `TOO_LARGE: <reason>`. The orchestrator then re-dispatches `requirement-analyst` for splitting, providing the reason as context.

### FUNC-TEST-005
**Title:** Test file linting before commit  
**Status:** validated  
**Dependencies:** [FUNC-TEST-001](functional.md#func-test-001), [CONF-LINT-001](configuration.md#conf-lint-001)  
**Description:** Before committing tests, `test-builder` runs the configured linting command. The commit is blocked if the linter fails.

---

## Implementation (IMPL)

### FUNC-IMPL-001
**Title:** Design pattern analysis with alternative proposals  
**Status:** validated  
**Dependencies:** [FUNC-TEST-005](functional.md#func-test-005)  
**Description:** The `code-builder` agent reads test files to understand the contracts, then analyzes existing design patterns in the project. For non-trivial choices, it proposes at least two alternatives to the user before implementing.

### FUNC-IMPL-002
**Title:** Production code implementation  
**Status:** validated  
**Dependencies:** [FUNC-IMPL-001](functional.md#func-impl-001)  
**Description:** `code-builder` implements the production code required to make the requirement's tests pass. It only writes production code — it never modifies test files.

### FUNC-IMPL-003
**Title:** Full test suite green gate before commit  
**Status:** validated  
**Dependencies:** [FUNC-IMPL-002](functional.md#func-impl-002), [TECH-SEP-002](technical.md#tech-sep-002)  
**Description:** Before committing the implementation, `code-builder` runs the full test suite. The commit is blocked if any single test fails.

### FUNC-IMPL-004
**Title:** Production code linting before commit  
**Status:** validated  
**Dependencies:** [FUNC-IMPL-002](functional.md#func-impl-002), [CONF-LINT-001](configuration.md#conf-lint-001)  
**Description:** Before committing the implementation, `code-builder` runs the configured linting command. The commit is blocked if the linter fails.

### FUNC-IMPL-005
**Title:** SCOPE TOO WIDE signal when implementation exceeds the requirement  
**Status:** validated  
**Dependencies:** [FUNC-IMPL-002](functional.md#func-impl-002)  
**Description:** If `code-builder` detects that the necessary implementation exceeds the requirement's scope (typically > 500-600 lines or modifications to unplanned components), it emits the signal `SCOPE TOO WIDE: <reason>`. The orchestrator asks the user to split the requirement or justify an exception.

### FUNC-IMPL-006
**Title:** Architectural boundary check before writing any code  
**Status:** validated  
**Dependencies:** [FUNC-IMPL-001](functional.md#func-impl-001)  
**Description:** Before writing or modifying any file, `code-builder` reads `docs/architecture.md` and verifies that every file it plans to create or modify belongs to a component declared in the architecture. If any planned file cannot be mapped to a declared component, `code-builder` emits the signal `ARCH MISMATCH: <reason>` and stops — no file is written.

---

## Audit (AUDIT)

### FUNC-AUDIT-001
**Title:** Block audit if open findings exist  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-014](functional.md#func-audit-014)  
**Description:** At the start of an audit (`/rbd-audit`), the system checks whether the last audit report contains findings with status `open`. If so, it blocks and informs the user that existing findings must be resolved or excluded before launching a new audit.

### FUNC-AUDIT-002
**Title:** Parallel dispatch of coherence and traceability agents  
**Status:** validated  
**Dependencies:** [PERF-AUDIT-001](performance.md#perf-audit-001)  
**Description:** The `rbd-audit` skill dispatches `audit-coherence` and `audit-traceability` simultaneously. Both agents run in parallel and each return a JSON array of findings.

### FUNC-AUDIT-003
**Title:** C1 check — semantic overlap between requirements  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-coherence` verifies that validated requirements do not semantically overlap. Any identified overlap generates a C1 finding listing the two requirement IDs involved.

### FUNC-AUDIT-004
**Title:** C2 check — requirement precision and testability  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-coherence` verifies that each requirement is precise enough to be testable (no vague terms such as "handle", "optimize" without measurable criteria). Any imprecise requirement generates a C2 finding.

### FUNC-AUDIT-005
**Title:** C3 check — dependency validity  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-coherence` verifies that every ID referenced in a requirement's `Dependencies` field exists in the requirement files with status `validated`. Any invalid reference generates a C3 finding.

### FUNC-AUDIT-006
**Title:** C4 check — circular dependency detection  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-005](functional.md#func-audit-005)  
**Description:** `audit-coherence` detects cycles in the dependency graph between requirements. Any cycle generates a C4 finding listing the involved IDs.

### FUNC-AUDIT-007
**Title:** C5 check — architecture coherence  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-coherence` verifies that each requirement is assigned to an existing component in `docs/architecture.md`. Any requirement without a valid component generates a C5 finding.

### FUNC-AUDIT-008
**Title:** T1 check — test coverage per requirement  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that every `validated` requirement has at least one corresponding test commit in the format `test(ID):`. Any requirement without tests generates a T1 finding.

### FUNC-AUDIT-009
**Title:** T2 check — tag validity in tests  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that every ID referenced in test tags exists in the requirement files with status `validated`. Any orphan tag generates a T2 finding.

### FUNC-AUDIT-010
**Title:** T3 check — implementation coverage  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-008](functional.md#func-audit-008)  
**Description:** `audit-traceability` verifies that every requirement with tests also has a corresponding implementation commit (`feat/tech/perf/ui/conf`(ID):). Any requirement with tests but no implementation generates a T3 finding.

### FUNC-AUDIT-011
**Title:** T4 check — plan file coverage  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that every file listed in `.rbd/plan-files.yml` has been covered by a `plan:` commit at creation or modification. Any uncovered plan file generates a T4 finding.

### FUNC-AUDIT-012
**Title:** T5 check — architecture document currency  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that `docs/architecture.md` exists, that every validated requirement appears in the traceability table, that the DI map is valid, and that every modification has an `arch(ID):` commit. Any gap generates a T5 finding.

### FUNC-AUDIT-013
**Title:** T6 check — test structure conventions  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that all test functions carry a requirement tag (T6a) and that the GWT structure (Given/When/Then) is present (T6b). Any non-conforming test generates a T6 finding.

### FUNC-AUDIT-014
**Title:** Timestamped audit report generation  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-003](functional.md#func-audit-003), [FUNC-AUDIT-013](functional.md#func-audit-013)  
**Description:** After merging and deduplicating findings from both agents, `rbd-audit` generates a report `audits/YYYY-MM-DD-audit.md` containing a summary table and the detail of each finding with its status (open/excluded).

### FUNC-AUDIT-015
**Title:** Finding resolution with the user  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-014](functional.md#func-audit-014)  
**Description:** After report generation, `rbd-audit` works through each open finding with the user: direct fix or addition of a justified entry in `audits/exclusions.yml`.

---

## MR Review (REVIEW)

### FUNC-REVIEW-001
**Title:** Manual review trigger by MR number or URL  
**Status:** validated  
**Dependencies:** [FUNC-INIT-004](functional.md#func-init-004)  
**Description:** The user can trigger `/rbd-review` by providing an MR/PR number or URL. The skill fetches the associated commits and diffs for analysis.

### FUNC-REVIEW-003
**Title:** R1 check — requirement coverage in commits  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** `rbd-review` verifies that every ID referenced in commit prefixes (`feat(ID)`, `tech(ID)`, etc.) corresponds to an existing requirement with status `validated`.

### FUNC-REVIEW-004
**Title:** R2 check — uncovered behaviors via inference  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** `rbd-review` analyzes diffs by inference to detect new behaviors in the code that are not referenced by any requirement. Any uncovered behavior generates an R2 finding.

### FUNC-REVIEW-005
**Title:** R3 check — commit prefix consistency  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** `rbd-review` verifies that all commits in the MR use valid RBD prefixes (feat/tech/perf/ui/conf/arch/test/plan/req). Any commit without a valid prefix generates an R3 finding.

### FUNC-REVIEW-006
**Title:** R4 check — test presence for each implementation commit  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** `rbd-review` verifies that every implementation commit (`feat/tech/perf/ui/conf`(ID):) has a corresponding test commit (`test(ID):`) in the MR or in the branch history.

### FUNC-REVIEW-007
**Title:** Review report generation  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-003](functional.md#func-review-003), [FUNC-REVIEW-004](functional.md#func-review-004), [FUNC-REVIEW-005](functional.md#func-review-005), [FUNC-REVIEW-006](functional.md#func-review-006)  
**Description:** `rbd-review` generates a report `audits/YYYY-MM-DD-review-<branch>.md` and emits the signal `REVIEW PASSED` or `REVIEW FAILED`.

---

## Pre-push Control (PUSH)

### FUNC-PUSH-001
**Title:** Block push if open audit findings exist  
**Status:** validated  
**Dependencies:** [TECH-HOOK-001](technical.md#tech-hook-001), [FUNC-AUDIT-014](functional.md#func-audit-014)  
**Description:** Before any `git push`, the hook checks the latest audit report. If any findings have status `open`, the push is blocked and the user is informed of the findings to resolve.

### FUNC-PUSH-002
**Title:** Commit alignment validation  
**Status:** validated  
**Dependencies:** [TECH-HOOK-001](technical.md#tech-hook-001), [TECH-FMT-001](technical.md#tech-fmt-001)  
**Description:** The hook checks all commits on the current branch not present on the base branch: `prefix(ID):` format compliance, existence of the ID in requirements with status `validated`, and absence of code file modifications outside a properly prefixed commit.

### FUNC-PUSH-003
**Title:** rbd-review safety net trigger when remote MR exists  
**Status:** validated  
**Dependencies:** [TECH-HOOK-001](technical.md#tech-hook-001), [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** If a remote MR/PR exists for the current branch at push time, the hook triggers `rbd-review` for analysis. This acts as a safety net for pushes made outside the RBD workflow, ensuring that any code reaching the remote is reviewed against requirements even when the developer did not go through the standard RBD cycle. If no MR exists yet, this step is skipped (rbd-review will be triggered at merge time).

### FUNC-PUSH-004
**Title:** Pre-push validation state caching via dotfile  
**Status:** validated  
**Dependencies:** [FUNC-PUSH-001](functional.md#func-push-001), [FUNC-PUSH-002](functional.md#func-push-002), [FUNC-PUSH-003](functional.md#func-push-003), [TECH-HOOK-001](technical.md#tech-hook-001)  
**Description:** After completing all pre-push checks successfully ([FUNC-PUSH-001](functional.md#func-push-001), [FUNC-PUSH-002](functional.md#func-push-002), [FUNC-PUSH-003](functional.md#func-push-003)), the orchestrator writes `.rbd/.push-validated` containing the output of `git rev-parse HEAD`. When the pre-push hook fires, it reads this file first: if the file exists and its content matches the current HEAD hash, the hook allows the push and deletes the file; if the file is absent or the hash does not match, the hook proceeds with the full check sequence. The file `.rbd/.push-validated` must be listed in `.gitignore` — it is ephemeral state and must never be committed.

---

## Architecture Analysis (ANALYZE)

### FUNC-ANALYZE-001
**Title:** rbd-arch-analyze skill triggers the arch-analyst agent  
**Status:** validated  
**Dependencies:** [FUNC-INIT-004](functional.md#func-init-004)  
**Description:** The `/rbd-arch-analyze` skill dispatches the `arch-analyst` agent, providing it with the full project context: all `requirements/*.md` files and `docs/architecture.md` of the target project. The agent produces a timestamped Markdown report `docs/analysis-YYYY-MM-DD.md` and the skill confirms the output path to the user.

### FUNC-ANALYZE-002
**Title:** arch-analyst generates a global component partitioning diagram  
**Status:** validated  
**Dependencies:** [FUNC-ANALYZE-001](functional.md#func-analyze-001)  
**Description:** The `arch-analyst` agent produces one global Mermaid diagram (`graph LR` or `classDiagram`) showing the software components of the target project and their relationships. The diagram is inferred from the requirement files and `docs/architecture.md` of the target project. Its purpose is to help the user maintain architectural coherence across the project.

### FUNC-ANALYZE-003
**Title:** arch-analyst generates per-component Mermaid diagrams  
**Status:** validated  
**Dependencies:** [FUNC-ANALYZE-001](functional.md#func-analyze-001)  
**Description:** For each identified software component of the target project, the `arch-analyst` agent produces one Mermaid diagram: a `flowchart` for process or algorithm components, or a `stateDiagram` for stateful components. The diagram type is chosen based on the component's nature. The number of per-component diagrams is variable (one per identified component). All diagrams — one global and N per-component — appear in the same output document `docs/analysis-YYYY-MM-DD.md`.

### FUNC-ANALYZE-004
**Title:** arch-analyst performs a code-vs-architecture coherence scan  
**Status:** validated  
**Dependencies:** [FUNC-ANALYZE-001](functional.md#func-analyze-001)  
**Description:** When source code files are present in the target project, the `arch-analyst` agent scans them to detect structural mismatches between the actual code and the declared architecture. It reports two categories of finding in `docs/analysis-YYYY-MM-DD.md`: (a) code elements (modules, classes, or top-level functions) that cannot be mapped to any component in `docs/architecture.md` or any validated requirement; (b) component dependencies declared in `docs/architecture.md` that are not reflected in any import, instantiation, or inheritance relationship found in the scanned files. This section is omitted if no source code files are found.

---

## Audit — PLAT traceability (AUDIT)

### FUNC-AUDIT-016
**Title:** T7 check — derives_from traceability for PLAT requirements  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002), [CONF-PLAT-001](configuration.md#conf-plat-001)  
**Description:** `audit-traceability` verifies that every `PLAT-*` requirement with status `validated` has a `derives_from:` frontmatter field referencing an existing FUNC or TECH requirement with status `validated`. Any PLAT requirement missing this field, or referencing a non-existent or deprecated ID, generates a T7 finding (traceability violation).

---

## Coverage Metrics (METRICS)

### FUNC-METRICS-001
**Title:** Coverage metrics report per category and subcategory  
**Status:** validated  
**Dependencies:** [CONF-IDLVL-001](configuration.md#conf-idlvl-001)  
**Description:** The `rbd-metrics` skill reads all requirement files and counts, per main category (FUNC, TECH, PERF, UI, CONF, PLAT) and per subcategory, the total number of validated requirements and how many have at least one `test(ID):` commit. Output is an ASCII structured list printed to stdout:

```
FUNC  (12 validated)
├── AUTH    3 / 3  ████████████  100%
├── DATA    2 / 4  ██████░░░░░░   50%  ← 2 missing
└── PUSH    1 / 1  ████████████  100%
TECH  (4 validated)
└── TAG     4 / 4  ████████████  100%
```

No file is written. An optional `--json` flag exports the same data as a JSON object to stdout.

### FUNC-METRICS-002
**Title:** Opt-in req-to-green latency per requirement  
**Status:** validated  
**Dependencies:** [FUNC-METRICS-001](functional.md#func-metrics-001)  
**Description:** When invoked with the `--latency` flag, `rbd-metrics` traverses the git log to compute, for each validated requirement, the elapsed time between the `req(ID):` commit timestamp and the first `test(ID):` commit timestamp. Requirements with no test commit are shown as `pending`. Results are displayed as a latency column appended to the ASCII structured list produced by FUNC-METRICS-001. The computation is strictly read-only.
