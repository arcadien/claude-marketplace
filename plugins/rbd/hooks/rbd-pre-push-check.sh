#!/usr/bin/env bash
# RBD pre-push gate — type: "command" hook
# Receives tool input JSON on stdin.
# Exit 0 = allow, Exit 2 = block (stderr shown to user).

INPUT=$(cat)

# Extract the bash command from the JSON input
COMMAND=$(node -e "
  let d = '';
  process.stdin.on('data', c => d += c);
  process.stdin.on('end', () => {
    try { process.stdout.write(JSON.parse(d).tool_input?.command || ''); }
    catch { process.stdout.write(''); }
  });
" <<< "$INPUT" 2>/dev/null)

# Only gate on git push commands
if ! echo "$COMMAND" | grep -q 'git push'; then
  exit 0
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$REPO_ROOT" ] && exit 0

CACHE_FILE="$REPO_ROOT/.rbd/.push-validated"
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)

# ── 0. Cache check (FUNC-PUSH-004) ───────────────────────────────────────────
if [ -f "$CACHE_FILE" ]; then
  CACHED_HEAD=$(cat "$CACHE_FILE" 2>/dev/null)
  if [ "$CACHED_HEAD" = "$CURRENT_HEAD" ]; then
    rm -f "$CACHE_FILE"
    echo "Pre-push checks passed (cached validation for $CURRENT_HEAD)."
    exit 0
  fi
  # HEAD changed since last validation — fall through to full check
fi

# ── 1. Audit check ───────────────────────────────────────────────────────────
AUDITS_DIR="$REPO_ROOT/audits"
if [ -d "$AUDITS_DIR" ]; then
  LATEST=$(ls -t "$AUDITS_DIR"/*.md 2>/dev/null | head -1)
  if [ -n "$LATEST" ] && grep -qiE "status['\"]?\s*:\s*['\"]?open" "$LATEST" 2>/dev/null; then
    BASENAME=$(basename "$LATEST")
    # Check if this finding has an exclusion entry
    EXCLUSIONS="$AUDITS_DIR/exclusions.yml"
    if [ ! -f "$EXCLUSIONS" ] || ! grep -q "$BASENAME" "$EXCLUSIONS" 2>/dev/null; then
      echo "RBD BLOCKED: open findings in $BASENAME" >&2
      echo "  → Run /rbd-audit to resolve, or add an exclusion entry to audits/exclusions.yml" >&2
      exit 2
    fi
  fi
fi

# ── 2. Commit format + requirement ID check ───────────────────────────────────
BASE=$(git rev-parse --verify origin/HEAD 2>/dev/null \
    || git rev-parse --verify origin/main 2>/dev/null \
    || git rev-parse --verify main 2>/dev/null)

if [ -z "$BASE" ]; then
  echo "Pre-push checks passed (no base ref)."
  exit 0
fi

# Prefixes that are valid RBD commit types
VALID_PREFIX='^(req|test|feat|tech|perf|ui|conf|arch|plan|chore|fix|docs|style|refactor)\('

# Prefixes that require a FUNC-XXX-NNN requirement ID
NEEDS_REQ='^(feat|tech|perf|ui|conf|arch|test)\('

# Locate requirements directory (only validate IDs if requirements exist)
REQS_DIR="$REPO_ROOT/plugins/rbd/requirements"
[ ! -d "$REQS_DIR" ] && REQS_DIR="$REPO_ROOT/requirements"

while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  HASH=$(echo "$LINE" | awk '{print $1}')
  MSG=$(echo "$LINE" | cut -d' ' -f2-)

  # Check prefix format
  if ! echo "$MSG" | grep -qE "$VALID_PREFIX"; then
    echo "RBD BLOCKED: $HASH — invalid prefix in: '$MSG'" >&2
    echo "  Expected: req|test|feat|tech|perf|ui|conf|arch|plan|chore|fix|docs|style|refactor" >&2
    exit 2
  fi

  # For implementation commits, validate the requirement ID exists
  if echo "$MSG" | grep -qE "$NEEDS_REQ" && [ -d "$REQS_DIR" ]; then
    REQ_ID=$(echo "$MSG" | grep -oE 'FUNC-[A-Z]+-[0-9]+' | head -1)
    if [ -n "$REQ_ID" ]; then
      if ! grep -rl "$REQ_ID" "$REQS_DIR" 2>/dev/null | grep -q .; then
        echo "RBD BLOCKED: $HASH references $REQ_ID which was not found in requirements/." >&2
        exit 2
      fi
    fi
  fi
done < <(git log --oneline "$BASE"..HEAD 2>/dev/null)

# ── 3. MR safety net (informational only) ────────────────────────────────────
if gh pr view --json number -q .number >/dev/null 2>&1; then
  echo "Note: a remote PR exists for this branch — consider running /rbd-review before merging." >&2
fi

# ── All checks passed: write cache ───────────────────────────────────────────
mkdir -p "$(dirname "$CACHE_FILE")"
echo "$CURRENT_HEAD" > "$CACHE_FILE"
echo "Pre-push checks passed."
exit 0
