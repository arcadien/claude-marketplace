# Contributing

## Repository layout

```text
plugins/
  <name>/
    plugin.json          ← version, name, description, author
    skills/              ← Claude Code skills (slash commands)
    agents/              ← subagent definitions
    hooks/               ← PreToolUse / PostToolUse hook scripts
    commands/            ← user-invokable commands
    requirements/        ← RBD requirement files
    tests/               ← integration test scripts
scripts/
  build-registry.ts      ← regenerates marketplace.json + registry.json
site/
  public/
    marketplace.json     ← served to /plugin installer (auto-generated)
```

## Plugin development workflow

Feature work follows the RBD workflow (`/rbd`). Each change originates from
a validated requirement; tests are written before implementation.

## Releasing a new plugin version

### When to bump

Bump the version in `plugin.json` whenever:

- A new skill, agent, hook, or command is added or removed.
- An existing skill or agent has behavior changes (not just wording).
- A bug fix that changes runtime behavior.

Do **not** bump for: requirement doc updates, test changes, architecture
doc updates, or wording-only edits that don't affect runtime behavior.

### Version scheme

`MAJOR.MINOR.PATCH` — follow semantic versioning:

- `PATCH` for backward-compatible bug fixes.
- `MINOR` for new skills / agents / hooks / commands.
- `MAJOR` for breaking changes to skill behavior or hook protocol.

### Steps (in order)

> **Order matters.** `build-registry.ts` reads `git rev-parse HEAD` to pin
> the SHA. Run it only after committing the version bump.

1. **Finish and merge** the feature PR to `main`.

2. **On `main`** (or a short-lived PR branch), edit
   `plugins/<name>/plugin.json`:

   ```json
   { "version": "X.Y.Z" }
   ```

3. **Commit** the version bump:

   ```text
   conf: bump <name> plugin version to X.Y.Z
   ```

4. **Rebuild the registry** from the repo root:

   ```bash
   npx ts-node scripts/build-registry.ts
   ```

   This updates:

   - `site/public/marketplace.json` — installer reads this
   - `site/src/data/registry.json`
   - `marketplace.json`
   - `.claude-plugin/marketplace.json`

   The SHA recorded in `marketplace.json` is the HEAD commit at the time
   `build-registry` runs. That commit must be on `main` (or the branch
   the installer will fetch from).

5. **Commit** the registry output:

   ```text
   conf: rebuild marketplace registry for vX.Y.Z
   ```

6. **Push / merge to `main`**.

7. **Verify**: run `/plugin` — the installer should report the new version.

### Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `/plugin` shows old version | Stale SHA | Re-run step 4 from `main` HEAD |
| New skill not callable | Version not bumped | Bump + rebuild (steps 2–5) |
| SHA on feature branch | Rebuilt before merge | Merge, then re-run step 4 |
