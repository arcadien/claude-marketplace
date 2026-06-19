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

## Step 2b — Update CHANGELOG.md

Before committing, prepend a new section to `plugins/<name>/CHANGELOG.md`.

Find the SHA of the last version-bump commit:

```bash
PREV=$(git log --oneline --grep="bump <name> plugin version" -1 2>/dev/null | awk '{print $1}')
```

Extract commits since that SHA, scoped to this plugin — exclude merge commits and the bump commit itself:

```bash
git log --oneline ${PREV:+$PREV..}HEAD -- plugins/<name>/ \
  | grep -v "^[a-f0-9]* Merge " \
  | grep -v "^[a-f0-9]* conf: bump"
```

Group by prefix and prepend the following section to `plugins/<name>/CHANGELOG.md`:

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Features
- <feat commit messages, one per line>

### Fixes
- <fix commit messages>

### Tests
- <test commit messages>

### Configuration
- <conf/chore commit messages>

### Documentation
- <docs commit messages>
```

Omit sections with no commits. If `CHANGELOG.md` does not exist yet, create it with a `# Changelog` title line first.

## Step 3 — Commit the version bump and changelog

Stage both files and commit:

```text
conf: bump <name> plugin version to X.Y.Z
```

```bash
git add plugins/<name>/plugin.json plugins/<name>/CHANGELOG.md
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

## Step 6 — Open a PR and merge

**Never push directly to `main`.** Direct pushes risk recording a local worktree
SHA that does not exist on the remote, breaking `/plugin` with "not our ref".

```bash
git push -u origin <release-branch>
gh pr create --title "conf: release <name> vX.Y.Z" --base main
```

Merge the PR on GitHub, then run `/plugin` — the installer should report the
new version.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `/plugin` shows old version | Stale SHA | Re-run steps 4–5 from `main` |
| New skill not callable | Version not bumped | Full steps 2–6 |
| SHA on feature branch | Rebuilt before merge | Merge, then re-run step 4 |
