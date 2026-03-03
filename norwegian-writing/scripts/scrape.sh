#!/usr/bin/env bash
# Norwegian Writing Skill - Content Scraper
# Scrapes language guidance from Språkrådet (sprakradet.no)
# Uses the sitemap to discover all pages — no links are missed.
#
# Usage: scripts/scrape.sh
# Requires: Node.js with turndown installed (npm install in skill root)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_DIR="$SKILL_DIR/references"
CONVERTER="$SCRIPT_DIR/convert.mjs"

SITEMAP_URL="https://sprakradet.no/page-sitemap.xml"

# Additional sitemaps for Q&A content
QA_SITEMAPS="
https://sprakradet.no/sprakspoersmal-sitemap.xml
https://sprakradet.no/sprakspoersmal-sitemap2.xml
https://sprakradet.no/sprakspoersmal-sitemap3.xml
"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo "${GREEN}[INFO]${NC} $1"; }
warn() { echo "${YELLOW}[WARN]${NC} $1"; }
err()  { echo "${RED}[ERROR]${NC} $1"; }

# ── Check dependencies ──

if ! command -v node &> /dev/null; then
    err "Node.js is required. Install it first."
    exit 1
fi

if [ ! -d "$SKILL_DIR/node_modules/turndown" ]; then
    log "Installing dependencies..."
    (cd "$SKILL_DIR" && npm install)
fi

# ── Configuration ──

# Sections: "local-dir-name|url-path-prefix"
SECTIONS="
rettskriving-og-grammatikk|godt-og-korrekt-sprak/rettskriving-og-grammatikk/
praktisk-sprakbruk|godt-og-korrekt-sprak/praktisk-sprakbruk/
klarsprak-om-skriving|klarsprak/om-skriving/
ordlister|godt-og-korrekt-sprak/ordlister-og-ordboker/
"

# Pages to skip (by slug — the last path segment)
SKIP_SLUGS="svadagenerator har-du-eit-spraksporsmal cielga-giella"

# ── Helper functions ──

should_skip() {
    local slug="$1"
    for skip in $SKIP_SLUGS; do
        if [ "$slug" = "$skip" ]; then
            return 0
        fi
    done
    return 1
}

scrape_page() {
    local url="$1"
    local output_file="$2"

    log "Scraping: $url"

    local html
    html=$(curl -s "$url")

    if [ -z "$html" ]; then
        warn "Empty response from $url"
        return 1
    fi

    local md
    md=$(echo "$html" | node "$CONVERTER" 2>/dev/null)

    if [ -z "$md" ]; then
        warn "No content extracted from $url"
        return 1
    fi

    mkdir -p "$(dirname "$output_file")"

    printf '%s\n\n\n---\nKilde: %s\n' "$md" "$url" > "$output_file"
}

# ── Fetch sitemap ──

log "Fetching sitemap from $SITEMAP_URL ..."
ALL_URLS=$(curl -s "$SITEMAP_URL" | grep -o '<loc>[^<]*</loc>' | sed 's/<loc>//;s/<\/loc>//')

if [ -z "$ALL_URLS" ]; then
    err "Failed to fetch sitemap"
    exit 1
fi

url_count=$(echo "$ALL_URLS" | wc -l | tr -d ' ')
log "Found $url_count total pages in sitemap"

# ── Clean and rebuild ──

log "Output directory: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# ── Scrape each section ──

SCRAPED=0
SKIPPED=0

echo "$SECTIONS" | while IFS='|' read -r section_name prefix; do
    # Skip empty lines
    [ -z "$section_name" ] && continue

    log "Processing section: $section_name (prefix: $prefix)"

    # Filter sitemap URLs for this section
    echo "$ALL_URLS" | grep "https://sprakradet.no/${prefix}" | while read -r url; do
        # Get the slug (last path segment)
        slug=$(echo "$url" | sed 's|/$||' | sed 's|.*/||')

        # Get path relative to section prefix
        rel=$(echo "$url" | sed "s|https://sprakradet.no/${prefix}||" | sed 's|/$||')

        # Skip section landing pages (empty rel = the section root)
        if [ -z "$rel" ]; then
            continue
        fi

        # Skip blocklisted pages
        if should_skip "$slug"; then
            warn "Skipping: $slug"
            continue
        fi

        # Build output path: section-name/relative/path.md
        output_path="${section_name}/${rel}.md"

        scrape_page "$url" "$OUTPUT_DIR/$output_path"
    done
done

# ── Scrape Q&A pages ──

QA_DIR="$OUTPUT_DIR/spraksporsmal"
mkdir -p "$QA_DIR"

log "Fetching Q&A sitemaps..."
QA_URLS=""
for sitemap_url in $QA_SITEMAPS; do
    urls=$(curl -s "$sitemap_url" | grep -o '<loc>[^<]*</loc>' | sed 's/<loc>//;s/<\/loc>//')
    QA_URLS="$QA_URLS
$urls"
done

# Filter to actual Q&A pages (not the landing page)
QA_URLS=$(echo "$QA_URLS" | grep '/spraksporsmal-og-svar/[^/]' | sort -u)
qa_count=$(echo "$QA_URLS" | grep -c . || echo 0)
log "Found $qa_count Q&A pages"

echo "$QA_URLS" | while read -r url; do
    [ -z "$url" ] && continue

    slug=$(echo "$url" | sed 's|/$||;s|.*/||')

    if should_skip "$slug"; then
        warn "Skipping Q&A: $slug"
        continue
    fi

    scrape_page "$url" "$QA_DIR/${slug}.md"
done

# ── Post-scrape validation ──

log "Running post-scrape validation..."

ISSUES=0
while IFS= read -r -d '' file; do
    relpath="${file#$OUTPUT_DIR/}"

    max_line=$(awk '{ print length }' "$file" | sort -rn | head -1)
    if [ "$max_line" -gt 500 ]; then
        warn "Long line ($max_line chars) in $relpath"
        ISSUES=$((ISSUES + 1))
    fi

    if grep -q "Til toppen" "$file"; then
        warn "'Til toppen' artifact in $relpath"
        ISSUES=$((ISSUES + 1))
    fi

    content_lines=$(grep -cvE "^$|^---|^Kilde:" "$file" 2>/dev/null || echo 0)
    if [ "$content_lines" -lt 5 ]; then
        warn "Low content ($content_lines lines) in $relpath"
    fi

done < <(find "$OUTPUT_DIR" -name "*.md" -type f -print0)

# ── Generate INDEX.md ──

log "Generating index..."
"$SCRIPT_DIR/generate-skill.sh" --index-only

# ── Summary ──

echo ""
echo "${BLUE}=== Scrape Summary ===${NC}"
file_count=$(find "$OUTPUT_DIR" -name "*.md" -type f | wc -l | tr -d ' ')
total_size=$(du -sh "$OUTPUT_DIR" | cut -f1)
echo "  Files: $file_count"
echo "  Size:  $total_size"
if [ "$ISSUES" -gt 0 ]; then
    echo "  ${YELLOW}Warnings: $ISSUES${NC}"
else
    echo "  ${GREEN}No quality issues detected${NC}"
fi

total_chars=$(find "$OUTPUT_DIR" -name "*.md" -type f -exec cat {} + | wc -c | tr -d ' ')
est_tokens=$((total_chars / 4))
echo "  Estimated tokens: ~$est_tokens"
echo ""
echo "Done."
