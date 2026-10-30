import {installBufferTrace} from '../../tests/replay_render_audit/trace.mjs';
import puppeteer from 'puppeteer-core';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const [base, control, logs] = process.argv.slice(2);
fs.mkdirSync(logs, {recursive: true});
const peers = [], events = [];
let serial = 0;
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
async function open(member) {
  const browser = await puppeteer.launch({executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true, protocolTimeout: 20000,
    args: ['--no-sandbox', ...(process.env.RSB_HARDWARE==='1'?[]:['--enable-unsafe-swiftshader','--use-gl=angle','--use-angle=swiftshader']), '--ignore-gpu-blocklist', '--enable-webgl', '--disable-features=WebRtcHideLocalIpsWithMdns', '--disable-background-timer-throttling', '--disable-renderer-backgrounding', '--disable-backgrounding-occluded-windows']});
  const page = await browser.newPage(); await page.setViewport({width: 1280, height: 704, deviceScaleFactor: 1});
  const peer = {browser, page, member, errors: []}; peers.push(peer);
  if(process.env.RSB_RENDER_TRACE==='1')await page.evaluateOnNewDocument(installBufferTrace);
  page.on('console', message => {const text = message.text(); fs.appendFileSync(`${logs}/member-${member}.log`, text + '\n'); if (/REPLAY_SCRAPYARD_FAIL|SCRIPT ERROR|ERROR:/.test(text) || process.env.RSB_RENDER_TRACE==='1' && text.includes('WebGL: INVALID_OPERATION')) peer.errors.push(text);});
  page.on('pageerror', error => peer.errors.push(String(error)));
  const url = new URL(base);
  url.search = new URLSearchParams({ui_test: '1', member: String(member), incarnation: String(100 + member), coord_key: (member + 20).toString(16).padStart(2, '0') + '00'.repeat(31), coord_url: control,
    trace: process.env.RSB_TRACE_ACTIONS || '0', lz4: member === 3 ? '0' : '1', reuse_equal: process.env.RSB_REUSE_EQUAL || '0', token: `browser-room-${member}`, name: `member-${member}`, role: member === 1 ? 'host' : 'client', persist: '0', dev: '1', run: '1', waves: '1', wave_base: '0', wave_growth: '0', rest: '12', barrels: '0', mobs: '0', audio: '0'});
  await page.goto(url.href, {waitUntil: 'domcontentloaded', timeout: 60000});
  const query = ++serial; await page.evaluate(query => {globalThis.uiQuery = query;}, query);
  await page.waitForFunction(query => globalThis.uiState?.query === query, {timeout: 60000}, query);
  await until(peer, s => s.ready && s.chat_ready, 'joined'); return peer;
}
async function state(peer) {
  for (const p of peers) assert.deepEqual(p.errors, [], p.errors.join('\n'));
  const id = ++serial;
  await peer.page.evaluate(id => {globalThis.uiQuery = id;}, id);
  await peer.page.waitForFunction(id => globalThis.uiState?.query === id, {timeout: 10000}, id);
  return peer.page.evaluate(() => globalThis.uiState);
}
async function until(peer, predicate, label, ms = 45000) {
  const end = Date.now() + ms; let value;
  while (Date.now() < end) {value = await state(peer); if (predicate(value)) {events.push({member: peer.member, label, state: value}); return value;} await pause(80);}
  fs.writeFileSync(`${logs}/failed-${label}.json`, JSON.stringify({value, peers: await Promise.all(peers.map(p => state(p).catch(error => ({error:String(error)}))))}, null, 2));
  throw Error(`${label}: ${JSON.stringify(value)}`);
}
async function command(peer, kind, extra = {}) {
  const id = ++serial; await peer.page.evaluate(command => {globalThis.uiCommand = command;}, {id, kind, ...extra});
  await peer.page.waitForFunction(id => globalThis.uiAck?.id === id, {timeout: 10000}, id);
  assert.ok(await peer.page.evaluate(() => globalThis.uiAck.accepted), `${kind} refused`);
}
async function cast(peer,slot,x,y) {
  const seat=peer.member-1;
  const ready=await until(peer,s=>s.players_state[seat]['cd'+slot]===0,`cast-${slot}-ready`,20000);
  const before=ready.players_state[seat].casts;
  await command(peer,'cast',{slot,x,y});
  await until(peer,s=>s.players_state[seat].casts===before+1,`cast-${slot}-applied`);
}
async function point(peer, xy, viewport) {
  const canvas = await peer.page.$('canvas'), box = await canvas.boundingBox();
  return {x: box.x + xy[0] * box.width / viewport[0], y: box.y + xy[1] * box.height / viewport[1]};
}
async function clickCard(peer, index) {
  const s = await state(peer), [x, y, w, h] = s.cards[index].box; assert.equal(s.cards[index].disabled, false);
  const at = await point(peer, [x + w / 2, y + h / 2], s.viewport);
  await peer.page.mouse.click(at.x, at.y, {delay: 100});
}
async function say(peer, text) {
  await peer.page.focus('canvas'); await peer.page.keyboard.press('Enter');
  await until(peer, s => s.typing === 1, 'chat-focus');
  await peer.page.keyboard.type(text); await peer.page.keyboard.press('Enter');
  await until(peer, s => s.typing === 0 && s.history.includes(text), 'chat-delivered');
}
try {
  const host = await open(1), client = await open(2);
  async function musterClick(peer, path) {
    await command(peer, 'muster_focus', {path});
    const s = await state(peer), button = s.muster.buttons[path];
    assert.ok(button.visible && !button.disabled, path);
    const [x,y,w,h] = button.box, at = await point(peer,[x+w/2,y+h/2],s.viewport);
    await peer.page.mouse.click(at.x,at.y,{delay:100});
  }
  const staged = await until(host,s => s.players===2 && s.muster.rows[1].visible && s.muster.rows[1].name.includes('member-2'),'muster-roster');
  assert.ok(staged.muster.buttons['Actions/Start'].disabled);
  await command(host,'start'); await pause(150); assert.equal((await state(host)).stage,0);
  for (const [field, next, previous] of [['look','Picks/Look','Picks/LookPrev'],['iron','Picks/Iron','Picks/IronPrev'],['ability0','Abilities/Left','Abilities/LeftPrev'],['ability1','Abilities/Right','Abilities/RightPrev']]) {
    const old = (await state(client)).players_state[1][field];
    await musterClick(client,'Actions/Ready'); await until(host,s => s.players_state[1].marked_ready,'guest-readied');
    await musterClick(client,next);
    const changed = await until(host,s => s.players_state[1][field]===(field==='ability0'||field==='ability1'?1:0) && !s.players_state[1].marked_ready,'remote-pick-unreadies');
    assert.equal(changed.muster.rows[1].lamp,'...'); assert.ok(changed.muster.buttons['Actions/Start'].disabled);
    if (field === 'look') assert.ok(changed.muster.rows[1].texture.endsWith(`runner_${['becca','joe','unknow'][changed.players_state[1].look]}_idle.png`));
    assert.notEqual((await state(client)).muster.automatic,15);
    await musterClick(client,previous); await until(host,s => s.players_state[1][field]===old && !s.players_state[1].marked_ready,'reverse-pick');
    assert.equal((await state(client)).muster.automatic,15);
  }
  await command(host,'abilities',{first:3,second:4});
  await until(host,s => s.players_state[0].ability0===3 && s.players_state[0].ability1===4,'area-loadout-before-start');
  await command(client,'abilities',{first:1,second:6});
  await until(host,s => s.players_state[1].ability0===1 && s.players_state[1].ability1===6,'lob-loadout-before-start');
  await musterClick(client,'Actions/Ready');
  const startable = await until(host,s => !s.players_state[0].marked_ready && s.players_state[1].marked_ready && !s.muster.buttons['Actions/Start'].disabled,'host-start-shortcut');
  assert.equal(startable.muster.rows[0].frame,0);assert.equal(startable.muster.rows[1].frame,0);
  await host.page.screenshot({path:`${logs}/muster.png`});
  await musterClick(host,'Actions/Start');
  for (const peer of [host, client]) await until(peer, s => s.stage === 2 && s.players_state[peer.member - 1].in_yard, 'floor-clear');

  await host.page.focus('canvas'); await host.page.keyboard.press('Escape');
  const menuBefore = await until(host, s => s.menu && s.veil && s.focus.endsWith('/Resume'), 'menu-focused');
  for (const key of ['w', 'Shift', 'q', 'e', '9']) await host.page.keyboard.down(key);
  await host.page.mouse.move(40, 100); await host.page.mouse.down(); await pause(350); await host.page.mouse.up();
  for (const key of ['w', 'Shift', 'q', 'e', '9']) await host.page.keyboard.up(key);
  const menuDuring = await state(host);
  for (const field of ['x','y','shots','casts','dashes','iron']) assert.equal(menuDuring.players_state[0][field], menuBefore.players_state[0][field], `menu leaked ${field}`);
  assert.ok(menuDuring.head > menuBefore.head + 5, 'menu paused simulation');
  await host.page.screenshot({path: `${logs}/menu.png`});
  await host.page.keyboard.press('Enter');
  const resumed = await until(host, s => !s.menu && !s.veil, 'menu-resumed'); assert.equal(resumed.typing, 0);
  await host.page.keyboard.press('Escape');
  const heldMenu = await until(host, s => s.menu && s.focus.endsWith('/Resume'), 'held-key-menu');
  await host.page.keyboard.down('Shift'); await pause(80);
  const [hx,hy,hw,hh] = heldMenu.resume_box, heldAt = await point(host,[hx+hw/2,hy+hh/2],heldMenu.viewport);
  await host.page.mouse.click(heldAt.x,heldAt.y,{delay:100});
  await until(host,s => !s.menu,'held-key-resume');
  await pause(200); assert.equal((await state(host)).players_state[0].dashes, menuBefore.players_state[0].dashes);
  await host.page.keyboard.up('Shift');
  await host.page.keyboard.down('Tab'); await until(host, s => s.tally, 'tally-held');
  await until(host, s => s.tally_rows[0].values[7] === '0' && /^\d+$/.test(s.tally_rows[1].values[7]), 'tally-live-round-trip');
  await client.page.keyboard.down('Tab');
  const guestTally = await until(client, s => s.tally && s.tally_rows[0].values[7] === '0' && /^\d+$/.test(s.tally_rows[1].values[7]), 'tally-relayed-round-trip');
  assert.equal(guestTally.tally_rows[1].values[6], '0');
  await client.page.keyboard.up('Tab');
  await host.page.screenshot({path: `${logs}/tally.png`});
  await host.page.keyboard.press('Enter'); await until(host, s => s.typing, 'tally-chat-focus');
  await host.page.keyboard.up('Tab'); await until(host, s => !s.tally && s.typing, 'tally-release-in-chat');
  await host.page.keyboard.press('Escape'); await until(host, s => !s.typing && !s.menu, 'tally-chat-cancel');
  await host.page.keyboard.press('Escape'); await until(host, s => s.menu, 'resized-menu-open');
  await host.page.setViewport({width: 960, height: 540, deviceScaleFactor: 1}); await pause(300);
  const resized = await state(host);
  const [mx,my,mw,mh] = resized.menu_box, [vw,vh] = resized.viewport;
  assert.ok(mx >= 0 && my >= 0 && mx+mw <= vw+1 && my+mh <= vh+1 && Math.abs(mx+mw/2-vw/2)<1);
  assert.deepEqual(resized.veil_box, [0,0,vw,vh]);
  await host.page.screenshot({path: `${logs}/menu-small.png`});
  await host.page.setViewport({width:1280,height:704,deviceScaleFactor:1}); await pause(250);
  const resumeState = await state(host), [rx,ry,rw,rh] = resumeState.resume_box;
  const resumeAt = await point(host,[rx+rw/2,ry+rh/2],resumeState.viewport);
  await host.page.mouse.click(resumeAt.x,resumeAt.y,{delay:100});
  await until(host,s => !s.menu && s.players_state[0].shots === menuBefore.players_state[0].shots,'resume-click-isolated');

  await client.page.focus('canvas'); await client.page.keyboard.press('Enter');
  const before = await until(client, s => s.typing === 1, 'typing-start');
  await client.page.keyboard.down('w'); await client.page.keyboard.down('Shift'); await client.page.keyboard.down('q'); await pause(450);
  for (const key of ['w', 'Shift', 'q']) await client.page.keyboard.up(key);
  const during = await state(client);
  for (const field of ['x', 'y', 'casts', 'dashes', 'shots']) assert.equal(during.players_state[1][field], before.players_state[1][field], `typing leaked ${field}`);
  assert.ok(during.head > before.head + 5, 'chat paused simulation');
  await client.page.keyboard.press('Escape'); assert.equal((await until(client, s => !s.typing, 'chat-cancel')).menu, 0);
  // Clear the keyboard-test draft, then send literal markup through real input.
  await client.page.keyboard.press('Enter'); await until(client, s => s.typing === 1, 'draft-focus');
  const modifier = process.platform === 'darwin' ? 'Meta' : 'Control';
  await client.page.keyboard.down(modifier); await client.page.keyboard.press('a'); await client.page.keyboard.up(modifier);
  await client.page.keyboard.press('Backspace'); await client.page.keyboard.type('[b]browser bolts[/b]'); await client.page.keyboard.press('Enter');
  for (const peer of [host, client]) {
    const s = await until(peer, s => s.history.split('\n').includes('member-2: [b]browser bolts[/b]'), 'literal-chat');
    assert.equal(s.bbcode, false); assert.ok(s.parsed_history.includes('[b]browser bolts[/b]'));
  }
  await say(host, 'host ready');

  const pingState = await state(host), at = await point(host, pingState.ping_point, pingState.viewport);
  await host.page.mouse.click(at.x, at.y, {button: 'middle', delay: 100});
  for (const peer of [host, client]) await until(peer, s => s.pings === 1 && s.active_pings === 1, 'live-ping');
  await client.page.screenshot({path: `${logs}/ping-chat.png`});
  const late = await open(3);
  const history = await until(late, s => s.history.includes('browser bolts') && s.history.includes('host ready'), 'late-history');
  assert.equal(history.pings, 0, 'late join replayed old marker'); assert.equal(history.active_pings, 0);
  const dropIn = await until(late,s => s.muster.visible && s.muster.rows[2].visible && s.muster.rows[0].lamp==='IN THE YARD' && s.muster.rows[1].lamp==='IN THE YARD','late-muster');
  assert.ok(dropIn.muster.rows[0].tint[3]<0.8 && dropIn.muster.rows[1].tint[3]<0.8);
  assert.ok(dropIn.chat_box[0]+dropIn.chat_box[2] <= dropIn.muster.box[0]-4,'chat overlaps muster');
  assert.equal(dropIn.muster.buttons['Actions/Ready'].text,'DROP IN');assert.equal(dropIn.muster.buttons['Actions/Start'].visible,false);
  await late.page.screenshot({path:`${logs}/late-muster.png`});
  await command(late,'abilities',{first:5,second:2});
  await until(late,s => s.players_state[2].ability0===5,'zone-loadout-before-entry');
  await musterClick(late,'Actions/Ready'); await until(late, s => s.players_state[2].in_yard === 1 && !s.muster.visible, 'late-entry');
  for (const peer of peers) await until(peer, s => s.active_pings === 0, 'ping-expired');

  await command(host, 'scrap', {seat: 1, amount: 20}); await command(host, 'cores', {seat: 1, amount: 9});
  const funded = await until(host, s => s.players_state[0].scrap >= 20 && !s.cards[0].disabled, 'shop-funded');
  await clickCard(host, 0);
  const bought = await until(host, s => s.players_state[0].boost_damage === 1, 'card-purchased');
  assert.equal(bought.players_state[0].scrap, funded.players_state[0].scrap - 5); assert.equal(bought.players_state[0].shots, funded.players_state[0].shots);
  await clickCard(host, 5); await until(host, s => s.health === '14/14' && s.cards[5].disabled && s.cards[5].text.includes('OWNED'), 'plate-hud');
  await command(host, 'jam', {seat: 1}); await until(host, s => s.ammo_state.includes('JAMMED'), 'jam-hud');
  await host.page.mouse.move(700, 300); await host.page.keyboard.press('q'); await host.page.keyboard.press('e');
  await until(host, s => s.pip0 < 45 && s.pip1 < 45, 'cooldown-hud');
  await host.page.screenshot({path: `${logs}/shop-hud.png`});

  await command(host, 'hurt', {seat: 2, amount: 8});
  await until(client, s => s.health === '2/10' && s.vignette && s.vignette_alpha > 0.3, 'browser-vignette');
  await client.page.screenshot({path: `${logs}/low-health.png`});
  await command(host, 'hurt', {seat: 2, amount: 255});
  await until(client, s => s.players_state[1].hp === 0 && s.camera === 1 && s.following && s.health === '0/10', 'borrowed-camera');
  assert.equal((await state(client)).vignette, false, 'downed vignette remained');
  await client.page.screenshot({path: `${logs}/downed-camera.png`});
  await host.page.focus('canvas'); await host.page.keyboard.down('f');
  await until(client, s => s.players_state[1].hp === 4 && s.camera === 2 && !s.following, 'revived-camera');
  await host.page.keyboard.up('f');

  // Ordnance uses the same shop/actions and simulation as native play. The
  // opt-in bridge retains transient view observations across slow browser polls.
  async function equip(iron) {
    for (let count = 0; count < 7; count++) {
      const current = (await state(host)).players_state[0].iron;
      if (current === iron) return;
      await clickCard(host, 8);
      await until(host, s => s.players_state[0].iron !== current, 'swap-ordnance');
    }
    assert.equal((await state(host)).players_state[0].iron, iron);
  }
  for (const iron of [5, 6]) {
    await equip(iron);
    for (const peer of peers) await command(peer, 'ordnance');
    await command(host, 'aim', {x: -1, y: 0, fire: true});
    for (const peer of peers) {
      const s = await until(peer, s => s.ordnance.sparks.length >= 3, `rail-${iron}-contact`);
      for (const spark of s.ordnance.sparks) {
        assert.ok(spark.position[0] >= 649 && spark.position[0] < 705);
        assert.ok(Math.abs(spark.position[1] - 544) < 40 && Math.cos(spark.rotation) > 0.8);
        assert.equal(spark.points, 3);
      }
    }
    await host.page.screenshot({path: `${logs}/rail-${iron}.png`});
    await command(host, 'aim', {x: -1, y: 0, fire: false});
    for (const peer of peers) await until(peer, s => s.ordnance.active.sparks === 0, 'rail-expired');
  }
  await equip(4);
  for (const peer of peers) await command(peer, 'ordnance');
  const blasts = (await state(host)).players_state[0].blasts;
  await command(host, 'aim', {x: -1, y: 0, fire: true});
  for (const peer of peers) {
    const s = await until(peer, s => s.ordnance.embers.length && s.ordnance.bounced, 'grenade-bounce-trail');
    assert.ok(s.ordnance.shells.length); assert.equal(s.ordnance.shells[0].points, 6);
    assert.equal(s.ordnance.embers[0].points, 4);
    assert.equal(s.ordnance.sparks.length, 0);
  }
  await client.page.screenshot({path: `${logs}/grenade-trail.png`});
  await command(host, 'aim', {x: -1, y: 0, fire: false});
  for (const peer of peers) {
    const s = await until(peer, s => s.players_state[0].blasts > blasts && s.ordnance.active.shells === 0 && s.ordnance.active.embers === 0, 'grenade-fuse-expiry');
    assert.equal(s.ordnance.dropped, 0); assert.equal(s.ordnance.old_epoch, 0);
  }

  // These submissions use the ordinary Cast action; all three renderers
  // record the transient glyph each frame, including the owning prediction.
  function verifyGlob(row, radius, color) {
    assert.equal(row.points,10); assert.equal(row.depth,6);
    for (const value of row.radii) assert.ok(Math.abs(value-radius)<0.001);
    color.forEach((v,i)=>assert.ok(Math.abs(v-row.color[i])<0.001));
    assert.ok(row.min_scale>=0.819 && row.max_scale<=1.181 && row.max_scale-row.min_scale>0.001);
    assert.ok(row.samples>2 && Math.abs(row.last[0]-row.first[0])>1);
  }
  for (const [slot,color] of [[0,[0.45,0.9,0.5,1]],[1,[0.75,0.85,1,1]]]) {
    for (const peer of peers) await command(peer,'glob_watch');
    const before = await state(client), caster = before.players_state[1];
    await command(client,'cast',{slot,x:caster.x+300,y:caster.y});
    for (const peer of peers) {
      const seen = await until(peer,s => s.globs.records.some(r=>r.kind==='lob' && r.samples>2) && s.globs.active.lob===0,`lob-${slot}-observed`);
      const rows = seen.globs.records.filter(r=>r.kind==='lob'); assert.equal(rows.length,1);
      verifyGlob(rows[0],7,color);
      assert.ok(rows[0].name.startsWith(peer===client?'Lob0_':'Lob1_'));
    }
  }
  function verifyDisc(row,radius,color,depth,fade) {
    assert.equal(row.points,24); assert.equal(row.depth,depth);
    row.radii.forEach(r=>assert.ok(Math.abs(r-1)<0.001));
    color.slice(0,3).forEach((v,i)=>assert.ok(Math.abs(v-row.color[i])<0.001));
    assert.ok(row.samples>2);
    if (fade) {
      assert.ok(row.min_scale>=radius*0.919 && row.max_scale<=radius*1.061 && row.max_scale>row.min_scale);
      assert.ok(row.max_alpha<=color[3]+0.001 && row.min_alpha<row.max_alpha);
    } else {
      assert.ok(Math.abs(row.min_scale-radius)<0.001 && Math.abs(row.max_scale-radius)<0.001);
      assert.ok(Math.abs(row.min_alpha-color[3])<0.001 && Math.abs(row.max_alpha-color[3])<0.001);
    }
  }
  for (const peer of peers) await command(peer,'area_watch');
  for (const peer of peers) await until(peer,s=>s.areas.active.area===0,'prior-area-expiry');
  for (const peer of peers) await command(peer,'area_watch');
  await cast(host,0,0,0);
  for (const peer of peers) {
    const seen = await until(peer,s=>s.areas.records.some(r=>r.kind==='area' && r.samples>2) && s.areas.active.area===0,'nova-filled-fade');
    const rows = seen.areas.records.filter(r=>r.kind==='area'); assert.equal(rows.length,1);
    verifyDisc(rows[0],150,[0.5,0.75,1,0.5],8,true); assert.ok(rows[0].name.startsWith('Area1_'));
  }
  for (const peer of peers) await command(peer,'area_watch');
  await cast(host,1,0,0);
  for (const peer of peers) {
    const seen = await until(peer,s=>s.areas.records.some(r=>r.kind==='buff') && s.areas.active.buff===0,'buff-once-expired');
    const rows = seen.areas.records.filter(r=>r.kind==='buff'); assert.equal(rows.length,1);
    assert.equal(rows[0].amount,12); assert.ok(Math.abs(rows[0].lifetime-0.4)<0.001); assert.equal(rows[0].one_shot,true);
    assert.equal(seen.areas.records.filter(r=>r.kind==='area').length,0);
  }
  for (const peer of peers) await command(peer,'area_watch');
  const fieldCaster = (await state(late)).players_state[2];
  await cast(late,0,fieldCaster.x+100,fieldCaster.y+60);
  for (const peer of peers) await until(peer,s=>s.areas.active.zone===1,'standing-zone-filled');
  await late.page.screenshot({path:`${logs}/zone-filled.png`});
  for (const peer of peers) {
    const seen = await until(peer,s=>s.areas.records.some(r=>r.kind==='zone') && s.areas.active.zone===0,'standing-zone-expired',12000);
    const rows=seen.areas.records.filter(r=>r.kind==='zone');assert.equal(rows.length,1);
    verifyDisc(rows[0],90,[0.5,1,0.6,0.22],2,false);
  }

  for (const peer of peers) await command(peer,'path_watch');
  const coneSource=(await state(late)).players_state[2];
  await cast(late,1,coneSource.x+150,coneSource.y);
  for (const peer of peers) {
    const seen=await until(peer,s=>s.paths.records.some(r=>r.kind==='flame' && r.samples>2) && s.paths.active.flame===0,'cone-tongues');
    const rows=seen.paths.records.filter(r=>r.kind==='flame');assert.equal(rows.length,peer===late?5:1);
    const angles=rows.map(r=>Math.atan2(r.first[1]-coneSource.y,r.first[0]-coneSource.x)).sort((a,b)=>a-b);
    angles.forEach((v,i)=>assert.ok(Math.abs(v-(peer===late?(i-2)*0.25:0))<0.001));
    for (const row of rows) {assert.equal(row.text,'*');assert.ok(row.name.startsWith(peer===late?'Flame0_':'Flame1_'));assert.ok(Math.hypot(row.last[0]-row.first[0],row.last[1]-row.first[1])>1);}
  }
  await command(host,'barrel',{dx:60});await command(host,'barrel',{dx:110});
  for (const peer of peers) await command(peer,'path_watch');
  const arcState=await state(host), arcSource=arcState.players_state[0];
  await command(host,'status',{seat:1,status:1});
  await until(host,s=>(s.players_state[0].fx_mask&(1<<1))!==0,'spread-primer');
  await command(host,'status',{seat:1,status:6});
  for (const peer of peers) {
    const seen=await until(peer,s=>s.paths.records.filter(r=>r.kind==='arc').length===4 && s.paths.active.arc===0,'spread-recorded-hops');
    for (const row of seen.paths.records.filter(r=>r.kind==='arc')) {
      assert.equal(row.points.length,8);assert.equal(row.depth,8);
      assert.ok(Math.hypot(row.first[0]-arcSource.x,row.first[1]-arcSource.y)<0.01);
      [0.75,0.85,1].forEach((v,i)=>assert.ok(Math.abs(v-row.color[i])<0.001));
      assert.ok(row.max_alpha<=0.8001 && row.min_alpha<row.max_alpha);
      const end=[(row.points[3][0]+row.points[4][0])/2,(row.points[3][1]+row.points[4][1])/2];
      assert.ok(Math.abs(end[1])<0.01 && [40,60,80,110].some(v=>Math.abs(v-end[0])<0.01));
    }
  }

  // Stock shock ignites the close barrels and wipes this intentionally packed
  // crew. Observe that consequence, then test spit in the freshly reset yard.
  for (const peer of peers) await until(peer,s=>s.stage===3 && s.run===arcState.run,'spread-barrel-wipe',12000);
  for (const peer of peers) {
    const reset=await until(peer,s=>s.run===arcState.run+1 && s.stage===2 && s.players_state.every(p=>p.hp>0),'spread-yard-reset',15000);
    assert.equal(reset.paths.active.arc,0);assert.equal(reset.paths.active.flame,0);
  }

  for (const peer of peers) await command(peer,'glob_watch');
  await command(host,'spitter');
  for (const peer of peers) {
    const seen = await until(peer,s => s.globs.records.some(r=>r.kind==='spit' && r.samples>2),'spit-observed');
    verifyGlob(seen.globs.records.find(r=>r.kind==='spit' && r.samples>2),5,[0.45,0.9,0.5,1]);
  }

  for (const peer of peers) await command(peer, 'hashes');
  let hashes, common = []; const deadline = Date.now() + 20000;
  do {
    await pause(250); for (const peer of peers) assert.deepEqual(peer.errors, []);
    hashes = await Promise.all(peers.map(p => p.page.evaluate(() => globalThis.uiHashes || {})));
    common = Object.keys(hashes[0]).filter(t => hashes.every(h => h[t] !== undefined));
    for (const tick of common) for (const hash of hashes) assert.equal(hash[tick], hashes[0][tick], `world ${tick}`);
  } while (common.length < 10 && Date.now() < deadline);
  assert.ok(common.length >= 10, 'common world frames');
  fs.writeFileSync(`${logs}/hashes.json`, JSON.stringify({common, hashes}, null, 2));
  const snapshotTraffic = await Promise.all(peers.map(peer => state(peer)));
  for (const row of snapshotTraffic) assert.equal(row.network.snapshot_every,3,'default snapshot interval');
  assert.ok(snapshotTraffic[0].network.fragmented_snapshots > 0, 'host used snapshot parts');
  assert.ok(snapshotTraffic[0].network.lz4_snapshots > 0 && snapshotTraffic[1].network.lz4_snapshots > 0, 'capable peers used negotiated LZ4 snapshots');
  assert.equal(snapshotTraffic[2].network.lz4_snapshots, 0, 'parts-only peer received no LZ4');
  assert.equal(snapshotTraffic[2].network.shuffled_snapshots, 0, 'parts-only peer received no shuffled LZ4');
  assert.ok(snapshotTraffic[1].network.action_copy_batches > 0, 'client used negotiated action copies');
  assert.ok(snapshotTraffic[2].network.snapshot_parts_received > 0, 'parts-only peer received snapshot parts');
  assert.ok(snapshotTraffic[0].network.snapshot_parity_sent > 0, 'host sent negotiated snapshot parity');
  assert.ok(snapshotTraffic[2].network.snapshot_parity_received > 0, 'parts-only client received negotiated parity over RTC');
  if(process.env.RSB_REUSE_EQUAL==='1'){
    assert.equal(snapshotTraffic[1].network.reuse_enabled,1);assert.equal(snapshotTraffic[2].network.reuse_enabled,1);
    assert.ok(snapshotTraffic[1].network.reused_correction_ticks>0 && snapshotTraffic[2].network.reused_correction_ticks>0,'clients exercised exact correction reuse');
  }
  fs.writeFileSync(`${logs}/snapshot-traffic.json`, JSON.stringify(snapshotTraffic.map(s => s.network), null, 2));
  // Quit the third game through its menu and prove the other two continue.
  await late.page.focus('canvas'); await late.page.keyboard.press('Escape');
  await until(late, s => s.menu && s.focus.endsWith('/Resume'), 'quit-menu');
  await late.page.keyboard.down('Shift'); await late.page.keyboard.press('Tab'); await late.page.keyboard.up('Shift');
  const quitState = await until(late, s => s.focus.endsWith('/Quit'), 'quit-focus');
  const [qx,qy,qw,qh] = quitState.quit_box, quitAt = await point(late,[qx+qw/2,qy+qh/2],quitState.viewport);
  const headBeforeQuit = (await state(host)).head;
  await late.page.mouse.click(quitAt.x,quitAt.y,{delay:100});
  await host.page.focus('canvas'); await host.page.keyboard.down('Tab');
  const survivors = await until(host,s => s.players===2 && s.head>headBeforeQuit+5 && s.tally && !s.tally_rows[2].visible,'quit-leaves-live-yard',20000);
  assert.equal(survivors.tally_rows[0].values.length,8);
  assert.ok(fs.readFileSync(`${logs}/member-3.log`,'utf8').includes('RSY_MENU_QUIT'));
  assert.ok(fs.readFileSync(`${logs}/member-3.log`,'utf8').includes('RSY_YARD_CLOSED'));
  await late.page.screenshot({path:`${logs}/yard-closed.png`});
  await host.page.keyboard.up('Tab');
  if(process.env.RSB_RENDER_TRACE==='1') {
    const traces=await Promise.all(peers.map(p=>p.page.evaluate(()=>globalThis.bufferTrace)));
    fs.writeFileSync(`${logs}/render-traces.json`,JSON.stringify(traces,null,2));
    assert.ok(traces.every(t=>t.conflicts===0));
  }
  console.log(`REPLAY_SCRAPYARD_BROWSER_UI_OK peers=3 common_frames=${common.length} chat=true pings=true shop=true hud=true camera=true rails=true grenades=true menu=true tally=true quit=true muster=true globs=true areas=true paths=true`);
} finally {
  if(process.env.RSB_RENDER_TRACE==='1') {
    const traces=await Promise.allSettled(peers.filter(p=>p.browser.connected).map(p=>p.page.evaluate(()=>globalThis.bufferTrace)));
    fs.writeFileSync(`${logs}/terminal-render-traces.json`,JSON.stringify(traces,null,2));
  }
  fs.writeFileSync(`${logs}/events.json`, JSON.stringify(events, null, 2));
  await Promise.allSettled(peers.filter(p => p.browser.connected).map(p => p.browser.close()));
}
process.exit(0);
