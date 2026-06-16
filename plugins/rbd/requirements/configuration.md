# Configuration Requirements

---

### CONF-IDLVL-001
**Title:** Configurable intermediate ID classification levels
**Status:** validated
**Dependencies:** none
**Description:** The ID format must support zero or more intermediate classification levels between the category prefix and the sequence number (e.g. with levels `["domain", "feature"]`, IDs look like `FUNC-AUTH-LOGIN-001`). Levels are negotiated interactively during Phase 1 and stored in `.rbd/config.yml`.

### CONF-TAG-001
**Title:** Configurable test tagging convention per language and framework
**Status:** validated
**Dependencies:** none
**Description:** The test tagging convention (decorator, comment, or annotation syntax) is configurable per project and stored in `.rbd/config.yml`. The `{id}` placeholder in the convention string is replaced with the requirement ID at test generation time. The language and convention are negotiated during Phase 1.

### CONF-LINT-001
**Title:** Configurable linter command per project
**Status:** validated
**Dependencies:** none
**Description:** The linting command is configurable per project and stored in `.rbd/config.yml`. It is used by both `test-builder` (before test commits) and `code-builder` (before implementation commits). The command is elicited during Phase 1.

### CONF-PLAT-001
**Title:** PLAT as a recognized requirement category in config
**Status:** validated
**Dependencies:** [CONF-IDLVL-001](configuration.md#conf-idlvl-001)
**Description:** The `.rbd/config.yml` categories list must include `PLAT` alongside `FUNC`, `TECH`, `PERF`, `UI`, and `CONF`. The `PLAT` category designates Platform-Specific Model (PSM) requirements in MDA terms: behavioral requirements that specify HOW a PIM requirement (FUNC or TECH) is realized on a concrete technology target (protocol, library, runtime). PLAT requirements use the same domain-based intermediate level convention as other categories (e.g. `PLAT-COMM-001`). The `init-agent` must present `PLAT` as an available category during Phase 1 ID format negotiation.
