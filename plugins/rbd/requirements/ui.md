# UI Requirements

---

### UI-DOC-001
**Title:** Markdown hyperlinks for all requirement ID references in RBD documents  
**Status:** validated  
**Dependencies:** [FUNC-REQ-005](functional.md#func-req-005), [FUNC-ARCH-001](functional.md#func-arch-001)  
**Description:** In every RBD-managed document produced by `requirement-analyst`, all requirement ID references must be Markdown hyperlinks, not bare strings. This applies to two locations: (1) the `Dependencies` field in `requirements/*.md` — each referenced ID links to its anchor in the appropriate requirements file (e.g. `[FUNC-REQ-005](functional.md#func-req-005)`); (2) the Requirement ID column in the traceability table in `docs/architecture.md` — each ID links to its anchor in the appropriate requirements file using a relative path (e.g. `[FUNC-REQ-005](../requirements/functional.md#func-req-005)`).

### UI-DOC-002
**Title:** Markdown hyperlinks for derives_from references in PLAT requirements  
**Status:** validated  
**Dependencies:** [UI-DOC-001](ui.md#ui-doc-001), [CONF-PLAT-001](configuration.md#conf-plat-001)  
**Description:** In every PLAT requirement block produced by `requirement-analyst`, the `derives_from:` field value must be a Markdown hyperlink pointing to the parent requirement's anchor in the appropriate requirements file (e.g. `[FUNC-DATA-001](functional.md#func-data-001)`). This extends the hyperlink convention of UI-DOC-001 to cover the PLAT-specific derivation link.
