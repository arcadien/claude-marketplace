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
6. Install the pre-push hook so RBD gates activate immediately:
   - Resolve the absolute path of this SKILL.md at runtime (the plugin cache path varies per install).
   - Derive the hook source path: `<skill-dir>/../../hooks/rbd-pre-push-check.sh`
     (i.e. two directories up from `skills/rbd/`, then into `hooks/`).
   - Run `mkdir -p ~/.claude/hooks` via Bash to ensure the directory exists.
   - Read the hook source file content using the Read tool.
   - Write that content to `~/.claude/hooks/rbd-pre-push-check.sh` using the Write tool.
     The Write tool always produces LF output, stripping any CRLF regardless of the cached
     file's encoding.
   - Run `chmod +x ~/.claude/hooks/rbd-pre-push-check.sh` via Bash.
7. Commit: `plan: init rbd project`

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
| `ARCH MISMATCH: <reason>` | Present two options to the user (see below). code-builder is blocked until the chosen option completes. |

### ARCH MISMATCH — two-option routing

When `code-builder` emits `ARCH MISMATCH`, present the user with exactly two choices:

- **Option (a) — Update architecture:** Re-dispatch `requirement-analyst` to update `docs/architecture.md` so that the missing component is declared. code-builder is not resumed until the architecture update is committed and the `requirement-analyst` returns successfully. Then re-dispatch `code-builder` with the same requirement.
- **Option (b) — Revise or split the requirement:** Re-dispatch `requirement-analyst` to revise the requirement scope or split it so that all planned files fit within declared components. After the updated or split requirement is validated, return to Phase 4 (test-builder) for the revised requirement before dispatching code-builder again.

In both cases, code-builder is gated: it must not be resumed until the selected option has completed.

---

## Phase 6 — Pre-Push Check

Run before any `git push`, automatically via the hook or manually.

### Validation state cache (`.rbd/.push-validated`)

Before running any check, read `.rbd/.push-validated`:

- **File present and HEAD hash matches:** The push was already fully validated for this commit. Allow the push immediately, delete `.rbd/.push-validated` (it is ephemeral one-time-use state), and skip the checks below.
- **File absent or HEAD hash does not match:** Proceed with the full check sequence below.

After all checks in steps 1–3 pass, write `.rbd/.push-validated` containing the output of `git rev-parse HEAD`. This caches the validated state so the next `git push` attempt for the same HEAD commit is instant.

> Note: `.rbd/.push-validated` is ephemeral state and must never be committed. It is listed in `.gitignore`.

### Full check sequence

1. Read the latest report in `audits/`. If any finding has status `open` → block the push. Tell the user which findings must be resolved first.
2. **Commit alignment check (mechanical):** List all commits on the current branch not present on the base branch. Verify:
   - Every `feat/tech/perf/ui/conf/arch/test` commit follows the `prefix(ID):` format.
   - Every referenced ID exists in `requirements/*.md` with status `validated`.
   - No code file was modified outside of a properly prefixed commit.
   Flag any violation and block the push until resolved.
3. **MR safety net (`rbd-review`):** This step is a fallback for cases where code was pushed to a remote branch *without* going through the RBD workflow. If a PR/MR already exists on GitHub/GitLab for this branch, invoke `rbd-review` against that MR. The review performs deep inference-based analysis (uncovered behaviors, category mismatches, missing tests) that goes beyond the mechanical check in step 2.
   - If no remote MR exists yet, skip this step — `rbd-review` will be triggered at merge time.
4. Report all issues. Block the push if any check in steps 1–2 fails.
5. If all checks pass → write `.rbd/.push-validated` with the HEAD commit hash, confirm and allow the push.

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
