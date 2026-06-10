# RBD — Requirement-Based Development

A Claude Code plugin that enforces a structured requirement-based development workflow.
Every code change originates from a validated requirement.
Traceability between requirements, tests, and code is mandatory and continuously audited.

## Goal

Most projects accumulate code whose origin no one can explain six months later.
RBD solves this by making the requirement the single source of truth for every change.

The core invariants are:

1. **No code without a requirement.** Every behavior committed to the codebase is traceable to a validated, written requirement.
2. **No requirement without tests.** Before any implementation begins, integration tests tagged with the requirement ID are committed (TDD red).
3. **No test without a requirement.** Orphan tests — tags that reference a non-existent ID — are a hard audit failure.
4. **Continuous auditability.** At any point, a full audit can verify that requirements, tests, and code form a coherent, gap-free chain.

The workflow is intentionally structured but lightweight:

- Requirements are discussed and challenged *before* tests or code are written, so splitting a bloated requirement never forces rework.
- The `plan:` commit type covers workflow-level changes (skills, config, requirements files) without dragging them into the TDD cycle — avoiding circular dependency.
- Audit findings block new audits until resolved, keeping technical debt visible and actionable.

The result is a codebase where every line of code has a traceable reason to exist.

## Skills

| Skill | Invoke | Purpose |
|-------|--------|---------|
| `rbd` | `/rbd` | Guided workflow: init, requirement discussion, TDD cycle, pre-push checks |
| `rbd-audit` | `/rbd-audit` | Full read-only audit with two parallel agents |
| `rbd-review` | `/rbd-review` | MR/PR review from a requirements perspective |

## Quick Start

1. Install this plugin in Claude Code.
2. In your project, invoke `/rbd` — it detects a missing config and guides you through initialization.
3. Whenever you want to add a feature or constraint: `/rbd` to start the workflow.
4. Before pushing: the pre-push hook runs automatically, or run Phase 6 (pre-push check) manually via `/rbd`.
5. For a periodic full audit: `/rbd-audit`.
6. Before merging a branch: `/rbd-review`.

## Project Structure Created on Init

```
.rbd/
  config.yml          # ID format, test tagging convention, linter command
  plan-files.yml      # workflow files monitored for plan: commit discipline

requirements/
  functional.md       # FUNC-* requirements
  technical.md        # TECH-* requirements
  performance.md      # PERF-* requirements
  ui.md               # UI-* requirements
  configuration.md    # CONF-* requirements

audits/
  exclusions.yml                     # justified audit exclusions
  YYYY-MM-DD-audit.md                # timestamped full audit reports
  YYYY-MM-DD-review-<branch>.md      # MR review reports
```

## Commit Convention

```
req(ID):   requirement validated and committed
test(ID):  integration tests committed (TDD red)
feat(ID):  functional requirement implemented
tech(ID):  technical requirement implemented
perf(ID):  performance requirement implemented
ui(ID):    UI requirement implemented
conf(ID):  configuration value set
arch(ID):  architecture document updated (ID = triggering requirement)
plan:      workflow file changed (no ID — no TDD cycle)

# Multi-requirement (avoid — suggest splitting)
feat: description
Requirements: ID-001, ID-002
```

## Requirement Categories

| Category | ID prefix | Commit prefix | Tests |
|----------|-----------|---------------|-------|
| Functional | FUNC-... | feat(ID): | required |
| Technical | TECH-... | tech(ID): | required |
| Performance | PERF-... | perf(ID): | required |
| UI | UI-... | ui(ID): | required |
| Configuration | CONF-... | conf(ID): | required |
| Plan | *(no file)* | plan: | none |

## Workflow Summary

```
Phase 1: Init         → .rbd/config.yml created, commit: plan: init rbd project
Phase 2: Requirement  → requirements/*.md updated, commit: req(ID): title
Phase 3: Architecture → docs/architecture.md updated, TECH reqs for DI,
                        commits: req(TECH-*): ... + arch(ID): update architecture
Phase 4: Tests        → tests written and tagged, linted, commit: test(ID): ...
Phase 5: Implement    → agent implements, full suite green, linted, commit: feat(ID): ...
Phase 6: Pre-push     → audit check + branch alignment + rbd-review if MR exists
```

## Design Spec

`docs/superpowers/specs/2026-05-27-rbd-workflow-design.md`
