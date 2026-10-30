import puppeteer from 'puppeteer-core';
import fs from 'node:fs';
const base = process.argv[2], signal = process.argv[3], mode = process.argv[4] || 'wire';
const logsDir = process.env.REPLAY_RTC_LOGS || '/tmp/replay-rtc-browser';
fs.mkdirSync(logsDir, { recursive: true });
const browsers = [], peers = [];
const wait = ms => new Promise(r => setTimeout(r, ms));
const deadline = async (predicate, label, ms = 60000) => {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    for (const p of peers) if (p.errors.length) throw new Error(`${p.name}: ${p.errors.join('\n')}`);
    if (predicate()) return;
    await wait(100);
  }
  throw new Error(`timeout: ${label}`);
};
async function open(name, role, room = '') {
  const browser = await puppeteer.launch({executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: true, protocolTimeout: 15000,
    args: ['--no-sandbox', '--enable-features=SharedArrayBuffer', '--disable-features=WebRtcHideLocalIpsWithMdns', '--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader', '--ignore-gpu-blocklist', '--enable-webgl']});
  browsers.push(browser);
  const page = await browser.newPage();
  const p = { browser, page, name, lines: [], errors: [] }; peers.push(p);
  page.on('console', msg => {
    const line = msg.text(); p.lines.push(line);
    fs.appendFileSync(`${logsDir}/${name}.log`, `${line}\n`);
    if (/REPLAY_RTC_(FAIL|DONE|CONNECTED|GONE|ROOM|VERIFIED|GAME_)/.test(line)) console.log(name, line);
    if (/REPLAY_RTC_FAIL|SCRIPT ERROR|ERROR:|Aborted\(|indirect call to null|memory access out of bounds/.test(line)) p.errors.push(line);
  });
  page.on('pageerror', error => p.errors.push(String(error)));
  const url = new URL(base); url.search = new URLSearchParams({ role, url: signal, room, mode });
  await page.goto(url.href, {waitUntil:'domcontentloaded', timeout:60000});
  return p;
}
try {
  const host = await open('host', 'host');
  await deadline(() => host.lines.some(x => x.includes(mode === 'game' ? 'REPLAY_RTC_GAME_ROOM' : 'REPLAY_RTC_ROOM')), 'host room');
  const room = host.lines.find(x => x.includes(mode === 'game' ? 'REPLAY_RTC_GAME_ROOM' : 'REPLAY_RTC_ROOM')).match(/REPLAY_RTC_(?:GAME_)?ROOM (\w+)/)[1];
  const a = await open('client', 'join', room), b = await open('observer', mode === 'game' ? 'observer' : 'join', room);
  if (mode === 'game') {
    await deadline(() => [host,a,b].every(p => p.lines.some(x => x.includes('REPLAY_RTC_GAME_STATE'))), 'game convergence');
    const hashes = [host,a,b].map(p => p.lines.find(x => x.includes('REPLAY_RTC_GAME_STATE')).match(/hash=(\d+)/)[1]);
    if (new Set(hashes).size !== 1) throw new Error(`world mismatch ${hashes}`);
    console.log(`REPLAY_RTC_GAME_OK hash=${hashes[0]}`);
  } else {
  await deadline(() => [host,a,b].every(p => p.lines.some(x => x.includes('REPLAY_RTC_DONE'))), 'three direct peers');
  await b.browser.close();
  await deadline(() => [host,a].every(p => p.lines.some(x => /REPLAY_RTC_GONE .*from=3/.test(x))), 'departed browser');
  const replacement = await open('replacement', 'join', room);
  await deadline(() => replacement.lines.some(x => x.includes('REPLAY_RTC_DONE')) && [host,a].every(p => p.lines.some(x => /REPLAY_RTC_VERIFIED .*from=4/.test(x))), 'replacement exchanges');
  await replacement.page.evaluate(() => { globalThis.replayCommand = 'restart'; });
  await deadline(() => replacement.lines.some(x => /REPLAY_RTC_DONE id=5/.test(x)) && [host,a].every(p => p.lines.some(x => /REPLAY_RTC_VERIFIED .*from=5/.test(x))), 'same adapter restart');
  await wait(1500);
  console.log('REPLAY_RTC_BROWSER_OK');
  }
} finally {
  await Promise.allSettled(browsers.filter(b => b.connected).map(b => b.close()));
}

console.log("REPLAY_RTC_BROWSER_CLEANUP_OK");
process.exit(0);
