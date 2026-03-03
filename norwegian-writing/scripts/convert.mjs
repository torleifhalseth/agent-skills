import TurndownService from 'turndown';

// Read HTML from stdin
const chunks = [];
for await (const chunk of process.stdin) {
  chunks.push(chunk);
}
const html = Buffer.concat(chunks).toString('utf-8');

// Extract <main> content
const mainMatch = html.match(/<main[\s\S]*?>([\s\S]*)<\/main>/i);
if (!mainMatch) {
  console.error('No <main> element found');
  process.exit(1);
}
let mainHtml = mainMatch[1];

// Also try to extract the page title from <h1> outside main if not in main
let pageTitle = '';
const h1InMain = mainHtml.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
if (h1InMain) {
  pageTitle = h1InMain[1].replace(/<[^>]*>/g, '').trim();
}
if (!pageTitle) {
  const h1Match = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  if (h1Match) {
    pageTitle = h1Match[1].replace(/<[^>]*>/g, '').trim();
  }
}

// Remove feedback form
mainHtml = mainHtml.replace(/<section class="bottom-form">[\s\S]*?<\/section>/gi, '');

// Remove script/style/svg
mainHtml = mainHtml.replace(/<script[\s\S]*?<\/script>/gi, '');
mainHtml = mainHtml.replace(/<style[\s\S]*?<\/style>/gi, '');
mainHtml = mainHtml.replace(/<svg[\s\S]*?<\/svg>/gi, '');

// Remove "Til toppen" figcaptions
mainHtml = mainHtml.replace(/<figcaption[^>]*>[\s\S]*?Til toppen[\s\S]*?<\/figcaption>/gi, '');

// Remove download link sections
mainHtml = mainHtml.replace(
  /<section class="wp-block-create-block-link-columns[\s\S]*?<\/section>/gi,
  ''
);

// Remove breadcrumb navigation
mainHtml = mainHtml.replace(/<nav[^>]*class="[^"]*breadcrumb[^"]*"[\s\S]*?<\/nav>/gi, '');
mainHtml = mainHtml.replace(
  /<div[^>]*class="[^"]*breadcrumb[^"]*"[\s\S]*?<\/div>/gi,
  ''
);

// Remove search widgets
mainHtml = mainHtml.replace(/<form[^>]*class="[^"]*search[^"]*"[\s\S]*?<\/form>/gi, '');
mainHtml = mainHtml.replace(/<input[^>]*type="search"[^>]*>/gi, '');

// Configure Turndown
const td = new TurndownService({
  headingStyle: 'atx',
  bulletListMarker: '-',
  codeBlockStyle: 'fenced',
  emDelimiter: '*',
  strongDelimiter: '**',
});

// Keep <br> as line breaks
td.addRule('br', {
  filter: 'br',
  replacement: () => '\n',
});

// Table conversion to markdown tables
td.addRule('table', {
  filter: 'table',
  replacement: function (_content, node) {
    const rows = [];
    const headerRow = node.querySelector('thead tr');
    const bodyRows = node.querySelectorAll('tbody tr');

    if (headerRow) {
      const headers = Array.from(headerRow.querySelectorAll('th, td')).map((cell) =>
        cellToMd(cell)
      );
      rows.push('| ' + headers.join(' | ') + ' |');
      rows.push('| ' + headers.map(() => '---').join(' | ') + ' |');
    }

    for (const row of bodyRows) {
      const cells = Array.from(row.querySelectorAll('td, th')).map((cell) => cellToMd(cell));
      rows.push('| ' + cells.join(' | ') + ' |');
    }

    return '\n\n' + rows.join('\n') + '\n\n';
  },
});

// Skip table sub-elements — handled by table rule
for (const tag of ['thead', 'tbody', 'tr', 'td', 'th', 'figure', 'figcaption']) {
  td.addRule(tag, {
    filter: tag,
    replacement: (content) => content,
  });
}

// Handle <q> as Norwegian quotes
td.addRule('q', {
  filter: 'q',
  replacement: (content) => '«' + content + '»',
});

// Helper: convert cell innerHTML to inline markdown
function cellToMd(cell) {
  const inner = new TurndownService({
    headingStyle: 'atx',
    emDelimiter: '*',
    strongDelimiter: '**',
  });
  inner.addRule('br', { filter: 'br', replacement: () => '<br>' });
  const md = inner.turndown(cell.innerHTML || '').trim();
  // Escape pipes in cell content
  return md.replace(/\|/g, '\\|').replace(/\n/g, '<br>');
}

// Convert
let markdown = td.turndown(mainHtml);

// ── Post-processing cleanup ──

// Remove breadcrumb lists at the top (lines like "- [Hjem](...)" or "- [Kansellisten](...)")
markdown = markdown.replace(/^(?:\s*-\s+\[[^\]]*\]\([^)]*\)\s*\n){2,}/m, '');

// Remove standalone "Søk" lines
markdown = markdown.replace(/^\s*Søk\s*$/gm, '');

// Remove download prompts
markdown = markdown.replace(/^Her kan du laste ned .+$/gm, '');

// Remove "Om basen" boilerplate (repeated on every Q&A page)
markdown = markdown.replace(/^#{1,6} \*{0,2}Om basen\*{0,2}[\s\S]*$/m, '');

// Remove "Sist oppdatert:" lines
markdown = markdown.replace(/^Sist oppdatert: .+$/gm, '');

// Remove category link lists at end of Q&A pages (lines like "- [Preposisjonsbruk](../...)")
markdown = markdown.replace(/(?:^-\s+\[[^\]]+\]\(\.\.\/.+\)\s*\n)+/gm, '');

// Remove horizontal rules that were separators
markdown = markdown.replace(/^\* \* \*$/gm, '---');

// Remove empty "Relaterte" sections (heading + optional blank lines, no content before next heading)
markdown = markdown.replace(
  /^#{1,6} Relaterte (?:sider|artiklar|artikler)\s*\n(?:\s*\n)*(?=#{1,6} |---|\s*$)/gm,
  ''
);

// Remove empty "Fra svarbasen" sections
markdown = markdown.replace(
  /^#{1,6} Fra svarbasen\s*\n(?:\s*\n)*(?=#{1,6} |---|\s*$)/gm,
  ''
);

// Remove empty headings (heading followed only by blank lines then another heading or EOF)
// Be careful: only remove if truly empty (no content between this heading and next same-or-higher level)
const lines = markdown.split('\n');
const filtered = [];
let i = 0;
while (i < lines.length) {
  const headingMatch = lines[i].match(/^(#{1,6}) (.+)$/);
  if (headingMatch) {
    // Look ahead: is there any content before the next heading of same/higher level?
    const level = headingMatch[1].length;
    let j = i + 1;
    let hasContent = false;
    while (j < lines.length) {
      const nextHeading = lines[j].match(/^(#{1,6}) /);
      if (nextHeading && nextHeading[1].length <= level) break;
      if (lines[j].trim() !== '') {
        hasContent = true;
        break;
      }
      j++;
    }
    if (!hasContent) {
      // Skip this empty heading and its blank lines
      i = j;
      continue;
    }
  }
  filtered.push(lines[i]);
  i++;
}
markdown = filtered.join('\n');

// Add page title as h1 if not already present
if (pageTitle && !markdown.match(/^# /m)) {
  markdown = '# ' + pageTitle + '\n\n' + markdown;
}

// Clean up excessive blank lines (3+ → 2)
markdown = markdown.replace(/\n{3,}/g, '\n\n');

// Trim
markdown = markdown.trim();

console.log(markdown);
