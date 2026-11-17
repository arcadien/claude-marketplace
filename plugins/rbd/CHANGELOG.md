# Changelog

## [0.16.0] - 2026-11-17

Feedback from using rbd 0.14.0 on tinySensor (#23–#38).

### Breaking

- `/rbd-audit` now audits what changed since the latest report (its `Audited commit:`); use `/rbd-audit --full` for the whole repository. Without a previous hash, it runs a full audit.

### Features

- feat(FUNC-AUDIT-014,FUNC-REVIEW-007,FUNC-AUDIT-017): audit and review reports record the audited commit; the report header states the mode (#23)
- feat(FUNC-AUDIT-018): audit agents read a temporary worktree at the audited commit (#24)
- feat(FUNC-AUDIT-019): findings grouped by check and cause, `info` items in their own section (#25)
- feat(FUNC-AUDIT-020): `/rbd-audit status <n> fixed|excluded [--ref ID]` updates table and details together (#26)
- feat(FUNC-AUDIT-014,FUNC-AUDIT-001): same-day reports named `-audit-2.md`…, latest by date then suffix (#27)
- feat(FUNC-REQ-008,FUNC-AUDIT-008,FUNC-AUDIT-010): `**Verification:**` field; T1/T3 skip the test for non-test verification (#28)
- feat(FUNC-TEST-006,FUNC-ORCH-003): `NO NATIVE TEST` signal routes to Phase 5 (#29)
- feat(FUNC-PUSH-002): audit-traceability and rbd-review expand ID ranges (#30)
- feat(FUNC-PUSH-005): warning for stacked PRs whose base is not the default branch (#31)
- feat(FUNC-AUDIT-009,FUNC-AUDIT-005): T2 warns on draft tags, C3 flags dependencies on draft (#32)
- feat(FUNC-AUDIT-011,FUNC-AUDIT-012): `accepted_prefixes:` per plan file for T4/T5 (#33)
- feat(FUNC-AUDIT-010): T3 recognises tag-only test commits (#34)
- feat(FUNC-ARCH-001,FUNC-AUDIT-007): traceability row follows the requirement text, C5 flags stale rows (#35)
- feat(FUNC-LINKS-001,FUNC-AUDIT-021,CONF-RULES-001): `/rbd-links` skill (`rbd_links.py`, apply and `--check`), T8 link check, optional `rules.non_technical_without_code` (#36)
- feat(FUNC-REQ-005): `User validation:` block relayed by the orchestrator (#37)
- feat(FUNC-ORCH-006): resume after an interrupted Phase 5, `Checks:` line in the implementation commit (#38)

### Fixes

- fix(FUNC-PUSH-001): pre-push hook orders same-day audit reports by their `-N` suffix
- fix(FUNC-PUSH-002): pre-push hook expands ID ranges and checks every ID in them
- fix(FUNC-LINKS-001): `rbd_links.py` matches IDs next to an underscore (italic)

### Tests

- New `tests/test_skill_agent_contracts.sh` (instruction contract cases) and `tests/test_func_links_001.sh`; hook cases for ranges and same-day ordering

### Configuration

- `.markdownlint.jsonc`: the linter of `.rbd/config.yml` passes; rules contradicting the plugin conventions are off, the rest is fixed
- README documents the pre-push hook timing and draft handling

## [0.15.0] - 2026-11-12

### Features

- req(CONF-DRAFT-001,FUNC-PUSH-002): prefixes listed in `draft_ok_prefixes` (`.rbd/config.yml`) may cite draft requirements
- fix(CONF-DRAFT-001): pre-push hook accepts draft requirements for those prefixes; without the key, nothing changes

### Tests

- test(CONF-DRAFT-001): `test(draft)` blocked without the key, accepted with `draft_ok_prefixes: [test]`; `feat(draft)`, unknown IDs and missing IDs still blocked

### Docs

- README lists the `draft_ok_prefixes` key; the Design section points to the requirements and architecture (spec file removed)

## [0.14.0] - 2026-11-06

### Breaking

- `req`, `test`, `feat`, `tech`, `perf`, `ui`, `conf`, `arch` commits without a requirement ID now block the push.
- The hook runs from the plugin (`${CLAUDE_PLUGIN_ROOT}`): delete the old copy `~/.claude/hooks/rbd-pre-push-check.sh`.
- Repositories without `.rbd/config.yml` are no longer checked.

### Fixes

- fix(FUNC-PUSH-001): pre-push hook picks the latest audit by file name
- fix(FUNC-PUSH-002): pre-push hook checks every cited ID of any category, with validated or deprecated status
- fix(FUNC-PUSH-004): remove the validation cache from hook, skill and gitignore
- fix(TECH-HOOK-001): run the pre-push hook from the plugin, drop the init copy step
- fix(FUNC-PUSH-002): pre-push hook skips merge commits
- fix(TECH-HOOK-001): pre-push hook writes the blocking reason to stderr
- fix(TECH-HOOK-002): pre-push hook checks the pushed repository and skips non-RBD repos
- fix(FUNC-PUSH-002,TECH-HOOK-001,CONF-PREFIX-001): pre-push hook checks only unpushed commits, detects git push anywhere, reads extra prefixes

### Tests

- test(FUNC-PUSH-001): latest audit is chosen by file name, not mtime
- test(FUNC-PUSH-002): deprecated requirement may be referenced
- test(FUNC-PUSH-002): requirement IDs of every category are checked
- test(FUNC-PUSH-004): remove the validation cache tests
- test(TECH-HOOK-001): hook runs from the plugin directory
- test(FUNC-PUSH-002): merge commits are not checked
- test(TECH-HOOK-001): blocking reason is written to stderr
- test(TECH-HOOK-002): hook checks the pushed repository, skips non-RBD repos, finds subdirectory projects
- test(FUNC-PUSH-002,TECH-HOOK-001,CONF-PREFIX-001): hook behaviour on throwaway repos

### Requirements and architecture

- arch(FUNC-PUSH-003): rbd-review is invoked by rbd Phase 6, the hook invokes nothing
- req(FUNC-PUSH-003,TECH-HOOK-001): rbd-review safety net belongs to Phase 6, not to the command hook
- req(FUNC-PUSH-001): latest audit is the last by file name
- req(FUNC-PUSH-002): deprecated requirements may still be referenced, to remove their tests and code
- req(FUNC-PUSH-004): deprecate instead of delete, per the RBD deletion convention
- req(FUNC-PUSH-002): every cited ID of any category is checked, ID-bearing prefixes must cite one
- arch(FUNC-PUSH-004): drop the validation cache from the architecture
- req(FUNC-PUSH-004): delete the pre-push validation cache, the command hook is instant
- req(TECH-HOOK-001): hook runs from the installed plugin, no copy at init
- req(FUNC-PUSH-002): merge commits are not checked
- req(TECH-HOOK-001): blocking reason goes to stderr
- req(TECH-HOOK-002): RBD project may live in a subdirectory of the repository
- req(TECH-HOOK-002): pre-push hook checks the repository being pushed, only in RBD projects
- req(FUNC-PUSH-002,TECH-HOOK-001,CONF-PREFIX-001): push gate checks only unpushed commits, detects git push anywhere, accepts project prefixes

### Documentation

- docs(FUNC-PUSH-003): skills say Phase 6 runs rbd-review, the hook runs the mechanical checks
- docs(TECH-HOOK-002): mark the single RBD project per repository as a shortcut
- docs(rbd): extra_commit_prefixes in .rbd/config.yml

## [0.13.1] - 2026-06-19

### Fixes

- fix(rbd): accept prefix: and prefix(ID): in VALID_PREFIX regex

### Documentation

- docs(rbd): fix markdown line breaks in requirement files
