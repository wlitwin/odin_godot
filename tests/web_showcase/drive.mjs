// Headless-browser driver for the FULL showcase game loop on web. Loads the exported Godot
// web build, captures the JS console (Godot routes engine + script prints there), and asserts
// the REAL coin-collector loop ran in-browser: a physics body_entered -> Odin collect ->
// shared score increment -> coin freed, surfaced as the driver's `SHOWCASE_WEB_OK` sentinel.
//
// It also exercises the web SCRIPT-CONTEXT fixes via two phases:
//   PHASE 1 (normal load): the full game loop runs clean (no wasm trap), AND core:math/rand
//     works on wasm (RAND_WEB_OK r1=..) — the regression guard for the "rand traps with
//     `unreachable executed`" bug.
//   PHASE 2 (?panic=1 load): proves (a) NON-DETERMINISM — the web context reseeds the PRNG
//     from Godot's browser entropy, so r1 differs from phase 1; and (b) a deliberate Odin
//     script panic now prints a READABLE message (ODIN_SCRIPT_PANIC: odin web panic sentinel
//     ...) to the console instead of a bare `unreachable`. The panic traps the wasm, which is
//     EXPECTED in this phase only.
//
// Requires: puppeteer-core (npm i puppeteer-core) + a local Chrome/Chromium. Override the
// Chrome path with CHROME=/path/to/chrome. The page must be served with COOP/COEP (see
// serve.sh) — Godot web needs SharedArrayBuffer.
//
//   node drive.mjs http://127.0.0.1:8098/index.html
//
// Exit 0 (and prints BROWSER_VERDICT: GREEN) iff all of the above hold.
import puppeteer from 'puppeteer-core';

const URL = process.argv[2] || 'http://127.0.0.1:8098/index.html';
const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const PHASE_MS = 90000;

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

// Per-phase capture: `lines` is reset at the start of each phase so each phase is scored on
// its OWN console output (the panic phase's expected trap must not taint the normal phase).
let lines = [];
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
const firstMatch = (re) => { for (const l of lines) { const m = l.match(re); if (m) return m; } return null; };
const firstLine = (re) => { for (const l of lines) { if (re.test(l)) return l; } return null; };

// Run one phase: fresh console capture, navigate, wait until `until(lines)` is satisfied or
// the budget elapses. Returns the captured lines for that phase.
async function phase(name, url, until) {
  lines = [];
  console.log(`\n==== PHASE ${name}: ${url} ====`);
  await page.goto(url, { waitUntil: 'domcontentloaded', timeout: PHASE_MS });
  const start = Date.now();
  while (Date.now() - start < PHASE_MS && !until()) await new Promise(r => setTimeout(r, 500));
  for (const l of lines) console.log(l);
  console.log(`==== end PHASE ${name} ====`);
  return lines.slice();
}

const trapRe = /unreachable executed|unreachable\b|RuntimeError/;

// ---- PHASE 1: normal run. Full game loop + rand must run clean, no trap. ----
await phase('1-normal', URL, () => has(/SHOWCASE_WEB_OK/) || has(/SHOWCASE_WEB_FAIL/) || has(trapRe));
const okM = firstMatch(/SHOWCASE_WEB_OK\s+score=(\d+)/);
const randM1 = firstMatch(/RAND_WEB_OK\s+r1=(-?\d+)/);
const p1_ok = !!okM && parseInt(okM[1], 10) > 0;
const p1_rand = !!randM1;
const p1_failSeen = has(/SHOWCASE_WEB_FAIL/);
const p1_trapSeen = has(trapRe);
const r1_phase1 = randM1 ? parseInt(randM1[1], 10) : null;

// ---- PHASE 2: ?panic=1. Reseed-from-entropy (r1 differs) + readable panic message. ----
const panicUrl = URL + (URL.includes('?') ? '&' : '?') + 'panic=1';
await phase('2-panic', panicUrl, () => has(/ODIN_SCRIPT_PANIC/) || has(/SHOWCASE_WEB_FAIL/));
const randM2 = firstMatch(/RAND_WEB_OK\s+r1=(-?\d+)/);
const panicM = firstMatch(/ODIN_SCRIPT_PANIC.*odin web panic sentinel/);
const panicLine = firstLine(/ODIN_SCRIPT_PANIC.*odin web panic sentinel/);
const p2_rand = !!randM2;
const r1_phase2 = randM2 ? parseInt(randM2[1], 10) : null;
const p2_panicReadable = !!panicM;
if (panicLine) console.log('panic console line:', panicLine);
const p2_nondeterministic = r1_phase1 !== null && r1_phase2 !== null && r1_phase1 !== r1_phase2;

await browser.close();

console.log('\n==== VERDICT ====');
console.log('phase1 SHOWCASE_WEB_OK(score>0):', p1_ok, ' RAND_WEB_OK:', p1_rand,
  ' FAIL:', p1_failSeen, ' trap:', p1_trapSeen, ' r1=', r1_phase1);
console.log('phase2 RAND_WEB_OK:', p2_rand, ' r1=', r1_phase2,
  ' nondeterministic(r1 differs):', p2_nondeterministic,
  ' readable panic message:', p2_panicReadable);

const green =
  p1_ok && p1_rand && !p1_failSeen && !p1_trapSeen && // normal run clean + rand works
  p2_rand && p2_nondeterministic &&                   // per-load entropy: r1 changed
  p2_panicReadable;                                   // panic printed a readable message

if (green) { console.log('BROWSER_VERDICT: GREEN'); process.exit(0); }
console.log('BROWSER_VERDICT: FAIL');
process.exit(1);
