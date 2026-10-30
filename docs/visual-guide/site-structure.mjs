import path from 'node:path';

export const contentRoot = 'docs/visual-guide/content/';
export const contentRoutes = {
  'start-here': 'docs.html', install: 'docs/install.html',
  'first-script': 'docs/first-script.html', 'existing-project': 'docs/existing-project.html',
  multiplayer: 'docs/multiplayer.html', 'kit-game': 'docs/kit.html',
  'replay-game': 'docs/replay.html', shipping: 'docs/exporting.html', examples: 'examples.html'
};
export const contentFiles = Object.keys(contentRoutes).map(name => `${contentRoot}${name}.md`);
export const readerPath = file => file.startsWith(contentRoot) && contentRoutes[path.posix.basename(file, '.md')]
  ? contentRoutes[path.posix.basename(file, '.md')] : `read/${file.replace(/\.md$/, '')}.html`;
export const relative = (from, to) => path.posix.relative(path.posix.dirname(from), to) || path.posix.basename(to);
export const escape = value => String(value).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
export const navGroups = [
  ['Get started', [
    ['Overview', `${contentRoot}start-here.md`], ['Installation', `${contentRoot}install.md`],
    ['Your first script', `${contentRoot}first-script.md`], ['Existing Godot projects', `${contentRoot}existing-project.md`]
  ]],
  ['Write gameplay', [
    ['Scripts and structs', 'docs/onboarding/02-thinking-in-structs.md'],
    ['Script API', 'docs/authoring-guide.md'], ['Signals and events', 'docs/events.md'],
    ['Editor workflow', 'docs/workflow.md'], ['Script modules', 'docs/modules.md']
  ]],
  ['Multiplayer', [
    ['Choose a model', `${contentRoot}multiplayer.md`], ['Build with Kit', `${contentRoot}kit-game.md`],
    ['Build with Replay', `${contentRoot}replay-game.md`], ['Prediction and timelines', 'docs/kit/timelines.md'],
    ['Authority profiles', 'docs/kit/profiles.md'], ['Replay sessions and rooms', 'replay/getting-started.md'],
    ['Deterministic peers', 'replay/p2p/README.md']
  ]],
  ['Build and ship', [
    ['Build and export', `${contentRoot}shipping.md`], ['Export reference', 'docs/exporting.md'],
    ['Debugging', 'docs/debugging.md'], ['Examples', `${contentRoot}examples.md`]
  ]],
  ['Scrapyard', [
    ['Contributor guide', 'examples/replay_scrapyard/contributor-guide.md'],
    ['Code guide', 'examples/replay_scrapyard/code-guide.md'],
    ['Shared turret', 'examples/replay_scrapyard/shared-turret.md']
  ]]
];
export const navigationFiles = [...new Set(navGroups.flatMap(([, items]) => items.map(([, file]) => file)))];

export function siteHeader(page, active = 'docs', sidebar = false) {
  const url = target => relative(page, target);
  return `<header class="sdk-header"><div class="sdk-header-inner">${sidebar ? '<button class="nav-toggle" type="button" data-nav-toggle aria-controls="docs-navigation" aria-expanded="false" aria-label="Open documentation navigation"><span></span><span></span><span></span></button>' : ''}<a class="sdk-brand" href="${url('index.html')}" aria-label="odin_godot home"><span class="mark" aria-hidden="true">o/g</span><span>odin_godot<span class="brand-caption">Odin × Godot</span></span></a><nav class="sdk-topnav" aria-label="Main navigation"><a href="${url('docs.html')}"${active === 'docs' ? ' aria-current="page"' : ''}>Docs</a><a href="${url('guide.html')}"${active === 'guide' ? ' aria-current="page"' : ''}>Field guide</a><a href="${url('examples.html')}"${active === 'examples' ? ' aria-current="page"' : ''}>Examples</a><a href="${url('reading.html')}" data-doc-index${active === 'index' ? ' aria-current="page"' : ''}>Index</a></nav><div class="sdk-header-actions"><button class="search-trigger" type="button" data-search-open aria-label="Search documentation"><svg width="15" height="15" viewBox="0 0 20 20" fill="none" aria-hidden="true"><circle cx="8.5" cy="8.5" r="5.5" stroke="currentColor" stroke-width="1.5"/><path d="m13 13 4 4" stroke="currentColor" stroke-width="1.5"/></svg><span>Search docs</span><kbd>⌘ K</kbd></button><a class="github-link" href="https://github.com/wlitwin/odin_godot" aria-label="odin_godot on GitHub">GitHub <span aria-hidden="true">↗</span></a></div></div></header>`;
}
export function docsSidebar(page, currentFile, files) {
  const url = target => relative(page, target);
  return `<div class="nav-scrim" data-nav-close hidden></div><aside class="docs-sidebar" id="docs-navigation" aria-label="Documentation"><div class="sidebar-title">DOCUMENTATION<span class="release-tag">SDK</span></div><a class="sidebar-index" href="${url('reading.html')}">Documentation index <span aria-hidden="true">→</span></a><nav>${navGroups.map(([group, items]) => `<section class="nav-group"><h2>${group}</h2>${items.filter(([, file]) => files.has(file)).map(([label, file]) => `<a href="${url(readerPath(file))}"${file === currentFile ? ' aria-current="page"' : ''}>${escape(label)}</a>`).join('')}</section>`).join('')}</nav><div class="sidebar-links"><a href="${url('guide.html')}">Illustrated field guide <span>↗</span></a><a href="https://itchyitches.itch.io/scrapyard" target="_blank" rel="noopener noreferrer">Play Scrapyard <span>↗</span></a></div></aside>`;
}
export function siteFooter(page, compact = false) {
  const url = target => relative(page, target);
  return `<footer class="sdk-footer ${compact ? 'compact' : ''}"><div><a class="sdk-brand" href="${url('index.html')}"><span class="mark">o/g</span><span>odin_godot</span></a><p>Godot scenes. Odin gameplay.</p></div><nav aria-label="Footer"><a href="${url('docs.html')}">Documentation</a><a href="${url('reading.html')}">Index</a><a href="${url('guide.html')}">Field guide</a><a href="https://github.com/wlitwin/odin_godot">GitHub ↗</a><a href="https://github.com/wlitwin/odin_godot/blob/main/LICENSE">Apache 2.0</a></nav></footer>`;
}
