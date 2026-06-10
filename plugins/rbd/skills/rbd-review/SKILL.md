---
name: rbd-review
description: "Reviews a GitHub or GitLab merge request from a requirements perspective. Two modes: (1) manual — user invokes /rbd-review with a MR number or URL to review a specific MR; (2) automatic — triggered by the rbd pre-push hook when a remote MR already exists for the branch, acting as a safety net for code pushed outside the RBD workflow. Responds to /rbd-review, 'review the MR', 'check the PR against requirements', 'validate the branch before merging', 'requirements review'."
---

# RBD Review

This skill performs a requirements-focused review of a GitHub or GitLab merge request.

## Two Modes

**Manual** — user provides a MR/PR number or URL:
- Fetch the diff via `gh pr diff <number>` (GitHub CLI) or GitLab API.
- This is the standard usage: review a MR before merging.

**Automatic** — invoked by the rbd pre-push hook with no MR reference:
- A remote MR already exists for the current branch, meaning code was likely pushed outside the RBD workflow.
- Diff the current branch against its base branch locally.
- Ask the user to confirm the base branch if ambiguous (default: `main` or `master`).

Proceed with the same analysis regardless of mode.

## Analysis

### Check R1: Requirement Coverage

- Extract all requirement IDs from commit messages on the branch (patterns: `feat(ID):`, `tech(ID):`, `perf(ID):`, `ui(ID):`, `test(ID):`, `req(ID):`).
- For each extracted ID: verify the requirement exists in `requirements/*.md` with status `validated`.
- Flag commits referencing non-existent or non-validated requirements.

### Check R2: Uncovered Behaviors

- Read the full diff.
- Use inference to identify new behaviors introduced in the code that do not correspond to any requirement referenced in the branch commits.
- "New behavior" means: new public function, new API endpoint, new UI component, new business rule, or any observable change in system behavior.
- Flag each uncovered behavior with the file and approximate line range.

### Check R3: Commit Prefix Consistency

- Verify each commit prefix matches the category of the referenced requirement:
  - `FUNC-*` → must use `feat(ID):`
  - `TECH-*` → must use `tech(ID):`
  - `PERF-*` → must use `perf(ID):`
  - `UI-*` → must use `ui(ID):`
  - `CONF-*` → must use `conf(ID):`
  - Architecture updates → must use `arch(ID):` where ID is any validated requirement
- Flag mismatches.
- Flag multi-requirement commits and note whether splitting was feasible.

### Check R4: Test Presence

- For every `feat/tech/perf/ui/conf` commit, verify there is a corresponding `test(ID):` commit on the branch.
- Flag implementation commits without a matching test commit.

## Report

Save to `audits/YYYY-MM-DD-review-<branch-name>.md`.
Sanitize the branch name for the filename: replace every `/` with `-`
(e.g. `feature/login` → `feature-login`).

```markdown
# MR Review — <branch-name> — YYYY-MM-DD

## Summary

| # | Finding | Status |
|---|---------|--------|
| 1 | feat(FUNC-AUTH-001): no matching test commit on branch | open |
| 2 | New behavior in auth_middleware.py:L45 not covered by any requirement | open |

## Findings

### Finding 1
**Type:** Test presence (R4)
**Commit:** feat(FUNC-AUTH-001): implement login
**Issue:** No test(FUNC-AUTH-001) commit found on this branch.
**Status:** open

### Finding 2
**Type:** Uncovered behavior (R2)
**Location:** src/auth_middleware.py, lines 43–67
**Issue:** Rate limiting logic introduced with no corresponding requirement.
**Status:** open
```

Present the summary to the user. Process each open finding together. Do not modify code, tests, or requirements autonomously.

## Outcome Signal

After presenting the summary, emit one of the following outcome lines so the calling context
(the `rbd` Phase 6 pre-push check, or the pre-push hook) can decide whether to block the push:

- **Zero open findings:** `REVIEW PASSED: no findings.`
- **One or more open findings:** `REVIEW FAILED: N open finding(s). See audits/YYYY-MM-DD-review-<branch>.md.`

When called from the pre-push hook, a `REVIEW FAILED` outcome blocks the push.
The user must either resolve the findings or explicitly confirm they want to push anyway
(which requires an OVERRIDE entry in `audits/exclusions.yml`, per the hook's OVERRIDE policy).
