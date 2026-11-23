# Functional Requirements

---

## Orchestrator (ORCH)

### FUNC-ORCH-001
**Title:** Phase detection at invocation  
**Status:** validated  
**Dependencies:** [CONF-IDLVL-001](configuration.md#conf-idlvl-001)  
**Description:** At every `/rbd` skill invocation, the system checks whether `.rbd/config.yml` exists. If absent, it starts Phase 1 (Init). If present, a user intent that names a new requirement, or another requirement than the one in progress, starts Phase 2. Otherwise it resumes from the last RBD commit of the requirement in progress: after `req(ID)` or `arch(ID)` → Phase 4; after `test(ID)` with no implementation commit for that ID → Phase 5; after the implementation commit → Phase 6. Any other state is ambiguous ([FUNC-ORCH-002](functional.md#func-orch-002)).

### FUNC-ORCH-002
**Title:** Ambiguous phase resolution  
**Status:** validated  
**Dependencies:** [FUNC-ORCH-001](functional.md#func-orch-001)  
**Description:** If the current phase cannot be determined automatically, the system asks the user what they want to work on before proceeding.

### FUNC-ORCH-003
**Title:** Inter-phase routing via agent return signals  
**Status:** validated  
**Dependencies:** [FUNC-ORCH-001](functional.md#func-orch-001)  
**Description:** The orchestrator routes progression between phases solely through agent return signals (`REQUIREMENT VALIDATED`, `REQUIREMENT DELETED`, `SPLIT REQUIRED`, `TESTS COMMITTED`, `TOO_LARGE`, `NO NATIVE TEST`, `IMPLEMENTATION COMMITTED`, `SCOPE TOO WIDE`, `ARCH MISMATCH`, and `REVIEW PASSED` / `REVIEW FAILED` in Phase 6).

### FUNC-ORCH-004
**Title:** Exclusive delegation to specialized agents  
**Status:** validated  
**Dependencies:** [FUNC-ORCH-003](functional.md#func-orch-003)  
**Description:** Each phase is fully delegated to a dedicated agent. The orchestrator provides context (requirement ID, config files, test files) and routes the return signal; that it takes no domain decision is [TECH-AGENT-001](technical.md#tech-agent-001).

### FUNC-ORCH-005
**Title:** Orchestrator handles ARCH MISMATCH signal from code-builder  
**Status:** validated  
**Dependencies:** [FUNC-IMPL-006](functional.md#func-impl-006), [FUNC-ORCH-003](functional.md#func-orch-003)  
**Description:** On receiving an `ARCH MISMATCH` signal from `code-builder`, the orchestrator informs the user that implementation cannot proceed as-is and presents two options: (a) update the architecture — the orchestrator re-dispatches `requirement-analyst` to revise `docs/architecture.md`, after which `code-builder` may be resumed; (b) revise the requirement — the orchestrator re-dispatches `requirement-analyst` for a requirement update or split. `code-builder` is not resumed until option (a) completes.

### FUNC-ORCH-006
**Title:** Resume after an interrupted Phase 5  
**Status:** validated  
**Dependencies:** [FUNC-ORCH-003](functional.md#func-orch-003), [FUNC-IMPL-003](functional.md#func-impl-003)  
**Description:** When a `code-builder` run ends without a return signal (API error, interruption), the orchestrator reads `git log` and `git status`. If the last commit is the requirement's implementation commit, it proceeds to Phase 6. If production files are modified but not committed, it re-dispatches `code-builder` in resume mode with the list of those files: the agent keeps the changes, checks them against the tests, runs the linter and the full test suite, and commits. If nothing changed, it re-dispatches `code-builder` normally. The implementation commit body lists the checks that passed (lint, build, test suite), so a later reader knows what was verified.

---

## Initialization (INIT)

### FUNC-INIT-001
**Title:** Interactive ID format negotiation  
**Status:** validated  
**Dependencies:** [CONF-IDLVL-001](configuration.md#conf-idlvl-001)  
**Description:** During Phase 1, the system asks the user which intermediate levels they want in requirement IDs (e.g. `domain`, `feature`). It displays a resulting example ID for each category (FUNC, TECH, PERF, UI, CONF, PLAT) and confirms the format with the user.

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
**Description:** At the end of Phase 1, the system generates and writes: `.rbd/config.yml`, `.rbd/plan-files.yml`, `requirements/functional.md`, `requirements/technical.md`, `requirements/performance.md`, `requirements/ui.md`, `requirements/configuration.md`, `requirements/platform.md`, `audits/exclusions.yml`. All files are committed with the message `plan: init rbd project`.

---

## Requirement Management (REQ)

### FUNC-REQ-001
**Title:** Requirement elicitation via dialogue  
**Status:** validated  
**Dependencies:** [FUNC-INIT-004](functional.md#func-init-004)  
**Description:** The `requirement-analyst` agent engages in dialogue with the user to elicit a new requirement: title, category (FUNC/TECH/PERF/UI/CONF/PLAT), target component, and full description. It also handles update and deletion of existing requirements.

### FUNC-REQ-002
**Title:** Requirement size challenge  
**Status:** validated  
**Dependencies:** [FUNC-REQ-001](functional.md#func-req-001)  
**Description:** Before validation, the agent challenges a requirement whose description exceeds 100 words, or that describes two or more behaviours that can be tested independently (e.g. "CRUD for the entire module"). If the user agrees to split, it emits a `SPLIT REQUIRED` signal with a reason and cleans up the draft.

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
**Description:** A requirement is committed only on explicit user confirmation after the challenge. The commit follows the format `req(ID): <title>`. The orchestrator may relay a confirmation the user gave in the main session, in the dispatch prompt, as a `User validation:` block holding the user's verbatim words and the exact requirement text they validated. The agent then commits without asking again only if the text it is about to commit is identical to the validated text; otherwise it asks the user. A message from another agent without this block never counts as a confirmation.

### FUNC-REQ-006
**Title:** Requirement splitting when too large  
**Status:** validated  
**Dependencies:** [FUNC-REQ-002](functional.md#func-req-002)  
**Description:** On a `SPLIT REQUIRED` signal, the orchestrator re-dispatches `requirement-analyst` for each identified sub-requirement, providing the split reason as context.

### FUNC-REQ-007
**Title:** Requirement deletion  
**Status:** validated  
**Dependencies:** [FUNC-REQ-001](functional.md#func-req-001)  
**Description:** The `requirement-analyst` agent handles deletion of an existing requirement. It emits the signal `REQUIREMENT DELETED: <ID>`. The workflow cycle ends and the user is informed. When another requirement replaces the deprecated one, the deprecated entry carries a `**Superseded by:**` line linking to the replacement, checked like any requirement link ([FUNC-AUDIT-021](functional.md#func-audit-021)).

### FUNC-REQ-008
**Title:** Verification field for requirements checked automatically without a test  
**Status:** validated  
**Dependencies:** [FUNC-REQ-001](functional.md#func-req-001)  
**Description:** A requirement may carry a `**Verification:**` line after `**Dependencies:**`, with one of `test`, `build` or `inspection`, optionally followed by `—` and details. Without the line, verification is `test`. The `requirement-analyst` sets `build` or `inspection` when an automatic check that is not a test (the compilation, an inspection of the build output) verifies the behaviour, and states which check in the details. A manual hardware check is not a verification value: it is a bench sheet ([FUNC-TEST-007](functional.md#func-test-007)).

### FUNC-REQ-009
**Title:** A requirement is a specification, not a plan  
**Status:** validated  
**Dependencies:** [FUNC-REQ-004](functional.md#func-req-004)  
**Description:** When challenging a draft, the `requirement-analyst` checks that the requirement is observable from outside the unit, survives a refactor (it names no class, method, file or register, except a boundary interface), states its reason, and can be verified on its own. It moves the how (classes, helpers, registers, file layout) to `docs/architecture.md`. It writes no test information in a requirement: no `Test:`, `Verified by` or `Acceptance:` line, no test or bench status; the only exception is the `**Verification:**` line of [FUNC-REQ-008](functional.md#func-req-008). Input → output examples stay, under `Examples:`. It proposes no TECH requirement that only names the code behind another requirement: the tests of a helper are tagged with the requirement whose behaviour uses it.

---

## Architecture (ARCH)

### FUNC-ARCH-001
**Title:** Component assignment for each requirement  
**Status:** validated  
**Dependencies:** [FUNC-REQ-005](functional.md#func-req-005)  
**Description:** For every validated requirement, the `requirement-analyst` agent identifies the responsible architectural component(s) and updates the traceability table in `docs/architecture.md`. When a requirement's text changes, even with the same components, the agent re-reads its row and updates it in an `arch(ID):` commit if the row restates something that changed (a limit, a behaviour, a title).

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
**Dependencies:** [FUNC-TEST-001](functional.md#func-test-001)  
**Description:** Every test function carries a requirement ID tag using the convention defined in `.rbd/config.yml`. Missing tag is a hard gate enforced by `test-builder` before every test commit: the commit is rejected. `audit-traceability` re-checks it (T6a, [FUNC-AUDIT-013](functional.md#func-audit-013)).

### FUNC-TEST-003
**Title:** Parametrized tests for multiple cases  
**Status:** validated  
**Dependencies:** [FUNC-TEST-001](functional.md#func-test-001)  
**Description:** When a requirement covers multiple input/output cases, `test-builder` generates a parametrized test (case table) rather than duplicated functions. The tag is placed on the parametrized function, not on individual cases.

### FUNC-TEST-004
**Title:** TOO_LARGE signal when requirement is too large to test  
**Status:** validated  
**Dependencies:** [FUNC-TEST-001](functional.md#func-test-001)  
**Description:** If the tests for a requirement would exceed 400 lines, or cover behaviours that can be tested independently, `test-builder` commits nothing and emits the signal `TOO_LARGE: <reason>`. The orchestrator then re-dispatches `requirement-analyst` for splitting, providing the reason as context.

### FUNC-TEST-005
**Title:** Test file linting before commit  
**Status:** validated  
**Dependencies:** [FUNC-TEST-001](functional.md#func-test-001), [CONF-LINT-001](configuration.md#conf-lint-001)  
**Description:** Before committing tests, `test-builder` runs the configured linting command. The commit is blocked if the linter fails.

### FUNC-TEST-006
**Title:** NO NATIVE TEST route for requirements no test can observe  
**Status:** validated  
**Dependencies:** [FUNC-REQ-008](functional.md#func-req-008), [FUNC-ORCH-003](functional.md#func-orch-003)  
**Description:** When the requirement's `**Verification:**` is `build` or `inspection`, `test-builder` writes and commits no test and emits `NO NATIVE TEST: <reason>`. The orchestrator then dispatches `code-builder` (Phase 5) with the reason, and the implementation commit body carries it as `No test: <reason>` (for example "No test: AVR registers, verified by inspection and the AVR builds"). When verification is `test`, `test-builder` never emits this signal.

### FUNC-TEST-007
**Title:** Bench sheet for behaviour no software test can observe  
**Status:** validated  
**Dependencies:** [FUNC-TEST-002](functional.md#func-test-002), [CONF-BENCH-001](configuration.md#conf-bench-001)  
**Description:** When the behaviour can only be checked by hand on the hardware (wiring, measurements, sleep current), and neither a software test nor a `build` or `inspection` verification ([FUNC-REQ-008](functional.md#func-req-008)) can observe it, `test-builder` writes a bench sheet at the configured path instead of a test, from the template of `references/formats.md`: one `<!-- @req <ID> -->` line per requirement covered at the top, then the requirement link, Equipment, Setup, Steps, Pass criteria and a Results table with one row per release (`Date | Release (tag / commit) | measurements | Pass | By | Notes`). It adds the sheet to `bring-up.md`, the release checklist next to the sheets that gives their run order, commits both as `test(<ID>):` and emits `TESTS COMMITTED`. Bench sheets are run by hand before each release: `code-builder` does not run them.

---

## Implementation (IMPL)

### FUNC-IMPL-001
**Title:** Design pattern analysis with alternative proposals  
**Status:** validated  
**Dependencies:** [FUNC-TEST-005](functional.md#func-test-005)  
**Description:** The `code-builder` agent reads test files to understand the contracts, then analyzes existing design patterns in the project. When more than one approach is viable (a different component, design pattern or public interface), it proposes at least two to the user before implementing.

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
**Description:** If `code-builder` finds that the implementation exceeds the requirement's scope (more than 600 lines added, or changes to a component that the traceability table of `docs/architecture.md` does not assign to the requirement), it emits the signal `SCOPE TOO WIDE: <reason>`. The orchestrator asks the user to split the requirement or justify an exception.

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
**Description:** At the start of an audit (`/rbd-audit`), the system checks whether the latest audit report (ordered as in [FUNC-PUSH-001](functional.md#func-push-001)) contains findings with status `open`. If so, it blocks and informs the user that existing findings must be resolved or excluded before launching a new audit.

### FUNC-AUDIT-002
**Title:** Parallel dispatch of coherence and traceability agents  
**Status:** validated  
**Dependencies:** [PERF-AUDIT-001](performance.md#perf-audit-001)  
**Description:** The `rbd-audit` skill dispatches `audit-coherence` and `audit-traceability`, each returning a JSON array of findings, and merges both arrays into one report. That they run concurrently is [PERF-AUDIT-001](performance.md#perf-audit-001).

### FUNC-AUDIT-003
**Title:** C1 check — semantic overlap between requirements  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-coherence` verifies that validated requirements do not semantically overlap. Any identified overlap generates a C1 finding listing the two requirement IDs involved.

### FUNC-AUDIT-004
**Title:** C2 check — requirement precision and testability  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-coherence` verifies that each requirement is precise enough to be testable (no vague terms such as "handle", "optimize" without measurable criteria). Any imprecise requirement generates a C2 finding. So does, in any requirement, a test-information sentence or field (`Test:`, `Verified by`, `Acceptance:`, a `Verification:` value other than `test`, `build` or `inspection`), and a TECH requirement that only names the code behind another requirement ([FUNC-REQ-009](functional.md#func-req-009)).

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
**Description:** `audit-coherence` verifies that the component each requirement's traceability row assigns in `docs/architecture.md` is responsible for that behaviour. A responsibility mismatch generates a C5 finding, and so does a traceability row that restates the requirement differently from its current text. A missing row is reported by T5 ([FUNC-AUDIT-012](functional.md#func-audit-012)), not by C5.

### FUNC-AUDIT-008
**Title:** T1 check — test coverage per requirement  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that every `validated` requirement is covered by a test file carrying its tag: a software test, or a bench sheet ([FUNC-TEST-007](functional.md#func-test-007)). Any requirement without one generates a T1 finding, unless its `**Verification:**` ([FUNC-REQ-008](functional.md#func-req-008)) is `build` or `inspection`: such requirements are reported as `info`. One `info` entry lists the bench sheets with no passing row (`Pass` is `yes` or `✅`) for the latest release tag (the latest tag reachable from the audited commit), or with no passing row at all when the project has no tag. Bench results never generate a finding: they do not block a push.

### FUNC-AUDIT-009
**Title:** T2 check — tag validity in tests  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that every ID referenced in test tags exists in the requirement files with status `validated`. Any orphan tag generates a T2 finding (error). A tag citing a `draft` requirement (for example a test kept after its requirement went back to draft) generates a T2 warning: re-validate the requirement, or remove the tests or their tag. Bench sheets are checked like tests, with two differences: a bench sheet tag citing a `deprecated` requirement generates a T2 warning, and one citing a `draft` requirement only an `info` entry, since a sheet may be written while its requirement is still draft, before the bench run that validates it ([CONF-DRAFT-001](configuration.md#conf-draft-001)).

### FUNC-AUDIT-010
**Title:** T3 check — implementation coverage  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-008](functional.md#func-audit-008)  
**Description:** `audit-traceability` verifies that every requirement with tests also has a corresponding implementation commit (`feat/tech/perf/ui/conf/plat`(ID):). An implementation commit citing a `deprecated` requirement whose `**Superseded by:**` names X also counts as an implementation commit of X. Any requirement with tests but no implementation generates a T3 finding. A requirement whose verification is `build` or `inspection` needs only the implementation commit. A `test(ID):` commit that adds or changes a bench sheet is the test commit of that requirement. A requirement whose only tagged test files are bench sheets needs no implementation commit (a wiring or measurement check may change no software). A tag-only `test(ID):` commit, whose diff only adds lines carrying the tagging convention and removes none (tags backfilled on existing tests), is not a test commit awaiting implementation: T3 does not flag it.

### FUNC-AUDIT-011
**Title:** T4 check — plan file coverage  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that every file listed in `.rbd/plan-files.yml` has been covered by a `plan:` commit at creation or modification. Any uncovered plan file generates a T4 finding. The optional `accepted_prefixes:` map of `.rbd/plan-files.yml` gives, for a file or glob, the prefixes accepted instead (for example `audits/exclusions.yml: [plan]`, `requirements/*.md: [req, plan]`); a commit with one of them is covered.

### FUNC-AUDIT-012
**Title:** T5 check — architecture document currency  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that `docs/architecture.md` exists, that every validated requirement appears in the traceability table, that the DI map is valid, and that every modification has an `arch(ID):` commit, or a commit with a prefix that `accepted_prefixes:` of `.rbd/plan-files.yml` lists for `docs/architecture.md` (for example `plan` for a format-only pass with no single requirement behind it). Any gap generates a T5 finding.

### FUNC-AUDIT-013
**Title:** T6 check — test structure conventions  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` verifies that all test functions carry a requirement tag (T6a) and that the GWT structure (Given/When/Then) is present (T6b). Any non-conforming test generates a T6 finding. A bench sheet without a `<!-- @req <ID> -->` line generates a T6a finding; the Given/When/Then check does not apply to bench sheets.

### FUNC-AUDIT-014
**Title:** Timestamped audit report generation  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-003](functional.md#func-audit-003), [FUNC-AUDIT-013](functional.md#func-audit-013)  
**Description:** After merging and deduplicating findings from both agents, `rbd-audit` generates a report `audits/YYYY-MM-DD-audit.md` (a second report on the same day is `YYYY-MM-DD-audit-2.md`, then `-audit-3.md`, and so on) containing a summary table and the detail of each finding with its status (open/excluded). Before dispatching its agents, `rbd-audit` records `git rev-parse HEAD`: the first line under the report title is `Audited commit: <full hash>`, followed by the branch and, when one exists, the PR/MR, so `git diff <hash>..HEAD` shows what changed since.

### FUNC-AUDIT-015
**Title:** Finding resolution with the user  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-014](functional.md#func-audit-014)  
**Description:** After report generation, `rbd-audit` works through each open finding with the user: direct fix or addition of a justified entry in `audits/exclusions.yml`.

### FUNC-AUDIT-017
**Title:** Since-last-audit mode by default, --full for the whole repository  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-014](functional.md#func-audit-014)  
**Description:** By default, `/rbd-audit` audits what changed since the latest report: it reads the `Audited commit:` hash of the latest report and gives both agents `git log <hash>..<audited>` and `git diff <hash>..<audited> -- requirements docs <code and test directories>`. The agents focus their checks on what changed; `audits/exclusions.yml` still applies to the whole history. `/rbd-audit --full` audits the whole repository instead. When there is no previous report, or the latest one has no `Audited commit:` line, the skill runs a full audit. The report header states the mode: `Mode: since <hash>` or `Mode: full`.

### FUNC-AUDIT-018
**Title:** Audit of a fixed commit  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-014](functional.md#func-audit-014)  
**Description:** The audit agents read the audited commit, not the working tree: `rbd-audit` creates a temporary detached `git worktree` at the recorded hash, gives its path to both agents as the project root, and removes it once both agents have returned. Git history commands of the agents run on that commit (`git log <hash>`), not on `--all`. Switching branches or editing files during the audit does not change what the agents read. The report is written to the `audits/` directory of the working tree.

### FUNC-AUDIT-019
**Title:** Findings grouped by cause, info items apart  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-014](functional.md#func-audit-014)  
**Description:** In its merge step, `rbd-audit` groups the agent entries that share a check and a cause into one finding that lists all their requirement IDs. Entries of severity `info` need no action: they go to an `Info (no action required)` section, unnumbered and without a status, and never block the next audit or a push. The report header states `N raw entries merged into M findings`.

### FUNC-AUDIT-020
**Title:** Finding status command  
**Status:** validated  
**Dependencies:** [FUNC-AUDIT-015](functional.md#func-audit-015)  
**Description:** `/rbd-audit status <n>[,<n>…] fixed|excluded [--ref <EXCLUSION-ID>]` sets the status of the listed findings of the latest report in both places: the summary table row and the `**Status:**` line of the finding. `excluded` requires `--ref`, whose ID must exist in `audits/exclusions.yml`; it is written as `**Exclusion ref:**`. After the update, the command checks that the table and the details agree for every finding and lists any mismatch. The pre-flight of [FUNC-AUDIT-001](functional.md#func-audit-001) runs the same agreement check and treats a mismatched finding as `open`.

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
**Description:** `rbd-review` verifies that every ID referenced in commit prefixes (`feat(ID)`, `tech(ID)`, etc., ranges expanded) corresponds to an existing requirement with a status the pre-push hook accepts ([FUNC-PUSH-002](functional.md#func-push-002)): `validated` or `deprecated`, or also `draft` for the prefixes of [CONF-DRAFT-001](configuration.md#conf-draft-001).

### FUNC-REVIEW-004
**Title:** R2 check — uncovered behaviors via inference  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** `rbd-review` analyzes diffs by inference to detect new behaviors in the code that are not referenced by any requirement. Any uncovered behavior generates an R2 finding.

### FUNC-REVIEW-005
**Title:** R3 check — commit prefix consistency  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** `rbd-review` verifies that all commits in the MR use a prefix the pre-push hook accepts: those of [TECH-FMT-001](technical.md#tech-fmt-001) and the project's extra prefixes ([CONF-PREFIX-001](configuration.md#conf-prefix-001)). An implementation commit's prefix must match the category of at least one ID it cites (`FUNC` → `feat`, `TECH` → `tech`, `PERF` → `perf`, `UI` → `ui`, `CONF` → `conf`, `PLAT` → `plat`). Any other commit generates an R3 finding.

### FUNC-REVIEW-006
**Title:** R4 check — test presence for each implementation commit  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** `rbd-review` verifies that every implementation commit (`feat/tech/perf/ui/conf/plat`(ID):) has a corresponding test commit (`test(ID):`, which may add a bench sheet) in the MR or in the branch history, except for a requirement whose `**Verification:**` is `build` or `inspection` ([FUNC-REQ-008](functional.md#func-req-008)).

### FUNC-REVIEW-007
**Title:** Review report generation  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-003](functional.md#func-review-003), [FUNC-REVIEW-004](functional.md#func-review-004), [FUNC-REVIEW-005](functional.md#func-review-005), [FUNC-REVIEW-006](functional.md#func-review-006)  
**Description:** `rbd-review` generates a report `audits/YYYY-MM-DD-review-<branch>.md` and emits the signal `REVIEW PASSED` or `REVIEW FAILED`. The first line under the report title is `Reviewed commit: <full hash>`, followed by the branch and the PR/MR.

---

## Pre-push Control (PUSH)

### FUNC-PUSH-001
**Title:** Block push if open audit findings exist  
**Status:** validated  
**Dependencies:** [TECH-HOOK-001](technical.md#tech-hook-001), [FUNC-AUDIT-014](functional.md#func-audit-014)  
**Description:** Before any `git push`, the hook checks the latest audit report: the last `audits/*-audit*.md` by file name, since reports are named `YYYY-MM-DD-audit.md` (file modification times change on checkout and say nothing). Review reports (`*-review-*.md`) are not audit reports and are ignored. Names are ordered by date, then by same-day suffix: `-audit.md` before `-audit-2.md`, and `-audit-2.md` before `-audit-10.md`. If any findings have status `open`, the push is blocked and the user is informed of the findings to resolve.

### FUNC-PUSH-002
**Title:** Commit alignment validation  
**Status:** validated  
**Dependencies:** [TECH-HOOK-001](technical.md#tech-hook-001), [TECH-FMT-001](technical.md#tech-fmt-001), [CONF-PREFIX-001](configuration.md#conf-prefix-001), [CONF-DRAFT-001](configuration.md#conf-draft-001)  
**Description:** The hook checks the commits about to be pushed: those not yet on the branch's remote tracking branch, or, when the branch has no upstream yet, those not present on the base branch. Commits already on the remote are never re-checked, since they cannot be fixed without rewriting published history. Merge commits are not checked either: git writes their message. For each checked commit: `prefix(ID):` format compliance (prefixes of [TECH-FMT-001](technical.md#tech-fmt-001) plus the project's extra prefixes of [CONF-PREFIX-001](configuration.md#conf-prefix-001)), existence of the ID in requirements with status `validated` (or `deprecated`, so the tests and code of a deprecated requirement can be removed; or `draft` for the prefixes of [CONF-DRAFT-001](configuration.md#conf-draft-001)), and absence of code file modifications outside a properly prefixed commit. A requirement ID is any `CATEGORY-...-NNN` whose category is one of `id_format.categories` in `.rbd/config.yml`. Commits with a prefix that needs an ID (`req`, `test`, `feat`, `tech`, `perf`, `ui`, `conf`, `plat`, `arch`) must cite at least one, and every ID they cite is checked, not only the first. A range `CATEGORY-...-NNN..MMM` (for example `FUNC-OREGON-001..015`) cites every ID from `NNN` to `MMM` with the same prefix and digit count, and each of them is checked. `req` commits are exempt from the existence check, since they create or delete requirements.

### FUNC-PUSH-003
**Title:** rbd-review safety net trigger when remote MR exists  
**Status:** validated  
**Dependencies:** [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** If a remote MR/PR exists for the current branch at push time, Phase 6 of the `rbd` skill triggers `rbd-review` for analysis. The pre-push hook does not: as a command script it cannot run a skill. This acts as a safety net for pushes made outside the RBD workflow, ensuring that any code reaching the remote is reviewed against requirements even when the developer did not go through the standard RBD cycle. If no MR exists yet, this step is skipped: the review runs at the first Phase 6 after the MR is opened, or on a manual `/rbd-review`.

### FUNC-PUSH-004
**Title:** Pre-push validation state caching via dotfile  
**Status:** deprecated  
**Dependencies:** [FUNC-PUSH-001](functional.md#func-push-001), [FUNC-PUSH-002](functional.md#func-push-002), [FUNC-PUSH-003](functional.md#func-push-003), [TECH-HOOK-001](technical.md#tech-hook-001)  
**Description:** After completing all pre-push checks successfully ([FUNC-PUSH-001](functional.md#func-push-001), [FUNC-PUSH-002](functional.md#func-push-002), [FUNC-PUSH-003](functional.md#func-push-003)), the orchestrator writes `.rbd/.push-validated` containing the output of `git rev-parse HEAD`. When the pre-push hook fires, it reads this file first: if the file exists and its content matches the current HEAD hash, the hook allows the push and deletes the file; if the file is absent or the hash does not match, the hook proceeds with the full check sequence. The file `.rbd/.push-validated` must be listed in `.gitignore` — it is ephemeral state and must never be committed. Deprecated: since the hook became a command script it runs in milliseconds, so the cache saved no time and could skip checks that changed between two pushes.

### FUNC-PUSH-005
**Title:** Warning for stacked PRs whose base is not the default branch  
**Status:** validated  
**Dependencies:** [FUNC-PUSH-003](functional.md#func-push-003), [FUNC-REVIEW-001](functional.md#func-review-001)  
**Description:** In Phase 6 of the `rbd` skill and in `/rbd-review`, when the PR/MR of the branch has a base that is not the repository's default branch, the user is warned: once the base PR is merged, this PR must be retargeted to the default branch, or its base branch deleted so the forge retargets it; otherwise it merges into a stale branch. The warning does not block. For a merged PR, `/rbd-review` also checks that its head commit is reachable from the default branch (`git merge-base --is-ancestor`) and reports it when it is not.

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
**Description:** `audit-traceability` verifies that every `PLAT-*` requirement with status `validated` has a `derives_from:` line in its requirement block referencing an existing FUNC or TECH requirement with status `validated`. Any PLAT requirement missing this line, or referencing a non-existent or deprecated ID, generates a T7 finding (traceability violation).

### FUNC-AUDIT-021
**Title:** T8 check — requirement ID links  
**Status:** validated  
**Dependencies:** [FUNC-LINKS-001](functional.md#func-links-001), [FUNC-AUDIT-002](functional.md#func-audit-002)  
**Description:** `audit-traceability` runs the check mode of `/rbd-links` on the audited tree. Every broken requirement anchor generates a T8 finding (error); every known requirement ID cited without a link generates a T8 finding (warning).

---

## Requirement Links (LINKS)

### FUNC-LINKS-001
**Title:** rbd-links skill links every cited requirement ID  
**Status:** validated  
**Dependencies:** [UI-DOC-001](ui.md#ui-doc-001)  
**Description:** `/rbd-links` runs `rbd_links.py` on the project. In apply mode it turns every bare requirement ID cited in `requirements/*.md` and `docs/architecture.md` into a link to its heading, with a path relative to the citing file (`[FUNC-X-001](functional.md#func-x-001)`, `[FUNC-X-001](../requirements/functional.md#func-x-001)`; the anchor is the lowercase ID). It leaves alone headings, fenced code, code spans, HTML comments, existing links, ID ranges and IDs with no heading. In check mode (`--check`) it changes nothing, lists every link whose target file has no heading for its ID and every bare known ID, and exits with status 1 when it finds any.

---

## Coverage Metrics (METRICS)

### FUNC-METRICS-001
**Title:** Coverage metrics report per category and subcategory  
**Status:** validated  
**Dependencies:** [CONF-IDLVL-001](configuration.md#conf-idlvl-001)  
**Description:** The `rbd-metrics` skill reads all requirement files and counts, per main category (FUNC, TECH, PERF, UI, CONF, PLAT) and per subcategory, the total number of validated requirements and how many have at least one `test(ID):` commit. Output is an ASCII structured list printed to stdout:

```text
FUNC  (12 validated)
├── AUTH    3 / 3  ████████████  100%
├── DATA    2 / 4  ██████░░░░░░   50%  ← 2 missing
└── PUSH    1 / 1  ████████████  100%
TECH  (4 validated)
└── TAG     4 / 4  ████████████  100%
```

Requirements whose only tagged test files are bench sheets count as covered, in `covered / total` and the percentage, and are also counted apart: their row shows `(N bench)` and the JSON gives a `bench` count.

No file is written. An optional `--json` flag exports the same data as a JSON object to stdout.

### FUNC-METRICS-002
**Title:** Opt-in req-to-green latency per requirement  
**Status:** validated  
**Dependencies:** [FUNC-METRICS-001](functional.md#func-metrics-001)  
**Description:** When invoked with the `--latency` flag, `rbd-metrics` traverses the git log to compute, for each validated requirement, the elapsed time between the `req(ID):` commit timestamp and the first `test(ID):` commit timestamp. Requirements with no test commit are shown as `pending`. Results are displayed as a latency column appended to the ASCII structured list produced by [FUNC-METRICS-001](functional.md#func-metrics-001). The computation is strictly read-only.

---

## Release (RELEASE)

### FUNC-RELEASE-001
**Title:** Release gate on bench sheets  
**Status:** validated  
**Dependencies:** [FUNC-TEST-007](functional.md#func-test-007)  
**Description:** `/rbd release <tag>` lists the bench sheets in the order of `bring-up.md`, each with its passing row (`Pass` is `yes` or `✅`) for `<tag>` or for the candidate commit (`HEAD`, written as its full hash or a prefix of at least 7 characters), and creates the tag on that commit only when every sheet has one. Otherwise it lists the sheets still to run and creates no tag. Bench results are recorded once per release, so outside this gate a missing result blocks nothing. Pushing the tag stays with the user.
