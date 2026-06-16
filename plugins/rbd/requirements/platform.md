# Platform Requirements

---

Platform (PLAT) requirements are Platform-Specific Model (PSM) requirements in MDA terms: they specify HOW a PIM-level requirement (FUNC or TECH) is realized on a concrete technology target (protocol, library, runtime). Every PLAT requirement must carry a `derives_from:` frontmatter field referencing the parent FUNC or TECH requirement it realizes. PLAT requirements follow the same domain-based intermediate level convention as other categories (e.g. `PLAT-COMM-001`).

PLAT requirements are added by project-specific RBD cycles targeting a concrete deployment platform. No PLAT entries exist at the plugin level.
