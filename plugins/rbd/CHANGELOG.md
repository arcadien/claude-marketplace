# Changelog

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

