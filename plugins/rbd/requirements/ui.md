# UI Requirements

---

### UI-DOC-001

**Title:** Markdown hyperlinks for all requirement ID references in RBD documents

**Status:** validated

**Dependencies:** [FUNC-REQ-005](functional.md#func-req-005), [FUNC-ARCH-001](functional.md#func-arch-001)

**Description:** In every RBD-managed document, all requirement ID references must be Markdown hyperlinks, not bare strings: every requirement ID cited in `requirements/*.md` and `docs/architecture.md`, with the exceptions of [FUNC-LINKS-001](functional.md#func-links-001) (headings, code, ranges, IDs with no heading). Each ID links to its anchor in the appropriate requirements file, with a path relative to the citing file (e.g. `[FUNC-REQ-005](functional.md#func-req-005)` in `requirements/`, `[FUNC-REQ-005](../requirements/functional.md#func-req-005)` in `docs/architecture.md`).

### UI-DOC-002

**Title:** Markdown hyperlinks for derives_from references in PLAT requirements

**Status:** validated

**Dependencies:** [UI-DOC-001](ui.md#ui-doc-001), [CONF-PLAT-001](configuration.md#conf-plat-001)

**Description:** In every PLAT requirement block produced by `requirement-analyst`, the `derives_from:` field value must be a Markdown hyperlink pointing to the parent requirement's anchor in the appropriate requirements file (e.g. `[FUNC-DATA-001](functional.md#func-data-001)`). This extends the hyperlink convention of [UI-DOC-001](ui.md#ui-doc-001) to cover the PLAT-specific derivation link.

### UI-DOC-003

**Title:** Requirement fields as separate paragraphs

**Status:** validated

**Dependencies:** [FUNC-REQ-001](functional.md#func-req-001)

**Description:** In `requirements/*.md`, every field of a requirement block (`**Title:**`, `**Status:**`, `**Dependencies:**`, `**Verification:**`, `**Superseded by:**`, `derives_from:`, `**Description:**`, `**Examples:**`) starts its own line and is separated from the next field by a blank line, so that each renders as its own paragraph; a field line ends with neither trailing spaces nor `\`. `requirement-analyst` writes this layout. The pre-push hook, `rbd_links.py` and the audit agents find a field anywhere between the requirement's `###` heading and the next heading, never on a fixed line.
