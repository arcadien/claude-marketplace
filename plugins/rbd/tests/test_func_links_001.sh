#!/usr/bin/env bash
# Integration tests for FUNC-LINKS-001: rbd_links.py links every cited requirement ID.
# Each case builds a throwaway RBD project and runs the real script on it.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$REPO_ROOT/skills/rbd-links/rbd_links.py"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0
FAIL=0

# new_project <name>: RBD project with FUNC-A-001, FUNC-A-002 and TECH-B-001; prints its path
new_project() {
  local d="$WORK/$1"
  mkdir -p "$d/.rbd" "$d/requirements" "$d/docs"
  printf 'id_format:\n  categories: [FUNC, TECH]\n' > "$d/.rbd/config.yml"
  cat > "$d/requirements/functional.md" <<'EOF'
# Functional Requirements

### FUNC-A-001
**Description:** Needs TECH-B-001 and FUNC-A-002.
Code `FUNC-A-002` stays, unknown FUNC-Z-999 stays, range FUNC-A-001..002 stays.
<!-- FUNC-A-002 in a comment stays -->
Already linked: [FUNC-A-002](functional.md#func-a-002).

### FUNC-A-002
**Description:** Done.

```text
FUNC-A-001 in fenced code stays
```
EOF
  printf '# Technical\n\n### TECH-B-001\n**Description:** Base.\n' > "$d/requirements/technical.md"
  printf '# Architecture\n\n| FUNC-A-001 | rbd |\n' > "$d/docs/architecture.md"
  printf '%s' "$d"
}

assert_eq() {
  if [ "$2" = "$3" ]; then echo "  PASS: $1"; PASS=$((PASS + 1))
  else echo "  FAIL: $1 (expected '$2', got '$3')"; FAIL=$((FAIL + 1)); fi
}

has_line() { grep -qxF -- "$2" "$1" && echo yes || echo no; }

test_apply_links_bare_ids() {
  echo "test_apply_links_bare_ids"
  # @req: FUNC-LINKS-001
  # Given a project citing IDs bare, in code, in comments, in links, in ranges and unknown
  local p; p=$(new_project apply)
  # When the script runs in apply mode
  python3 "$SCRIPT" "$p" >/dev/null
  # Then each file holds the expected line
  local file line
  while IFS='|' read -r file line; do
    assert_eq "$file: $line" yes "$(has_line "$p/$file" "$line")"
  done <<'CASES'
requirements/functional.md|### FUNC-A-001
requirements/functional.md|**Description:** Needs [TECH-B-001](technical.md#tech-b-001) and [FUNC-A-002](functional.md#func-a-002).
requirements/functional.md|Code `FUNC-A-002` stays, unknown FUNC-Z-999 stays, range FUNC-A-001..002 stays.
requirements/functional.md|<!-- FUNC-A-002 in a comment stays -->
requirements/functional.md|Already linked: [FUNC-A-002](functional.md#func-a-002).
requirements/functional.md|FUNC-A-001 in fenced code stays
docs/architecture.md|| [FUNC-A-001](../requirements/functional.md#func-a-001) | rbd |
CASES
}

test_check_mode() {
  echo "test_check_mode"
  # @req: FUNC-LINKS-001
  # Given a project with bare IDs, then the same project linked, then a broken anchor
  local p; p=$(new_project check)
  local before; before=$(cat "$p/requirements/functional.md")
  # When the script runs in check mode, Then it fails on bare IDs and writes nothing
  python3 "$SCRIPT" --check "$p" >/dev/null; assert_eq "bare IDs fail the check" 1 "$?"
  assert_eq "check mode writes nothing" "$before" "$(cat "$p/requirements/functional.md")"
  python3 "$SCRIPT" "$p" >/dev/null
  python3 "$SCRIPT" --check "$p" >/dev/null; assert_eq "linked project passes" 0 "$?"
  printf 'See [TECH-B-001](functional.md#tech-b-001).\n' >> "$p/docs/architecture.md"
  python3 "$SCRIPT" --check "$p" >/dev/null; assert_eq "broken anchor fails" 1 "$?"
}

test_apply_links_bare_ids
test_check_mode

echo
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
