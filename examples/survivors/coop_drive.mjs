// Two-BROWSER co-op survivors driver (web / WebRTC). Launches two headless-Chrome instances of
// the SAME exported coop.tscn page — one ?role=host, one ?role=join — which establish a real
// browser-native WebRTC link via the signaling server and run the scripted co-op session. It
// asserts the SAME core sync guarantees as the native ENet test, in-browser, from each page's
// console: both players synced/visible, a host->client enemy sync (MultiplayerSpawner +
// MultiplayerSynchronizer over WebRTC), and a client->host action (request_damage -> death).
//
// Usage: node coop_drive.mjs <pageURL> <signalingWsURL>
import puppeteer from "puppeteer-core";

const PAGE = process.argv[2] || "http://127.0.0.1:8098/index.html";
const WSURL = process.argv[3] || "ws://127.0.0.1:9080";
const CHROME = process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const TIMEOUT_MS = 110000;

const LAUNCH_ARGS = [
  "--no-sandbox",
  "--enable-features=SharedArrayBuffer",
  "--disable-features=WebRtcHideLocalIpsWithMdns",
  "--enable-unsafe-swiftshader",
  "--use-gl=angle",
  "--use-angle=swiftshader",
  "--ignore-gpu-blocklist",
  "--enable-webgl",
];

function makePeer(tag) {
  const lines = [];
  return {
    tag, lines,
    has: (re) => lines.some((l) => re.test(l)),
    async attach(page) {
      page.on("console", async (msg) => {
        let text = msg.text();
        try {
          const parts = await Promise.all(
            msg.args().map((a) => a.evaluate((o) => (typeof o === "object" ? JSON.stringify(o) : String(o))).catch(() => null))
          );
          const joined = parts.filter(Boolean).join(" ");
          if (joined && joined.length > text.length) text = joined;
        } catch {}
        lines.push(`[${tag}] ${text}`);
      });
      page.on("pageerror", (err) => lines.push(`[${tag}] pageerror ${err.stack || err.message}`));
    },
  };
}

const url = (role, room) =>
  `${PAGE}?role=${role}&url=${encodeURIComponent(WSURL)}` +
  (room ? `&room=${encodeURIComponent(room)}` : "");

const hostBrowser = await puppeteer.launch({ executablePath: CHROME, headless: "new", args: LAUNCH_ARGS });
const clientBrowser = await puppeteer.launch({ executablePath: CHROME, headless: "new", args: LAUNCH_ARGS });
const host = makePeer("HOST");
const client = makePeer("CLIENT");

let green = false;
try {
  const hostPage = await hostBrowser.newPage();
  const clientPage = await clientBrowser.newPage();
  await host.attach(hostPage);
  await client.attach(clientPage);

  // Host `create`s a room and prints "ROOM_CODE <code>"; scrape it, then join with that code.
  await hostPage.goto(url("host"), { waitUntil: "domcontentloaded", timeout: TIMEOUT_MS });
  let roomCode = null;
  const roomDeadline = Date.now() + 40000;
  while (Date.now() < roomDeadline && !roomCode) {
    const m = host.lines.map((l) => l.match(/ROOM_CODE (\S+)/)).find(Boolean);
    if (m) roomCode = m[1];
    else await new Promise((r) => setTimeout(r, 250));
  }
  if (!roomCode) throw new Error("host never produced a room code");
  console.log("room code from host:", roomCode);
  await clientPage.goto(url("join", roomCode), { waitUntil: "domcontentloaded", timeout: TIMEOUT_MS });

  const start = Date.now();
  const done = () =>
    (host.has(/SERVER_DONE/) && client.has(/CLIENT_DONE/)) ||
    host.has(/_TIMEOUT/) || client.has(/_TIMEOUT/);
  while (Date.now() - start < TIMEOUT_MS && !done()) {
    await new Promise((r) => setTimeout(r, 500));
  }

  console.log("==== HOST console ====");
  for (const l of host.lines) console.log(l);
  console.log("==== CLIENT console ====");
  for (const l of client.lines) console.log(l);
  console.log("==== end console ====");

  // ---- assertions (the in-browser core guarantees) ----
  const checks = {
    "host sees client":            host.has(/SERVER_SEES_CLIENT/),
    "both players (host)":         host.has(/PLAYERS_OK on=1 count=2/),
    "both players (client)":       client.has(/PLAYERS_OK on=\d+ count=2/),
    "client moved":                client.has(/MOVED on=\d+/),
    "host saw synced move":        host.has(/SAW_REMOTE_MOVE on=1 peer=\d+/),
    "enemy seen (spawner)":        client.has(/ENEMY_SEEN on=\d+ id=9001/),
    "enemy pos sync":              client.has(/ENEMY_SYNC on=\d+ id=9001/),
    "authoritative death (host)":  host.has(/ENEMY_DEAD on=1 id=9001/),
    "enemy gone (client)":         client.has(/ENEMY_GONE on=\d+ id=9001/),
    "host done":                   host.has(/SERVER_DONE/),
    "client done":                 client.has(/CLIENT_DONE/),
  };
  console.log("\n==== VERDICT ====");
  green = true;
  for (const [k, v] of Object.entries(checks)) {
    console.log(`${v ? "PASS" : "FAIL"}  ${k}`);
    if (!v) green = false;
  }
} finally {
  await hostBrowser.close().catch(() => {});
  await clientBrowser.close().catch(() => {});
}

if (green) { console.log("COOP_WEB_BROWSER_VERDICT: GREEN"); process.exit(0); }
console.log("COOP_WEB_BROWSER_VERDICT: FAIL");
process.exit(1);
