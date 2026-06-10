---
name: rbd
description: Guides the user through the full requirement-based development (RBD) workflow. Invoke when starting work on any feature or change, creating or updating requirements, reviewing architecture, writing integration tests for a requirement, implementing code, or before pushing to remote. Also triggers automatically when .rbd/config.yml is missing. Responds to /rbd, /rbd-init, "new requirement", "I want to add", "start feature", "implement", "let's work on", "update architecture".
---

# RBD — Requirement-Based Development Workflow

Every code change must originate from a validated requirement. Traceability between requirements, tests, and code is mandatory.

This skill is the **orchestrator**. It does not perform requirement analysis, test writing, or code implementation directly — it delegates those to dedicated agents and routes their return signals.

## Entry Point

On invocation:
1. Check whether `.rbd/config.yml` exists in the project root.
2. If absent → run **Phase 1: Init** immediately (handled inline below).
3. If present → determine the current phase from context (last commit, pending files, user's stated intent) and resume from the right phase.
4. If the phase is ambiguous, ask the user what they want to work on.

---

## Phase 1 — Init

Run when `.rbd/config.yml` is missing, or on explicit `/rbd init`.

1. Ask: "What intermediate classification levels do you want in your requirement IDs?"
   - Explain: "For example, with levels `domain` and `feature`, IDs look like `FUNC-AUTH-LOGIN-001`. What levels make sense for your project?"
   - Show the resulting example ID as the conversation progresses.
2. Confirm the full format with the user. Show one example ID per category (FUNC, TECH, PERF, UI, CONF).
3. Ask: "What language and test framework will this project use?" (needed for test tagging). Offer to defer if the stack is not decided yet.
4. Ask: "What is the linter command for this project?" (e.g. `ruff check .`, `eslint .`, `golangci-lint run`).
5. Generate and write all files using schemas from `references/formats.md`.
6. Commit: `plan: init rbd project`

---

## Phase 2+3 — Requirement & Architecture

**Dispatch the `requirement-analyst` agent.**

Provide the agent with:
- The user's stated intent: new requirement, update to an existing requirement, or deletion.
- Full project context: all existing `requirements/*.md` files, current `docs/architecture.md`.

The agent handles everything: elicitation, challenge (size/overlap/consistency), user validation, commit, architecture coherence check, DI constraint capture, and architecture update.

**Route based on the agent's return signal:**

| Signal | Next action |
|--------|-------------|
| `REQUIREMENT VALIDATED: <ID>` | Proceed to Phase 4 with this ID. |
| `REQUIREMENT DELETED: <ID>` | Workflow cycle complete. Inform the user. |
| `SPLIT REQUIRED: <reason>` | The draft was already cleaned up by the agent. Re-dispatch requirement-analyst for each sub-requirement identified. |

---

## Phase 4 — Tests (TDD Red)

**Dispatch the `test-builder` agent.**

Provide the agent with:
- The validated requirement ID and its full description.
- The path to `.rbd/config.yml`.

The agent handles everything: test design, GWT structure, parametrized test conventions, user review, size check, hard gate (tag presence on every function), lint, and commit.

**Route based on the agent's return signal:**

| Signal | Next action |
|--------|-------------|
| `TESTS COMMITTED: test(<ID>): ...` | Proceed to Phase 5. |
| `TOO_LARGE: <reason>` | The requirement is too large to test coherently. Re-dispatch requirement-analyst for splitting. Provide the `TOO_LARGE` reason as context so the agent knows where to split. |

---

## Phase 5 — Implementation (TDD Green)

**Dispatch the `code-builder` agent.**

Provide the agent with:
- The validated requirement ID and its full description.
- The committed test files for this requirement.
- The linter command from `.rbd/config.yml`.

The agent handles everything: design pattern analysis (proposes alternatives to the user when choices are non-trivial), implementation, full test suite run, lint, and commit.

**Route based on the agent's return signal:**

| Signal | Next action |
|--------|-------------|
| `IMPLEMENTATION COMMITTED: <prefix>(<ID>): ...` | Proceed to Phase 6. |
| `SCOPE TOO WIDE: <reason>` | Ask the user: split the requirement (re-dispatch requirement-analyst) or proceed with a justified exception? |

---

## Phase 6 — Pre-Push Check

Run before any `git push`, automatically via the hook or manually.

1. Read the latest report in `audits/`. If any finding has status `open` → block the push. Tell the user which findings must be resolved first.
2. **Commit alignment check (mechanical):** List all commits on the current branch not present on the base branch. Verify:
   - Every `feat/tech/perf/ui/conf/arch/test` commit follows the `prefix(ID):` format.
   - Every referenced ID exists in `requirements/*.md` with status `validated`.
   - No code file was modified outside of a properly prefixed commit.
   Flag any violation and block the push until resolved.
3. **MR safety net (`rbd-review`):** This step is a fallback for cases where code was pushed to a remote branch *without* going through the RBD workflow. If a PR/MR already exists on GitHub/GitLab for this branch, invoke `rbd-review` against that MR. The review performs deep inference-based analysis (uncovered behaviors, category mismatches, missing tests) that goes beyond the mechanical check in step 2.
   - If no remote MR exists yet, skip this step — `rbd-review` will be triggered at merge time.
4. Report all issues. Block the push if any check in steps 1–2 fails.
5. If all checks pass → confirm and allow the push.

---

## Key Invariants

- No code behavior without a requirement.
- No requirement without tests (except `plan` and `arch` commits).
- No test without a requirement.
- **Every test function carries its requirement ID tag. Untagged tests block the commit.**
- No test written before architecture coherence is validated (Phase 3 gate — enforced by requirement-analyst).
- Every DI constraint has a TECH requirement.
- Every architecture update has an `arch(ID):` commit.
- Requirements are challenged for size, overlap, and consistency before any test is written.
- Linter must pass before every test commit and every implementation commit.
- Full test suite must be green before any implementation commit.
- Test files and production code files are strictly separated: test-builder writes tests, code-builder writes code. Neither agent touches the other's domain.
