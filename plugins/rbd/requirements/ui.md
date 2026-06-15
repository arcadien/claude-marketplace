# UI Requirements

---

### UI-DOC-001
**Title:** Markdown hyperlinks for all requirement ID references in RBD documents
**Status:** validated
**Dependencies:** [FUNC-REQ-005](functional.md#func-req-005), [FUNC-ARCH-001](functional.md#func-arch-001)
**Description:** In every RBD-managed document produced by `requirement-analyst`, all requirement ID references must be Markdown hyperlinks, not bare strings. This applies to two locations: (1) the `Dependencies` field in `requirements/*.md` — each referenced ID links to its anchor in the appropriate requirements file (e.g. `[FUNC-REQ-005](functional.md#func-req-005)`); (2) the Requirement ID column in the traceability table in `docs/architecture.md` — each ID links to its anchor in the appropriate requirements file using a relative path (e.g. `[FUNC-REQ-005](../requirements/functional.md#func-req-005)`).
