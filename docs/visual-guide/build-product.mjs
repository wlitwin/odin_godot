import { readFile, writeFile, mkdir } from 'node:fs/promises';
import path from 'node:path';
import { siteHeader, siteFooter, readerPath, contentRoot, relative } from './site-structure.mjs';

export async function buildProduct(dist) {
  const doc = name => readerPath(`${contentRoot}${name}.md`);
  const home = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="theme-color" content="#ffffff"><meta name="description" content="Compiled Odin gameplay in the Godot editor. Typed scripts, multiplayer with Kit and Replay, and native and web exports."><title>odin_godot — Godot scenes. Odin gameplay.</title><link rel="icon" href="favicon.svg"><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="sdk.css"><script src="site.js" defer></script><script>if(['#boundary','#kit','#replay','#lab','#clocks','#choose','#start','#artifacts'].includes(location.hash))location.replace('guide.html'+location.hash);</script></head>
<body class="sdk-home"><a class="skip" href="#main">Skip to content</a>${siteHeader('index.html','home')}
<main id="main">
<section class="product-hero product-container"><div class="product-hero-copy"><div class="product-eyebrow"><span></span> THE ODIN SDK FOR GODOT</div><h1>Godot scenes.<br><span>Odin gameplay.</span></h1><p>Write Odin scripts and attach them to Godot nodes. Use typed engine bindings, build multiplayer with Kit or Replay, and export to desktop or the web.</p><div class="product-actions"><a class="button-primary" href="${doc('install')}">Get started <span>→</span></a><a class="button-secondary" href="docs.html">Read the docs <span>↗</span></a></div><div class="hero-note">Open source · Apache 2.0 · Native + WebAssembly</div></div>
<div class="hero-code"><div class="editor-tabs"><span><i></i> mover.odin</span><small>scripts/</small></div><pre><code><span class="token-comment">//gd:extends Node2D</span>
<span class="token-keyword">package</span> game_scripts

<span class="token-keyword">import</span> gd <span class="token-string">"godot:godot"</span>

Mover :: <span class="token-keyword">struct</span> {
    owner: gd.Node2d,
    speed: <span class="token-type">f32</span> <span class="token-string">&#96;gd:"export,default=120"&#96;</span>,
}

mover_process :: <span class="token-keyword">proc</span>(self: ^Mover, dt: <span class="token-type">f64</span>) {
    position := gd.node2d_get_position(self.owner)
    position.x += self.speed * <span class="token-type">f32</span>(dt)
    gd.node2d_set_position(self.owner, position)
}</code></pre><div class="editor-status"><span><span class="status-dot"></span> Typed state. Native code.</span><a href="${doc('first-script')}">Your first script →</a></div></div></section>
<div class="capability-strip"><div class="product-container"><span>Godot editor</span><span>Typed engine bindings</span><span>Compiled scripts</span><span>Kit + Replay</span><span>Desktop & web</span></div></div>

<section class="product-container product-section"><div class="section-intro"><div><p class="product-eyebrow">START BUILDING</p><h2>Pick your starting point.</h2></div><p>Start with a script, a multiplayer model, or an export target. Each guide links to the relevant API reference.</p></div><div class="path-grid">
<a class="path-card" href="${doc('first-script')}"><span class="path-icon">{ }</span><span class="path-number">01 / SCRIPTING</span><h3>Write your first script.</h3><p>Attach an Odin script to a node, expose a property, and run a frame callback.</p><span class="path-link">Build a moving node →</span></a>
<a class="path-card" href="${doc('multiplayer')}"><span class="path-icon">⇄</span><span class="path-number">02 / MULTIPLAYER</span><h3>Choose a multiplayer model.</h3><p>Choose who accepts gameplay changes and how clients predict them. Compare Kit entities with Replay frames.</p><span class="path-link">Kit or Replay →</span></a>
<a class="path-card" href="${doc('shipping')}"><span class="path-icon">↗</span><span class="path-number">03 / EXPORT</span><h3>Export your game.</h3><p>Compile for the target, configure Godot export templates, and check the exported build.</p><span class="path-link">Desktop and browser →</span></a></div></section>

<section class="product-section editor-section"><div class="product-container editor-split"><div><p class="product-eyebrow">GODOT SCENES AND RESOURCES</p><h2>Build the scene.<br>Compile the behavior.</h2><p>Place nodes, edit Resources, connect signals, and use the Inspector. Write script state as Odin structs and behavior as procedures. The build generates their Godot registration.</p><p>For a node script, <code>self</code> points to its data. <code>self.owner</code> points to the Godot node. Pass <code>self.owner</code> to engine calls and <code>self</code> to procedures that operate on script state.</p><a class="text-link" href="${doc('existing-project')}">Add Odin to an existing project →</a></div><div class="scene-panel"><div class="scene-panel-title"><span>SCENE</span><span>player.tscn</span></div><div class="scene-tree"><div><span>◇</span> World <small>Node2D</small></div><div class="scene-child selected"><span>◇</span> Player <small>mover.odin</small></div><div class="scene-grandchild"><span>▧</span> Sprite2D</div><div class="scene-grandchild"><span>◉</span> Camera2D</div><div class="scene-child"><span>◇</span> Level</div></div><div class="inspector-title">INSPECTOR <span>Mover</span></div><div class="inspector-field"><span>Speed</span><code>120.0</code></div><div class="scene-footer">Godot owns the node. Odin owns the script state.</div></div></div></section>

<section class="product-container product-section"><div class="section-intro"><div><p class="product-eyebrow">MULTIPLAYER</p><h2>Two ways to organize multiplayer state.</h2></div><p>Both frameworks support cooperative play and server-authoritative prediction. They differ in how you organize the state that must be restored after a correction.</p></div><div class="model-grid"><article class="model-card"><div class="model-heading"><span class="model-symbol">K</span><div><small>ENTITY FIELDS</small><h3>Kit</h3></div></div><p>Start with script entities. Declare which player or authority writes each field. Use commands for shared interactions and the simulation lane for fixed-tick prediction.</p><div class="model-code"><code>gd:"owner"</code><code>gd:"replicate"</code><code>@(gd_tick)</code></div><a class="text-link" href="${doc('kit-game')}">Build with Kit →</a></article><article class="model-card"><div class="model-heading"><span class="model-symbol replay-symbol">R</span><div><small>COMPLETE FRAMES</small><h3>Replay</h3></div></div><p>Keep mutable gameplay state in a typed World outside the scene tree. Record inputs and restore frames when the authority corrects a prediction. Godot views display the resulting state and events.</p><div class="model-code"><code>World + input → next frame</code><span class="experimental-tag">Experimental</span></div><a class="text-link" href="${doc('replay-game')}">Build with Replay →</a></article></div><a class="comparison-link" href="guide.html">Follow the same contested pickup through both designs <span>↗</span></a></section>

<section id="scrapyard" class="product-container product-section"><div class="game-showcase"><div class="game-showcase-copy"><p class="product-eyebrow">BUILT WITH ODIN × GODOT</p><h2>Take it into<br>the yard.</h2><p>Scrapyard is an arena shooter built with Odin and Godot. Play the browser build, then use the repository's Replay port to trace a feature from input to simulation and scene.</p><a class="button-primary" href="https://itchyitches.itch.io/scrapyard" target="_blank" rel="noopener noreferrer">Play Scrapyard <span>↗</span></a><a class="showcase-source" href="read/examples/replay_scrapyard/contributor-guide.html">Read the contributor guide →</a></div><a class="game-showcase-image" href="https://itchyitches.itch.io/scrapyard" target="_blank" rel="noopener noreferrer" aria-label="Play Scrapyard on itch.io, opens in a new tab"><img src="assets/scrapyard-game.jpg" width="1440" height="720" loading="lazy" alt="Scrapyard running in the browser, with the player fighting enemies in a top-down arena."><span>LIVE BROWSER BUILD <b>↗</b></span></a></div></section>

<section class="product-container product-section field-guide-promo"><div><p class="product-eyebrow">LEARN THE SYSTEM</p><h2>A world on every machine.</h2><p>Follow a contested pickup through Kit and Replay, then step through its correction. The guide connects the diagrams to runnable examples and source files.</p><a class="text-link" href="guide.html">Open the illustrated field guide →</a></div><a href="guide.html#lab" aria-label="Explore the correction lab"><img src="diagrams/correction.svg" width="1000" height="360" loading="lazy" alt="A predicted timeline restored and rebuilt with a corrected input."></a></section>
</main>${siteFooter('index.html')}</body></html>`;
  await writeFile(path.join(dist, 'index.html'), home);

  const guidePath = path.join(dist, 'guide.html');
  let guide = await readFile(guidePath, 'utf8');
  guide = guide.replace(/<body(?: class="[^"]*")?>/, '<body class="guide-page">');
  guide = guide.replace(/<header class="(?:masthead|sdk-header)">[\s\S]*?<\/header>/, siteHeader('guide.html','guide'));
  if (!guide.includes('href="sdk.css"')) guide = guide.replace('</head>', '<link rel="stylesheet" href="sdk.css"><script src="site.js" defer></script></head>');
  guide = guide.replace(/<title>[^<]*<\/title>/, '<title>Multiplayer field guide · odin_godot</title>');
  await writeFile(guidePath, guide);
  await writeFile(path.join(dist, 'reference.html'), `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Documentation · odin_godot</title><link rel="icon" href="favicon.svg"><link rel="stylesheet" href="style.css"><link rel="stylesheet" href="reader.css"><link rel="stylesheet" href="sdk.css"><script src="reference.js" defer></script><script src="site.js" defer></script></head><body class="sdk-library">${siteHeader('reference.html','docs')}<main class="reading-library"><p class="eyebrow">DOCUMENTATION</p><h1>Opening the article.</h1><p class="reader-dek" id="reference-status">Finding the documentation page…</p><p><a href="reading.html">Browse all documentation →</a></p></main></body></html>`);

  // These source-document pages appeared in an earlier reading graph. Keep
  // existing bookmarks useful without publishing stale generated copies.
  for (const [page, target] of [
    ['read/docs/visual-guide/README.html', 'docs.html'],
    ['read/docs/visual-guide/dist/field-guide.html', 'guide.html']
  ]) {
    const url = relative(page, target);
    await mkdir(path.dirname(path.join(dist, page)), { recursive: true });
    await writeFile(path.join(dist, page), `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="0;url=${url}"><title>Documentation · odin_godot</title></head><body><p><a href="${url}">Continue to the documentation</a></p><script>location.replace(${JSON.stringify(url)});</script></body></html>`);
  }

}
