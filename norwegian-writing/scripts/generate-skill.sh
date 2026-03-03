#!/bin/bash
# Norwegian Writing Skill - Generate/Update Script
# Regenerates references/INDEX.md and validates content quality.
#
# Usage: scripts/generate-skill.sh [--index-only]
#
# Options:
#   --index-only   Only regenerate INDEX.md (used by scrape.sh)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTENT_DIR="$SKILL_DIR/references"
INDEX_FILE="$CONTENT_DIR/INDEX.md"
SKILL_FILE="$SKILL_DIR/SKILL.md"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Check content exists
if [ ! -d "$CONTENT_DIR" ]; then
    echo "ERROR: Reference directory not found. Run scripts/scrape.sh first."
    exit 1
fi

# Map directory name to readable title
section_title() {
    case "$1" in
        rettskriving-og-grammatikk) echo "Rettskriving og grammatikk" ;;
        praktisk-sprakbruk) echo "Praktisk språkbruk" ;;
        klarsprak-om-skriving) echo "Klarspråk – om skriving" ;;
        ordlister) echo "Ordlister" ;;
        spraksporsmal) echo "Språkspørsmål og svar" ;;
        *) echo "$1" ;;
    esac
}

# ── Generate INDEX.md ──

generate_index() {
    log "Generating reference index..."

    cat > "$INDEX_FILE" << 'EOF'
# Reference Index

Reference material from Språkrådet (sprakradet.no). Read individual files for detailed guidance on specific topics.

EOF

    for section_dir in "$CONTENT_DIR"/*/; do
        [ -d "$section_dir" ] || continue
        section_name=$(basename "$section_dir")
        title=$(section_title "$section_name")

        echo "## ${title}" >> "$INDEX_FILE"
        echo "" >> "$INDEX_FILE"

        # For Q&A section: just summarize (too many files to list individually)
        if [ "$section_name" = "spraksporsmal" ]; then
            qa_count=$(find "$section_dir" -name "*.md" -type f | wc -l | tr -d ' ')
            qa_chars=$(find "$section_dir" -name "*.md" -type f -exec cat {} + | wc -c | tr -d ' ')
            qa_tokens=$((qa_chars / 4))
            cat >> "$INDEX_FILE" << EOF
**${qa_count} Q&A articles** (~${qa_tokens} tokens total) from Språkrådet's answer database.

Each file is named by topic slug, e.g. \`spraksporsmal/kjopt-av-fra-eller-hos.md\`, \`spraksporsmal/onboarding.md\`.

To find relevant Q&As, use the file listing:

\`\`\`bash
ls references/spraksporsmal/
\`\`\`

Or search by keyword:

\`\`\`bash
grep -rl "keyword" references/spraksporsmal/
\`\`\`

EOF
            echo "" >> "$INDEX_FILE"
            continue
        fi

        # Find all .md files recursively, sorted
        while IFS= read -r file; do
            relpath="${file#$CONTENT_DIR/}"

            file_title=$(grep -m1 '^# ' "$file" 2>/dev/null | sed 's/^# //' || echo "")
            [ -z "$file_title" ] && file_title=$(basename "$file" .md)

            chars=$(wc -c < "$file" | tr -d ' ')
            tokens=$((chars / 4))

            echo "- [\`${relpath}\`](${relpath}) — ${file_title} (~${tokens} tokens)" >> "$INDEX_FILE"
        done < <(find "$section_dir" -name "*.md" -type f | sort)

        echo "" >> "$INDEX_FILE"
    done

    cat >> "$INDEX_FILE" << 'EOF'
## Updating

Run `scripts/scrape.sh` from the skill root to fetch the latest content.
EOF

    log "Index generated: $INDEX_FILE"
}

# ── Main ──

generate_index

if [ "$1" = "--index-only" ]; then
    exit 0
fi

# ── Show summary with quality metrics ──

echo ""
echo -e "${BLUE}=== Reference Content Summary ===${NC}"
echo ""

total_tokens=0

for section_dir in "$CONTENT_DIR"/*/; do
    [ -d "$section_dir" ] || continue
    section_name=$(basename "$section_dir")
    file_count=$(find "$section_dir" -name "*.md" -type f | wc -l | tr -d ' ')
    section_chars=$(find "$section_dir" -name "*.md" -type f -exec cat {} + | wc -c | tr -d ' ')
    section_tokens=$((section_chars / 4))
    total_tokens=$((total_tokens + section_tokens))

    echo "  📁 ${section_name}/ (${file_count} files, ~${section_tokens} tokens)"

    while IFS= read -r file; do
        relpath="${file#$CONTENT_DIR/}"
        chars=$(wc -c < "$file" | tr -d ' ')
        tokens=$((chars / 4))
        lines=$(wc -l < "$file" | tr -d ' ')
        max_line=$(awk '{ print length }' "$file" | sort -rn | head -1)

        flag=""
        [ "$max_line" -gt 500 ] && flag=" ⚠️  long line (${max_line})"
        [ "$tokens" -lt 50 ] && flag=" ⚠️  very small"

        printf "     └─ %-55s %5d tokens  %4d lines%s\n" "$relpath" "$tokens" "$lines" "$flag"
    done < <(find "$section_dir" -name "*.md" -type f | sort)
    echo ""
done

echo "  Total estimated tokens: ~${total_tokens}"
echo ""

skill_lines=$(wc -l < "$SKILL_FILE" | tr -d ' ')
skill_chars=$(wc -c < "$SKILL_FILE" | tr -d ' ')
skill_tokens=$((skill_chars / 4))
echo "  SKILL.md: ${skill_lines} lines, ~${skill_tokens} tokens"
echo ""
