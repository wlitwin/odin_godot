import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';
import {createHash} from 'node:crypto';

const [url, signalURL, output, ticksText] = process.argv.slice(2);
const ticks = Number(ticksText);
const actors = {}, errors = [];
const report = {result: 'FAIL', ticks, scope: 'Functional independent Chrome processes with 3D drawing disabled, same Wasm cohort, real local WebRTC with the existing harness local-IP discovery flag; no default-browser Internet or rendering-budget claim'};
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const pause = ms => new Promise(resolve => setTimeout(resolve, ms));
process.on('SIGTERM', async () => {
  await Promise.all(Object.values(actors).map(a => a.browser.close()));
  process.exit(124);
});

async function open(role, room) {
  const directory = path.join(output, role);
  fs.mkdirSync(directory);
  const browser = await puppeteer.launch({
    executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true, userDataDir: path.join(directory, 'profile'),
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader',
           '--ignore-gpu-blocklist', '--enable-webgl', '--disable-background-timer-throttling',
           '--disable-renderer-backgrounding', '--disable-features=WebRtcHideLocalIpsWithMdns'],
  });
  const actor = actors[role] = {browser, role, rows: [], shutdown: false};
  fs.writeFileSync(path.join(directory, 'process.json'), JSON.stringify({pid: browser.process().pid, argv: browser.process().spawnargs}, null, 2));
  actor.version = await browser.version();
  const page = actor.page = await browser.newPage();
  await page.setViewport({width: 960, height: 640, deviceScaleFactor: 1});
  page.on('console', async msg => {
    const rawText = msg.text();
    let text = rawText;
    try {
      const values = await Promise.all(msg.args().map(arg => arg.evaluate(value =>
        value instanceof Error ? value.stack || value.message : String(value)).catch(() => null)));
      const expanded = values.filter(value => value !== null).join(' ');
      if (expanded.length > text.length) text = expanded;
    } catch {}
    const row = {type: msg.type(), raw_text: rawText, text, arrival_ms: performance.now()};
    actor.rows.push(row);
    fs.appendFileSync(path.join(directory, 'console.ndjson'), JSON.stringify(row) + '\n');
    if (text.includes('ODIN_BOX3D_WEB_SHUTDOWN_OK')) actor.shutdown = true;
    for (const tag of ['SAMPLE_ROOM', 'SAMPLE_READY', 'SAMPLE_RTC', 'SAMPLE_NETWORK', 'SAMPLE_WEB_FRAME', 'SAMPLE_INPUTS', 'SAMPLE_TAIL', 'SAMPLE_RESULT']) {
      const marker = text.indexOf(tag + ' ');
      if (marker >= 0) {
        try { actor[tag] = JSON.parse(text.slice(marker + tag.length + 1)); }
        catch (e) { errors.push(role + ' malformed ' + tag + ': ' + e); }
      }
    }
    if (['SCRIPT ERROR', 'ODIN_SCRIPT_PANIC', 'ODIN_BOX3D_WEB_SERVICE_REJECTED', 'SHUTDOWN_NOT_EMPTY',
         'SHUTDOWN_LIVE', 'RuntimeError:'].some(x => text.includes(x)) || msg.type() === 'error') errors.push(role + ': ' + text);
    if (actor.SAMPLE_RESULT?.ok === false) errors.push(role + ': actual failed result');
    if (actor.SAMPLE_RTC && actor.SAMPLE_RTC.error !== 'None') errors.push(role + ': actual RTC ' + actor.SAMPLE_RTC.error);
  });
  page.on('pageerror', error => errors.push(role + ': ' + String(error.stack || error)));
  const target = new URL(url);
  for (const [name, value] of Object.entries({role, scripted: '1', render: '0', ticks: String(ticks), signal: signalURL, ...(room ? {room} : {})}))
    target.searchParams.set(name, value);
  actor.url = target.toString();
  await page.goto(actor.url, {waitUntil: 'domcontentloaded', timeout: 60000});
  actor.isolated = await page.evaluate(() => crossOriginIsolated);
  return actor;
}

function require(value, message) { if (!value) throw Error(message); }
function validate(actor) {
  const ready = actor.SAMPLE_READY, frame = actor.SAMPLE_WEB_FRAME, result = actor.SAMPLE_RESULT;
  require(actor.isolated && actor.shutdown, actor.role + ': isolation or actual shutdown missing');
  require(ready?.backend_observed === true && /^[0-9a-f]{16}$/.test(ready.domain_cookie_hex) && ready.native_images === null,
          actor.role + ': real wasm backend observation unavailable');
  require(result?.ok === true && result.target === ticks && result.final_tick === ticks && result.confirmed >= ticks && result.errors.length === 0,
          actor.role + ': terminal confirmed result incomplete');
  require(result.cleanup?.observed === true && ['native', 'wrapper', 'meter', 'owners'].every(k => result.cleanup[k] === 0),
          actor.role + ': cleanup incomplete');
  require(frame?.tick === ticks && frame.epoch > 0 && frame.parts.length === 5 && frame.content_sha256 === ready.content_sha256,
          actor.role + ': complete frame unavailable');
  const directory = path.join(output, actor.role);
  const parts = {};
  for (const name of ['Solver', 'Game', 'Side', 'Observations', 'Occurrences']) {
    const part = frame.parts.find(p => p.name === name);
    require(part && !parts[name], actor.role + ': missing state part ' + name);
    const bytes = Buffer.from(part.base64, 'base64');
    require(bytes.length === part.bytes && sha(bytes) === part.sha256, actor.role + ': invalid state bytes ' + name);
    parts[name] = bytes;
    fs.writeFileSync(path.join(directory, name + '.bin'), bytes);
  }
  fs.writeFileSync(path.join(directory, 'signature.bin'), Buffer.from(frame.signature_base64, 'base64'));
  require(actor.SAMPLE_TAIL?.signature_match === true && actor.SAMPLE_TAIL.tick === ticks &&
          actor.SAMPLE_TAIL.stage === (actor.role === 'host' ? 'final_accepted' : 'close_accepted'), actor.role + ': actual terminal ACK absent');
  const network = actor.SAMPLE_NETWORK;
  require(network?.issued_sequence > 0 && network.boosts === 2 && network.boost_fx === 2 &&
          ['action_outcomes', 'action_applied', 'accepted_actions'].every(k => JSON.stringify(network[k]) === '[1,1]'),
          actor.role + ': actual actions/outcomes/eligible effects incomplete or duplicated');
  if (actor.role === 'client') require(network.stats.corrections > 0 && network.stats.replayed_ticks > 0 && network.repair_available &&
                                     network.repair_profile_limit === 8 && network.last_planned_depth > 0 && network.last_planned_depth <= 8 &&
                                     network.last_executed_steps > 0 && network.last_executed_steps <= 8,
                                     'actual bounded client correction unavailable');
  return parts;
}

try {
  const host = await open('host');
  let deadline = Date.now() + 60000;
  while (!host.SAMPLE_ROOM && !errors.length && Date.now() < deadline) await pause(50);
  require(host.SAMPLE_ROOM?.room && !errors.length, 'real Host room registration unavailable: ' + errors.join('\n'));
  const client = await open('client', host.SAMPLE_ROOM.room);
  deadline = Date.now() + 120000;
  while ((!host.shutdown || !client.shutdown) && !errors.length && Date.now() < deadline) await pause(50);
  require(!errors.length, errors.join('\n'));
  const hostParts = validate(host), clientParts = validate(client);
  for (const name of Object.keys(hostParts)) require(hostParts[name].equals(clientParts[name]), 'complete part mismatch: ' + name);
  require(host.SAMPLE_WEB_FRAME.signature_base64 === client.SAMPLE_WEB_FRAME.signature_base64, 'complete signature mismatch');
  require(host.SAMPLE_READY.build === client.SAMPLE_READY.build && host.SAMPLE_READY.target === client.SAMPLE_READY.target, 'backend identity mismatch');
  require(host.SAMPLE_INPUTS?.nonzero_by_seat?.length === 2 && host.SAMPLE_INPUTS.nonzero_by_seat.every(x => Number.isSafeInteger(x) && x > 0),
          'authority did not commit distinct nonzero controls from both seats');
  report.result = 'PASS';
} catch (error) {
  report.error = String(error.stack || error);
} finally {
  for (const actor of Object.values(actors)) {
    report[actor.role] = Object.fromEntries(Object.entries(actor).filter(([key]) => !['browser', 'page', 'rows'].includes(key)));
    await actor.browser.close();
  }
  report.errors = errors;
  fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify(report, null, 2) + '\n');
}
console.log(JSON.stringify({result: report.result, error: report.error, report: path.join(output, 'report.json')}));
process.exit(report.result === 'PASS' ? 0 : 1);
