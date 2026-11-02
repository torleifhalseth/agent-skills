#!/bin/bash
# Norwegian Writing Skill - Generate/Update Script
# Regenerates references/INDEX.md and the generated section of SKILL.md.
#
# Usage: scripts/generate-skill.sh [--index-only|--skill-only]
#
# Options:
#   --index-only   Only regenerate INDEX.md (used during the Chrome scrape)
#   --skill-only   Only regenerate the marked section of SKILL.md

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTENT_DIR="${REFERENCE_DIR:-$SKILL_DIR/references}"
INDEX_FILE="$CONTENT_DIR/INDEX.md"
SKILL_FILE="${SKILL_FILE:-$SKILL_DIR/SKILL.md}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Check content exists
if [ ! -d "$CONTENT_DIR" ]; then
    echo "ERROR: Reference directory not found. See BUILDING.md for update instructions."
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

See [BUILDING.md](../BUILDING.md) for instructions on fetching the latest content through Chrome.
EOF

    log "Index generated: $INDEX_FILE"
}

# ── Generate the compact, source-linked skill body ──

generate_skill() {
    log "Generating skill instructions..."

    if [ ! -f "$INDEX_FILE" ] || [ ! -d "$CONTENT_DIR/spraksporsmal" ]; then
        echo "ERROR: Reference index or Q&A directory not found in $CONTENT_DIR" >&2
        return 1
    fi

    local qa_count body_file updated_file
    qa_count=$(find "$CONTENT_DIR/spraksporsmal" -name '*.md' -type f | wc -l | tr -d ' ')
    if [ "$qa_count" -eq 0 ]; then
        echo "ERROR: No Q&A articles found in $CONTENT_DIR" >&2
        return 1
    fi

    body_file=$(mktemp "${TMPDIR:-/tmp}/norwegian-skill-body.XXXXXX")
    updated_file=$(mktemp "${SKILL_FILE}.tmp.XXXXXX")

    cat > "$body_file" << 'EOF'
## Workflow

1. Establish whether the text should be in Bokmål or Nynorsk. Follow the user's existing variety when not specified; ask if the choice matters and is unclear.
2. Locate the relevant topic below or in [the reference index](references/INDEX.md). Read the relevant source file before applying a specific rule; do not treat these links as a complete summary of the rules.
3. Preserve the writer's meaning and intended audience when editing. For spelling and inflection not covered by the references, consult [Bokmålsordboka](https://ordbokene.no/bm) or [Nynorskordboka](https://ordbokene.no/nn). State uncertainty rather than inventing a rule.

## Topic Guide

| Topic | Detailed guidance |
| --- | --- |
EOF

    local topic reference
    while IFS='|' read -r topic reference; do
        if [ ! -f "$CONTENT_DIR/$reference" ]; then
            echo "ERROR: Missing reference: $reference" >&2
            rm -f "$body_file" "$updated_file"
            return 1
        fi
        printf '| %s | [`%s`](references/%s) |\n' "$topic" "$reference" "$reference" >> "$body_file"
    done << 'EOF'
Comma rules|rettskriving-og-grammatikk/kommaregler.md
Capitalization|rettskriving-og-grammatikk/stor-eller-liten-forbokstav.md
Numbers, times, and dates|rettskriving-og-grammatikk/tall-tid-dato.md
Compound words|rettskriving-og-grammatikk/bindebokstaver-i-sammensatte-ord.md
Å versus og|rettskriving-og-grammatikk/a-eller-og.md
Da versus når|rettskriving-og-grammatikk/da-eller-nar.md
De versus dem|rettskriving-og-grammatikk/de-eller-dem.md
Plain language (Bokmål)|klarsprak-om-skriving/generelle-skriverad-bokmal.md
Plain language (Nynorsk)|klarsprak-om-skriving/generelle-skriverad-nynorsk.md
Language in digital services|klarsprak-om-skriving/sprak-i-digitale-tenester.md
Bureaucratic wording (Kansellisten)|praktisk-sprakbruk/kansellisten.md
Sensitive language|praktisk-sprakbruk/sensitive-ord.md
Gender-balanced language|praktisk-sprakbruk/kjonnsbalansert-sprak.md
EOF

    cat >> "$body_file" << EOF

## Other Questions

Search the ${qa_count} Q&A articles in \`references/spraksporsmal/\` by filename or keyword (for example, \`grep -rl 'keyword' references/spraksporsmal/\`). Read only the relevant answers. For other topics, consult [the reference index](references/INDEX.md).

For maintaining this skill and updating its sources, see [BUILDING.md](BUILDING.md).
EOF

    if ! awk -v body_file="$body_file" '
        BEGIN {
            start = "<!-- BEGIN GENERATED: scripts/generate-skill.sh -->"
            finish = "<!-- END GENERATED: scripts/generate-skill.sh -->"
        }
        $0 == start {
            if (begins++ || inside) invalid = 1
            print
            while ((getline line < body_file) > 0) print line
            close(body_file)
            inside = 1
            next
        }
        $0 == finish {
            if (!inside || ends++) invalid = 1
            inside = 0
            print
            next
        }
        !inside { print }
        END {
            if (begins != 1 || ends != 1 || inside || invalid) {
                print "ERROR: Expected exactly one pair of generated-section markers in SKILL.md" > "/dev/stderr"
                exit 1
            }
        }
    ' "$SKILL_FILE" > "$updated_file"; then
        rm -f "$body_file" "$updated_file"
        return 1
    fi

    chmod 644 "$updated_file"
    mv "$updated_file" "$SKILL_FILE"
    rm -f "$body_file"
    log "Skill generated: $SKILL_FILE"
}

# ── Main ──

case "${1:-}" in
    --index-only) generate_index; exit 0 ;;
    --skill-only) generate_skill; exit 0 ;;
    "") generate_index; generate_skill ;;
    *) echo "Usage: scripts/generate-skill.sh [--index-only|--skill-only]" >&2; exit 1 ;;
esac

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
