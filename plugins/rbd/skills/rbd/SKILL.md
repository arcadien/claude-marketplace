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
2. Confirm the full format with the user. Show one example ID per category (FUNC, TECH, PERF, UI, CONF, PLAT).
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

When the user already validated the exact requirement text in this session, add to the dispatch prompt:

```text
User validation:
  words: "<the user's verbatim words>"
  text: |
    <the exact requirement block they validated>
```

The agent then commits it without a second round trip. Relay only a validation of that exact text; never paraphrase.

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

For a manual hardware check, the committed test file is a bench sheet (see `references/formats.md`).

The agent handles everything: test design, GWT structure, parametrized test conventions, user review, size check, hard gate (tag presence on every function), lint, and commit.

**Route based on the agent's return signal:**

| Signal | Next action |
|--------|-------------|
| `TESTS COMMITTED: test(<ID>): ...` | Proceed to Phase 5. |
| `NO NATIVE TEST: <reason>` | The requirement's verification is `build` or `inspection`. Proceed to Phase 5 and give code-builder the reason. |
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
| `ARCH MISMATCH: <reason>` | Present two options to the user (see below). code-builder is blocked until the chosen option completes. |

### Resume after an interrupted Phase 5

If code-builder ends without a return signal (API error, interruption), read `git log -1` and `git status`:

- The last commit is `<prefix>(<ID>):` for this requirement → the implementation is committed; proceed to Phase 6.
- Production files are modified but not committed → re-dispatch code-builder in resume mode, listing those files.
- Nothing changed → re-dispatch code-builder normally.

Never commit the partial work yourself: code-builder runs the gates (lint, full suite) before committing.

### ARCH MISMATCH — two-option routing

When `code-builder` emits `ARCH MISMATCH`, present the user with exactly two choices:

- **Option (a) — Update architecture:** Re-dispatch `requirement-analyst` to update `docs/architecture.md` so that the missing component is declared. code-builder is not resumed until the architecture update is committed and the `requirement-analyst` returns successfully. Then re-dispatch `code-builder` with the same requirement.
- **Option (b) — Revise or split the requirement:** Re-dispatch `requirement-analyst` to revise the requirement scope or split it so that all planned files fit within declared components. After the updated or split requirement is validated, return to Phase 4 (test-builder) for the revised requirement before dispatching code-builder again.

In both cases, code-builder is gated: it must not be resumed until the selected option has completed.

---

## Phase 6 — Pre-Push Check

Run before any `git push`. The pre-push hook runs steps 1 and 2 mechanically on every push; run this whole phase via `/rbd` before pushing a branch that already has a remote MR, since step 3 needs Claude.

### Full check sequence

1. Read the latest report in `audits/`. If any finding has status `open` → block the push. Tell the user which findings must be resolved first.
2. **Commit alignment check (mechanical):** List all commits on the current branch not present on the base branch. Verify:
   - Every `req/test/feat/tech/perf/ui/conf/arch` commit follows the `prefix(ID):` format.
   - Every referenced ID exists in `requirements/*.md` with status `validated` (or `deprecated`); `req` commits are not looked up.
   - Merge commits are skipped.
   - No code file was modified outside of a properly prefixed commit.
   Flag any violation and block the push until resolved.
3. **MR safety net (`rbd-review`):** This step is a fallback for cases where code was pushed to a remote branch *without* going through the RBD workflow. If a PR/MR already exists on GitHub/GitLab for this branch, invoke `rbd-review` against that MR. The review performs deep inference-based analysis (uncovered behaviors, category mismatches, missing tests) that goes beyond the mechanical check in step 2.
   - `REVIEW PASSED: …` → continue. `REVIEW FAILED: …` → block the push and show the review report.
   - If no remote MR exists yet, skip this step — `rbd-review` will be triggered at merge time.
   - **Stacked PR warning (does not block):** compare the PR base (`gh pr view --json baseRefName`) with the default
     branch (`gh repo view --json defaultBranchRef`). When they differ, warn: once the base PR is merged, retarget this PR
     to the default branch or delete its base branch so the forge retargets it; otherwise it merges into a stale branch.
4. Report all issues. Block the push if any check in steps 1–2 fails.
5. If all checks pass → confirm and allow the push.

---

## Release — `/rbd release <tag>`

Bench sheets are run by hand, once per release. Before creating a release tag:

1. Read the bench sheets (`test_tagging.bench_sheets` in `.rbd/config.yml`, default `tests/bench/*.md`) in the
   order of `bring-up.md`, then any sheet it does not list.
2. For each sheet, find a Results row whose `Release (tag / commit)` is `<tag>` or the candidate commit `HEAD`
   (its full hash, or a prefix of at least 7 characters) and whose `Pass` is `yes` or `✅`.
3. Print the list in that order, each sheet with its passing row or `missing`.
4. If a sheet is missing → stop: list the sheets still to run and creates no tag.
5. Otherwise run `git tag <tag> HEAD`. Pushing the tag stays with the user.

Without bench sheets, the gate passes. Outside this step, a missing bench result blocks nothing.

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
