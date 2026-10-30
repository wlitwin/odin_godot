import { readFile, writeFile, mkdir, copyFile, access, readdir, unlink } from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { createServer } from 'node:http';
import { fileURLToPath } from 'node:url';
import { execFileSync } from 'node:child_process';
import { Marked, Renderer } from 'marked';
import GithubSlugger from 'github-slugger';
import hljs from 'highlight.js';
import { documentationIndex } from './build-index.mjs';
import { readerPath, relative, siteHeader, docsSidebar, siteFooter, contentFiles, contentRoot, navigationFiles, navGroups } from './site-structure.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const posix = path.posix;
const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
const plain = tokens => (tokens || []).map(token => token.tokens ? plain(token.tokens) : token.text || '').join('');
const sourceExtensions = new Set(['.md', '.odin', '.gd', '.sh', '.ps1', '.tscn', '.godot', '.json', '.toml', '.txt', '.h', '.c', '.ini']);
const imageExtensions = new Set(['.svg', '.png', '.jpg', '.jpeg', '.webp', '.gif']);
const languageNames = { sh: 'Shell', bash: 'Shell', odin: 'Odin', gdscript: 'GDScript', gd: 'GDScript', ini: 'Configuration', json: 'JSON', text: 'Text', '': 'Code' };
hljs.registerLanguage('odin', hl => ({
  name: 'Odin', aliases: ['odin'],
  keywords: { keyword: 'package import foreign proc struct enum union bit_set bit_field distinct dynamic map matrix using in not_in for if else when switch case break continue fallthrough return defer do where cast transmute auto_cast or_else or_return or_break or_continue context', literal: 'true false nil', type: 'bool b8 b16 b32 b64 int uint uintptr rawptr string cstring rune byte i8 i16 i32 i64 i128 u8 u16 u32 u64 u128 f16 f32 f64 complex64 complex128 any typeid' },
  contains: [hl.C_LINE_COMMENT_MODE, hl.C_BLOCK_COMMENT_MODE, hl.QUOTE_STRING_MODE, hl.APOS_STRING_MODE, { className: 'string', begin: '`', end: '`' }, hl.C_NUMBER_MODE, { className: 'meta', begin: '@\\(', end: '\\)' }, { className: 'meta', begin: '#[A-Za-z_]\\w*' }]
}));
const featureInfo = {
  'docs/getting-started.md': ['The first Odin script', 'Install the toolchain, connect the extension, and attach a compiled script to a Godot node.'],
  'docs/onboarding/02-thinking-in-structs.md': ['Thinking in structs', 'Keep script state, free procedures, and engine nodes separate.'],
  'docs/onboarding/04-verbs-not-rpcs.md': ['Writing a Kit command', 'Predict the target mutation. Let authority settle the request and commit its consequences.'],
  'docs/kit/quickstart.md': ['The first two-peer game', 'Build a cooperative game with two players, replicated entities, and commands.'],
  'docs/kit/quickstart-sim.md': ['Server authority and prediction', 'Move the cooperative square to a fixed tick, then predict its movement on the client.'],
  'docs/kit/timelines.md': ['Choosing a timeline', 'Decide whose simulation drives each object and which moment each screen displays.'],
  'docs/replay/architecture.md': ['The Replay frame contract', 'Define the state stored at each tick, the inputs used to advance it, and the rules for restoring it.'],
  'docs/replay/owner-streams.md': ['Cooperative body ownership', 'Record accepted Godot body observations and track who may produce them before and after a handoff.'],
  'docs/replay/framework-audit.md': ['Replay implementation and test scope', 'Implemented contracts, tested configurations, and remaining support limits.'],
  'replay/getting-started.md': ['Starting a Replay game', 'Choose Timeline, Session, or Room to run the game, then connect its World to input and Godot scenes.'],
  'replay/view/README.md': ['Presenting Replay state', 'Read simulation frames and match recorded events across corrections while keeping display state separate.'],
  'examples/hello_net/scripts/player.odin': ['A cooperative player', 'The complete player script from Hello Net. Ownership tags determine which machine writes each field.'],
  'examples/hello_sim/scripts/player.odin': ['A predicted player', 'The same square moved to the authoritative simulation lane, with typed input and a fixed tick.'],
  'examples/replay_loot/game/game.odin': ['The Loot world', 'Players, entity lifetime, inventories, and RNG live in one replayable model.'],
  'examples/replay_loot/main.odin': ['Correcting the Loot timeline', 'Run a prediction, revise its winning input, and compare the result with an independent run.'],
  'examples/replay_hello/shared/hello/network.odin': ['The Hello network model', 'Input validation, action handling, and the server/client model used by the network example.']
};
function category(file) {
  if (file.startsWith(contentRoot)) return navGroups.find(([, items]) => items.some(([, target]) => target === file))?.[0] || 'Guides';
  if (file.startsWith('docs/kit/') || file.startsWith('kit/')) return 'Kit';
  if (file.includes('replay')) return 'Replay';
  if (file.startsWith('docs/onboarding/')) return 'Odin in Godot';
  if (file.startsWith('examples/')) return 'Examples';
  if (file.startsWith('tests/')) return 'Validation';
  return 'Odin × Godot';
}
function sourceLanguage(file) { return ({'.odin':'odin','.gd':'gdscript','.sh':'bash','.ps1':'powershell','.tscn':'ini','.godot':'ini','.json':'json','.toml':'ini','.h':'c','.c':'c','.ini':'ini'})[posix.extname(file)] || 'text'; }
function highlight(code, language) { return hljs.getLanguage(language) ? hljs.highlight(code, { language, ignoreIllegals: true }).value : escape(code); }
function codeBlock(code, language = '') {
  const name = languageNames[language] || language || 'Code';
  return `<div class="code-block"><div class="code-title"><span>${escape(name)}</span><button class="copy-code" type="button">Copy</button></div><pre><code class="language-${escape(language)}">${highlight(code, language)}</code></pre></div>`;
}

export async function buildReaders({ root, dist, seeds, revision, dirty, date }) {
  const tracked = new Set(execFileSync('git', ['ls-files'], { cwd: root, encoding: 'utf8' }).trim().split('\n'));
  for (const file of seeds) tracked.add(file);
  const files = new Map(), assets = new Set(), pending = [...seeds];
  function resolveLink(file, href) {
    if (!href || href.startsWith('#')) return { anchor: href || '' };
    if (/^(https?:|mailto:)/i.test(href)) return { external: href };
    if (/^[a-z][a-z\d+.-]*:/i.test(href)) return {};
    let url;
    try { url = new URL(href, `https://repository.invalid/${file}`); } catch { return {}; }
    let target;
    try { target = decodeURIComponent(url.pathname).replace(/^\//, ''); } catch { return {}; }
    if (!tracked.has(target) && !seeds.includes(target)) target = [target + '/README.md', target + '/index.md'].find(candidate => tracked.has(candidate)) || target;
    return { file: target, hash: url.hash };
  }
  // Follow document links, never parse fenced code as if it were Markdown.
  while (pending.length) {
    const file = pending.shift();
    if (files.has(file)) continue;
    const text = await readFile(path.join(root, file), 'utf8');
    const isMarkdown = file.endsWith('.md');
    const tokens = isMarkdown ? new Marked().lexer(text) : [];
    const firstHeading = tokens.find(token => token.type === 'heading' && token.depth === 1);
    const originalTitle = firstHeading ? plain(firstHeading.tokens) : posix.basename(file);
    const title = featureInfo[file]?.[0] || originalTitle;
    files.set(file, { file, text, isMarkdown, title, originalTitle, tokens, headings: [], links: [] });
    if (!isMarkdown) continue;
    new Marked().walkTokens(tokens, token => {
      if (token.type !== 'link' && token.type !== 'image') return;
      const link = resolveLink(file, token.href);
      if (!link.file || !tracked.has(link.file)) return;
      const ext = posix.extname(link.file).toLowerCase();
      if (imageExtensions.has(ext)) assets.add(link.file);
      else if (sourceExtensions.has(ext) && !files.has(link.file)) pending.push(link.file);
    });
  }
  // Precompute headings so cross-document fragments can be checked before rendering.
  for (const doc of files.values()) {
    const slugger = new GithubSlugger();
    new Marked().walkTokens(doc.tokens, token => {
      if (token.type === 'heading') doc.headings.push({ depth: token.depth, text: plain(token.tokens), id: slugger.slug(plain(token.tokens)) });
      if (token.type === 'html') for (const match of token.text.matchAll(/<(?:a|span)\s+(?:name|id)="([^"]+)"/g)) doc.headings.push({ depth: 0, text: '', id: match[1] });
    });
  }
  const diagramJobs = new Map();
  const pages = {}, titles = {};
  for (const doc of files.values()) { pages[doc.file] = readerPath(doc.file); titles[doc.file] = doc.title; }
  for (const asset of assets) { const dest = path.join(dist, 'reference', asset); await mkdir(path.dirname(dest), { recursive: true }); await copyFile(path.join(root, asset), dest); }
  for (const doc of files.values()) {
    const page = pages[doc.file];
    const url = target => relative(page, target);
    const renderer = new Renderer();
    const slugger = new GithubSlugger();
    const outgoing = [];
    const renderLink = (href, text, image = false) => {
      const link = resolveLink(doc.file, href);
      if (link.external) return image ? `<img src="${escape(link.external)}" alt="${escape(text)}" loading="lazy">` : `<a href="${escape(link.external)}" rel="noreferrer">${text}</a>`;
      if (link.anchor) {
        const valid = doc.headings.some(heading => heading.depth !== 1 && heading.id === decodeURIComponent(link.anchor.slice(1)));
        return `<a href="${escape(valid ? link.anchor : '#article')}">${text}</a>`;
      }
      if (files.has(link.file)) {
        const target = files.get(link.file);
        let hash = link.hash;
        if (hash && !target.headings.some(heading => heading.depth !== 1 && heading.id === decodeURIComponent(hash.slice(1)))) hash = '';
        if (link.file !== doc.file && !outgoing.includes(link.file)) outgoing.push(link.file);
        return `<a href="${escape(url(pages[link.file]) + hash)}">${text}</a>`;
      }
      if (assets.has(link.file)) return image ? `<img src="${escape(url('reference/' + link.file))}" alt="${escape(text)}" loading="lazy">` : `<a href="${escape(url('reference/' + link.file))}">${text}</a>`;
      // Local benchmark reports and generated files are not part of this publication.
      // Retain their citation text, rather than creating a broken navigation target.
      return `<span class="local-reference" title="${escape(link.file || href)} · available in the repository">${text}</span>`;
    };
    renderer.link = function(token) { return renderLink(token.href, this.parser.parseInline(token.tokens)); };
    renderer.image = token => renderLink(token.href, token.text, true);
    renderer.heading = function(token) {
      const id = slugger.slug(plain(token.tokens));
      if (token.depth === 1 && id === doc.headings.find(h => h.depth === 1)?.id) return '';
      const level = Math.min(6, token.depth);
      return `<h${level} id="${escape(id)}">${this.parser.parseInline(token.tokens)}<a class="heading-anchor" href="#${escape(id)}" aria-label="Link to this section">#</a></h${level}>\n`;
    };
    renderer.code = ({ text, lang = '' }) => {
      const language = lang.split(/\s/)[0].toLowerCase();
      if (language === 'mermaid') {
        const hash = createHash('sha256').update('sdk-diagrams-v2\n' + text).digest('hex').slice(0, 14);
        const asset = `diagrams/reading-${hash}.svg`;
        diagramJobs.set(hash, { source: text, asset, title: doc.title });
        return `<figure class="figure paper reading-diagram"><div class="figure-top"><span>SYSTEM DIAGRAM</span><span><a href="${url(asset)}" target="_blank" rel="noopener">Open full size ↗</a> · <a href="${url(asset)}" download>SVG ↓</a></span></div><img src="${url(asset)}" alt="System diagram: ${escape(doc.title)}" loading="lazy"></figure>`;
      }
      return codeBlock(text, language);
    };
    renderer.table = function(token) { return `<div class="table-scroll" tabindex="0" role="region" aria-label="Reference table">${Renderer.prototype.table.call(this, token)}</div>`; };
    renderer.html = ({ text }) => {
      if (/^\s*<!--/.test(text)) return '';
      const anchor = text.match(/^\s*<a\s+(?:name|id)="([^"]+)"\s*>(?:<\/a>)?\s*$/);
      if (anchor) return `<span id="${escape(anchor[1])}"></span>`;
      if (/^\s*<\/a>\s*$/.test(text)) return '';
      if (/^\s*<br\s*\/?>\s*$/.test(text)) return '<br>';
      return escape(text);
    };
    const md = new Marked({ renderer, gfm: true });
    const content = doc.isMarkdown ? md.parse(doc.text) : codeBlock(doc.text, sourceLanguage(doc.file));
    const toc = doc.headings.filter(h => h.depth === 2 || (h.depth === 3 && doc.headings.filter(h => h.depth === 2).length < 12));
    const count = doc.isMarkdown ? Math.max(1, Math.round(doc.text.replace(/```[\s\S]*?```/g, '').split(/\s+/).length / 210)) : null;
    const sourceFile = 'reference/' + doc.file;
    const summary = featureInfo[doc.file]?.[1];
    const related = outgoing.filter(file => files.get(file).isMarkdown).slice(0, 3);
    const outline = toc.map(h => `<a href="#${escape(h.id)}" class="${h.depth === 3 ? 'subsection' : ''}">${escape(h.text)}</a>`).join('');
    const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#ffffff"><title>${escape(doc.title)} · odin_godot</title>${summary ? `<meta name="description" content="${escape(summary)}">` : ''}<link rel="icon" href="${url('favicon.svg')}"><link rel="stylesheet" href="${url('style.css')}"><link rel="stylesheet" href="${url('reader.css')}"><link rel="stylesheet" href="${url('sdk.css')}"><script src="${url('reader.js')}" defer></script><script src="${url('site.js')}" defer></script></head>
<body class="sdk-docs"><a class="skip" href="#article">Skip to article</a>${siteHeader(page, doc.file.endsWith('/examples.md') ? 'examples' : 'docs', true)}
<div class="docs-layout">${docsSidebar(page, doc.file, files)}
<main class="docs-main" id="article"><div class="reader-hero"><div class="breadcrumbs"><a href="${url('docs.html')}">Docs</a><span>/</span><a href="${url('reading.html')}">${escape(category(doc.file))}</a><span>/</span><span>${doc.isMarkdown ? 'Guide' : 'Source'}</span></div><p class="eyebrow">${escape(category(doc.file))}</p><h1>${escape(doc.title)}</h1>${summary ? `<p class="reader-dek">${escape(summary)}</p>` : ''}<div class="reader-meta"><span>${count ? `${count} min read` : `${doc.text.split('\n').length} lines · ${languageNames[sourceLanguage(doc.file)] || 'Source'}`}</span><span>Odin × Godot</span><a href="${url(sourceFile)}" download>Page source ↓</a></div></div>
${toc.length ? `<details class="mobile-toc"><summary>On this page <span>↓</span></summary><nav>${toc.filter(h => h.depth === 2).map(h => `<a href="#${escape(h.id)}">${escape(h.text)}</a>`).join('')}</nav></details>` : ''}
<article class="reading-body ${doc.isMarkdown ? '' : 'source-article'}">${content}</article>
<div class="reader-end"><p class="eyebrow">RELATED DOCUMENTATION</p>${related.map(file => `<a href="${url(pages[file])}"><span>${escape(files.get(file).title)}</span><span aria-hidden="true">→</span></a>`).join('')}<a href="${url('guide.html')}"><span>Illustrated multiplayer field guide</span><span aria-hidden="true">↗</span></a></div><p class="reader-provenance">${escape(doc.file)} · source ${revision.slice(0, 12)}${dirty ? ' with local changes' : ''}.</p>${siteFooter(page,true)}</main>
<aside class="page-outline" aria-label="On this page"><p>On this page</p><nav>${outline || '<a href="#article">Source example</a>'}</nav><div class="outline-actions"><a href="${url(sourceFile)}" download>Download source ↓</a><button type="button" data-print>Print this page</button><a href="${url('reading.html')}">Documentation index ↗</a></div></aside></div><div id="toast" role="status" aria-live="polite"></div></body></html>`;
    const destination = path.join(dist, page); await mkdir(path.dirname(destination), { recursive: true }); await writeFile(destination, html);
    const copy = path.join(dist, sourceFile); await mkdir(path.dirname(copy), { recursive: true }); await writeFile(copy, doc.text);
  }
  await renderDiagrams([...diagramJobs.values()], dist);
  const activeDiagrams = new Set([...diagramJobs.values()].map(job => posix.basename(job.asset)));
  for (const filename of await readdir(path.join(dist, 'diagrams'))) {
    if (/^reading-[a-f0-9]+\.svg$/.test(filename) && !activeDiagrams.has(filename)) await unlink(path.join(dist, 'diagrams', filename));
  }
  const featured = [...contentFiles, ...seeds.filter(file => /contributor-guide|quickstart-sim|replay\/getting-started/.test(file))];
  const manifest = { revision, dirty, date, featured, files: [...files.keys()], pages, titles };
  await writeFile(path.join(dist, 'reference-manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
  await writeFile(path.join(dist, 'reading.html'), documentationIndex(files, pages));
  console.log(`Built ${files.size} reading pages (${[...files.values()].filter(doc => doc.isMarkdown).length} documents), ${diagramJobs.size} diagrams, and the reading library.`);
  const primary = new Set(navigationFiles);
  const search = [...files.values()].map(doc => {
    const description = featureInfo[doc.file]?.[1] || doc.text.replace(/```[\s\S]*?```/g, '').replace(/^#+.*$/gm, '').replace(/[\[\]`*_]/g, '').trim().replace(/\s+/g, ' ').slice(0, 180);
    return { title: doc.title, category: category(doc.file), file: doc.file, path: pages[doc.file], description, primary: primary.has(doc.file), search: [doc.title, category(doc.file), doc.file, description, ...doc.headings.map(h => h.text)].join(' ').toLowerCase() };
  });
  search.unshift(
    { title: 'Documentation index', category: 'Site navigation', file: 'reading.html', path: 'reading.html', description: 'Every guide, reference page, game example, and source listing, grouped by topic.', primary: true, search: 'documentation index site map sitemap all pages browse guides references examples source listings' },
    { title: 'Illustrated multiplayer field guide', category: 'Guides', file: 'guide.html', path: 'guide.html', description: 'System diagrams and a correction you can step through, comparing Kit and Replay.', primary: true, search: 'illustrated multiplayer field guide kit replay diagrams correction lab' }
  );
  await writeFile(path.join(dist, 'search-index.json'), JSON.stringify(search));
  return manifest;
}

async function renderDiagrams(jobs, dist) {
  const missing = [];
  for (const job of jobs) { try { await access(path.join(dist, job.asset)); } catch { missing.push(job); } }
  if (!missing.length) return;
  const { default: puppeteer } = await import('puppeteer-core');
  const candidates = [process.env.GUIDE_CHROME, '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser'].filter(Boolean);
  let chrome;
  for (const candidate of candidates) { try { await access(candidate); chrome = candidate; break; } catch {} }
  if (!chrome) throw new Error('A new diagram needs Chrome. Set GUIDE_CHROME to its executable and run prepare.mjs again.');
  const server = createServer(async (request, response) => {
    if (request.url === '/') { response.writeHead(200, { 'Content-Type': 'text/html' }); response.end('<!doctype html><html><body><script src="/node_modules/mermaid/dist/mermaid.min.js"></script></body></html>'); return; }
    const file = path.resolve(here, '.' + decodeURIComponent(new URL(request.url, 'http://localhost').pathname));
    if (!file.startsWith(path.join(here, 'node_modules/mermaid/'))) { response.writeHead(404); response.end(); return; }
    try { const body = await readFile(file); response.writeHead(200, { 'Content-Type': 'text/javascript' }); response.end(body); } catch { response.writeHead(404); response.end(); }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await puppeteer.launch({ executablePath: chrome, headless: true });
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${server.address().port}/`, { waitUntil: 'networkidle0' });
    await page.evaluate(() => window.mermaid.initialize({ startOnLoad: false, securityLevel: 'strict', theme: 'base', fontFamily: '-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif', themeVariables: { primaryColor: '#e5eadd', primaryTextColor: '#202925', primaryBorderColor: '#9cab92', lineColor: '#58645c', secondaryColor: '#f1e4d8', tertiaryColor: '#fafbf7', background: '#fafbf7', fontSize: '14px' }, flowchart: { htmlLabels: false, curve: 'linear' } }));
    for (let i = 0; i < missing.length; i++) {
      const job = missing[i];
      const svg = await page.evaluate(async ({ source, id, title }) => {
        const result = await window.mermaid.render(id, source);
        const container = document.createElement('div');
        container.innerHTML = result.svg;
        const element = container.querySelector('svg');
        if (!element) throw new Error('The diagram renderer returned no SVG.');
        // Serialize the parsed DOM as XML. innerHTML leaves HTML void elements
        // such as <br> unclosed inside foreignObject, breaking standalone SVGs.
        const heading = document.createElementNS('http://www.w3.org/2000/svg', 'title');
        heading.textContent = title; element.prepend(heading);
        element.setAttribute('role', 'img');
        const serialized = new XMLSerializer().serializeToString(element);
        const parsed = new DOMParser().parseFromString(serialized, 'image/svg+xml');
        if (parsed.querySelector('parsererror')) throw new Error('Diagram is not valid XML.');
        if (/ﬂ°°|¶ß/.test(element.textContent)) throw new Error('Diagram contains unresolved entity placeholders.');
        const image = new Image();
        const objectURL = URL.createObjectURL(new Blob([serialized], { type: 'image/svg+xml' }));
        try {
          image.src = objectURL; await image.decode();
          if (!image.naturalWidth || !image.naturalHeight) throw new Error('Diagram has no image dimensions.');
        } finally { URL.revokeObjectURL(objectURL); }
        return serialized;
      }, { source: job.source, id: `diagram-${path.basename(job.asset, '.svg')}`, title: job.title });
      await writeFile(path.join(dist, job.asset), svg);
    }
  } finally { if (browser) await browser.close(); await new Promise(resolve => server.close(resolve)); }
}
