// Headless-browser driver for the FULL showcase game loop on web. Loads the exported
// Godot web build, captures the JS console (Godot routes engine + script prints there),
// and asserts the REAL coin-collector loop ran in-browser: a physics body_entered ->
// Odin collect -> shared score increment -> coin freed, surfaced as the GDScript driver's
// `SHOWCASE_WEB_OK score=<n> value=<v>` sentinel.
//
// Requires: puppeteer-core (npm i puppeteer-core) + a local Chrome/Chromium. Override the
// Chrome path with CHROME=/path/to/chrome. The page must be served with COOP/COEP (see
// serve.sh) — Godot web needs SharedArrayBuffer.
//
//   node drive.mjs http://127.0.0.1:8098/index.html
//
// Exit 0 (and prints BROWSER_VERDICT: GREEN) iff SHOWCASE_WEB_OK with score>0 is seen and
// no SHOWCASE_WEB_FAIL appeared.
import puppeteer from 'puppeteer-core';

const URL = process.argv[2] || 'http://127.0.0.1:8098/index.html';
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

let okSeen = false, failSeen = false, okScore = 0;
let randSeen = false, trapSeen = false;
const lines = [];
function record(src, text) {
  lines.push(`[${src}] ${text}`);
  const m = text.match(/SHOWCASE_WEB_OK\s+score=(\d+)/);
  if (m) { okSeen = true; okScore = parseInt(m[1], 10); }
  if (text.includes('SHOWCASE_WEB_FAIL')) failSeen = true;
  // Regression guard for the core:math/rand wasm trap (see hud.odin / driver.gd): the HUD
  // calls rand every frame + roll() twice, surfacing RAND_WEB_OK only if rand did NOT trap.
  if (/RAND_WEB_OK\s+r1=/.test(text)) randSeen = true;
  // An unseeded/entropy-less random_generator on freestanding_wasm32 surfaces as this trap.
  if (/unreachable executed|RuntimeError/.test(text)) trapSeen = true;
}
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

await page.goto(URL, { waitUntil: 'domcontentloaded', timeout: TIMEOUT_MS });

const start = Date.now();
while (Date.now() - start < TIMEOUT_MS && !okSeen && !failSeen && !trapSeen) {
  await new Promise(r => setTimeout(r, 500));
}

console.log('==== captured browser output ====');
for (const l of lines) console.log(l);
console.log('==== end output ====');
console.log('SHOWCASE_WEB_OK seen:', okSeen, ' score:', okScore, '  SHOWCASE_WEB_FAIL seen:', failSeen);
console.log('RAND_WEB_OK seen:', randSeen, '  wasm trap (unreachable/RuntimeError) seen:', trapSeen);

await browser.close();
if (okSeen && randSeen && !failSeen && !trapSeen && okScore > 0) { console.log('BROWSER_VERDICT: GREEN'); process.exit(0); }
console.log('BROWSER_VERDICT: FAIL');
process.exit(1);
