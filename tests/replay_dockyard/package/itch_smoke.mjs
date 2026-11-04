// Boot the actual packaged game at a nested URL without launch parameters.
// This checks the new HTML bootstrap, not multiplayer or performance admission.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import puppeteer from '../../web/node_modules/puppeteer-core/lib/esm/puppeteer/puppeteer-core.js';

const [webDirectory, outputDirectory] = process.argv.slice(2);
const root = fs.realpathSync(webDirectory), output = path.resolve(outputDirectory);
fs.mkdirSync(output, {recursive: false});
const report = {result: 'FAIL', scope: 'Actual Chrome boot of extracted itch ZIP at a nested URL with no query; no itch-hosting, remote-network or performance claim.'};
const logs = [], errors = [];
let browser, server;
try {
  server = http.createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    const prefix = '/html/42/';
    const name = decodeURIComponent(url.pathname.slice(prefix.length));
    const file = path.resolve(root, name);
    if (!url.pathname.startsWith(prefix) || !file.startsWith(root + path.sep)) {
      response.writeHead(404); response.end(); return;
    }
    const mime = {'.js': 'text/javascript', '.wasm': 'application/wasm', '.html': 'text/html', '.png': 'image/png', '.json': 'application/json'};
    response.setHeader('Cross-Origin-Opener-Policy', 'same-origin');
    response.setHeader('Cross-Origin-Embedder-Policy', 'require-corp');
    response.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
    response.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
    fs.readFile(file, (error, data) => {
      if (error) response.writeHead(404);
      response.end(error ? '' : data);
    });
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  browser = await puppeteer.launch({executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
    headless: true, userDataDir: path.join(output, 'profile'), args: [
      '--no-sandbox', '--enable-unsafe-swiftshader', '--use-gl=angle', '--use-angle=swiftshader',
      '--ignore-gpu-blocklist', '--enable-webgl', '--disable-background-timer-throttling']});
  report.browser = await browser.version();
  const page = await browser.newPage();
  await page.setViewport({width: 1280, height: 720});
  let menuReady;
  page.on('console', message => {
    const text = message.text(); logs.push({type: message.type(), text});
    if (text.startsWith('DOCKYARD_MENU_READY ')) menuReady = JSON.parse(text.slice('DOCKYARD_MENU_READY '.length));
    if (message.type() === 'error' || /SCRIPT ERROR|ODIN_SCRIPT_PANIC/.test(text)) errors.push(text);
  });
  page.on('pageerror', error => errors.push(String(error)));
  report.navigation_url = `http://127.0.0.1:${server.address().port}/html/42/index.html`;
  await page.goto(report.navigation_url, {waitUntil: 'domcontentloaded', timeout: 60000});
  const deadline = Date.now() + 80000;
  while (!menuReady && !errors.length && Date.now() < deadline) await new Promise(resolve => setTimeout(resolve, 100));
  assert.ok(menuReady, 'actual game menu must initialize');
  report.menu = menuReady;
  report.isolated = await page.evaluate(() => crossOriginIsolated);
  assert.equal(report.isolated, true);
  const url = new URL(page.url());
  assert.equal(url.pathname, '/html/42/index.html');
  assert.equal(url.searchParams.get('service'), 'wss://mc.laserturtle.net:62127/replay-room/dockyard');
  assert.equal(url.searchParams.get('relay'), '1');
  assert.equal(url.searchParams.get('local'), '0');
  assert.ok(logs.some(row => row.text.startsWith('DOCKYARD_LOBBY ') && JSON.parse(row.text.slice('DOCKYARD_LOBBY '.length)).configured));
  report.defaults_applied_before_game_startup = true;
  await page.screenshot({path: path.join(output, 'menu.png')});
  await page.evaluate(() => engine.requestQuit());
  await page.waitForFunction(() => engine.rtenv === null, {timeout: 20000});
  report.full_engine_exit = true;
  assert.ok(logs.some(row => row.text.includes('ODIN_BOX3D_WEB_SHUTDOWN_OK')), 'typed backend shutdown required');
  assert.deepEqual(errors, []);
  report.result = 'PASS';
} catch (error) {
  report.error = String(error.stack || error);
} finally {
  if (browser) await browser.close();
  if (server) {server.closeAllConnections(); await new Promise(resolve => server.close(resolve));}
  report.errors = errors;
  fs.writeFileSync(path.join(output, 'console.json'), JSON.stringify(logs, null, 2));
  fs.writeFileSync(path.join(output, 'report.json'), JSON.stringify(report, null, 2));
}
console.log(JSON.stringify(report));
process.exitCode = report.result === 'PASS' ? 0 : 1;
