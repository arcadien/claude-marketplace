---
name: rbd-audit
description: Runs a full read-only audit of the requirement-based development state. Invoke when the user types /rbd-audit, asks to "audit the codebase", "check requirements coverage", "run rbd audit", or "is everything aligned". Dispatches two parallel agents — one for traceability (requirements vs tests and code), one for requirement coherence (overlaps, precision, dependencies). Produces a timestamped report in audits/.
---

# RBD Audit

This skill is **read-only**. It never modifies code, tests, or requirements.
It produces a Markdown report. The user processes each finding together with Claude.

## Pre-Flight Check

Before running a new audit:
1. List all files in `audits/` and find the most recent report (highest date in filename).
2. If the latest report contains any finding with status `open` → **block the audit**.
   - Tell the user: "The previous audit from [date] has [N] open finding(s). Resolve them before running a new audit."
   - List the open findings from the previous report.
3. Load `audits/exclusions.yml`. Keep this in context for the merge step.

## Dispatch Parallel Agents

Launch both agents simultaneously using the Agent tool.
These are named Claude Code agents installed at `.claude/agents/`:

- **`audit-traceability`** (`agent file: .claude/agents/audit-traceability.md`) — checks requirements vs tests and commits
- **`audit-coherence`** (`agent file: .claude/agents/audit-coherence.md`) — checks requirements against each other

Invoke each with `subagent_type: "claude"` and use the agent file's content as the prompt,
or dispatch by agent name if your Claude Code version supports named agent dispatch.
Pass the current working directory as context so the agents can locate project files.

Wait for both to complete. Collect their JSON finding arrays.
If an agent returns non-JSON output or fails, treat it as zero findings and add a warning
to the report header: "Agent <name> failed to return valid output."

## Merge and Deduplicate Findings

1. Combine findings from both agents into a single list.
2. Assign a sequential finding number to each (1, 2, 3…).
3. Cross-reference with `audits/exclusions.yml`: for each finding, check if an exclusion entry matches (by requirement ID(s) and issue description). If a match exists → set status to `excluded` and add the exclusion ref.
4. All remaining findings start with status `open`.

## Write the Report

Save to `audits/YYYY-MM-DD-audit.md` using today's date.

```markdown
# Audit Report — YYYY-MM-DD

## Summary

| # | Finding | Status |
|---|---------|--------|
| 1 | FUNC-AUTH-LOGIN-001 has no associated test | open |
| 2 | FUNC-AUTH-001 and FUNC-AUTH-002 overlap semantically | excluded |

## Findings

### Finding 1
**Type:** Traceability — test coverage
**Requirement:** FUNC-AUTH-LOGIN-001
**Issue:** No test tagged with this requirement ID was found in the test files.
**Status:** open

### Finding 2
**Type:** Coherence — semantic overlap
**Requirements:** FUNC-AUTH-001, FUNC-AUTH-002
**Issue:** Both requirements describe overlapping authentication behaviors.
**Status:** excluded
**Exclusion ref:** AUTH-OVERLAP-001
```

## Post-Audit: Process Findings With the User

Present the summary table. For each `open` finding:
1. Explain the issue in plain language.
2. Offer two options:
   - **Fix** — work on the issue together (add missing tests, clarify requirement, etc.).
     Once the fix is confirmed, update the finding's `**Status:**` field in the report file
     from `open` to `fixed`, and update its row in the summary table accordingly.
   - **Exclude** — add an entry to `audits/exclusions.yml` with a required justification,
     then update the finding's status to `excluded` in the report file.
3. Never modify code, tests, or requirements autonomously. Act only with explicit user direction.

All findings must reach `fixed` or `excluded` status before this audit is considered complete.
