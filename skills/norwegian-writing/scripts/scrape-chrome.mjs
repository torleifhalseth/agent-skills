#!/usr/bin/env node
// Fetch Språkrådet through one approved Chrome DevTools MCP connection.
// Requires the page sitemap to be open in a Chrome profile with remote debugging enabled.
import { spawn } from 'node:child_process';
import { createInterface } from 'node:readline';
import { copyFile, mkdtemp, mkdir, readdir, rename, rm, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

const skillDir = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const outputDir = process.env.SCRAPE_OUTPUT_DIR || path.join(skillDir, 'references');
const skillFile = process.env.SCRAPE_SKILL_FILE || path.join(skillDir, 'SKILL.md');
const site = 'https://sprakradet.no';
const sitemapPaths = ['/page-sitemap.xml', '/sprakspoersmal-sitemap.xml', '/sprakspoersmal-sitemap2.xml', '/sprakspoersmal-sitemap3.xml'];
const sections = [
  ['rettskriving-og-grammatikk', '/godt-og-korrekt-sprak/rettskriving-og-grammatikk/'],
  ['praktisk-sprakbruk', '/godt-og-korrekt-sprak/praktisk-sprakbruk/'],
  ['klarsprak-om-skriving', '/klarsprak/om-skriving/'],
  ['ordlister', '/godt-og-korrekt-sprak/ordlister-og-ordboker/'],
];
const skipped = new Set(['svadagenerator', 'har-du-eit-spraksporsmal', 'cielga-giella']);
const batchSize = 2;

function mcpConnection() {
  const command = process.env.CHROME_MCP_BIN || 'npx';
  const args = process.env.CHROME_MCP_BIN
    ? ['--autoConnect', '--no-usage-statistics']
    : ['--yes', 'chrome-devtools-mcp@1.12.0', '--autoConnect', '--no-usage-statistics'];
  const child = spawn(command, args, { stdio: ['pipe', 'pipe', 'pipe'] });
  child.stderr.on('data', (data) => {
    if (/error|failed/i.test(data.toString())) process.stderr.write(data);
  });
  let nextId = 0;
  const pending = new Map();
  createInterface({ input: child.stdout }).on('line', (line) => {
    let response;
    try { response = JSON.parse(line); } catch { return; }
    pending.get(response.id)?.(response);
    pending.delete(response.id);
  });
  child.on('exit', () => {
    for (const resolve of pending.values()) resolve({ error: { message: 'Chrome MCP disconnected' } });
    pending.clear();
  });

  function call(method, params = {}) {
    return new Promise((resolve, reject) => {
      const id = ++nextId;
      const timeout = setTimeout(() => {
        pending.delete(id);
        reject(new Error(`Chrome MCP timed out during ${method}`));
      }, 60_000);
      pending.set(id, (response) => {
        clearTimeout(timeout);
        if (response.error) reject(new Error(JSON.stringify(response.error)));
        else resolve(response.result);
      });
      child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id, method, params })}\n`);
    });
  }

  return {
    async start() {
      await call('initialize', { protocolVersion: '2025-03-26', capabilities: {}, clientInfo: { name: 'sprakradet-scraper', version: '1.0' } });
      child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', method: 'notifications/initialized', params: {} })}\n`);
    },
    async tool(name, args) {
      const result = await call('tools/call', { name, arguments: args });
      const text = result.content?.filter((item) => item.type === 'text').map((item) => item.text).join('\n') || '';
      if (result.isError) throw new Error(`${name}: ${text.slice(0, 1000)}`);
      return text;
    },
    close() { child.kill(); },
  };
}

function parseResult(text) {
  const json = text.match(/```json\s*([\s\S]*)\n```\s*$/);
  if (!json) throw new Error(`Unexpected Chrome MCP result: ${text.slice(0, 300)}`);
  return JSON.parse(json[1]);
}

function sitemapUrls(xml, sitemapPath) {
  const urls = [...xml.matchAll(/<loc>\s*([^<]+?)\s*<\/loc>/g)].map((match) => match[1].replaceAll('&amp;', '&'));
  if (!urls.length) throw new Error(`No URLs in ${sitemapPath}`);
  return urls;
}

function outputFiles(sitemaps) {
  const files = new Map();
  for (const [section, prefix] of sections) {
    let count = 0;
    for (const href of sitemaps[0]) {
      const url = new URL(href);
      if (url.origin !== site || !url.pathname.startsWith(prefix)) continue;
      const relative = url.pathname.slice(prefix.length).replace(/\/$/, '');
      if (!relative || skipped.has(relative.split('/').at(-1))) continue;
      if (relative.split('/').some((part) => part === '.' || part === '..')) throw new Error(`Unsafe path: ${href}`);
      files.set(path.join(section, `${relative}.md`), href);
      count++;
    }
    if (!count) throw new Error(`No content pages in ${section}`);
    console.log(`${section}: ${count} pages`);
  }
  const qaPrefix = '/spraksporsmal-og-svar/';
  const questions = new Set(sitemaps.slice(1).flat().filter((href) => {
    const url = new URL(href);
    return url.origin === site && url.pathname.startsWith(qaPrefix) && url.pathname !== qaPrefix;
  }));
  for (const href of questions) {
    const slug = new URL(href).pathname.replace(/\/$/, '').split('/').at(-1);
    if (!slug || skipped.has(slug)) continue;
    const filename = path.join('spraksporsmal', `${slug}.md`);
    if (files.has(filename)) throw new Error(`Duplicate output file: ${filename}`);
    files.set(filename, href);
  }
  if (!questions.size) throw new Error('No Q&A pages found');
  console.log(`spraksporsmal: ${questions.size} pages`);
  return files;
}

async function convert(html) {
  const child = spawn(process.execPath, [path.join(skillDir, 'scripts', 'convert.mjs')], { stdio: ['pipe', 'pipe', 'pipe'] });
  let stdout = '';
  let stderr = '';
  child.stdout.setEncoding('utf8').on('data', (chunk) => { stdout += chunk; });
  child.stderr.setEncoding('utf8').on('data', (chunk) => { stderr += chunk; });
  child.stdin.end(html);
  const code = await new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('close', resolve);
  });
  if (code !== 0 || !stdout.trim()) throw new Error(`HTML conversion failed: ${stderr.trim()}`);
  return stdout.trim();
}

async function main() {
  const mcp = mcpConnection();
  let staging = '';
  let backup = '';
  let stagedSkill = '';
  try {
    await mcp.start();
    // Read only the Språkrådet sitemap tab; do not navigate or inspect other tabs.
    const tabs = await mcp.tool('list_pages', {});
    const tab = tabs.split('\n').find((line) => line.includes(`(${site}/page-sitemap.xml)`));
    if (!tab) throw new Error(`Open ${site}/page-sitemap.xml in Chrome first`);
    const pageId = Number(tab.match(/^\s*(\d+):/)?.[1]);
    if (!pageId) throw new Error('Could not identify the sitemap tab');

    async function fetchBatch(urls) {
      for (const url of urls) if (new URL(url, site).origin !== site) throw new Error(`Unexpected host: ${url}`);
      const script = `async () => Promise.all(${JSON.stringify(urls)}.map(async (url) => {
        try {
          const response = await fetch(url, { credentials: 'same-origin', signal: AbortSignal.timeout(20000) });
          return { url, status: response.status, body: await response.text() };
        } catch (error) { return { url, error: String(error) }; }
      }))`;
      const text = await mcp.tool('evaluate_script', { pageId, function: script, waitForStableDom: false });
      const responses = parseResult(text);
      if (!Array.isArray(responses) || responses.length !== urls.length) throw new Error('Incomplete browser response');
      for (const response of responses) {
        if (response.error || response.status !== 200 || !response.body) {
          throw new Error(`Failed to fetch ${response.url}: ${response.error || `HTTP ${response.status}`}`);
        }
      }
      return responses;
    }

    const sitemaps = [];
    for (const sitemapPath of sitemapPaths) {
      const [response] = await fetchBatch([`${site}${sitemapPath}`]);
      sitemaps.push(sitemapUrls(response.body, sitemapPath));
      console.log(`${sitemapPath}: ${sitemaps.at(-1).length} URLs`);
    }
    const files = outputFiles(sitemaps);
    const priorCount = await countMarkdown(outputDir);
    if (priorCount && files.size < priorCount * 0.75) throw new Error(`Only ${files.size} pages found versus ${priorCount} existing references; refusing to publish`);

    staging = await mkdtemp(`${outputDir}.staging.`);
    const entries = [...files];
    for (let i = 0; i < entries.length; i += batchSize) {
      const group = entries.slice(i, i + batchSize);
      const responses = await fetchBatch(group.map(([, href]) => href));
      for (let j = 0; j < group.length; j++) {
        const [filename, href] = group[j];
        const markdown = await convert(responses[j].body);
        if (markdown.length < 20) console.warn(`Short content (${markdown.length} chars): ${href}`);
        const destination = path.join(staging, filename);
        await mkdir(path.dirname(destination), { recursive: true });
        await writeFile(destination, `${markdown}\n\n\n---\nKilde: ${href}\n`);
      }
      if (i < batchSize) console.log('Pilot pages converted successfully; continuing with the full scrape.');
      if ((i + group.length) % 50 < batchSize || i + group.length === entries.length) console.log(`Converted ${i + group.length}/${entries.length}`);
      if (i + group.length < entries.length) await new Promise((resolve) => setTimeout(resolve, 750));
    }

    await runGenerator(staging, '--index-only');
    if (await countMarkdown(staging) !== entries.length + 1) throw new Error('Index or reference files missing from staging');
    stagedSkill = `${skillFile}.staging.${randomUUID()}`;
    await copyFile(skillFile, stagedSkill);
    await runGenerator(staging, '--skill-only', stagedSkill);

    backup = `${outputDir}.backup.${randomUUID()}`;
    if (await exists(outputDir)) await rename(outputDir, backup);
    else backup = '';
    await rename(staging, outputDir);
    staging = '';
    try {
      await rename(stagedSkill, skillFile);
      stagedSkill = '';
    } catch (error) {
      await rm(outputDir, { recursive: true });
      if (backup) { await rename(backup, outputDir); backup = ''; }
      throw error;
    }
    if (backup) { await rm(backup, { recursive: true }); backup = ''; }
    console.log(`Published ${entries.length} references and updated INDEX.md and SKILL.md`);
  } finally {
    mcp.close();
    if (backup) {
      try { await stat(outputDir); } catch { await rename(backup, outputDir); backup = ''; }
    }
    if (staging) await rm(staging, { recursive: true, force: true });
    if (stagedSkill) await rm(stagedSkill, { force: true });
    if (backup) console.error(`Previous references retained at ${backup}`);
  }
}

async function countMarkdown(dir) {
  let count = 0;
  async function visit(current) {
    let entries;
    try { entries = await readdir(current, { withFileTypes: true }); } catch (error) {
      if (error.code === 'ENOENT') return;
      throw error;
    }
    for (const entry of entries) {
      if (entry.isDirectory()) await visit(path.join(current, entry.name));
      else if (entry.name.endsWith('.md')) count++;
    }
  }
  await visit(dir);
  return count;
}

async function exists(filename) {
  try { await stat(filename); return true; } catch (error) {
    if (error.code === 'ENOENT') return false;
    throw error;
  }
}

async function runGenerator(dir, mode, destination = skillFile) {
  const child = spawn('bash', [path.join(skillDir, 'scripts', 'generate-skill.sh'), mode], {
    env: { ...process.env, REFERENCE_DIR: dir, SKILL_FILE: destination },
    stdio: 'inherit',
  });
  const status = await new Promise((resolve, reject) => { child.on('error', reject); child.on('close', resolve); });
  if (status !== 0) throw new Error(`Generation failed: ${mode}`);
}

main().catch((error) => { console.error(error); process.exitCode = 1; });
