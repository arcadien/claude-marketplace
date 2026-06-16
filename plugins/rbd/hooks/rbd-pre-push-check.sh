#!/usr/bin/env bash
# RBD pre-push gate — type: "command" hook
# Receives tool input JSON on stdin.
# Exit 0 = allow, Exit 2 = block (stderr shown to user).
#
# Safety: any internal error allows the push through rather than breaking bash.

set +e

# Read stdin
INPUT=$(cat 2>/dev/null || true)

# Extract the bash command — pipeline avoids here-string (not portable on Windows)
COMMAND=$(printf '%s' "$INPUT" | node -e "
  var d = '';
  process.stdin.on('data', function(c) { d += c; });
  process.stdin.on('end', function() {
    try { process.stdout.write(JSON.parse(d).tool_input.command || ''); }
    catch(e) { process.stdout.write(''); }
  });
" 2>/dev/null || true)

# Only gate on git push commands
if ! printf '%s' "$COMMAND" | grep -q 'git push' 2>/dev/null; then
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -z "$REPO_ROOT" ] && exit 0

CACHE_FILE="$REPO_ROOT/.rbd/.push-validated"
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null || true)

# ── 0. Cache check (FUNC-PUSH-004) ───────────────────────────────────────────
if [ -f "$CACHE_FILE" ] && [ -n "$CURRENT_HEAD" ]; then
  CACHED_HEAD=$(cat "$CACHE_FILE" 2>/dev/null || true)
  if [ "$CACHED_HEAD" = "$CURRENT_HEAD" ]; then
    rm -f "$CACHE_FILE"
    echo "Pre-push checks passed (cached validation for $CURRENT_HEAD)."
    exit 0
  fi
fi

# ── 1. Audit check ───────────────────────────────────────────────────────────
AUDITS_DIR="$REPO_ROOT/audits"
if [ -d "$AUDITS_DIR" ]; then
  LATEST=$(ls -t "$AUDITS_DIR"/*.md 2>/dev/null | head -1 || true)
  if [ -n "$LATEST" ] && grep -qiE "status['\"]?[[:space:]]*:[[:space:]]*['\"]?open" "$LATEST" 2>/dev/null; then
    EXCLUSIONS="$AUDITS_DIR/exclusions.yml"
    BASENAME=$(basename "$LATEST")
    if [ ! -f "$EXCLUSIONS" ] || ! grep -q "$BASENAME" "$EXCLUSIONS" 2>/dev/null; then
      printf 'RBD BLOCKED: open findings in %s\n  → Run /rbd-audit to resolve, or add an exclusion entry to audits/exclusions.yml\n' "$BASENAME" >&2
      exit 2
    fi
  fi
fi

# ── 2. Commit format + requirement ID check ───────────────────────────────────
BASE=$(git rev-parse --verify origin/HEAD 2>/dev/null \
    || git rev-parse --verify origin/main 2>/dev/null \
    || git rev-parse --verify main 2>/dev/null \
    || true)

if [ -z "$BASE" ]; then
  echo "Pre-push checks passed (no base ref)."
  exit 0
fi

VALID_PREFIX='^(req|test|feat|tech|perf|ui|conf|arch|plan|chore|fix|docs|style|refactor)\('
NEEDS_REQ='^(feat|tech|perf|ui|conf|arch|test)\('

REQS_DIR="$REPO_ROOT/plugins/rbd/requirements"
[ ! -d "$REQS_DIR" ] && REQS_DIR="$REPO_ROOT/requirements"

while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  HASH=$(printf '%s' "$LINE" | awk '{print $1}')
  MSG=$(printf '%s' "$LINE" | cut -d' ' -f2-)

  if ! printf '%s' "$MSG" | grep -qE "$VALID_PREFIX" 2>/dev/null; then
    printf 'RBD BLOCKED: %s — invalid prefix in: %s\n  Expected: req|test|feat|tech|perf|ui|conf|arch|plan|chore|fix|docs|style|refactor\n' "$HASH" "$MSG" >&2
    exit 2
  fi

  if printf '%s' "$MSG" | grep -qE "$NEEDS_REQ" 2>/dev/null && [ -d "$REQS_DIR" ]; then
    REQ_ID=$(printf '%s' "$MSG" | grep -oE 'FUNC-[A-Z]+-[0-9]+' 2>/dev/null | head -1 || true)
    if [ -n "$REQ_ID" ]; then
      if ! grep -rl "$REQ_ID" "$REQS_DIR" 2>/dev/null | grep -q .; then
        printf 'RBD BLOCKED: %s references %s which was not found in requirements/.\n' "$HASH" "$REQ_ID" >&2
        exit 2
      fi
    fi
  fi
done < <(git log --oneline "$BASE"..HEAD 2>/dev/null || true)

# ── 3. MR safety net (informational) ─────────────────────────────────────────
if gh pr view --json number -q .number >/dev/null 2>&1; then
  printf 'Note: a remote PR exists — consider running /rbd-review before merging.\n' >&2
fi

# ── All checks passed: write cache ───────────────────────────────────────────
if [ -n "$CURRENT_HEAD" ]; then
  mkdir -p "$(dirname "$CACHE_FILE")" 2>/dev/null || true
  printf '%s' "$CURRENT_HEAD" > "$CACHE_FILE" 2>/dev/null || true
fi

echo "Pre-push checks passed."
exit 0
