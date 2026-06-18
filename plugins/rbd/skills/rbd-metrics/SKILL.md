---
name: rbd-metrics
description: >
  Computes requirement coverage metrics per category and subcategory.
  Invoke when the user types /rbd-metrics, asks for "coverage metrics",
  "how many requirements are tested", or "show me the metrics".
  Reads all requirement files and git log, then prints an ASCII structured
  report to stdout. Supports --json flag. Never writes any file.
---

# RBD Metrics

This skill is **read-only**. It never modifies code, tests, requirements,
or any other file. All output goes to **stdout only**. No file is written.

## Purpose

Compute and display test-coverage metrics for validated requirements,
grouped by category and subcategory. Coverage is determined by scanning
git log for `test(ID):` commit messages.

## Step 1 — Read Requirement Files

Read all `requirements/*.md` files. For each requirement entry found:

- Extract the requirement ID (e.g. `FUNC-AUTH-001`).
- Extract the `status:` field.
- Keep only requirements whose `status: validated`. Draft, proposed, and
  deprecated requirements are excluded from all counts.
- Parse the category (first segment: `FUNC`, `TECH`, `PERF`, `UI`, `CONF`,
  `PLAT`) and subcategory (second segment, e.g. `AUTH`, `DATA`, `PUSH`)
  from each validated requirement ID.

## Step 2 — Scan Git Log for test Commits

Run `git log --oneline` and search commit messages for `test(ID):`.
For each validated requirement, record whether at least one matching
`test(REQUIREMENT-ID):` commit exists. This is the "covered" flag.

## Step 3 — Aggregate Counts

Group validated requirements by category, then by subcategory:

- **Total**: number of validated requirements in the subcategory.
- **Covered**: number with at least one `test(ID):` commit in git log.
- **Missing**: total minus covered (used for the "N missing" annotation).

## Step 4 — Print ASCII Structured Report

Output an ASCII tree to stdout using tree-drawing characters
(`├──` and `└──`):

```text
FUNC  (12 validated)
├── AUTH    3 / 3  ████████████  100%
├── DATA    2 / 4  ██████░░░░░░   50%  ← 2 missing
└── PUSH    1 / 1  ████████████  100%
TECH  (4 validated)
└── TAG     4 / 4  ████████████  100%
```

Each subcategory line includes:

- **Subcategory label** (left-aligned).
- **covered / total** fraction.
- **Block-character progress bar**: filled block characters (`█`) for
  covered requirements and empty block characters (`░`) for uncovered
  ones. The bar is 12 characters wide, proportional to coverage.
- **Percentage** derived from covered / total (e.g. `100%`, `50%`).
- **"N missing" annotation** (prefixed with `←`) when coverage is below
  100%, indicating how many requirements still lack a `test(ID):` commit.

Categories with zero validated requirements are omitted.
Subcategories are listed in alphabetical order within each category.

## Step 5 — --json Flag

When the `--json` flag is passed, emit the same data as a JSON object to
stdout instead of the ASCII report. The JSON output contains equivalent
information for every category and subcategory: validated total, covered
count, missing count, and percentage. Example structure:

```json
{
  "FUNC": {
    "total_validated": 12,
    "subcategories": {
      "AUTH": { "total": 3, "covered": 3, "missing": 0, "percent": 100 },
      "DATA": { "total": 4, "covered": 2, "missing": 2, "percent": 50 }
    }
  }
}
```

The JSON output and the ASCII report are always equivalent representations
of the same data.

## Invocation

```text
/rbd-metrics           # ASCII structured list to stdout
/rbd-metrics --json    # JSON object to stdout (same data, machine-readable)
```

## Constraints

- **Read-only**: this skill never writes, modifies, or deletes any file.
- **Stdout only**: all output is printed to stdout. No file is written.
- Only requirements with `status: validated` are counted.
- Categories recognized: `FUNC`, `TECH`, `PERF`, `UI`, `CONF`, `PLAT`.
- The skill reads the requirements directory on every invocation (no
  caching).
