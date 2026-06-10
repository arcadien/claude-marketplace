# Audit Checklist

Used by the two parallel audit agents. Each agent executes its section and returns a JSON array of findings.

---

## Agent 1 — Traceability

### Check T1: Test Coverage per Requirement

For each requirement with status `validated` in `requirements/functional.md`, `technical.md`, `performance.md`, `ui.md`, `configuration.md`:
- Read all test files in the project.
- Search for the tagging pattern from `.rbd/config.yml` (e.g. `@pytest.mark.req('ID')`).
- If no test file contains a tag matching this requirement ID → flag as finding.

Note: `deprecated` and `draft` requirements are excluded. Deprecated requirements may have been intentionally decommissioned; draft requirements have not yet reached the test phase.

```json
{
  "type": "traceability",
  "check": "T1-test-coverage",
  "requirement_id": "FUNC-AUTH-LOGIN-001",
  "issue": "No test tagged with FUNC-AUTH-LOGIN-001 was found.",
  "severity": "error"
}
```

### Check T2: Tag Validity

For every test tag found across all test files:
- Extract the requirement ID from the tag.
- Verify the ID exists in `requirements/*.md`.
- If the ID does not exist → flag as finding.

```json
{
  "type": "traceability",
  "check": "T2-tag-validity",
  "test_file": "tests/test_auth.py",
  "tag_value": "FUNC-AUTH-LOGOUT-999",
  "issue": "Test tag references non-existent requirement FUNC-AUTH-LOGOUT-999.",
  "severity": "error"
}
```

### Check T3: Implementation Coverage

For each validated requirement (status: `validated`):
- Check git log for a commit matching `feat(ID):`, `tech(ID):`, `perf(ID):`, `ui(ID):`, or `conf(ID):`.
- Check git log for a commit matching `test(ID):`.
- States to flag:
  - `test(ID):` commit exists but no implementation commit → "tests committed, implementation missing"
  - Implementation commit exists but no `test(ID):` commit → "implementation committed, tests missing"

Note: for `CONF-*` requirements, the implementation commit is `conf(ID):` and tests verify the actual configured value is applied (e.g., assert timeout == 30).
  - Neither exists (but requirement is validated) → "no test and no implementation"

```json
{
  "type": "traceability",
  "check": "T3-implementation-coverage",
  "requirement_id": "FUNC-AUTH-LOGIN-001",
  "issue": "test(FUNC-AUTH-LOGIN-001) commit found but no feat(FUNC-AUTH-LOGIN-001) commit.",
  "severity": "error"
}
```

### Check T4: Plan File Coverage

Read `.rbd/plan-files.yml`. For each listed file:
- Check git log for any commit that modified this file.
- Verify that a `plan:` commit exists covering that modification.
- If a plan file was modified without a `plan:` commit → flag.

```json
{
  "type": "traceability",
  "check": "T4-plan-file-coverage",
  "file": ".rbd/config.yml",
  "issue": ".rbd/config.yml was modified in commit abc1234 but no plan: commit covers this change.",
  "severity": "warning"
}
```

### Check T5: Architecture Document Currency

Read `docs/architecture.md`. If absent → flag as error.

**T5a — Requirement traceability coverage:**
For each validated requirement across all category files:
- Verify it appears in the "Requirement → Component Traceability" table.
- If missing → flag as finding.

**T5b — DI Map requirement coverage:**
For each entry in the "Dependency Injection Map":
- Verify a corresponding `TECH-*` requirement exists in `requirements/technical.md` with status `validated`.
- If missing → flag as finding.

**T5c — Architecture commit coverage:**
- Run `git log --oneline -- docs/architecture.md` to get all commits that modified the file.
- For each such commit: verify it starts with `arch(` followed by a valid requirement ID and `)`.
- If a modification commit does not use the `arch(ID):` format → flag as finding.

```json
{
  "type": "traceability",
  "check": "T5-architecture-currency",
  "requirement_id": "FUNC-AUTH-001",
  "issue": "FUNC-AUTH-001 is validated but does not appear in docs/architecture.md traceability table.",
  "severity": "error"
}
```

### Check T6: Test Structure Conventions

For every test function in the project:

**T6a — Tag coverage (error):**
- Verify the requirement tag is present (pattern from `.rbd/config.yml`).
- If missing → flag as error.

**T6b — Given/When/Then structure (warning):**
- Check for the presence of `# Given`, `# When`, `# Then` comment markers (or language-equivalent: `// Given`, etc.).
- If any section is missing → flag as warning.

**T6c — Parametrize opportunity (warning, inference-based):**
- Use inference to detect groups of test functions that share the same structure and differ only in inputs/outputs.
- If 2+ such functions exist and are not already parametrized → flag as warning, suggest merging into a parametrized test.

Note: T6a and T6b are enforced as hard gates by the test-builder agent at commit time. The audit re-checks them as a backstop for tests written outside the RBD workflow. T6c is advisory and inference-based — it is only evaluated during the audit, not at commit time.

```json
{
  "type": "traceability",
  "check": "T6-test-tag-coverage",
  "test_file": "tests/test_auth.py",
  "function": "test_login_invalid_password",
  "issue": "test_login_invalid_password has no requirement tag.",
  "severity": "error"
}
```

---

## Agent 2 — Coherence

### Check C1: Semantic Overlap

Read all requirements across all category files. Compare pairs using inference.
- Flag pairs where the two requirements describe the same behavior or overlapping behaviors that could be merged or where the boundary is unclear.
- Do not flag requirements that are intentionally related (parent/child) if the distinction is clear.

```json
{
  "type": "coherence",
  "check": "C1-overlap",
  "requirement_ids": ["FUNC-AUTH-001", "FUNC-AUTH-002"],
  "issue": "Both requirements describe the standard user authentication flow. The distinction between them is not clear from the descriptions.",
  "severity": "warning"
}
```

### Check C2: Precision and Testability

For each requirement, evaluate via inference:
- Is the requirement precise enough to write unambiguous tests?
- Does it contain vague language ("should be fast", "user-friendly", "as needed")?
- Could two developers write substantially different implementations from this requirement?
- If yes to any → flag.

```json
{
  "type": "coherence",
  "check": "C2-precision",
  "requirement_id": "PERF-API-001",
  "issue": "The requirement states 'the API should respond quickly' without specifying a measurable threshold.",
  "severity": "warning"
}
```

### Check C3: Dependency Validity

For each requirement with a `Dependencies:` field:
- Verify each referenced ID exists in `requirements/*.md`.
- If a dependency ID does not exist → flag.

```json
{
  "type": "coherence",
  "check": "C3-dependency-validity",
  "requirement_id": "FUNC-AUTH-LOGIN-001",
  "missing_dependency": "TECH-DB-999",
  "issue": "FUNC-AUTH-LOGIN-001 depends on TECH-DB-999 which does not exist.",
  "severity": "error"
}
```

### Check C4: Circular Dependencies

Build the dependency graph from all requirements. Detect cycles.
- If a cycle is found → flag all requirements in the cycle.

```json
{
  "type": "coherence",
  "check": "C4-circular-dependency",
  "cycle": ["FUNC-A-001", "FUNC-B-001", "FUNC-A-001"],
  "issue": "Circular dependency detected: FUNC-A-001 → FUNC-B-001 → FUNC-A-001.",
  "severity": "error"
}
```

### Check C5: Architecture Coherence

Read `docs/architecture.md`. For each validated requirement:
- Use inference to determine whether the requirement is consistent with the component responsible for it in the architecture (per the traceability table).
- Flag cases where a requirement describes behavior that clearly does not belong in the assigned component (responsibility mismatch).
- Flag components in the DI Map that receive a concrete class instead of an interface (detectable from the "Interface" column being blank or identical to the concrete type).

```json
{
  "type": "coherence",
  "check": "C5-architecture-coherence",
  "requirement_id": "FUNC-AUTH-001",
  "issue": "FUNC-AUTH-001 is assigned to DatabaseService but describes user-facing authentication behavior — likely belongs in AuthService.",
  "severity": "warning"
}
```

---

## Output Format

Each agent returns a JSON array. Return `[]` if no issues are found.

```json
[
  {
    "type": "traceability" | "coherence",
    "check": "<check-id>",
    "requirement_id": "...",          // single requirement (omit if not applicable)
    "requirement_ids": ["...", "..."],// multiple requirements (omit if not applicable)
    "issue": "Plain English description of the problem.",
    "severity": "error" | "warning"
  }
]
```
