# Building the Norwegian Writing Skill

This document explains how the `norwegian-writing` skill is built: where the content comes from, how the scraping pipeline works, and how to maintain and extend it.

## Architecture Overview

```
scripts/scrape.sh          ← Orchestrates the full pipeline
    ↓ curl
sprakradet.no HTML pages   ← Source: Norwegian government language authority
    ↓ pipe
scripts/convert.mjs        ← HTML → clean markdown (turndown)
    ↓ write
references/**/*.md         ← Output: organized by section
    ↓
scripts/generate-skill.sh  ← Generates INDEX.md with token counts
```

The pipeline produces two layers of content:

1. **SKILL.md** — A hand-written quick-reference (~300 lines) that agents always load. Contains the most important rules inline so they're available without extra file reads.
2. **references/** — Detailed reference files (~80k tokens across ~35 files) scraped from sprakradet.no. Agents load these on demand when they need deeper information.

## Prerequisites

- **Node.js** (any recent version)
- **curl** (for fetching pages)

Dependencies are installed automatically by `scrape.sh`, or manually:

```bash
cd skills/norwegian-writing
npm install
```

This installs [turndown](https://github.com/mixmark-io/turndown) — the only dependency — for HTML-to-markdown conversion.

## Running a Full Scrape

```bash
cd skills/norwegian-writing
bash scripts/scrape.sh
```

This will:

1. Delete and recreate `references/`
2. Fetch all pages from sprakradet.no (3 main sections + extras)
3. Convert each page to clean markdown via `convert.mjs`
4. Run quality validation (warns about long lines, small files, artifacts)
5. Generate `references/INDEX.md` with token estimates
6. Print a summary

Typical output: ~1,180 files, ~5.6MB, ~700k estimated tokens (~180k reference + ~520k Q&A).

## How Each Script Works

### `scripts/convert.mjs` — The HTML-to-Markdown Converter

Takes full HTML on stdin, outputs clean markdown on stdout. This is the core of the pipeline.

**What it does:**

1. **Extracts `<main>` content** — ignores headers, footers, sidebars
2. **Strips non-content HTML** before conversion:
   - Feedback forms (`<section class="bottom-form">`)
   - Scripts, styles, SVGs
   - "Til toppen" (back-to-top) figcaptions
   - Download link sections (WordPress block)
   - Breadcrumb navigation
   - Search widgets
3. **Converts with Turndown** using custom rules:
   - **Tables** → proper markdown tables with `|` pipes and `---` separator. Cell content preserves bold/italic and uses `<br>` for line breaks within cells.
   - **`<q>` tags** → Norwegian quotes `«»`
   - **`<br>` tags** → actual line breaks (not Turndown's default `\n`)
4. **Post-processes the markdown:**
   - Removes remaining breadcrumb link lists
   - Strips standalone "Søk" lines and download prompts
   - Removes empty headings (heading with no content before next heading)
   - Removes empty "Relaterte sider/artikler" and "Fra svarbasen" sections
   - Adds page title as `# h1` if not already present
   - Collapses excessive blank lines

**Why Turndown instead of sed?** The original pipeline used `sed` chains to strip HTML tags, which produced unreadable output for tables (the Kansellisten was a wall of text) and mangled multi-line examples. Turndown properly parses the DOM and handles nested elements.

**Testing the converter in isolation:**

```bash
curl -s "https://sprakradet.no/godt-og-korrekt-sprak/rettskriving-og-grammatikk/kommaregler/" \
  | node scripts/convert.mjs
```

### `scripts/scrape.sh` — The Scrape Orchestrator

**Section discovery:** The scraper fetches the [page sitemap](https://sprakradet.no/page-sitemap.xml) and filters URLs by section prefix. This is more reliable than scraping links from landing pages — it catches nested subpages (like `tegn/apostrof/`) and new pages automatically.

**Sections scraped:**

| Section | URL pattern | Output directory |
|---------|------------|-----------------|
| Rettskriving og grammatikk | `godt-og-korrekt-sprak/rettskriving-og-grammatikk/*` | `rettskriving-og-grammatikk/` |
| Praktisk språkbruk | `godt-og-korrekt-sprak/praktisk-sprakbruk/*` | `praktisk-sprakbruk/` |
| Klarspråk – Om skriving | `klarsprak/om-skriving/*` | `klarsprak-om-skriving/` |
| Ordlister | `godt-og-korrekt-sprak/ordlister-og-ordboker/*` | `ordlister/` |

Additionally, **Q&A articles** are scraped from three dedicated sitemaps (`sprakspoersmal-sitemap.xml`, `sprakspoersmal-sitemap2.xml`, `sprakspoersmal-sitemap3.xml`) into `spraksporsmal/`. These contain ~1,100 real questions and authoritative answers from Språkrådet's advisory service.

Nested pages (e.g., `tegn/apostrof/`, `nynorskhjelp/s-genitiv/`) are preserved as subdirectories in the output.

**Skip list:** Some pages are skipped because they have no reference value:

- `svadagenerator` — interactive toy, no content
- `har-du-eit-spraksporsmal` — "do you have a question?" form page
- `cielga-giella` — Sami language page (out of scope for this skill)

**Deduplication:** Kansellisten appears under both "praktisk-sprakbruk" and "ordlister" on the site. Since sections are defined by URL prefix, it naturally lands in `praktisk-sprakbruk/` only (it's not under the `ordlister-og-ordboker/` URL path).

**Source attribution:** Each output file ends with:
```
---
Kilde: https://sprakradet.no/...
```

**Validation checks:**
- Lines longer than 500 chars (suggests broken table/list conversion)
- "Til toppen" artifacts (navigation remnants)
- Files with fewer than 10 content lines (possibly empty pages)

### `scripts/generate-skill.sh` — Index Generator

Generates `references/INDEX.md` listing every reference file with:
- Relative link to the file
- Title (from first `# heading`)
- Estimated token count (~4 chars/token for Norwegian)

Also has a `--index-only` mode (used by `scrape.sh`) and a full mode that prints per-file quality metrics.

```bash
bash scripts/generate-skill.sh          # Full summary with metrics
bash scripts/generate-skill.sh --index-only  # Just regenerate INDEX.md
```

## Content Design Decisions

### Why two layers (SKILL.md + references)?

SKILL.md is always loaded by the agent — it needs to be compact enough to fit in context alongside other instructions. The ~300-line quick reference covers the rules an agent needs most often (comma rules, capitalization, common word confusions, Kansellisten highlights).

The `references/` directory has the full, detailed content (~80k tokens). Agents read individual files on demand when they need specifics — e.g., reading `preposisjonsbruk.md` (14k tokens) only when helping with preposition usage.

### Why not scrape more sections?

Språkrådet has many more pages (language policy, news, organization info). We only scrape pages that contain actionable writing guidance — rules, examples, and word lists that an agent can apply directly.

### Table format for word lists

The Kansellisten and similar pages use HTML tables with two columns: "avoid" and "use instead". The converter produces proper markdown tables:

```markdown
| PRØV Å UNNGÅ | SKRIV HELLER |
| --- | --- |
| **anbringe** | **sette, legge, plassere, feste** |
| Oblaten anbringes på frontruten. | Oblaten settes/festes på frontruten. |
```

Bold entries are the headwords; non-bold rows are usage examples.

## Extending the Skill

### Adding a new section to scrape

In `scrape.sh`, add a line to the `SECTIONS` variable:

```bash
SECTIONS="
rettskriving-og-grammatikk|godt-og-korrekt-sprak/rettskriving-og-grammatikk/
praktisk-sprakbruk|godt-og-korrekt-sprak/praktisk-sprakbruk/
klarsprak-om-skriving|klarsprak/om-skriving/
ordlister|godt-og-korrekt-sprak/ordlister-og-ordboker/
new-section|path/on/sprakradet.no/
"
```

The left side is the local directory name, the right side is the URL path prefix to match in the sitemap. All sitemap URLs under that prefix will be scraped automatically, including nested subpages.

### Adding individual pages

For one-off pages outside any section, add a direct `scrape_page` call after the main section loop in `scrape.sh`:

```bash
scrape_page \
    "https://sprakradet.no/path/to/page/" \
    "$OUTPUT_DIR/section-name/page-name.md"
```

### Adding pages to the skip list

Add the page slug to the `SKIP_SLUGS` variable in `scrape.sh`:

```bash
SKIP_SLUGS="svadagenerator har-du-eit-spraksporsmal cielga-giella new-page-to-skip"
```

### Handling new HTML patterns

If sprakradet.no introduces new HTML structures that don't convert well, add a Turndown rule in `convert.mjs`:

```javascript
td.addRule('ruleName', {
  filter: 'element-name',  // or a function: (node) => node.matches('.some-class')
  replacement: function (content, node) {
    return '/* your markdown output */';
  },
});
```

Or add HTML stripping before conversion:

```javascript
mainHtml = mainHtml.replace(/<unwanted-element[\s\S]*?<\/unwanted-element>/gi, '');
```

### Updating SKILL.md

SKILL.md is **hand-written**, not generated. When reference content changes significantly, review and update the quick-reference sections manually. Key sections to keep in sync:

- Kansellisten table (curated subset of the full list)
- Comma rules summary
- Capitalization rules
- Any rules that changed in new Språkrådet guidance

## Troubleshooting

**"No `<main>` element found"** — The page structure changed. Check the HTML with `curl -s URL | grep -i '<main'` and update the regex in `convert.mjs`.

**Tables rendering as flat text** — The `<table>` rule in `convert.mjs` may not be matching. Check if the table uses non-standard markup (e.g., `<div>` grids instead of `<table>`).

**Long-line warnings** — Usually means a table or list wasn't properly converted. Check the specific file and compare against the source HTML.

**Empty/tiny files** — The page may be a redirect, a form, or an interactive element with no static content. Add it to the skip list.
