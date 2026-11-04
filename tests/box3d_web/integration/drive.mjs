import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';

const [url, output] = process.argv.slice(2);
let browser;
const lines = [], errors = [];
let actualResult;
let actualShutdown = false;
const report = {result: 'FAIL', url, scope: 'Actual Chrome exported Godot integration; no game/network/performance qualification'};
process.on('SIGTERM', async () => { if (browser) await browser.close(); process.exit(124); });
try {
  browser = await puppeteer.launch({
    executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true, userDataDir: path.join(output, 'chrome-profile'),
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle',
           '--use-angle=swiftshader', '--ignore-gpu-blocklist', '--enable-webgl'],
  });
  fs.writeFileSync(path.join(output, 'browser-process.json'), JSON.stringify({pid: browser.process().pid, spawnargs: browser.process().spawnargs}, null, 2));
  report.browser = await browser.version();
  const page = await browser.newPage();
  await page.setViewport({width: 960, height: 640, deviceScaleFactor: 1});
  page.on('console', async msg => {
    const rawText = msg.text();
    let text = rawText;
    try {
      const parts = await Promise.all(msg.args().map(arg => arg.evaluate(value => {
        if (value instanceof Error) return value.stack || value.message;
        if (typeof value === 'object') { try { return JSON.stringify(value); } catch { return String(value); } }
        return String(value);
      }).catch(() => null)));
      const expanded = parts.filter(value => value !== null).join(' ');
      if (expanded.length > text.length) text = expanded;
    } catch {}
    const row = {type: msg.type(), raw_text: rawText, text};
    lines.push(row);
    fs.appendFileSync(path.join(output, 'console.ndjson'), JSON.stringify(row) + '\n');
    if (text.includes("ODIN_BOX3D_WEB_SHUTDOWN_OK")) actualShutdown = true;
    const marker = text.indexOf('WEBBOX_PASS ');
    if (marker >= 0) {
      try { actualResult = JSON.parse(text.slice(marker + 12)); }
      catch (e) { errors.push('Malformed actual result: ' + e); }
    }
    if (['SCRIPT ERROR', 'ODIN_SCRIPT_PANIC', 'ODIN_BOX3D_WEB_SERVICE_REJECTED',
         'SHUTDOWN_NOT_EMPTY', 'RuntimeError:'].some(x => text.includes(x)) || msg.type() === 'error') errors.push(text);
  });
  page.on('pageerror', e => errors.push(String(e.stack || e)));
  await page.goto(url, {waitUntil: 'domcontentloaded', timeout: 60000});
  const deadline = Date.now() + 120000;
  while ((!actualResult || !actualShutdown) && errors.length === 0 && Date.now() < deadline)
    await new Promise(resolve => setTimeout(resolve, 100));
  report.isolated = await page.evaluate(() => crossOriginIsolated);
  report.actual_result = actualResult;
  report.actual_engine_shutdown = actualShutdown;
  if (!actualResult || !actualShutdown || errors.length || !report.isolated) throw Error('actual Godot acceptance unavailable or failed');
  if (actualResult.native?.ok !== true || actualResult.native.pointer_bits !== 32 ||
      actualResult.native.asset_bytes !== 64 || actualResult.native.asset_align !== 4 ||
      actualResult.owner_churn !== 70000 || actualResult.weak_source_freed !== true ||
      actualResult.origins_rejected !== true || actualResult.actual_source_free !== true ||
      actualResult.native.native_live !== 0 || actualResult.native.wrapper_live !== 0)
    throw Error('actual service/ABI/ownership result incomplete');
  const anchors = [actualResult.temp_before, actualResult.temp_middle, actualResult.temp_after];
  if (!anchors.every(a => Array.isArray(a) && a.length === 3 && a.every(Number.isInteger)) ||
      anchors[0][0] < 0 || anchors[0][1] <= 0 || anchors[0][2] !== 1 ||
      JSON.stringify(anchors[0]) !== JSON.stringify(anchors[1]) ||
      JSON.stringify(anchors[1]) !== JSON.stringify(anchors[2]))
    throw Error('actual temporary allocator anchors disagree');
  await page.screenshot({path: path.join(output, 'scene.png')});
  report.result = 'PASS';
} catch (e) {
  report.error = String(e.stack || e);
} finally {
  if (browser) await browser.close();
  fs.writeFileSync(path.join(output, 'console.json'), JSON.stringify({lines, errors}, null, 2));
  fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify(report, null, 2));
}
console.log(JSON.stringify({result: report.result, report: path.join(output, 'report.json'), error: report.error}));
process.exitCode = report.result === 'PASS' ? 0 : 1;
