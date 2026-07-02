// Headless-browser smoke test for the barrage WEB export. Loads the exported build,
// waits for the title scene's Odin sentinel (BARRAGE_TITLE_READY — proves the AOT
// SIDE_MODULE wasm booted and the ui module runs), then CLICKS the Play button and
// waits for the game scene's sentinel (BARRAGE_FIELD_READY — proves input reached an
// Odin handler, start_game switched scenes, and a second isolated module booted).
// Fails on any wasm trap (`unreachable` / RuntimeError) throughout.
//
// Requires: puppeteer-core + a local Chrome (CHROME=/path/to/chrome). Serve with
// COOP/COEP headers (tests/web/serve.sh) — Godot web needs SharedArrayBuffer.
//
//   node drive_web.mjs http://127.0.0.1:8098/index.html
import puppeteer from 'puppeteer-core';

const URL = process.argv[2] || 'http://127.0.0.1:8098/index.html';
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const BUDGET_MS = 90000;

// Play button rect in title.tscn: (420,360)-(540,404) in the 960x720 viewport.
const VIEW_W = 960, VIEW_H = 720;
const PLAY_X = 480, PLAY_Y = 382;

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
await page.setViewport({ width: VIEW_W, height: VIEW_H });

const lines = [];
function record(src, text) { lines.push(`[${src}] ${text}`); }
page.on('console', msg => record('console.' + msg.type(), msg.text()));
page.on('pageerror', err => record('pageerror', err.stack || err.message));

const has = (re) => lines.some(l => re.test(l));
const trapRe = /unreachable executed|unreachable\b|RuntimeError/;

async function waitFor(what, until) {
  const start = Date.now();
  while (Date.now() - start < BUDGET_MS && !until() && !has(trapRe)) {
    await new Promise(r => setTimeout(r, 500));
  }
  const ok = until() && !has(trapRe);
  console.log(`${what}: ${ok ? 'ok' : 'FAILED'}`);
  return ok;
}

await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: BUDGET_MS });

// 1. Odin wasm boots into the title scene.
const booted = await waitFor('title scene (ui module) booted', () => has(/BARRAGE_TITLE_READY/));

// 2. Click Play (map the design-space button center into the canvas' on-page box).
let entered = false;
if (booted) {
  const canvas = await page.$('canvas');
  const box = canvas ? await canvas.boundingBox() : null;
  if (box) {
    const x = box.x + box.width * (PLAY_X / VIEW_W);
    const y = box.y + box.height * (PLAY_Y / VIEW_H);
    await page.mouse.click(x, y);
    entered = await waitFor('game scene (barrage module) entered via Play click',
      () => has(/BARRAGE_FIELD_READY/));
  } else {
    console.log('game scene: FAILED (no canvas element)');
  }
}

// Let the game run a moment so an early physics/render crash would surface.
if (entered) await new Promise(r => setTimeout(r, 3000));
const clean = !has(trapRe) && !has(/ODIN_SCRIPT_PANIC|ODIN_GODOT_CRASH/);

await browser.close();

for (const l of lines) if (/BARRAGE_|ERROR|error|unreachable|RuntimeError/.test(l)) console.log(l);
console.log('\n==== VERDICT ====');
console.log('booted:', booted, ' entered game:', entered, ' clean:', clean);
if (booted && entered && clean) { console.log('BROWSER_VERDICT: GREEN'); process.exit(0); }
console.log('BROWSER_VERDICT: FAIL');
process.exit(1);
