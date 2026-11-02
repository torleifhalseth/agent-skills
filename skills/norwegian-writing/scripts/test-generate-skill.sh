#!/usr/bin/env bash
# Verify SKILL.md generation without modifying the repository's skill or references.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/generate-skill-test.XXXXXX")
trap 'rm -rf "$TEST_DIR"' EXIT

export REFERENCE_DIR="$SKILL_DIR/references"
export SKILL_FILE="$TEST_DIR/SKILL.md"
cp "$SKILL_DIR/SKILL.md" "$SKILL_FILE"
head -n 10 "$SKILL_FILE" > "$TEST_DIR/intro"

bash "$SCRIPT_DIR/generate-skill.sh" --skill-only > "$TEST_DIR/log"
cmp "$TEST_DIR/intro" <(head -n 10 "$SKILL_FILE")
qa_count=$(find "$REFERENCE_DIR/spraksporsmal" -name '*.md' -type f | wc -l | tr -d ' ')
grep -q "Search the ${qa_count} Q&A articles" "$SKILL_FILE"
while IFS= read -r reference; do
    test -f "$SKILL_DIR/$reference"
done < <(grep -oE 'references/[A-Za-z0-9/._-]+\.md' "$SKILL_FILE" | sort -u)

cp "$SKILL_FILE" "$TEST_DIR/expected"
bash "$SCRIPT_DIR/generate-skill.sh" --skill-only > "$TEST_DIR/log"
cmp "$TEST_DIR/expected" "$SKILL_FILE"

sed '/<!-- END GENERATED: scripts\/generate-skill.sh -->/d' "$SKILL_FILE" > "$TEST_DIR/missing-marker"
cp "$TEST_DIR/missing-marker" "$SKILL_FILE"
if bash "$SCRIPT_DIR/generate-skill.sh" --skill-only > "$TEST_DIR/log" 2>&1; then
    echo 'Expected missing marker to fail' >&2
    exit 1
fi
cmp "$TEST_DIR/missing-marker" "$SKILL_FILE"

cp "$TEST_DIR/expected" "$SKILL_FILE"
mkdir -p "$TEST_DIR/references/spraksporsmal"
printf '# Test\n' > "$TEST_DIR/references/spraksporsmal/test.md"
REFERENCE_DIR="$TEST_DIR/references" bash "$SCRIPT_DIR/generate-skill.sh" --index-only > "$TEST_DIR/log"
cmp "$TEST_DIR/expected" "$SKILL_FILE"
REFERENCE_DIR="$TEST_DIR/references" bash "$SCRIPT_DIR/generate-skill.sh" --skill-only > "$TEST_DIR/log" 2>&1 && {
    echo 'Expected missing reference to fail' >&2
    exit 1
}
cmp "$TEST_DIR/expected" "$SKILL_FILE"

echo 'Skill generation checks passed.'
