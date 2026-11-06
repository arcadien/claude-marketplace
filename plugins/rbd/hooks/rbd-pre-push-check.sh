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
# shortcut: one RBD project per repository; with several, map each commit to its project by changed paths.
if [ -f "$REPO_ROOT/.rbd/config.yml" ]; then
  RBD_ROOT=$REPO_ROOT
else
  SUB_CONFIG=$(git -C "$REPO_ROOT" ls-files '*/.rbd/config.yml' 2>/dev/null | head -1)
  [ -z "$SUB_CONFIG" ] && allow
  RBD_ROOT="$REPO_ROOT/${SUB_CONFIG%/.rbd/config.yml}"
fi
git() { command git -C "$REPO_ROOT" "$@"; }

# ── 1. Audit check ───────────────────────────────────────────────────────────
AUDITS_DIR="$RBD_ROOT/audits"
if [ -d "$AUDITS_DIR" ]; then
  LATEST=$(ls "$AUDITS_DIR"/*.md 2>/dev/null | sort | tail -1)  # audits are named YYYY-MM-DD-audit.md
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
NEEDS_REQ='^(req|test|feat|tech|perf|ui|conf|arch)[:(]'
CATEGORIES=$(sed -n 's/^[[:space:]]*categories:[[:space:]]*\[\(.*\)\].*/\1/p' "$RBD_ROOT/.rbd/config.yml" 2>/dev/null \
  | tr -d ' "'"'"'\r' | tr ',' '|')
REQ_ID_PATTERN="(${CATEGORIES:-FUNC|TECH|PERF|UI|CONF|PLAT})(-[A-Z0-9]+)*-[0-9]+"

REQS_DIR="$RBD_ROOT/requirements"

# status of a requirement: the **Status:** line under its "### <ID>" heading, empty when absent
req_status() {
  awk -v id="$1" '$0 == "### " id { found = 1; next }
    found && /^###/ { exit }
    found && /^\*\*Status:\*\*/ { sub(/^\*\*Status:\*\*[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }' \
    "$REQS_DIR"/*.md 2>/dev/null
}

while IFS= read -r LINE; do
  [ -z "$LINE" ] && continue
  HASH=$(printf '%s' "$LINE" | awk '{print $1}')
  MSG=$(printf '%s' "$LINE" | cut -d' ' -f2-)

  if ! printf '%s' "$MSG" | grep -qE "$VALID_PREFIX" 2>/dev/null; then
    block "RBD: $HASH has invalid prefix — $MSG"
  fi

  if printf '%s' "$MSG" | grep -qE "$NEEDS_REQ" 2>/dev/null; then
    IDS=$(printf '%s' "$MSG" | grep -oE "$REQ_ID_PATTERN" 2>/dev/null || true)
    [ -z "$IDS" ] && block "RBD: $HASH needs a requirement ID — $MSG"
    case "$MSG" in req*) continue ;; esac  # a req commit may create or delete its requirement
    for REQ_ID in $IDS; do
      STATUS=$(req_status "$REQ_ID")
      [ -z "$STATUS" ] && block "RBD: $HASH references $REQ_ID not found in requirements/"
      case "$STATUS" in validated|deprecated) ;; *) block "RBD: $HASH references $REQ_ID with status $STATUS, not validated" ;; esac
    done
  fi
done < <(git log --oneline --no-merges "$RANGE"..HEAD 2>/dev/null || true)

printf '{"systemMessage":"Pre-push checks passed."}'; exit 0
