#!/usr/bin/env bash
# RBD pre-push gate — type: "command" PreToolUse hook
#
# Protocol: read JSON from stdin, output JSON to stdout, exit 0 (allow) or 2 (block).
# An empty stdout is invalid — always output at least {}.

set +e

INPUT=$(cat 2>/dev/null || true)

allow() { printf '{}'; exit 0; }
block() { printf '{"decision":"block","reason":"%s"}' "$1"; exit 2; }

# Fast path: only act on git push commands
if ! printf '%s' "$INPUT" | grep -q '"git push' 2>/dev/null; then
  allow
fi

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
[ -z "$REPO_ROOT" ] && allow

CACHE_FILE="$REPO_ROOT/.rbd/.push-validated"
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null || true)

# ── 0. Cache check (FUNC-PUSH-004) ───────────────────────────────────────────
if [ -f "$CACHE_FILE" ] && [ -n "$CURRENT_HEAD" ]; then
  CACHED_HEAD=$(cat "$CACHE_FILE" 2>/dev/null || true)
  if [ "$CACHED_HEAD" = "$CURRENT_HEAD" ]; then
    rm -f "$CACHE_FILE"
    printf '{"systemMessage":"Pre-push checks passed (cached)."}'; exit 0
  fi
fi

# ── 1. Audit check ───────────────────────────────────────────────────────────
AUDITS_DIR="$REPO_ROOT/audits"
if [ -d "$AUDITS_DIR" ]; then
  LATEST=$(ls -t "$AUDITS_DIR"/*.md 2>/dev/null | head -1 || true)
  if [ -n "$LATEST" ] && grep -qiE "status.{0,5}open" "$LATEST" 2>/dev/null; then
    EXCLUSIONS="$AUDITS_DIR/exclusions.yml"
    BASENAME=$(basename "$LATEST")
    if [ ! -f "$EXCLUSIONS" ] || ! grep -q "$BASENAME" "$EXCLUSIONS" 2>/dev/null; then
      block "RBD: open findings in $BASENAME — run /rbd-audit first"
    fi
  fi
fi

# ── 2. Commit format + requirement ID check ───────────────────────────────────
BASE=$(git rev-parse --verify origin/HEAD 2>/dev/null \
    || git rev-parse --verify origin/main 2>/dev/null \
    || git rev-parse --verify main 2>/dev/null \
    || true)

[ -z "$BASE" ] && { printf '{"systemMessage":"Pre-push checks passed (no base ref)."}'; exit 0; }

VALID_PREFIX='^(req|test|feat|tech|perf|ui|conf|arch|plan|chore|fix|docs|style|refactor)\('
NEEDS_REQ='^(feat|tech|perf|ui|conf|arch|test)\('

REQS_DIR="$REPO_ROOT/plugins/rbd/requirements"
[ ! -d "$REQS_DIR" ] && REQS_DIR="$REPO_ROOT/requirements"

while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  HASH=$(printf '%s' "$LINE" | awk '{print $1}')
  MSG=$(printf '%s' "$LINE" | cut -d' ' -f2-)

  if ! printf '%s' "$MSG" | grep -qE "$VALID_PREFIX" 2>/dev/null; then
    block "RBD: $HASH has invalid prefix — $MSG"
  fi

  if printf '%s' "$MSG" | grep -qE "$NEEDS_REQ" 2>/dev/null && [ -d "$REQS_DIR" ]; then
    REQ_ID=$(printf '%s' "$MSG" | grep -oE 'FUNC-[A-Z]+-[0-9]+' 2>/dev/null | head -1 || true)
    if [ -n "$REQ_ID" ] && ! grep -rl "$REQ_ID" "$REQS_DIR" 2>/dev/null | grep -q .; then
      block "RBD: $HASH references $REQ_ID not found in requirements/"
    fi
  fi
done < <(git log --oneline "$BASE"..HEAD 2>/dev/null || true)

# ── All checks passed: write cache ───────────────────────────────────────────
if [ -n "$CURRENT_HEAD" ]; then
  mkdir -p "$(dirname "$CACHE_FILE")" 2>/dev/null || true
  printf '%s' "$CURRENT_HEAD" > "$CACHE_FILE" 2>/dev/null || true
fi

printf '{"systemMessage":"Pre-push checks passed."}'; exit 0
