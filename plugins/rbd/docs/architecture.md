# Architecture — RBD Plugin

_Last updated: 2026-06-15 — triggering requirement: FUNC-ANALYZE-003_

---

## Component Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│  Claude Code Plugin: RBD                                           │
│                                                                    │
│  Skills (entry points)          Agents (delegated logic)           │
│  ─────────────────────          ──────────────────────             │
│                                                                    │
│  ┌──────────────────┐           ┌─────────────────────────┐        │
│  │  rbd (ORCH)      │──────────▶│  init-agent (INIT)      │        │
│  │                  │           └─────────────────────────┘        │
│  │  - phase detect  │           ┌─────────────────────────┐        │
│  │  - signal route  │──────────▶│  requirement-analyst    │        │
│  │  - context assem │           │  (REQ + ARCH)           │        │
│  └──────────────────┘           └─────────────────────────┘        │
│                                 ┌─────────────────────────┐        │
│                                 │  test-builder (TEST)    │        │
│                          ───────▶                         │        │
│                                 └─────────────────────────┘        │
│                                 ┌─────────────────────────┐        │
│                                 │  code-builder (IMPL)    │        │
│                          ───────▶                         │        │
│                                 └─────────────────────────┘        │
│                                                                    │
│  ┌──────────────────┐           ┌─────────────────────────┐        │
│  │  rbd-audit       │──────────▶│  audit-coherence        │        │
│  │  (AUDIT skill)   │    ┌─────▶│  (read-only, C1–C5)     │        │
│  │                  │────┘      └─────────────────────────┘        │
│  │  - merge findings│           ┌─────────────────────────┐        │
│  │  - report gen    │──────────▶│  audit-traceability     │        │
│  │  - resolution    │           │  (read-only, T1–T6)     │        │
│  └──────────────────┘           └─────────────────────────┘        │
│                                                                    │
│  ┌──────────────────┐                                              │
│  │  rbd-review      │  (R1–R4 checks, report generation)          │
│  │  (REVIEW skill)  │                                              │
│  └──────────────────┘                                              │
│                                                                    │
│  ┌──────────────────┐           ┌─────────────────────────┐        │
│  │  rbd-analyze     │──────────▶│  arch-analyst           │        │
│  │  (ANALYZE skill) │           │  (read-only, diagrams)  │        │
│  │                  │           └─────────────────────────┘        │
│  │  - dispatch agent│                                              │
│  │  - report path   │                                              │
│  └──────────────────┘                                              │
│                                                                    │
│  ┌──────────────────┐                                              │
│  │  pre-push hook   │  (PreToolUse on Bash, git push intercept)   │
│  │  (PUSH)          │──▶ invokes rbd-review when remote MR exists │
│  └──────────────────┘                                              │
│                                                                    │
│  Shared data (filesystem)                                          │
│  ─────────────────────────                                         │
│  .rbd/config.yml          .rbd/plan-files.yml                      │
│  requirements/*.md        docs/architecture.md                     │
│  audits/*.md              audits/exclusions.yml                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## Component Descriptions

| Component | Type | Responsibilities |
|---|---|---|
| `rbd` | Skill / Orchestrator | Phase detection from config and git state; assembles context; routes agent return signals; no domain logic (TECH-AGENT-001) |
| `init-agent` | Agent | Negotiates ID format, language/framework, linter; generates all initial project files; performs initial commit |
| `requirement-analyst` | Agent | Requirement elicitation via dialogue; challenge (size, overlap, consistency); architecture coherence check; DI constraint identification; updates `docs/architecture.md` |
| `test-builder` | Agent | Generates integration tests in GWT structure; enforces requirement ID tags; runs linter before commit; emits `TOO_LARGE` signal; never touches production code |
| `code-builder` | Agent | Reads test contracts; proposes design alternatives; implements production code; runs full test suite and linter before commit; emits `SCOPE TOO WIDE` signal; never touches test files |
| `rbd-audit` | Skill | Dispatches `audit-coherence` and `audit-traceability` in parallel; merges and deduplicates findings; generates timestamped report; resolves findings with user |
| `audit-coherence` | Agent | Read-only; performs C1 (overlap), C2 (precision), C3 (dependency validity), C4 (circular deps), C5 (architecture coherence) checks |
| `audit-traceability` | Agent | Read-only; performs T1 (test coverage), T2 (tag validity), T3 (impl coverage), T4 (plan file coverage), T5 (architecture currency), T6 (test structure) checks |
| `rbd-review` | Skill | Triggered manually by MR/PR number or by pre-push hook; performs R1–R4 checks; generates review report; emits `REVIEW PASSED` or `REVIEW FAILED` |
| `pre-push hook` | Hook (PreToolUse) | Intercepts `git push` Bash calls; checks open audit findings; validates commit alignment; triggers `rbd-review` when remote MR exists |
| `rbd-analyze` | Skill | Dispatches `arch-analyst`; provides full project context (requirements, architecture, skill/agent files); confirms output path to the user |
| `arch-analyst` | Agent | Read-only; reads requirements, `docs/architecture.md`, and skill/agent definition files; produces `docs/analysis-YYYY-MM-DD.md` containing a Mermaid execution flow diagram and a Mermaid component decomposition diagram |

---

## Dependency Injection Map

No runtime DI bindings are required at this stage. The RBD plugin is a Claude Code plugin composed of skills (YAML entry points) and agents (YAML + prompt definitions). Component interactions happen through:

1. **Skill → Agent dispatch**: the orchestrator skill invokes agents by name with a context payload. No interface abstraction is needed at this layer — agent names are stable string identifiers in the plugin manifest.
2. **Agent → Filesystem**: all agents read/write shared state through the filesystem (requirement files, config, architecture doc). No injectable repository interface is needed.
3. **Hook → Skill invocation**: the pre-push hook invokes `rbd-review` by name. Same pattern as skill → agent.

If a future requirement introduces a component that depends on an external service (e.g. a GitHub/GitLab API client injected into `rbd-review`), a corresponding `TECH-*` DI constraint requirement will be created at that point.

---

## Requirement → Component Traceability

| Requirement ID | Title (abbreviated) | Component(s) |
|---|---|---|
| [FUNC-ORCH-001](../requirements/functional.md#func-orch-001) | Phase detection at invocation | `rbd` |
| [FUNC-ORCH-002](../requirements/functional.md#func-orch-002) | Ambiguous phase resolution | `rbd` |
| [FUNC-ORCH-003](../requirements/functional.md#func-orch-003) | Inter-phase routing via agent return signals | `rbd` |
| [FUNC-ORCH-004](../requirements/functional.md#func-orch-004) | Exclusive delegation to specialized agents | `rbd` |
| [FUNC-INIT-001](../requirements/functional.md#func-init-001) | Interactive ID format negotiation | `init-agent` |
| [FUNC-INIT-002](../requirements/functional.md#func-init-002) | Test framework and language elicitation | `init-agent` |
| [FUNC-INIT-003](../requirements/functional.md#func-init-003) | Linter command elicitation | `init-agent` |
| [FUNC-INIT-004](../requirements/functional.md#func-init-004) | Creation of all project files and initial commit | `init-agent` |
| [FUNC-REQ-001](../requirements/functional.md#func-req-001) | Requirement elicitation via dialogue | `requirement-analyst` |
| [FUNC-REQ-002](../requirements/functional.md#func-req-002) | Requirement size challenge | `requirement-analyst` |
| [FUNC-REQ-003](../requirements/functional.md#func-req-003) | Semantic overlap challenge | `requirement-analyst` |
| [FUNC-REQ-004](../requirements/functional.md#func-req-004) | Consistency challenge | `requirement-analyst` |
| [FUNC-REQ-005](../requirements/functional.md#func-req-005) | User validation before commit | `requirement-analyst` |
| [FUNC-REQ-006](../requirements/functional.md#func-req-006) | Requirement splitting when too large | `rbd` |
| [FUNC-REQ-007](../requirements/functional.md#func-req-007) | Requirement deletion | `requirement-analyst` |
| [FUNC-ARCH-001](../requirements/functional.md#func-arch-001) | Component assignment for each requirement | `requirement-analyst` |
| [FUNC-ARCH-002](../requirements/functional.md#func-arch-002) | DI constraint identification → TECH requirement | `requirement-analyst` |
| [FUNC-ARCH-003](../requirements/functional.md#func-arch-003) | docs/architecture.md update with arch(ID) commit | `requirement-analyst` |
| [FUNC-ARCH-004](../requirements/functional.md#func-arch-004) | Architecture coherence gate before tests | `requirement-analyst` |
| [FUNC-TEST-001](../requirements/functional.md#func-test-001) | Integration test generation with GWT structure | `test-builder` |
| [FUNC-TEST-002](../requirements/functional.md#func-test-002) | Mandatory requirement ID tag on every test function | `test-builder` |
| [FUNC-TEST-003](../requirements/functional.md#func-test-003) | Parametrized tests for multiple cases | `test-builder` |
| [FUNC-TEST-004](../requirements/functional.md#func-test-004) | TOO_LARGE signal when requirement is too large | `test-builder` |
| [FUNC-TEST-005](../requirements/functional.md#func-test-005) | Test file linting before commit | `test-builder` |
| [FUNC-IMPL-001](../requirements/functional.md#func-impl-001) | Design pattern analysis with alternative proposals | `code-builder` |
| [FUNC-IMPL-002](../requirements/functional.md#func-impl-002) | Production code implementation | `code-builder` |
| [FUNC-IMPL-003](../requirements/functional.md#func-impl-003) | Full test suite green gate before commit | `code-builder` |
| [FUNC-IMPL-004](../requirements/functional.md#func-impl-004) | Production code linting before commit | `code-builder` |
| [FUNC-IMPL-005](../requirements/functional.md#func-impl-005) | SCOPE TOO WIDE signal | `code-builder` |
| [FUNC-AUDIT-001](../requirements/functional.md#func-audit-001) | Block audit if open findings exist | `rbd-audit` |
| [FUNC-AUDIT-002](../requirements/functional.md#func-audit-002) | Parallel dispatch of coherence and traceability agents | `rbd-audit` |
| [FUNC-AUDIT-003](../requirements/functional.md#func-audit-003) | C1 check — semantic overlap | `audit-coherence` |
| [FUNC-AUDIT-004](../requirements/functional.md#func-audit-004) | C2 check — precision and testability | `audit-coherence` |
| [FUNC-AUDIT-005](../requirements/functional.md#func-audit-005) | C3 check — dependency validity | `audit-coherence` |
| [FUNC-AUDIT-006](../requirements/functional.md#func-audit-006) | C4 check — circular dependency detection | `audit-coherence` |
| [FUNC-AUDIT-007](../requirements/functional.md#func-audit-007) | C5 check — architecture coherence | `audit-coherence` |
| [FUNC-AUDIT-008](../requirements/functional.md#func-audit-008) | T1 check — test coverage per requirement | `audit-traceability` |
| [FUNC-AUDIT-009](../requirements/functional.md#func-audit-009) | T2 check — tag validity in tests | `audit-traceability` |
| [FUNC-AUDIT-010](../requirements/functional.md#func-audit-010) | T3 check — implementation coverage | `audit-traceability` |
| [FUNC-AUDIT-011](../requirements/functional.md#func-audit-011) | T4 check — plan file coverage | `audit-traceability` |
| [FUNC-AUDIT-012](../requirements/functional.md#func-audit-012) | T5 check — architecture document currency | `audit-traceability` |
| [FUNC-AUDIT-013](../requirements/functional.md#func-audit-013) | T6 check — test structure conventions | `audit-traceability` |
| [FUNC-AUDIT-014](../requirements/functional.md#func-audit-014) | Timestamped audit report generation | `rbd-audit` |
| [FUNC-AUDIT-015](../requirements/functional.md#func-audit-015) | Finding resolution with the user | `rbd-audit` |
| [FUNC-REVIEW-001](../requirements/functional.md#func-review-001) | Manual review trigger by MR number or URL | `rbd-review` |
| [FUNC-REVIEW-003](../requirements/functional.md#func-review-003) | R1 check — requirement coverage in commits | `rbd-review` |
| [FUNC-REVIEW-004](../requirements/functional.md#func-review-004) | R2 check — uncovered behaviors via inference | `rbd-review` |
| [FUNC-REVIEW-005](../requirements/functional.md#func-review-005) | R3 check — commit prefix consistency | `rbd-review` |
| [FUNC-REVIEW-006](../requirements/functional.md#func-review-006) | R4 check — test presence for each impl commit | `rbd-review` |
| [FUNC-REVIEW-007](../requirements/functional.md#func-review-007) | Review report generation | `rbd-review` |
| [FUNC-PUSH-001](../requirements/functional.md#func-push-001) | Block push if open audit findings exist | `pre-push hook` |
| [FUNC-PUSH-002](../requirements/functional.md#func-push-002) | Commit alignment validation | `pre-push hook` |
| [FUNC-PUSH-003](../requirements/functional.md#func-push-003) | rbd-review safety net trigger when remote MR exists | `pre-push hook` |
| [PERF-AUDIT-001](../requirements/performance.md#perf-audit-001) | Coherence and traceability audit agents run in parallel | `rbd-audit` |
| [TECH-HOOK-001](../requirements/technical.md#tech-hook-001) | PreToolUse Bash hook for git push interception | `pre-push hook` |
| [TECH-SEP-001](../requirements/technical.md#tech-sep-001) | test-builder must not modify production code | `test-builder` |
| [TECH-SEP-002](../requirements/technical.md#tech-sep-002) | code-builder must not modify test files | `code-builder` |
| [TECH-TAG-001](../requirements/technical.md#tech-tag-001) | Untagged test functions are a hard gate | `test-builder` |
| [TECH-FMT-001](../requirements/technical.md#tech-fmt-001) | Non-plan commits must follow prefix(ID): format | `pre-push hook`, `test-builder`, `code-builder` |
| [TECH-AUDIT-001](../requirements/technical.md#tech-audit-001) | Audit agents are strictly read-only | `audit-coherence`, `audit-traceability` |
| [TECH-AGENT-001](../requirements/technical.md#tech-agent-001) | Each phase is delegated to a dedicated agent | `rbd` |
| [CONF-IDLVL-001](../requirements/configuration.md#conf-idlvl-001) | Configurable intermediate ID classification levels | `init-agent`, `rbd` |
| [CONF-TAG-001](../requirements/configuration.md#conf-tag-001) | Configurable test tagging convention | `init-agent`, `test-builder` |
| [CONF-LINT-001](../requirements/configuration.md#conf-lint-001) | Configurable linter command per project | `init-agent`, `test-builder`, `code-builder` |
| [UI-DOC-001](../requirements/ui.md#ui-doc-001) | Markdown hyperlinks for all requirement ID references | `requirement-analyst` |
| [FUNC-ANALYZE-001](../requirements/functional.md#func-analyze-001) | rbd-analyze skill triggers the arch-analyst agent | `rbd-analyze` |
| [FUNC-ANALYZE-002](../requirements/functional.md#func-analyze-002) | arch-analyst generates a Mermaid execution flow diagram | `arch-analyst` |
| [FUNC-ANALYZE-003](../requirements/functional.md#func-analyze-003) | arch-analyst generates a Mermaid component decomposition diagram | `arch-analyst` |
