#!/usr/bin/env bash
# Offline integration test for the Chrome scraper's staging and publish behavior.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR=$(mktemp -d "${TMPDIR:-/tmp}/scrape-chrome-test.XXXXXX")
trap 'status=$?; if [ "$status" -ne 0 ] && [ -f "$TEST_DIR/log" ]; then cat "$TEST_DIR/log" >&2; fi; rm -rf "$TEST_DIR"' EXIT
mkdir -p "$TEST_DIR/references"

cat > "$TEST_DIR/mock-mcp" <<'EOF'
#!/usr/bin/env node
const site = 'https://sprakradet.no';
const paths = [
  '/godt-og-korrekt-sprak/rettskriving-og-grammatikk/kommaregler/',
  '/godt-og-korrekt-sprak/rettskriving-og-grammatikk/stor-eller-liten-forbokstav/',
  '/godt-og-korrekt-sprak/rettskriving-og-grammatikk/tall-tid-dato/',
  '/godt-og-korrekt-sprak/rettskriving-og-grammatikk/bindebokstaver-i-sammensatte-ord/',
  '/godt-og-korrekt-sprak/rettskriving-og-grammatikk/a-eller-og/',
  '/godt-og-korrekt-sprak/rettskriving-og-grammatikk/da-eller-nar/',
  '/godt-og-korrekt-sprak/rettskriving-og-grammatikk/de-eller-dem/',
  '/godt-og-korrekt-sprak/praktisk-sprakbruk/eksempel/',
  '/godt-og-korrekt-sprak/praktisk-sprakbruk/kansellisten/',
  '/godt-og-korrekt-sprak/praktisk-sprakbruk/sensitive-ord/',
  '/godt-og-korrekt-sprak/praktisk-sprakbruk/kjonnsbalansert-sprak/',
  '/klarsprak/om-skriving/eksempel/',
  '/klarsprak/om-skriving/generelle-skriverad-bokmal/',
  '/klarsprak/om-skriving/generelle-skriverad-nynorsk/',
  '/klarsprak/om-skriving/sprak-i-digitale-tenester/',
  '/godt-og-korrekt-sprak/ordlister-og-ordboker/eksempel/',
];
const { createInterface } = await import('node:readline');
for await (const line of createInterface({ input: process.stdin })) {
  const request = JSON.parse(line);
  if (!request.id) continue;
  let result;
  if (request.method === 'initialize') result = { protocolVersion: '2025-03-26', capabilities: {}, serverInfo: { name: 'mock', version: '1' } };
  if (request.method === 'tools/call') {
    let text;
    if (request.params.name === 'list_pages') {
      text = `## Pages\n4: XML Sitemap (${site}/page-sitemap.xml) [selected]`;
    } else {
      const source = request.params.arguments.function;
      const urls = JSON.parse(source.match(/Promise\.all\((\[[^\n]*\])\.map/)[1]);
      const responses = urls.map((url) => {
        const pathname = new URL(url).pathname;
        if (process.env.MOCK_FAIL_PAGE && pathname === paths[0]) return { url, status: 403, body: 'Forbidden' };
        let locations;
        if (pathname === '/page-sitemap.xml') locations = process.env.MOCK_MISSING_TOPIC
          ? paths.filter((path) => !path.endsWith('/kjonnsbalansert-sprak/')) : paths;
        else if (pathname.startsWith('/sprakspoersmal-sitemap')) locations = [`/spraksporsmal-og-svar/eksempel-${pathname.match(/sitemap(\d*)/)[1] || '1'}/`, '/spraksporsmal-og-svar/'];
        const body = locations
          ? `<urlset>${locations.map((loc) => `<loc>${site}${loc}</loc>`).join('')}</urlset>`
          : '<html><main><h1>Test page</h1><p>Useful language guidance.</p></main></html>';
        return { url, status: 200, body };
      });
      text = `Script ran on page and returned:\n\`\`\`json\n${JSON.stringify(responses)}\n\`\`\``;
    }
    result = { content: [{ type: 'text', text }] };
  }
  process.stdout.write(`${JSON.stringify({ jsonrpc: '2.0', id: request.id, result })}\n`);
}
EOF
chmod +x "$TEST_DIR/mock-mcp"

export CHROME_MCP_BIN="$TEST_DIR/mock-mcp"
export SCRAPE_OUTPUT_DIR="$TEST_DIR/references"
export SCRAPE_SKILL_FILE="$TEST_DIR/SKILL.md"
cp "$SCRIPT_DIR/../SKILL.md" "$SCRAPE_SKILL_FILE"
printf 'original references\n' > "$SCRAPE_OUTPUT_DIR/keep.txt"

if MOCK_FAIL_PAGE=1 node "$SCRIPT_DIR/scrape-chrome.mjs" > "$TEST_DIR/log" 2>&1; then
    echo 'Expected a failed fetch to stop the scrape' >&2
    exit 1
fi
grep -q 'original references' "$SCRAPE_OUTPUT_DIR/keep.txt"
! grep -q '3 Q&A articles' "$SCRAPE_SKILL_FILE"

if MOCK_MISSING_TOPIC=1 node "$SCRIPT_DIR/scrape-chrome.mjs" > "$TEST_DIR/log" 2>&1; then
    echo 'Expected a missing skill reference to stop the scrape' >&2
    exit 1
fi
grep -q 'original references' "$SCRAPE_OUTPUT_DIR/keep.txt"
! grep -q '3 Q&A articles' "$SCRAPE_SKILL_FILE"

node "$SCRIPT_DIR/scrape-chrome.mjs" > "$TEST_DIR/log" 2>&1
test ! -e "$SCRAPE_OUTPUT_DIR/keep.txt"
test "$(find "$SCRAPE_OUTPUT_DIR" -name '*.md' | wc -l | tr -d ' ')" -eq 20
grep -q 'kommaregler.md' "$SCRAPE_OUTPUT_DIR/INDEX.md"
grep -q '3 Q&A articles' "$SCRAPE_SKILL_FILE"
echo 'Chrome scrape integration checks passed.'
