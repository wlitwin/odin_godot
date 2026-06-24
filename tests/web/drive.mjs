// Headless-browser driver for the web milestone. Loads the exported Godot web build,
// captures the JS console (Godot routes engine + script prints there), and asserts the
// Odin script's `_ready` ran (prints WEB_RAN + WEB_ASSERT_OK).
//
// Requires: puppeteer-core (npm i puppeteer-core) + a local Chrome/Chromium. Override
// the Chrome path with CHROME=/path/to/chrome. The page must be served with COOP/COEP
// (see serve.sh) — Godot web needs SharedArrayBuffer.
//
//   node drive.mjs http://127.0.0.1:8099/index.html
//
// Exit 0 (and prints BROWSER_VERDICT: GREEN) iff WEB_RAN + WEB_ASSERT_OK are seen.
import puppeteer from 'puppeteer-core';

const URL = process.argv[2] || 'http://127.0.0.1:8099/index.html';
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const TIMEOUT_MS = 60000;

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

let ranSeen = false, assertSeen = false;
const lines = [];
function record(src, text) {
  lines.push(`[${src}] ${text}`);
  if (text.includes('WEB_RAN')) ranSeen = true;
  if (text.includes('WEB_ASSERT_OK')) assertSeen = true;
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
while (Date.now() - start < TIMEOUT_MS && !ranSeen) {
  await new Promise(r => setTimeout(r, 500));
}

console.log('==== captured browser output ====');
for (const l of lines) console.log(l);
console.log('==== end output ====');
console.log('WEB_RAN seen:', ranSeen, '  WEB_ASSERT_OK seen:', assertSeen);

await browser.close();
if (ranSeen && assertSeen) { console.log('BROWSER_VERDICT: GREEN'); process.exit(0); }
console.log('BROWSER_VERDICT: FAIL');
process.exit(1);
