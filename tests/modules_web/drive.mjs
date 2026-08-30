// Headless-browser driver for the MULTI-MODULE web test. Loads the exported Godot web
// build (main module + the enemies script module composed into ONE wasm SIDE_MODULE),
// captures the JS console (Godot routes engine + script prints there), and asserts:
//   * MODWEB_MAIN_RAN     — the MAIN module's Player _ready ran in-browser,
//   * MODWEB_MODULE_RAN   — the enemies MODULE's Enemy _ready ran in-browser,
//   * MODWEB_CROSS_OK     — a cross-module engine call (Player.attack -> Enemy.take_hit
//                           by name) worked,
//   * MODWEB_DRIVER_OK    — the in-scene driver's full pass,
//   * the DELIBERATE duplicate explicit global alias ("Contested", declared by BOTH
//     modules) surfaced a LOUD error naming both canonical source paths. The scripts
//     remain independently path-addressable; only the ambiguous global alias is refused.
//   * and NO MODWEB_FAIL line.
//
// Requires: puppeteer-core (npm i puppeteer-core) + a local Chrome/Chromium. Override
// the Chrome path with CHROME=/path/to/chrome. The page must be served with COOP/COEP
// (see tests/web/serve.sh) — Godot web needs SharedArrayBuffer.
//
//   node drive.mjs http://127.0.0.1:8097/index.html
//
// Exit 0 (and prints BROWSER_VERDICT: GREEN) iff all of the above hold.
import puppeteer from 'puppeteer-core';

const URL = process.argv[2] || 'http://127.0.0.1:8097/index.html';
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const TIMEOUT_MS = 90000;

const browser = await puppeteer.launch({
  executablePath: CHROME,
  headless: 'new',
  args: [
    '--no-sandbox',
    '--enable-features=SharedArrayBuffer',
    // Software WebGL2 so the Compatibility renderer boots in headless.
    '--enable-unsafe-swiftshader',
    '--use-gl=angle',
    '--use-angle=swiftshader',
    '--ignore-gpu-blocklist',
    '--enable-webgl',
  ],
});
const page = await browser.newPage();

const lines = [];
function record(src, text) { lines.push(`[${src}] ${text}`); }
page.on('console', async msg => {
  let text = msg.text();
  try {
    const parts = await Promise.all(msg.args().map(a => a.evaluate(o => {
      if (o instanceof Error) return o.stack || o.message;
      if (typeof o === 'object') { try { return JSON.stringify(o); } catch { return String(o); } }
      return String(o);
    }).catch(() => null)));
    const joined = parts.filter(Boolean).join(' ');
    if (joined && joined.length > text.length) text = joined;
  } catch {}
  record('console.' + msg.type(), text);
});
page.on('pageerror', err => record('pageerror', err.stack || err.message));

const has = (re) => lines.some(l => re.test(l));
const dupRe = /duplicate explicit \/\/gd:class 'Contested'(?=[^\n]*res:\/\/scripts\/contested\.odin)(?=[^\n]*res:\/\/modules\/enemies\/contested\.odin)/;

await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: TIMEOUT_MS });

const done = () =>
  (has(/MODWEB_DRIVER_OK/) && has(dupRe)) || has(/MODWEB_FAIL/);
const start = Date.now();
while (Date.now() - start < TIMEOUT_MS && !done()) {
  await new Promise(r => setTimeout(r, 500));
}

console.log('==== captured browser output ====');
for (const l of lines) console.log(l);
console.log('==== end output ====');

const mainRan = has(/MODWEB_MAIN_RAN/);
const moduleRan = has(/MODWEB_MODULE_RAN/);
const crossOk = has(/MODWEB_CROSS_OK/);
const driverOk = has(/MODWEB_DRIVER_OK/);
const dupSeen = has(dupRe);
const failSeen = has(/MODWEB_FAIL/);

console.log('MODWEB_MAIN_RAN:', mainRan, ' MODWEB_MODULE_RAN:', moduleRan,
  ' MODWEB_CROSS_OK:', crossOk, ' MODWEB_DRIVER_OK:', driverOk,
  ' duplicate-class error on console:', dupSeen, ' FAIL seen:', failSeen);

await browser.close();
if (mainRan && moduleRan && crossOk && driverOk && dupSeen && !failSeen) {
  console.log('BROWSER_VERDICT: GREEN');
  process.exit(0);
}
console.log('BROWSER_VERDICT: FAIL');
process.exit(1);
