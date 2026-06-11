# Technical Requirements

---

### TECH-HOOK-001
**Title:** PreToolUse Bash hook for git push interception
**Status:** validated
**Dependencies:** none
**Description:** The plugin registers a `PreToolUse` hook on Bash tool calls. The hook intercepts any command matching `git push` and runs the Phase 6 pre-push checks (audit findings, commit alignment, rbd-review safety net) before allowing or blocking the push.

### TECH-SEP-001
**Title:** test-builder must not modify production code
**Status:** validated
**Dependencies:** none
**Description:** The `test-builder` agent is strictly forbidden from writing to or editing any production code file. It may only create or modify files in the test directories. Any violation of this constraint invalidates the TDD Red phase.

### TECH-SEP-002
**Title:** code-builder must not modify test files
**Status:** validated
**Dependencies:** none
**Description:** The `code-builder` agent is strictly forbidden from writing to or editing any test file. It may only create or modify production code files. Any violation of this constraint invalidates the TDD Green phase.

### TECH-TAG-001
**Title:** Untagged test functions are a hard gate blocking commit
**Status:** validated
**Dependencies:** TECH-SEP-001
**Description:** The presence of a valid requirement ID tag on every test function is a hard gate enforced by `test-builder` before every test commit. Any test function missing its tag causes the commit to be rejected. This check is also enforced by `audit-traceability` (T6a).

### TECH-FMT-001
**Title:** Non-plan commits must follow the prefix(ID): format
**Status:** validated
**Dependencies:** none
**Description:** Every commit that modifies requirements, tests, production code, or architecture must follow the format `prefix(ID): <description>` where `prefix` is one of: req, test, feat, tech, perf, ui, conf, arch. Only `plan:` commits are exempt from the ID requirement.

### TECH-AUDIT-001
**Title:** Audit agents are strictly read-only
**Status:** validated
**Dependencies:** none
**Description:** The `audit-coherence` and `audit-traceability` agents must not write, edit, or delete any file. They only read requirement files, test files, commit history, and the architecture document, then return a JSON array of findings.

### TECH-AGENT-001
**Title:** Each phase is delegated to a dedicated agent
**Status:** validated
**Dependencies:** none
**Description:** The orchestrator skill (`rbd`) contains no domain logic. All business decisions (requirement elicitation, test design, implementation strategy, audit analysis) are performed by dedicated agents. The orchestrator is responsible only for context assembly and signal routing.
