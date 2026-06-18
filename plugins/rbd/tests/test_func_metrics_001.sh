#!/usr/bin/env bash
# Integration tests for FUNC-METRICS-001
# Requirement: Coverage metrics report per category and subcategory
#
# rbd-metrics reads all requirement files and counts, per main category and
# per subcategory, the total number of validated requirements and how many have
# at least one test(ID): commit. Output is an ASCII structured list on stdout.
# An optional --json flag exports the same data as a JSON object to stdout.
# No file is ever written.
#
# Production side must provide:
#   - skills/rbd-metrics/SKILL.md  -- must declare all behaviors listed below:
#       * reads requirements/*.md files
#       * counts validated requirements per category and per subcategory
#       * scans git log for test(ID): commit messages
#       * prints an ASCII structured list (tree characters)
#       * includes a progress bar (filled and empty block characters)
#       * includes a percentage value per subcategory
#       * annotates incomplete subcategories with N missing
#       * writes nothing to the filesystem (stdout only)
#       * supports a --json flag that emits the same data as JSON

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL_FILE="$REPO_ROOT/skills/rbd-metrics/SKILL.md"

PASS=0
FAIL=0
# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

assert_contains() {
  local description="$1"
  local file="$2"
  local grep_flag=""
  local pattern="$3"
  if [ "$3" = "-E" ]; then
    grep_flag="-E"
    pattern="$4"
  fi

  if grep -q $grep_flag -- "$pattern" "$file" 2>/dev/null; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    echo "        file    : $file"
    echo "        pattern : $pattern"
    FAIL=$((FAIL + 1))
  fi
}

assert_file_exists() {
  local description="$1"
  local file="$2"

  if [ -f "$file" ]; then
    echo "  PASS: $description"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $description"
    echo "        expected file: $file"
    FAIL=$((FAIL + 1))
  fi
}

# ---------------------------------------------------------------------------
# FUNC-METRICS-001: Coverage metrics report per category and subcategory
# ---------------------------------------------------------------------------

test_metrics_skill_file_exists() {
  echo "test_metrics_skill_file_exists"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 introduces rbd-metrics as a new skill component.
  # The plugin skill convention places entry-point definitions under
  # skills/<skill-name>/SKILL.md.

  # When
  # We check that skills/rbd-metrics/SKILL.md is present on the filesystem.

  # Then
  assert_file_exists \
    "skills/rbd-metrics/SKILL.md exists" \
    "$SKILL_FILE"
}

test_metrics_skill_reads_requirement_files() {
  echo "test_metrics_skill_reads_requirement_files"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 requires rbd-metrics to read all requirement files
  # in order to enumerate validated requirements.

  # When
  # We inspect the skill definition for a declaration that it reads
  # requirements/*.md (or an equivalent reference to the requirements directory).

  # Then
  assert_contains \
    "rbd-metrics skill declares reading requirement files" \
    "$SKILL_FILE" \
    -E "requirements/\*\.md|requirements/.*\.md|requirements directory"
}

test_metrics_skill_counts_validated_requirements() {
  echo "test_metrics_skill_counts_validated_requirements"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 requires the skill to count requirements whose status
  # is exactly "validated". Draft, proposed, or deprecated requirements must
  # not be included in the totals.

  # When
  # We inspect the skill definition for a declaration that it filters on
  # status: validated before counting.

  # Then
  assert_contains \
    "rbd-metrics skill declares counting validated requirements" \
    "$SKILL_FILE" \
    -E "status.*validated|validated.*status|validated requirements"
}

test_metrics_skill_groups_by_category() {
  echo "test_metrics_skill_groups_by_category"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 requires output grouped by main category
  # (FUNC, TECH, PERF, UI, CONF, PLAT). Each category appears as a top-level
  # line with its total validated-requirement count.

  # When
  # We inspect the skill definition for a declaration that counts are
  # grouped or aggregated by category.

  # Then
  assert_contains \
    "rbd-metrics skill declares grouping by category" \
    "$SKILL_FILE" \
    -E "categor|FUNC.*TECH|per category"
}

test_metrics_skill_groups_by_subcategory() {
  echo "test_metrics_skill_groups_by_subcategory"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 requires each category to be further broken down by
  # subcategory (the middle segment of the ID, e.g. AUTH in FUNC-AUTH-001).
  # The ASCII tree indents subcategories under their parent category.

  # When
  # We inspect the skill definition for a declaration that counts are also
  # computed per subcategory (or per "subgroup", "sub-level", "intermediate
  # classification level").

  # Then
  assert_contains \
    "rbd-metrics skill declares grouping by subcategory" \
    "$SKILL_FILE" \
    -E "subcategor|sub-categor|subgroup|per sub|intermediate.*level|level.*intermediate"
}

test_metrics_skill_scans_git_log_for_test_commits() {
  echo "test_metrics_skill_scans_git_log_for_test_commits"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 requires the skill to determine test coverage by checking
  # how many validated requirements have at least one commit whose message
  # matches the prefix test(ID): -- which is the established commit convention
  # for this project.

  # When
  # We inspect the skill definition for a declaration that it reads the git log
  # and searches for test(ID): commit messages.

  # Then
  assert_contains \
    "rbd-metrics skill declares scanning git log for test(ID): commits" \
    "$SKILL_FILE" \
    -E "git log|git.*log|test\(.*\):|test commit"
}

test_metrics_skill_outputs_ascii_tree_structure() {
  echo "test_metrics_skill_outputs_ascii_tree_structure"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 specifies an ASCII structured list as the output format.
  # The example in the requirement uses box-drawing tree characters to show
  # the hierarchy between categories and their subcategories.

  # When
  # We inspect the skill definition for a reference to tree-drawing characters
  # or the ASCII structured list format described in the requirement.

  # Then
  assert_contains \
    "rbd-metrics skill declares ASCII tree output with tree-drawing characters" \
    "$SKILL_FILE" \
    -E "tree|ASCII.*list|structured list|box-drawing|tree character"
}

test_metrics_skill_outputs_progress_bar() {
  echo "test_metrics_skill_outputs_progress_bar"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 specifies a visual progress bar using filled block
  # characters for covered requirements and empty block characters for
  # uncovered ones, displayed inline per subcategory.

  # When
  # We inspect the skill definition for a reference to the block-character
  # progress bar (filled blocks, empty blocks, or "progress bar").

  # Then
  assert_contains \
    "rbd-metrics skill declares block-character progress bar" \
    "$SKILL_FILE" \
    -E "progress bar|block.*bar|bar.*block|block character|filled.*block|empty.*block"
}

test_metrics_skill_outputs_percentage() {
  echo "test_metrics_skill_outputs_percentage"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 requires a percentage value at the end of each
  # subcategory line (e.g. 100%, 50%), derived from covered / total.

  # When
  # We inspect the skill definition for a declaration that a percentage
  # is displayed per subcategory.

  # Then
  assert_contains \
    "rbd-metrics skill declares percentage display per subcategory" \
    "$SKILL_FILE" \
    -E "percent|100%"
}

test_metrics_skill_annotates_missing_requirements() {
  echo "test_metrics_skill_annotates_missing_requirements"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 requires that when coverage is below 100%, the output
  # line is annotated with an arrow and "N missing" indicating how many
  # requirements still lack a test(ID): commit.

  # When
  # We inspect the skill definition for a declaration of the missing-count
  # annotation (arrow and "missing" keyword, or equivalent phrasing).

  # Then
  assert_contains \
    "rbd-metrics skill declares missing-count annotation for incomplete subcategories" \
    "$SKILL_FILE" \
    -E "missing"
}

test_metrics_skill_writes_nothing_to_filesystem() {
  echo "test_metrics_skill_writes_nothing_to_filesystem"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 explicitly states: "No file is written."
  # rbd-metrics is strictly read-only with respect to the filesystem.

  # When
  # We inspect the skill definition for a declaration of its read-only nature
  # or an explicit statement that no file is created or modified.

  # Then
  assert_contains \
    "rbd-metrics skill declares no file is written (stdout only / read-only)" \
    "$SKILL_FILE" \
    -E "no file|stdout only|read-only|read only|never write|never modif"
}

test_metrics_skill_supports_json_flag() {
  echo "test_metrics_skill_supports_json_flag"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 requires an optional --json flag that, when present,
  # causes the skill to emit a JSON object to stdout instead of the ASCII
  # structured list.

  # When
  # We inspect the skill definition for a declaration that --json is a
  # recognized flag.

  # Then
  assert_contains \
    "rbd-metrics skill declares --json flag support" \
    "$SKILL_FILE" \
    "--json"
}

test_metrics_json_output_contains_same_data() {
  echo "test_metrics_json_output_contains_same_data"
  # @req: FUNC-METRICS-001

  # Given
  # FUNC-METRICS-001 specifies that the JSON output from --json must contain
  # the same data as the ASCII report: category totals, subcategory covered/total
  # counts, and missing counts. The two representations must be equivalent.

  # When
  # We inspect the skill definition for a declaration that the JSON output
  # mirrors (or contains) the same data as the ASCII report.

  # Then
  assert_contains \
    "rbd-metrics skill declares JSON output contains same data as ASCII report" \
    "$SKILL_FILE" \
    -E "same data|same.*data|equivalent|JSON.*categor|categor.*JSON"
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------

echo "=== FUNC-METRICS-001: Coverage metrics report per category and subcategory ==="
echo ""

test_metrics_skill_file_exists
test_metrics_skill_reads_requirement_files
test_metrics_skill_counts_validated_requirements
test_metrics_skill_groups_by_category
test_metrics_skill_groups_by_subcategory
test_metrics_skill_scans_git_log_for_test_commits
test_metrics_skill_outputs_ascii_tree_structure
test_metrics_skill_outputs_progress_bar
test_metrics_skill_outputs_percentage
test_metrics_skill_annotates_missing_requirements
test_metrics_skill_writes_nothing_to_filesystem
test_metrics_skill_supports_json_flag
test_metrics_json_output_contains_same_data

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
exit 0
