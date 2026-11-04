import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';
const [url, output, marker = 'KIT_WEB_PASS', mode = 'kit'] = process.argv.slice(2);
const report = {result: 'FAIL', url}, errors = [];
let browser, actual, shutdown = false;
try {
  browser = await puppeteer.launch({executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true, userDataDir: path.join(output, 'chrome-profile'),
    args: ['--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader', '--ignore-gpu-blocklist']});
  report.browser = await browser.version();
  report.pid = browser.process().pid;
  const page = await browser.newPage();
  page.on('console', async msg => {
    const rawText = msg.text();
    let text = rawText;
    try {
      const values = await Promise.all(msg.args().map(arg => arg.evaluate(value =>
        value instanceof Error ? value.stack || value.message : String(value)).catch(() => null)));
      const expanded = values.filter(x => x !== null).join(' ');
      if (expanded.length > text.length) text = expanded;
    } catch {}
    fs.appendFileSync(path.join(output, 'console.ndjson'), JSON.stringify({type: msg.type(), raw_text: rawText, text}) + '\n');
    const at = text.indexOf(marker + ' ');
    if (at >= 0) {try {actual = JSON.parse(text.slice(at + marker.length + 1));} catch (e) {errors.push(String(e));}}
    if (text.includes('ODIN_BOX3D_WEB_SHUTDOWN_OK')) shutdown = true;
    if (msg.type() === 'error' || ['SCRIPT ERROR', 'PANIC', 'KIT_WEB_FAIL', 'SHUTDOWN_NOT_EMPTY'].some(x => text.includes(x))) errors.push(text);
  });
  page.on('pageerror', e => errors.push(String(e.stack || e)));
  await page.goto(url, {waitUntil: 'domcontentloaded', timeout: 60000});
  const deadline = Date.now() + 60000;
  while (!shutdown && !errors.length && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 50));
  report.isolated = await page.evaluate(() => crossOriginIsolated);
  report.actual = actual;
  report.actual_shutdown = shutdown;
  if (!report.isolated || !shutdown || errors.length || !actual?.ok || !actual.source_free ||
      actual.native !== 0 || actual.wrapper !== 0 || actual.owners_before !== actual.owners_after || actual.part_bytes?.length !== 5)
    throw Error('actual adapter compatibility evidence incomplete');
  if (mode === 'kit' && actual.steps !== 16) throw Error('actual Kit steps unavailable');
  if (mode === 'window' && !(actual.gap > 128 && actual.discarded_packets > 0 && actual.discarded_bytes > 0 &&
      actual.resyncs > 0 && actual.notice > 0 && actual.baseline_after > actual.baseline_before &&
      (actual.generation_after > actual.generation_before || actual.serial_after > actual.serial_before) && actual.confirmed >= 160))
    throw Error('actual canonical recovery scope unavailable');
  report.result = 'PASS';
} catch (e) {report.error = String(e.stack || e);}
finally {
  if (browser) await browser.close();
  report.errors = errors;
  fs.writeFileSync(path.join(output, 'browser-report.json'), JSON.stringify(report, null, 2) + '\n');
}
console.log(JSON.stringify({result: report.result, error: report.error}));
process.exit(report.result === 'PASS' ? 0 : 1);
