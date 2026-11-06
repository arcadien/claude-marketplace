# Technical Requirements

---

### TECH-HOOK-001
**Title:** PreToolUse Bash hook for git push interception  
**Status:** validated  
**Dependencies:** none  
**Description:** The plugin registers a `PreToolUse` hook on Bash tool calls in its `hooks/hooks.json`, running the script from the installed plugin (`${CLAUDE_PLUGIN_ROOT}/hooks/`), so it follows plugin updates and needs no copy at init. The hook intercepts any command that runs `git push`, wherever it appears in the command line (for example after `cd dir &&` or `;`), and only those: text that merely contains the words, such as an `echo` argument or a commit message, does not trigger it. It runs the mechanical Phase 6 checks (audit findings, commit alignment) before allowing or blocking the push; the rbd-review safety net needs Claude and stays in Phase 6 of the `rbd` skill. When it blocks, it exits with code 2 and writes the reason to stderr, the only channel Claude Code shows for a blocking hook.

### TECH-HOOK-002
**Title:** Pre-push hook checks the repository being pushed, only when it is an RBD project  
**Status:** validated  
**Dependencies:** [TECH-HOOK-001](technical.md#tech-hook-001)  
**Description:** The hook runs its checks on the repository the push targets, not on the session's starting directory. The target is the `<dir>` of `git -C <dir> push`, otherwise of the last `cd <dir>` before `git push`, otherwise the `cwd` of the PreToolUse payload; a relative `<dir>` is resolved against that `cwd`. The RBD project is the directory holding `.rbd/config.yml`: the repository root, or else the first subdirectory with a tracked `.rbd/config.yml` (monorepo, such as a marketplace of plugins); its `requirements/`, `audits/` and config are the ones used by the checks. When the target is not inside a git repository, or the repository holds no RBD project, the push is allowed without any check.

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
**Dependencies:** [TECH-SEP-001](technical.md#tech-sep-001)  
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

### TECH-ANALYST-001
**Title:** arch-analyst write access limited to its output document  
**Status:** validated  
**Dependencies:** none  
**Description:** The `arch-analyst` agent must not write, edit, or delete any requirement file (`requirements/*.md`), the architecture document (`docs/architecture.md`), or any source code file of the target project. Its only permitted write operation is creating or overwriting its output document at `docs/analysis-YYYY-MM-DD.md`.
