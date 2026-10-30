/* Explanatory browser model. No Odin runtime or network code executes here. */
'use strict';
const $ = (s) => document.querySelector(s);
const $$ = (s) => [...document.querySelectorAll(s)];
const readingPath = file => `read/${file.replace(/\.md$/, '')}.html`;
let toastTimer;
function toast(message) { $('#toast').textContent = message; $('#toast').classList.add('visible'); clearTimeout(toastTimer); toastTimer = setTimeout(() => $('#toast').classList.remove('visible'), 1800); }
document.addEventListener('click', async (event) => {
  const button = event.target.closest('.copy-code');
  if (!button) return;
  const text = button.closest('.code-block, .run-panel').querySelector('pre').textContent;
  try { await navigator.clipboard.writeText(text); toast('Copied to clipboard'); }
  catch { const range = document.createRange(); range.selectNodeContents(button.closest('.code-block, .run-panel').querySelector('pre')); const selection = window.getSelection(); selection.removeAllRanges(); selection.addRange(range); toast('Code selected. Copy with your keyboard.'); }
});
$('#print-guide').addEventListener('click', () => window.print());

// This simplified value model follows the local Loot example's input revision.
// Each step takes a detached previous state. History is never mutated in place.
function step(previous, tick, winner) {
  const next = { tick, chest: previous.chest, bags: [...previous.bags], projectile: previous.projectile, occurrences: [] };
  if (tick === 1 && next.chest) { next.bags[winner] += 5; next.chest = false; next.occurrences.push(`take:${winner}`); }
  if (tick === 2) { next.projectile = true; next.occurrences.push('fire:0'); }
  if (tick === 5) next.projectile = false;
  return next;
}
function run(winner, head = 8) {
  const history = [{tick:0, chest:true, bags:[0,0], projectile:false, occurrences:[]}];
  for (let tick = 1; tick <= head; tick++) history.push(step(history[tick - 1], tick, winner));
  return history;
}
const predicted = run(0);
const reference = run(1);
let history = run(0), corrected = false, rebuilt = 0, selected = 8;
const frameButtons = predicted.map((_, tick) => {
  const button = document.createElement('button'); button.type = 'button'; button.className = 'frame speculative';
  button.innerHTML = `<span>T${tick}</span><small>${tick === 0 ? 'BASE' : 'PRED'}</small>`;
  button.addEventListener('click', () => { selected = tick; renderLab(); });
  $('#frames').append(button); return button;
});
function renderLab() {
  const head = history.length - 1;
  selected = Math.min(selected, head);
  const state = history[selected];
  const complete = corrected && rebuilt === 8;
  $('#lab-phase').textContent = !corrected ? 'PREDICTED' : complete ? 'REBUILT' : rebuilt === 0 ? 'RESTORED T0' : `STAGING T${rebuilt}`;
  $('#world-view-label').textContent = corrected && !complete ? 'STAGED WORLD PREVIEW' : 'WORLD VIEW';
  $('#journal-label').textContent = corrected && !complete ? 'JOURNAL DIFF / PREVIEW' : 'PRESENTATION JOURNAL';
  $('#bag-a').textContent = state.bags[0]; $('#bag-b').textContent = state.bags[1];
  $('#chest-state').textContent = state.chest ? '5 items' : 'absent';
  $('#chest').setAttribute('visibility', state.chest ? 'visible' : 'hidden');
  $('#empty-chest').toggleAttribute('hidden', state.chest);
  $('#projectile').toggleAttribute('hidden', !state.projectile);
  $('#transfer').setAttribute('visibility', state.chest ? 'hidden' : 'visible');
  const winner = state.bags[1] ? 1 : 0;
  $('#transfer').setAttribute('d', winner ? 'M260 108 Q310 48 360 100' : 'M260 108 Q210 48 160 100');
  $('#transfer').setAttribute('stroke', winner ? '#b84424' : '#2461d9');
  $('#view-tick').textContent = `TICK ${String(selected).padStart(2,'0')}`;
  $('#tick').max = head; $('#tick').value = selected; $('#tick-output').textContent = selected;
  $('#replayed').textContent = `${rebuilt} / 8 ticks rebuilt`;
  $('#correct').disabled = corrected; $('#step').disabled = !corrected || complete; $('#finish').disabled = !corrected || complete;
  frameButtons.forEach((button,tick) => {
    button.disabled = tick > head;
    button.className = `frame ${tick === 0 ? '' : corrected && tick <= rebuilt ? 'rebuilt' : 'speculative'}`;
    button.setAttribute('aria-pressed', String(tick === selected));
    button.setAttribute('aria-label', `Inspect tick ${tick}${tick > head ? ', not rebuilt yet' : ''}`);
    button.querySelector('small').textContent = tick === 0 ? 'BASE' : corrected && tick <= rebuilt ? 'NEW' : 'PRED';
  });
  let entries = [];
  if (!corrected) {
    if (selected >= 1) entries.push(['begin','Begin · A takes 5','tick 1 / take:A']);
    if (selected >= 2) entries.push(['unchanged','Begin · projectile','tick 2 / fire:A']);
    if (!selected) entries.push(['unchanged','No occurrences','Checkpoint before the pickup.']);
  } else {
    entries.push(['cancel','Cancel · A’s pickup','Old speculative effect is removed.']);
    if (selected >= 1) entries.push(['begin','Begin · B takes 5','Replacement occurrence at tick 1.']);
    if (selected >= 2) entries.push(['unchanged','Keep · projectile effect','Same ID and payload; do not start twice.']);
  }
  $('#journal').innerHTML = entries.map(([kind,title,description]) => `<div class="journal-entry ${kind}"><b>${title}</b><br>${description}</div>`).join('');
  if (complete) {
    const matches = history.every((state,tick) => JSON.stringify(state) === JSON.stringify(reference[tick]));
    $('#check-state').textContent = matches ? 'MATCH · All 9 frames equal a fresh run with B’s input. A: 0 · B: 5.' : 'MISMATCH · Correction differs from the fresh run.';
  } else $('#check-state').textContent = corrected ? `Restored tick 0. ${rebuilt} of 8 transitions rebuilt; compare after reaching the head.` : 'Prediction has A’s take. The corrected reference gives the items to B.';
  $('#lab-status').textContent = !corrected ? `Predicted head at tick 8. Inspecting tick ${selected}.` : complete ? `Correction complete. Inspecting tick ${selected}; B is the corrected winner. The local revision remains unconfirmed.` : `Staging preview through tick ${rebuilt}. The live predicted head stays unchanged until all 8 transitions succeed.`;
  // Read-only inspection hook for the guide's browser QA.
  window.guideLab = { phase: !corrected ? 'predicted' : complete ? 'rebuilt' : 'replaying', selected, rebuilt, state: structuredClone(state), matches: complete && history.every((state,tick) => JSON.stringify(state) === JSON.stringify(reference[tick])) };
}
$('#correct').addEventListener('click', () => { corrected = true; rebuilt = 0; selected = 0; history = [structuredClone(predicted[0])]; renderLab(); });
function replayOne() { if (!corrected || rebuilt >= 8) return; rebuilt++; history.push(step(history[rebuilt-1],rebuilt,1)); selected = rebuilt; }
$('#step').addEventListener('click', () => { replayOne(); renderLab(); });
$('#finish').addEventListener('click', () => { while (rebuilt < 8) replayOne(); renderLab(); });
$('#reset').addEventListener('click', () => { corrected = false; rebuilt = 0; selected = 8; history = run(0); renderLab(); });
$('#tick').addEventListener('input', (event) => { selected = Number(event.target.value); renderLab(); });
renderLab();

function updateDelay() {
  const ms = Number($('#delay').value), percent = 100 - ms / 250 * 80;
  $('#delay-value').textContent = `${ms} ms`; $('#remote-clock').textContent = ms ? `−${ms} ms` : 'now';
  $('#remote-dot').style.left = `calc(${percent}% - 6px)`;
  $('#delay-gap').style.left = `${percent}%`;
}
$('#delay').addEventListener('input',updateDelay); updateDelay();

const policies = {
  coop: { label:'TRUSTED PLAYERS / OWNER-DRIVEN MOTION',title:'Players simulate motion; the authority resolves shared interactions.',
    kit:'Start with hello_net. The entity’s owning player writes its movement fields, while the host writes shared state. Commands let the authority judge interactions such as taking loot or transferring control.',
    replay:'Use Party for invitations and enrollment, then Room for the recoverable game session. Use the owned profile to record accepted body observations when movement depends on Godot physics.',
    note:'This policy trusts the owning player’s motion observations. A successor taking over authority needs a complete authority backup and an accepted authority transition. A recipient-filtered client snapshot is insufficient for that recovery.' },
  server: { label:'LISTEN HOST OR DEDICATED AUTHORITY',title:'Submit input, predict locally, then apply authority corrections.',
    kit:'Start with hello_sim or quickdraw. A gd_tick procedure advances tagged predicted fields from typed input. Session replication handles the lobby and other shared state alongside that simulation.',
    replay:'Start with the Session starter. A net.Model supplies step and action callbacks, validators, and held-input rules. Session runs Host, Server, Client, or Observer roles. Hello’s network scene demonstrates lower-level runner integration.',
    note:'The hosting player controls a listen host. Run a dedicated competitive authority and its failover on trusted infrastructure. Clients can predict an action immediately, but must still wait for the authority to accept it.' },
  p2p: { label:'FIXED ROSTER / REPRODUCIBLE SIMULATION',title:'Exchange inputs and reproduce the same simulation ticks.',
    kit:'Kit’s simulation lane uses authority and client prediction. Use the Replay P2P example when the game needs deterministic input exchange among peers.',
    replay:'Start with replay_duel. P2P_Party admits a fixed roster. P2P_Direct or RTC binds connections to those identities, and p2p.Runner exchanges inputs and replays affected ticks when an input arrives late.',
    note:'The game must reproduce arithmetic, random-number generation, iteration, allocation, and input order across its targets. The integer Duel example has cross-target checks; a new model needs its own determinism tests. These checks do not cover Godot rigid-body solving.' }
};
function selectPolicy(key) {
  const p = policies[key];
  $('#policy-panel').innerHTML = `<div class="policy-topline">${p.label}</div><h3>${p.title}</h3><div class="policy-columns"><div><b class="kit-label">KIT</b><p>${p.kit}</p></div><div><b class="replay-label">REPLAY</b><p>${p.replay}</p></div></div><p class="policy-note">${p.note}</p>`;
  $('#policy-panel').setAttribute('aria-labelledby',`policy-tab-${key}`);
}
const runs = {
  kit:{title:'Owner motion and replicated state',code:'# Build the existing co-op example.\nnix develop --command bash build/build_scripts.sh examples/hello_net\n\n# Terminal 1: launch, then choose Host.\nnix develop --command bash -c \'"$GODOT" --path examples/hello_net\'\n\n# Terminal 2: launch, then choose Join.\nnix develop --command bash -c \'HELLO_LATENCY=120 "$GODOT" --path examples/hello_net\'',files:['examples/hello_net/scripts/player.odin','docs/kit/quickstart.md']},
  sim:{title:'The same square, driven by a server tick',code:'nix develop --command bash build/build_scripts.sh examples/hello_sim\n\n# Terminal 1: choose Host.\nnix develop --command bash -c \'"$GODOT" --path examples/hello_sim\'\n\n# Terminal 2: choose Join.\nnix develop --command bash -c \'HELLO_LATENCY=120 "$GODOT" --path examples/hello_sim\'\n\n# Existing headless behavior check:\nnix develop --command bash examples/hello_sim/run.sh',files:['examples/hello_sim/scripts/player.odin','docs/kit/quickstart-sim.md']},
  loot:{title:'A complete world, corrected without Godot',code:'# Engine-free executable: revise the winning input, replay, compare.\nnix develop --command bash examples/replay_loot/run.sh\n\n# The same loot model with a Godot view. Space changes the winner.\nnix develop --command bash examples/replay_hello/play.sh loot',files:['examples/replay_loot/main.odin','examples/replay_loot/game/game.odin','examples/replay_hello/README.md']},
  net:{title:'Authority, two predicting players, and an observer',code:'# Interactive host:\nnix develop --command bash examples/replay_hello/play.sh network\n\n# A second terminal joins the host:\nREPLAY_ROLE=client nix develop --command bash examples/replay_hello/play.sh network\n\n# Existing four-process behavior check with injected delay:\nnix develop --command bash examples/replay_hello/network_run.sh',files:['examples/replay_hello/shared/hello/network.odin','replay/getting-started.md','examples/replay_recipes/README.md']}
};
function escapeHTML(value) { return value.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;'); }
function selectRun(key) {
  const r = runs[key];
  $('#run-panel').innerHTML = `<div class="code-title"><span>${r.title}</span><button type="button" class="copy-code">Copy</button></div><pre><code>${escapeHTML(r.code)}</code></pre><p>Read: ${r.files.map(file=>`<a href="${readingPath(file)}">${file}</a>`).join(' · ')}</p>`;
  $('#run-panel').setAttribute('aria-labelledby',`run-tab-${key}`);
}
function setupTabs(selector,dataName,select) {
  const buttons = $$(selector);
  function activate(button,focus = false) {
    buttons.forEach(b => { const active = b === button; b.setAttribute('aria-selected',String(active)); b.tabIndex = active ? 0 : -1; });
    select(button.dataset[dataName]); if(focus) button.focus();
  }
  buttons.forEach((button,index) => {
    button.addEventListener('click',()=>activate(button));
    button.addEventListener('keydown',event=>{ let next;
      if(event.key==='ArrowRight') next=(index+1)%buttons.length;
      if(event.key==='ArrowLeft') next=(index+buttons.length-1)%buttons.length;
      if(event.key==='Home') next=0;
      if(event.key==='End') next=buttons.length-1;
      if(next!==undefined){event.preventDefault();activate(buttons[next],true);}
    });
  }); activate(buttons[0]);
}
setupTabs('[data-policy]','policy',selectPolicy);
setupTabs('[data-run]','run',selectRun);

if ('IntersectionObserver' in window) {
  const observer = new IntersectionObserver(entries=>entries.forEach(entry=>{if(entry.isIntersecting){$$('.contents nav a').forEach(a=>{ const active=a.hash===`#${entry.target.id}`;a.classList.toggle('active',active); if(active)a.setAttribute('aria-current','location');else a.removeAttribute('aria-current');});}}),{rootMargin:'-10% 0px -65% 0px',threshold:0});
  $$('.chapter[id]').forEach(section=>observer.observe(section));
}
fetch('reference-manifest.json').then(response=>response.json()).then(manifest=>{
  $('#revision').textContent = `Source ${manifest.revision.slice(0,8)}`;
  $('#provenance').textContent = `Built from repository ${manifest.revision.slice(0,12)}${manifest.dirty ? ' with local source changes' : ''}, ${manifest.date}. Source snapshots are included. The browser models illustrate behavior; they do not execute the Odin frameworks. Replay remains experimental.`;
  $('#source-list').innerHTML = (manifest.featured || manifest.files).map(file=>`<li><a href="${manifest.pages[file]}">${escapeHTML(manifest.titles[file] || file)}</a></li>`).join('');
}).catch(()=>{ $('#source-list').innerHTML='<li>Serve this directory over HTTP to read the source snapshots.</li>'; });
