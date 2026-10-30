import { contentRoot, escape, siteHeader, siteFooter } from './site-structure.mjs';

const topics = [
  ['getting-started', 'Get started', 'Installation, project setup, and the first script.', file =>
    ['start-here', 'install', 'first-script', 'existing-project'].some(name => file === `${contentRoot}${name}.md`) || file === 'docs/getting-started.md'],
  ['multiplayer', 'Choose a multiplayer model', 'The visual field guide and the choice between Kit and Replay.', file =>
    file === '@field-guide' || file === `${contentRoot}multiplayer.md`],
  ['kit', 'Kit', 'Entity fields, commands, prediction, and session services.', file =>
    file.startsWith('docs/kit/') || file === `${contentRoot}kit-game.md`],
  ['replay-core', 'Replay: simulation and lifecycle', 'The frame contract, runtime owners, compatibility, and support.', file =>
    file === `${contentRoot}replay-game.md` || file === 'docs/replay/architecture.md' || /^replay\/[^/]+\.md$/.test(file)],
  ['replay-network', 'Replay: networking', 'Server/client runners, input delivery, replication, and transports.', file =>
    /^replay\/(net|transport|comms|lobby)\//.test(file)],
  ['replay-godot', 'Replay: Godot integration', 'Sessions, scene views, input bindings, storage, and engine adapters.', file =>
    file.startsWith('replay/godot/')],
  ['replay-recovery', 'Replay: admission and recovery', 'Enrollment, authority decisions, checkpoints, and host recovery.', file =>
    /^replay\/(authority|provision|recovery|relay)\//.test(file)],
  ['replay-peers', 'Replay: deterministic peers', 'Fixed-roster input exchange, rollback, and spectators.', file =>
    /^replay\/(p2p|deterministic)\//.test(file)],
  ['replay-gameplay', 'Replay: gameplay and presentation', 'Motion helpers, recorded events, owner observations, and content.', file =>
    /^replay\/(play|view|owned|definitions|assets)\//.test(file) || file === 'docs/replay/owner-streams.md'],
  ['replay-data', 'Replay: schemas and data transfer', 'Canonical encodings, deltas, compression, and file transfer.', file =>
    /^replay\/(schema|delta|transfer)\//.test(file)],
  ['replay-tools', 'Replay: tools and diagnostics', 'Recordings, telemetry, editor tools, testing, and version conversion.', file =>
    /^replay\/(diagnostic|telemetry|editor|testing|evolution|erasure)\//.test(file)],
  ['examples', 'Game examples', 'Browse each example and its feature guides.', file =>
    file.startsWith('examples/') || file === `${contentRoot}examples.md` || file.startsWith('build/template/')],
  ['verification', 'Verification records', 'Test scenarios, fixtures, and the scope of their results.', file =>
    file.startsWith('tests/')],
  ['implementation', 'Design and implementation notes', 'Architecture proposals, implementation records, and assessments.', file =>
    file.startsWith('docs/replay/') || file.startsWith('docs/design/') || file === 'PLAN.md'],
  ['attribution', 'Licensing and attribution', 'Credits for the binding generator and upstream code.', file =>
    file.startsWith('bindgen/')],
  ['sdk', 'SDK reference', 'Script authoring, editor workflow, builds, and the onboarding series.', () => true],
  ['source', 'Source listings', 'Complete code and scene files linked from the guides.', () => false]
];

const exampleNames = {
  hello: 'Hello', hello_net: 'Hello Net', hello_sim: 'Hello Sim',
  replay_hello: 'Replay Hello and Loot', replay_loot: 'Replay Loot',
  replay_recipes: 'Replay API recipes', replay_scrapyard: 'Replay Scrapyard',
  replay_cavecrawl: 'Replay Cavecrawl', replay_cavecrawl_owned: 'Replay Cavecrawl with owner motion',
  cavecrawl: 'Cavecrawl (Kit)', quickdraw: 'Quickdraw (Kit)',
  claimball: 'Claimball (Kit)', slopball: 'Slopball (Kit)', slopball3d: 'Slopball 3D (Kit)',
  speedball: 'Speedball (Kit)', survivors: 'Survivors', coop_arena: 'Co-op Arena', barrage: 'Barrage',
  replay_claimball: 'Replay Claimball', replay_quickdraw: 'Replay Quickdraw',
  replay_speedball: 'Replay Speedball', replay_slopball: 'Replay Slopball',
  replay_slopball3d: 'Replay Slopball 3D', replay_duel: 'Replay Duel',
  replay_room_service: 'Replay room service', replay_duel_service: 'Replay Duel service'
};

function subgroup(doc, topic) {
  if (topic === 'sdk') return doc.file.startsWith('docs/onboarding/') ? ['onboarding', 'Onboarding series'] : ['reference', 'Authoring, tools, and export'];
  if (topic === 'examples') {
    if (!doc.file.startsWith('examples/')) return ['overview', 'Overview and starter'];
    const folder = doc.file.split('/')[1];
    return [folder, exampleNames[folder] || folder.replaceAll('_', ' ')];
  }
  if (topic === 'replay-godot') {
    const folder = doc.file.split('/')[2];
    const names = { scene: 'Scenes and views', input: 'Input bindings', storage: 'Storage', transport: 'Engine transports', debug: 'Debugging tools' };
    return names[folder] ? [folder, names[folder]] : ['sessions', 'Sessions and setup'];
  }
  if (topic === 'replay-network' || topic === 'replay-recovery') {
    const folder = doc.file.split('/')[1];
    const names = { net: 'Server/client simulation', transport: 'Transport interface', comms: 'Application messages', lobby: 'Lobby', authority: 'Authority coordination', provision: 'Enrollment and checkpoint storage', recovery: 'Checkpoint replication', relay: 'Relay credentials' };
    return [folder, names[folder]];
  }
  return ['', ''];
}

export function documentationIndex(files, pages) {
  const entries = [...files.values()].map(doc => ({ ...doc, path: pages[doc.file] }));
  entries.push({ file: '@field-guide', path: 'guide.html', title: 'Illustrated multiplayer field guide', isMarkdown: true });
  const grouped = new Map(topics.map(([id, title, description]) => [id, { id, title, description, entries: [] }]));
  for (const doc of entries) {
    const id = doc.isMarkdown ? topics.find(([, , , match]) => match(doc.file))[0] : 'source';
    grouped.get(id).entries.push(doc);
  }
  const order = ['getting-started', 'sdk', ...topics.map(([id]) => id).filter(id => !['getting-started', 'sdk'].includes(id))];
  const groups = [...grouped.values()].filter(group => group.entries.length).sort((a,b) => order.indexOf(a.id) - order.indexOf(b.id));
  const sourceCount = entries.filter(doc => !doc.isMarkdown).length;
  const summary = `${entries.length} pages · ${entries.length - sourceCount} guides and notes · ${sourceCount} code listings`;

  function pageLink(doc) {
    const displayPath = doc.file === '@field-guide' ? 'Interactive guide · diagrams and correction lab' : doc.file;
    const search = `${doc.title} ${displayPath}`.toLowerCase();
    return `<a class="library-item index-page-link" href="${escape(doc.path)}" data-search="${escape(search)}"${doc.file !== '@field-guide' ? ` data-source-file="${escape(doc.file)}"` : ''}><span class="index-entry-copy"><strong>${escape(doc.title)}</strong><small>${escape(displayPath)}</small></span><span class="index-entry-arrow" aria-hidden="true">→</span></a>`;
  }

  function section(group) {
    const subgroups = new Map();
    for (const doc of group.entries) {
      const [id, title] = subgroup(doc, group.id);
      if (!subgroups.has(id)) subgroups.set(id, { id, title, entries: [] });
      subgroups.get(id).entries.push(doc);
    }
    const parts = [...subgroups.values()].sort((a, b) => a.title.localeCompare(b.title));
    return `<section class="index-section" id="${group.id}" data-index-section aria-labelledby="${group.id}-title"><div class="index-section-heading"><h2 id="${group.id}-title">${group.title}</h2><span data-section-count>${group.entries.length}</span></div><p class="index-section-description">${group.description}</p>${parts.map(part => `<div class="index-subgroup" data-index-subgroup>${part.title ? `<h3>${escape(part.title)} <span data-subgroup-count>${part.entries.length}</span></h3>` : ''}<div class="index-pages">${part.entries.sort((a, b) => (group.id === 'source' ? a.file.localeCompare(b.file) : a.title.localeCompare(b.title, undefined, { numeric: true, sensitivity: 'base' }))).map(pageLink).join('')}</div></div>`).join('')}</section>`;
  }

  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#ffffff"><title>Documentation index · odin_godot</title><meta name="description" content="Browse every odin_godot guide, API reference, example, implementation note, and source listing by topic."><link rel="icon" href="favicon.svg"><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="reader.css"><link rel="stylesheet" href="sdk.css"><script src="reader.js" defer></script><script src="site.js" defer></script></head><body class="sdk-index"><a class="skip" href="#index-content">Skip to the page index</a>${siteHeader('reading.html', 'index')}<div class="index-top"><div class="index-intro"><p class="product-eyebrow">DOCUMENTATION / COMPLETE INDEX</p><h1>Documentation index</h1><p>Browse the SDK guides, API references, game examples, and source listings. Every page is listed below, grouped by topic.</p></div><div class="index-filter"><label for="library-search">Filter pages by title or path</label><input type="search" id="library-search" placeholder="For example: turret, recovery, kit/sim…" autocomplete="off" aria-describedby="library-count"><p id="library-count" role="status" data-summary="${summary}">${summary}</p></div></div><div class="index-layout"><aside class="index-topics" aria-label="Index topics"><p>Browse by topic</p><nav>${groups.map(group => `<a href="#${group.id}" data-index-target="${group.id}"><span>${group.title}</span><small data-topic-count>${group.entries.length}</small></a>`).join('')}</nav></aside><main class="documentation-index" id="index-content" aria-label="Documentation pages">${groups.map(section).join('')}<p id="library-empty" hidden>No pages match. Clear the filter or try a shorter term.</p></main></div>${siteFooter('reading.html')}<div id="toast" role="status" aria-live="polite"></div></body></html>`;
}
