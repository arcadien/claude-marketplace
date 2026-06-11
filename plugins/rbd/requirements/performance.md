# Performance Requirements

---

### PERF-AUDIT-001
**Title:** Coherence and traceability audit agents run in parallel
**Status:** validated
**Dependencies:** TECH-AUDIT-001
**Description:** The `rbd-audit` skill must dispatch `audit-coherence` and `audit-traceability` as concurrent agents, not sequentially. Both agents operate on read-only data with no shared state, making parallel execution safe and expected.
