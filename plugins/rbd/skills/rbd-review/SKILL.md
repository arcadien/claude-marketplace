---
name: rbd-review
description: "Reviews a GitHub or GitLab merge request from a requirements perspective. Two modes: (1) manual — user invokes /rbd-review with a MR number or URL to review a specific MR; (2) automatic — triggered by rbd Phase 6 (pre-push check) when a remote MR already exists for the branch, acting as a safety net for code pushed outside the RBD workflow. Responds to /rbd-review, 'review the MR', 'check the PR against requirements', 'validate the branch before merging', 'requirements review'."
---

# RBD Review

This skill performs a requirements-focused review of a GitHub or GitLab merge request.

## Two Modes

**Manual** — user provides a MR/PR number or URL:

- Fetch the diff via `gh pr diff <number>` (GitHub CLI) or GitLab API.
- This is the standard usage: review a MR before merging.

**Automatic** — invoked by `rbd` Phase 6 (pre-push check) with no MR reference:

- A remote MR already exists for the current branch, meaning code was likely pushed outside the RBD workflow.
- Diff the current branch against its base branch locally.
- Ask the user to confirm the base branch if ambiguous (default: `main` or `master`).

Proceed with the same analysis regardless of mode.
Before analysing, record the reviewed commit: `git rev-parse HEAD` in automatic mode, the PR head (`gh pr view <n> --json headRefOid`) in manual mode.

**Stacked PR warning (does not block):** compare the PR base (`gh pr view --json baseRefName`) with the default
branch (`gh repo view --json defaultBranchRef`). When they differ, warn: once the base PR is merged, retarget this PR
to the default branch or delete its base branch so the forge retargets it; otherwise it merges into a stale branch.

For a merged PR, check that its head commit reached the default branch:
`git merge-base --is-ancestor <head> origin/<default>`. If it did not, report it as a finding.

## Analysis

### Check R1: Requirement Coverage

- Extract all requirement IDs from commit messages on the branch (patterns: `feat(ID):`, `tech(ID):`, `perf(ID):`, `ui(ID):`, `conf(ID):`, `plat(ID):`, `arch(ID):`, `test(ID):`).
- Expand ID ranges: `FUNC-X-001..015` cites every ID from `FUNC-X-001` to `FUNC-X-015` (same digit count).
- For each extracted ID: verify the requirement exists in `requirements/*.md` with a status the pre-push hook accepts:
  `validated` or `deprecated`, or also `draft` when the commit prefix is listed in `draft_ok_prefixes` of
  `.rbd/config.yml`.
- Flag commits referencing non-existent requirements, or requirements with another status.

### Check R2: Uncovered Behaviors

- Read the full diff.
- Use inference to identify new behaviors introduced in the code that do not correspond to any requirement referenced in the branch commits.
- "New behavior" means: new public function, new API endpoint, new UI component, new business rule, or any observable change in system behavior.
- Flag each uncovered behavior with the file and approximate line range.

### Check R3: Commit Prefix Consistency

- Accepted prefixes are those of the pre-push hook: `req`, `test`, `feat`, `tech`, `perf`, `ui`, `conf`, `plat`,
  `arch`, `plan`, `chore`, `fix`, `docs`, `style`, `refactor`, and the `extra_commit_prefixes` of `.rbd/config.yml`.
  Flag any other prefix.
- An implementation commit's prefix matches the category of at least one ID it cites:
  - `FUNC-*` → must use `feat(ID):`
  - `TECH-*` → must use `tech(ID):`
  - `PERF-*` → must use `perf(ID):`
  - `UI-*` → must use `ui(ID):`
  - `CONF-*` → must use `conf(ID):`
  - `PLAT-*` → must use `plat(ID):`
  - Architecture updates → must use `arch(ID):` where ID is any validated requirement
- Flag mismatches. A multi-requirement commit is accepted when its prefix matches one of its IDs; note whether
  splitting was feasible.

### Check R4: Test Presence

- For every `feat/tech/perf/ui/conf/plat` commit, verify there is a corresponding `test(ID):` commit (it may add a bench
  sheet) on the branch or in its history.
- A requirement whose `**Verification:**` is `build` or `inspection` needs no test commit.
- Flag implementation commits without a matching test commit.

## Report

Save to `audits/YYYY-MM-DD-review-<branch-name>.md`.
Sanitize the branch name for the filename: replace every `/` with `-`
(e.g. `feature/login` → `feature-login`).

```markdown
# MR Review — <branch-name> — YYYY-MM-DD

Reviewed commit: <full hash> — branch `<branch>` — PR #<n>

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
(the `rbd` Phase 6 pre-push check) can decide whether to block the push:

- **Zero open findings:** `REVIEW PASSED: no findings.`
- **One or more open findings:** `REVIEW FAILED: N open finding(s). See audits/YYYY-MM-DD-review-<branch>.md.`

When called from Phase 6, a `REVIEW FAILED` outcome blocks the push.
The user must either resolve the findings or explicitly confirm they want to push anyway
(which requires an OVERRIDE entry in `audits/exclusions.yml`).
