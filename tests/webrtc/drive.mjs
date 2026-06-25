// Two-BROWSER WebRTC RPC driver (tests/webrtc). Launches TWO independent headless-Chrome
// instances (two real peers), points one at ?role=host and the other at ?role=join of the
// SAME exported Godot web page, and proves they establish a REAL browser-native WebRTC data
// channel (via the WebSocket signaling server) and exchange `@(gd_rpc)` calls in BOTH
// directions with the correct sender ids — the in-browser mirror of tests/rpc_net's ENet
// guarantees.
//
// Usage: node drive.mjs <pageURL> <signalingWsURL>
//   e.g. node drive.mjs http://127.0.0.1:8097/index.html ws://127.0.0.1:9080
//
// Exit 0 (prints WEBRTC_BROWSER_VERDICT: GREEN) iff:
//   - host  console: WEBRTC_CONNECTED role=host my_id=1
//   - client console: WEBRTC_CONNECTED role=join my_id=<cid>   (cid != 0, != 1)
//   - client received the host's broadcast ping : RPC_RECV ping on=<cid> from=1 value=99
//   - host received the client's targeted ping  : RPC_RECV ping on=1 from=<cid> value=22
//   - host's call_local echo ran locally        : RPC_RECV echo on=1 ... value=88
//   - both printed WEBRTC_DONE.
import puppeteer from "puppeteer-core";

const PAGE = process.argv[2] || "http://127.0.0.1:8097/index.html";
const WSURL = process.argv[3] || "ws://127.0.0.1:9080";
const CHROME = process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const TIMEOUT_MS = 75000;

const LAUNCH_ARGS = [
  "--no-sandbox",
  "--enable-features=SharedArrayBuffer",
  // Force raw 127.0.0.1 host ICE candidates instead of mDNS *.local (which two separate
  // browser instances may not resolve for each other) — makes localhost WebRTC reliable.
  "--disable-features=WebRtcHideLocalIpsWithMdns",
  // Software WebGL2 so the Compatibility renderer boots headless.
  "--enable-unsafe-swiftshader",
  "--use-gl=angle",
  "--use-angle=swiftshader",
  "--ignore-gpu-blocklist",
  "--enable-webgl",
];

function makePeer(tag) {
  const lines = [];
  return {
    tag,
    lines,
    has: (re) => lines.some((l) => re.test(l)),
    firstMatch: (re) => { for (const l of lines) { const m = l.match(re); if (m) return m; } return null; },
    async attach(page) {
      page.on("console", async (msg) => {
        let text = msg.text();
        try {
          const parts = await Promise.all(
            msg.args().map((a) =>
              a.evaluate((o) => {
                if (o instanceof Error) return o.stack || o.message;
                if (typeof o === "object") { try { return JSON.stringify(o); } catch { return String(o); } }
                return String(o);
              }).catch(() => null)
            )
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

const url = (role) => `${PAGE}?role=${role}&url=${encodeURIComponent(WSURL)}`;

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

  // Bring the host up first (so the signaling server has the host slot), then the client.
  await hostPage.goto(url("host"), { waitUntil: "domcontentloaded", timeout: TIMEOUT_MS });
  await new Promise((r) => setTimeout(r, 1500));
  await clientPage.goto(url("join"), { waitUntil: "domcontentloaded", timeout: TIMEOUT_MS });

  const start = Date.now();
  const done = () =>
    (host.has(/WEBRTC_DONE/) && client.has(/WEBRTC_DONE/)) ||
    host.has(/WEBRTC_TIMEOUT/) || client.has(/WEBRTC_TIMEOUT/);
  while (Date.now() - start < TIMEOUT_MS && !done()) {
    await new Promise((r) => setTimeout(r, 500));
  }

  console.log("==== HOST console ====");
  for (const l of host.lines) console.log(l);
  console.log("==== CLIENT console ====");
  for (const l of client.lines) console.log(l);
  console.log("==== end console ====");

  // ---- assertions ----
  const cidM = client.firstMatch(/WEBRTC_CONNECTED role=join my_id=(\d+)/);
  const cid = cidM ? cidM[1] : null;

  const hostConnected = host.has(/WEBRTC_CONNECTED role=host my_id=1\b/);
  const clientConnected = !!cid && cid !== "0" && cid !== "1";
  const clientGotHostPing = !!cid && client.has(new RegExp(`RPC_RECV ping on=${cid} from=1 value=99`));
  const hostGotClientPing = !!cid && host.has(new RegExp(`RPC_RECV ping on=1 from=${cid} value=22`));
  const hostCallLocalEcho = host.has(/RPC_RECV echo on=1 .*value=88/);
  const bothDone = host.has(/WEBRTC_DONE/) && client.has(/WEBRTC_DONE/);

  console.log("\n==== VERDICT ====");
  console.log("client id            :", cid);
  console.log("host connected (id 1):", hostConnected);
  console.log("client connected     :", clientConnected);
  console.log("host->client ping 99 :", clientGotHostPing);
  console.log("client->host ping 22 :", hostGotClientPing);
  console.log("host call_local echo :", hostCallLocalEcho);
  console.log("both done            :", bothDone);

  green = hostConnected && clientConnected && clientGotHostPing && hostGotClientPing && hostCallLocalEcho && bothDone;
} finally {
  await hostBrowser.close().catch(() => {});
  await clientBrowser.close().catch(() => {});
}

if (green) { console.log("WEBRTC_BROWSER_VERDICT: GREEN"); process.exit(0); }
console.log("WEBRTC_BROWSER_VERDICT: FAIL");
process.exit(1);
