#!/usr/bin/env bash
# RBD plan file commit gate (FUNC-COMMIT-001, TECH-HOOK-003)
#
# Two entry points:
#   rbd-plan-file-check.sh <message-file>   git commit-msg hook: refuse with exit 1
#   rbd-plan-file-check.sh < payload.json   PreToolUse hook on Bash: block with exit 2, allow with {} on stdout
# Either way the reason goes to stderr.

set +e

# rbd_root_of <repo_root>: the RBD project, root or first tracked subdirectory config (TECH-HOOK-002)
rbd_root_of() {
  if [ -f "$1/.rbd/config.yml" ]; then printf '%s' "$1"; return; fi
  local sub; sub=$(git -C "$1" ls-files '*/.rbd/config.yml' 2>/dev/null | head -1)
  [ -n "$sub" ] && printf '%s' "$1/${sub%/.rbd/config.yml}"
}

# plan_patterns <plan-files.yml>: one path or glob per line, from plan_files:
plan_patterns() {
  awk '/^[^[:space:]#]/ { in_list = /^plan_files:/; next }
    in_list && /^[[:space:]]*-[[:space:]]/ { sub(/^[[:space:]]*-[[:space:]]*/, ""); sub(/[[:space:]]+#.*/, "")
      gsub(/["'"'"']/, ""); sub(/[[:space:]]+$/, ""); print }' "$1"
}

# accepted_map <plan-files.yml>: "<path or glob> <prefix> <prefix>..." per line, from accepted_prefixes:
accepted_map() {
  awk '/^[^[:space:]#]/ { in_map = /^accepted_prefixes:/; next }
    in_map && /^[[:space:]]+[^[:space:]#][^:]*:[[:space:]]*\[/ { line = $0; sub(/[[:space:]]+#.*/, "", line)
      key = line; sub(/^[[:space:]]+/, "", key); sub(/:[[:space:]]*\[.*/, "", key)
      list = line; sub(/^[^[]*\[/, "", list); sub(/\].*/, "", list); gsub(/[,"'"'"']/, " ", list)
      gsub(/["'"'"']/, "", key); print key " " list }' "$1"
}

# refusal <repo_root> <subject> <changed file>...: prints the reason when a plan file is changed under a
# prefix it does not accept, nothing otherwise
refusal() {
  local repo=$1 subject=$2; shift 2
  local rbd; rbd=$(rbd_root_of "$repo")
  local plan_files="$rbd/.rbd/plan-files.yml"
  [ -n "$rbd" ] && [ -f "$plan_files" ] || return
  [ -f "$(git -C "$repo" rev-parse --absolute-git-dir)/MERGE_HEAD" ] && return  # git writes merge messages

  local sub="" prefix=${subject%%[:(]*} patterns accepted file rel pat allowed bad=""
  [ "$rbd" != "$repo" ] && sub="${rbd#"$repo"/}/"
  patterns=$(plan_patterns "$plan_files")
  accepted=$(accepted_map "$plan_files")
  for file in "$@"; do
    case "$file" in "$sub"*) rel=${file#"$sub"} ;; *) continue ;; esac
    while IFS= read -r pat; do [ -n "$pat" ] && [[ $rel == $pat ]] && break; done <<< "$patterns"
    [ -n "$pat" ] && [[ $rel == $pat ]] || continue
    allowed="plan"
    while read -r pat list; do
      [ -n "$pat" ] && [[ $rel == $pat ]] && allowed="$allowed $list"
    done <<< "$accepted"
    allowed=$(printf '%s\n' $allowed | awk '!seen[$0]++' | paste -sd, - | sed 's/,/, /g')
    case ", $allowed," in *", $prefix,"*) ;; *) bad="$bad"$'\n'"  $file ($allowed)" ;; esac
  done
  [ -n "$bad" ] && printf 'RBD: "%s" changes plan files that need plan: or a prefix accepted for them in .rbd/plan-files.yml:%s\n' \
    "$subject" "$bad"
}

# ── commit-msg entry ─────────────────────────────────────────────────────────
if [ $# -gt 0 ]; then
  SUBJECT=$(grep -vE '^[[:space:]]*(#|$)' "$1" | head -1)
  REPO=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
  mapfile -t FILES < <(git -C "$REPO" diff --cached --name-only)
  REASON=$(refusal "$REPO" "$SUBJECT" "${FILES[@]}")
  [ -n "$REASON" ] && { printf '%s\n' "$REASON" >&2; exit 1; }
  exit 0
fi

# ── PreToolUse entry ─────────────────────────────────────────────────────────
allow() { printf '{}'; exit 0; }
INPUT=$(cat 2>/dev/null || true)

# shortcut: JSON is unescaped for \" \\ \n \t only, enough for git commands; use jq if more show up.
json_string() {
  local s; s=$(printf '%s' "$INPUT" | grep -oE "\"$1\"[[:space:]]*:[[:space:]]*\"([^\"\\\\]|\\\\.)*\"" | head -1)
  s=${s#*:}; s=${s#*\"}; s=${s%\"}
  s=${s//\\\\/$'\1'}; s=${s//\\\"/\"}; s=${s//\\n/$'\n'}; s=${s//\\t/$'\t'}; s=${s//$'\1'/\\}
  printf '%s' "$s"
}
CMD=$(json_string command)
CWD=$(json_string cwd); [ -z "$CWD" ] && CWD=$PWD

# git commit at the start of the command or after a shell separator, not when it is only text (TECH-HOOK-001)
SEP=$'(^|;|&&|[|]|\n|[(`])[[:space:]]*'
GIT_COMMIT='git([[:space:]]+-C[[:space:]]+([^[:space:];&|)]+))?[[:space:]]+commit([[:space:]]|$)'
[[ $CMD =~ ${SEP}${GIT_COMMIT} ]] || allow
DASH_C=${BASH_REMATCH[3]}
BEFORE=${CMD%%"${BASH_REMATCH[0]}"*}
ARGS=${CMD#*"${BASH_REMATCH[0]}"}

# subject: first line of the -m message, plain quoted or heredoc; no -m is left to the commit-msg entry
[[ $ARGS =~ (^|[[:space:]])(-[a-zA-Z]*m|--message)(=|[[:space:]]+)(.*) ]] || allow
MSG_FLAG=${BASH_REMATCH[2]}
VALUE=${BASH_REMATCH[4]}
case "$VALUE" in
  '"$(cat <<'*) SUBJECT=$(printf '%s\n' "$VALUE" | sed -n 2p) ;;
  \"*) VALUE=${VALUE#\"}; SUBJECT=${VALUE%%[\"$'\n']*} ;;
  \'*) VALUE=${VALUE#\'}; SUBJECT=${VALUE%%[\'$'\n']*} ;;
  *) SUBJECT=${VALUE%%[[:space:]]*} ;;
esac

# repository: git -C <dir>, else the last cd <dir> before the commit, else the payload cwd (TECH-HOOK-002)
# shortcut: paths with spaces are not parsed.
DIR=$DASH_C
if [ -z "$DIR" ]; then
  DIR=$(printf '%s\n' "$BEFORE" | grep -oE '(^|[;&|(`[:space:]])cd[[:space:]]+[^[:space:];&|)`]+' | tail -1 \
    | sed -E 's/.*cd[[:space:]]+//; s/^["'"'"']//; s/["'"'"']$//')
fi
case "$DIR" in
  "") DIR=$CWD ;;
  "~"*) DIR="$HOME${DIR#\~}" ;;
  /*) ;;
  *) DIR="$CWD/$DIR" ;;
esac
REPO=$(git -C "$DIR" rev-parse --show-toplevel 2>/dev/null) || allow

# files: the index, plus what -a and earlier git add commands in the same line would stage
FILES=$(git -C "$REPO" diff --cached --name-only)
if [[ $MSG_FLAG == -*a*m || " $ARGS" =~ [[:space:]](-a|--all)[[:space:]] ]]; then
  FILES+=$'\n'$(git -C "$REPO" diff --name-only)
fi
REST=$BEFORE
while [[ $REST =~ git[[:space:]]+add[[:space:]]+([^;&|$'\n']*) ]]; do
  read -ra ADD_ARGS <<< "${BASH_REMATCH[1]}"
  FILES+=$'\n'$(git -C "$DIR" add --dry-run "${ADD_ARGS[@]}" 2>/dev/null \
    | sed -nE "s/^(add|remove) '(.*)'$/\2/p" | while IFS= read -r f; do
      git -C "$DIR" ls-files --full-name --error-unmatch -- "$f" 2>/dev/null \
        || git -C "$DIR" ls-files --full-name -o -- "$f"; done)
  REST=${REST#*"${BASH_REMATCH[0]}"}
done
mapfile -t FILE_LIST < <(printf '%s\n' "$FILES" | grep -v '^$' | sort -u)

REASON=$(refusal "$REPO" "$SUBJECT" "${FILE_LIST[@]}")
[ -n "$REASON" ] && { printf '%s\n' "$REASON" >&2; exit 2; }
allow
