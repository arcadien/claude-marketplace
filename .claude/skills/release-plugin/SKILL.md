---
name: release-plugin
description: >
  Release a new plugin version: bump plugin.json, rebuild the marketplace
  registry, and commit both. Invoke when the user says "release plugin",
  "bump version", "publish plugin", "update marketplace", or "new plugin
  version". Requires being on or merging to main first.
---

# Release Plugin

Follow these steps in order. The SHA recorded in `marketplace.json` is read
from `git rev-parse HEAD` at build time — order is critical.

## Pre-flight check

1. Confirm all feature PRs for this release are merged to `main`.
2. Confirm you are on `main` (or a release branch that merges to `main`
   immediately after).

   ```bash
   git branch --show-current
   git pull origin main
   ```

## Step 1 — Identify what changed

List plugins with unreleased changes since the last version bump:

```bash
git log --oneline \
  $(git describe --tags --abbrev=0 2>/dev/null || echo HEAD~20)..HEAD \
  -- plugins/
```

Read the current version of each changed plugin:

```bash
cat plugins/<name>/plugin.json
```

## Step 2 — Bump version in plugin.json

Edit `plugins/<name>/plugin.json` and increment the version:

- **PATCH** (`0.11.0` → `0.11.1`): bug fix, no new components.
- **MINOR** (`0.11.0` → `0.12.0`): new skill / agent / hook / command.
- **MAJOR** (`0.11.0` → `1.0.0`): breaking behavior or hook protocol change.

## Step 3 — Commit the version bump

```text
conf: bump <name> plugin version to X.Y.Z
```

Do NOT run `build-registry` yet — the SHA must point to this commit.

## Step 4 — Rebuild the marketplace registry

From the repository root:

```bash
npx ts-node scripts/build-registry.ts
```

This regenerates:

- `site/public/marketplace.json` — read by the `/plugin` installer
- `site/src/data/registry.json`
- `marketplace.json`
- `.claude-plugin/marketplace.json`

Confirm the version and SHA look correct:

```bash
node -e "
const d = require('./site/public/marketplace.json');
d.plugins.forEach(p =>
  console.log(p.name, p.version, p.source.sha?.slice(0, 12))
);
"
```

## Step 5 — Commit the registry output

Stage all four generated files and commit:

```text
conf: rebuild marketplace registry for vX.Y.Z
```

## Step 6 — Push and verify

```bash
git push origin main
```

Then run `/plugin` — the installer should report the new version.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `/plugin` shows old version | Stale SHA | Re-run steps 4–5 from `main` |
| New skill not callable | Version not bumped | Full steps 2–6 |
| SHA on feature branch | Rebuilt before merge | Merge, then re-run step 4 |
