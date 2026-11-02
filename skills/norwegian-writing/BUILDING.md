# Building the Norwegian Writing Skill

This document explains how the `norwegian-writing` skill is built: where the content comes from, how the scraping pipeline works, and how to maintain and extend it.

## Architecture Overview

```
scripts/scrape-chrome.mjs   ← Fetches sitemaps and pages through Chrome DevTools MCP
    ↓ Chrome session
sprakradet.no HTML pages   ← Source: Norwegian government language authority
    ↓
scripts/convert.mjs        ← HTML → clean markdown (turndown)
    ↓ write
references/**/*.md         ← Output: organized by section
    ↓
scripts/generate-skill.sh  ← Generates INDEX.md and the linked SKILL.md body
```

The pipeline produces two layers of content:

1. **SKILL.md** — A short workflow and topic guide. Its metadata and introduction are maintained manually; the section between generated markers is produced from curated links and the current Q&A count.
2. **references/** — Detailed reference files scraped from sprakradet.no. Agents load individual files on demand instead of loading the entire collection.

## Prerequisites

- **Node.js** (any recent version)
- **Chrome** with remote debugging enabled

Install the converter dependency before updating:

```bash
cd skills/norwegian-writing
npm install
```

This installs [turndown](https://github.com/mixmark-io/turndown) — the only dependency — for HTML-to-markdown conversion.

## Updating References

Open `https://sprakradet.no/page-sitemap.xml` in Chrome and enable remote debugging at `chrome://inspect/#remote-debugging`. Then, from the skill directory, run:

```bash
cd skills/norwegian-writing
npm install
node scripts/scrape-chrome.mjs
```

Approve Chrome's connection prompt and keep the sitemap tab and browser open until the scrape completes. Review the output and `git diff` afterward. The approval grants broad access to that browser profile, including other tabs and cookies; use it only in a trusted environment and turn off remote debugging when finished.

The scraper will:

1. Fetch the sitemaps and build a fresh copy alongside `references/`
2. Fetch pages from sprakradet.no (4 main sections plus Q&A) in small batches
3. Convert each page to clean markdown via `convert.mjs`
4. Warn about short pages and stop if a fetch or conversion fails
5. Generate `references/INDEX.md` with token estimates
6. Replace the old `references/` only if all required pages succeeded, then regenerate the linked section of `SKILL.md`

It uses one long-lived Chrome DevTools MCP connection and fetches two pages at a time with a short pause. It does **not** use a model to rewrite pages. The scraper reads only the Språkrådet sitemap tab and fetches only Språkrådet URLs. If any request fails, the existing references remain in place.

Run `bash scripts/test-scrape-chrome.sh` for an offline check of the browser pipeline. The approval dialog can reappear when a new Chrome MCP process connects; one scraper run keeps its connection open rather than reconnecting for each page.

Typical output: ~1,195 reference files plus the index, including ~1,130 Q&A articles.

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
node scripts/convert.mjs < saved-page.html
```

### `scripts/scrape-chrome.mjs` — The Browser Scraper

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

**Validation checks:** Failed requests and conversions abort without replacing existing references. The scraper warns about short pages and refuses to publish if the number of discovered pages drops sharply compared with the existing references.

### `scripts/generate-skill.sh` — Index and Skill Generator

Generates `references/INDEX.md` listing every reference file with:
- Relative link to the file
- Title (from first `# heading`)
- Estimated token count (~4 chars/token for Norwegian)

It also regenerates the marked section of `SKILL.md` with a concise workflow, verified reference links, and the current Q&A count. It does not summarize language rules automatically. `--index-only` is used while the Chrome scraper builds in a staging directory; `--skill-only` updates the skill after publishing. The default mode generates both and prints per-file quality metrics.

```bash
bash scripts/generate-skill.sh               # Regenerate both and print metrics
bash scripts/generate-skill.sh --index-only  # Just regenerate INDEX.md
bash scripts/generate-skill.sh --skill-only  # Just regenerate the SKILL.md body
```

Run `bash scripts/test-generate-skill.sh` to verify that generation is repeatable, preserves the manually maintained header, and refuses broken reference links or missing section markers.

## Content Design Decisions

### Why two layers (SKILL.md + references)?

SKILL.md is loaded when the skill is active, so it should stay compact. It tells agents how to find and use the detailed guidance instead of repeating rules that may change on the source site.

The `references/` directory contains the full, detailed content. Agents read individual files on demand when they need specifics — e.g., reading `preposisjonsbruk.md` only when helping with preposition usage.

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

In `scrape-chrome.mjs`, add an entry to the `sections` array:

```js
const sections = [
  ['rettskriving-og-grammatikk', '/godt-og-korrekt-sprak/rettskriving-og-grammatikk/'],
  ['praktisk-sprakbruk', '/godt-og-korrekt-sprak/praktisk-sprakbruk/'],
  ['klarsprak-om-skriving', '/klarsprak/om-skriving/'],
  ['ordlister', '/godt-og-korrekt-sprak/ordlister-og-ordboker/'],
  ['new-section', '/path/on/sprakradet.no/'],
];
```

The left side is the local directory name, the right side is the URL path prefix to match in the sitemap. All sitemap URLs under that prefix will be scraped automatically, including nested subpages.

### Adding pages to the skip list

Add the page slug to the `skipped` set in `scrape-chrome.mjs`:

```js
const skipped = new Set(['svadagenerator', 'har-du-eit-spraksporsmal', 'cielga-giella', 'new-page-to-skip']);
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

Edit the frontmatter and introduction in `SKILL.md` manually. Do not edit between the generated-section markers; update the topic links and workflow in `scripts/generate-skill.sh`, then run `bash scripts/generate-skill.sh --skill-only`. The generator checks that linked reference files exist and leaves `SKILL.md` unchanged if a link or marker is missing. Detailed linguistic advice belongs in the source references, not in the generated topic guide.

## Troubleshooting

**HTTP 403 on a sitemap or page** — Check that the sitemap is accessible in the connected Chrome profile. The scraper stops without replacing existing references. If the browser is also denied access, use an authorized network or ask the site administrator about access.

**"No `<main>` element found"** — The page structure changed. Inspect the page in Chrome and update the regex in `convert.mjs`.

**Tables rendering as flat text** — The `<table>` rule in `convert.mjs` may not be matching. Check if the table uses non-standard markup (e.g., `<div>` grids instead of `<table>`).

**Long-line warnings** — Usually means a table or list wasn't properly converted. Check the specific file and compare against the source HTML.

**Empty/tiny files** — The page may be a redirect, a form, or an interactive element with no static content. Add it to the skip list.
