#!/usr/bin/env bash
# RBD pre-push gate — type: "command" PreToolUse hook
#
# Protocol: read JSON from stdin. Allow: exit 0 with JSON on stdout (at least {}).
# Block: exit 2 with the reason on stderr — Claude Code ignores stdout on exit 2 (TECH-HOOK-001).

set +e

INPUT=$(cat 2>/dev/null || true)

allow() { printf '{}'; exit 0; }
block() { printf '%s\n' "$1" >&2; exit 2; }

# Fast path: only act on commands that run git push (TECH-HOOK-001): at the start of the
# command or after a shell separator, optionally as git -C <dir>; not when it is only text
CMD_START='("command"[[:space:]]*:[[:space:]]*"|;|&&|[|]|\\n|[(`])'
GIT_PUSH='[[:space:]]*git([[:space:]]+-C[[:space:]]+[^[:space:]]+)?[[:space:]]+push([[:space:]]|\\|"|$)'
if ! printf '%s' "$INPUT" | grep -qE "${CMD_START}${GIT_PUSH}" 2>/dev/null; then
  allow
fi

# Repository being pushed (TECH-HOOK-002): the last cd <dir> or git -C <dir> before push,
# resolved against the payload cwd, falling back to that cwd.
# shortcut: paths with spaces or escaped quotes are not parsed; use jq if they show up.
CWD=$(printf '%s' "$INPUT" | grep -oE '"cwd"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed -E 's/.*"([^"]*)"$/\1/')
[ -z "$CWD" ] && CWD=$PWD
CMD=$(printf '%s' "$INPUT" | grep -oE '"command"[[:space:]]*:[[:space:]]*"([^"\\]|\\.)*"' | head -1)
BEFORE_PUSH=$(printf '%s' "$CMD" | sed -E 's/[[:space:]]+push([[:space:]]|\\|"|$).*//')
TARGET=$(printf '%s' "$BEFORE_PUSH" \
  | grep -oE '(^|[";&|(`[:space:]]|\\n)(cd|-C)[[:space:]]+(\\"|'"'"')?[^[:space:];&|)`\\"'"'"']+' \
  | tail -1 | sed -E 's/.*(cd|-C)[[:space:]]+(\\"|'"'"')?//')
case "$TARGET" in
  "") TARGET=$CWD ;;
  "~"*) TARGET="$HOME${TARGET#\~}" ;;
  /*) ;;
  *) TARGET="$CWD/$TARGET" ;;
esac

REPO_ROOT=$(git -C "$TARGET" rev-parse --show-toplevel 2>/dev/null || true)
[ -z "$REPO_ROOT" ] && allow

# RBD project: .rbd/config.yml at the root, else the first tracked one in a subdirectory (monorepo)
if [ -f "$REPO_ROOT/.rbd/config.yml" ]; then
  RBD_ROOT=$REPO_ROOT
else
  SUB_CONFIG=$(git -C "$REPO_ROOT" ls-files '*/.rbd/config.yml' 2>/dev/null | head -1)
  [ -z "$SUB_CONFIG" ] && allow
  RBD_ROOT="$REPO_ROOT/${SUB_CONFIG%/.rbd/config.yml}"
fi
git() { command git -C "$REPO_ROOT" "$@"; }

CACHE_FILE="$RBD_ROOT/.rbd/.push-validated"
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
AUDITS_DIR="$RBD_ROOT/audits"
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

# only commits about to be pushed (FUNC-PUSH-002): published history is never re-checked
RANGE=$(git rev-parse --verify -q "@{u}" 2>/dev/null || printf '%s' "$BASE")

# extra_commit_prefixes: [hw, ...] in .rbd/config.yml (CONF-PREFIX-001)
EXTRA=$(sed -n 's/^extra_commit_prefixes:[[:space:]]*\[\(.*\)\].*/\1/p' "$RBD_ROOT/.rbd/config.yml" 2>/dev/null \
  | tr -d ' "'"'"'\r' | tr ',' '|')
VALID_PREFIX="^(req|test|feat|tech|perf|ui|conf|arch|plan|chore|fix|docs|style|refactor${EXTRA:+|$EXTRA})[:(]"
NEEDS_REQ='^(feat|tech|perf|ui|conf|arch|test)\('

REQS_DIR="$RBD_ROOT/requirements"

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
done < <(git log --oneline "$RANGE"..HEAD 2>/dev/null || true)

# ── All checks passed: write cache ───────────────────────────────────────────
if [ -n "$CURRENT_HEAD" ]; then
  mkdir -p "$(dirname "$CACHE_FILE")" 2>/dev/null || true
  printf '%s' "$CURRENT_HEAD" > "$CACHE_FILE" 2>/dev/null || true
fi

printf '{"systemMessage":"Pre-push checks passed."}'; exit 0
