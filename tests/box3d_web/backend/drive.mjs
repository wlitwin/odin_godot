import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';
import fs from 'node:fs';
import path from 'node:path';

const [rootURL, output] = process.argv.slice(2);
let browser;
const report = {result: 'FAIL', pages: {}, scope: 'Headless Chrome C-backend CPU comparison; no rendering/Godot/adapter qualification'};
process.on('SIGTERM', async () => { if (browser) await browser.close(); process.exit(124); });
try {
  browser = await puppeteer.launch({
    executablePath: process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true, userDataDir: path.join(output, 'chrome-profile'),
    args: ['--no-sandbox'],
  });
  fs.writeFileSync(path.join(output, 'browser-process.json'), JSON.stringify({pid: browser.process().pid, spawnargs: browser.process().spawnargs}, null, 2));
  report.browser = await browser.version();
  for (const variant of ['WebScalar', 'WebSIMD']) {
    const page = await browser.newPage();
    const lines = [], errors = [];
    page.on('console', msg => lines.push({type: msg.type(), text: msg.text()}));
    page.on('pageerror', e => errors.push(String(e.stack || e)));
    await page.goto(`${rootURL}/${variant}/index.html`, {waitUntil: 'domcontentloaded', timeout: 30000});
    await page.waitForFunction('window.backendResult !== undefined', {timeout: 90000});
    const data = await page.evaluate(() => ({result: window.backendResult,
      samples: window.backendSamples, isolated: crossOriginIsolated,
      user_agent: navigator.userAgent}));
    fs.writeFileSync(path.join(output, variant + '-console.json'), JSON.stringify({lines, errors}, null, 2));
    if (errors.length || !data.isolated || data.result?.ok !== true || data.samples.length !== 256)
      throw Error('Actual browser backend result unavailable: ' + variant);
    if (!data.samples.every((s, i) => s.sequence === i && Number.isFinite(s.milliseconds) && s.milliseconds >= 0))
      throw Error('Malformed/unretained browser samples');
    report.pages[variant] = data;
    await page.close();
  }
  report.result = 'PASS';
} catch (e) {
  report.error = String(e.stack || e);
} finally {
  if (browser) await browser.close();
  fs.writeFileSync(path.join(output, 'browser-report.json'), JSON.stringify(report, null, 2));
}
console.log(JSON.stringify({result: report.result, report: path.join(output, 'browser-report.json'), error: report.error}));
process.exitCode = report.result === 'PASS' ? 0 : 1;
