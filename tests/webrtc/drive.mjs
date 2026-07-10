// Three-BROWSER WebRTC RPC driver (tests/webrtc). Launches THREE independent headless-Chrome
// instances (three real peers), points one at ?role=host and two at ?role=join of the SAME
// exported Godot web page, and proves they form a STAR of browser-native WebRTC data channels
// (via the WebSocket signaling server) and exchange `@(gd_rpc)` calls in every direction that
// matters — including JOINER->JOINER, which has no direct channel and must be relayed through
// the host by the WebRTCMultiplayerPeer server mode.
//
// Usage: node drive.mjs <pageURL> <signalingWsURL>
//   e.g. node drive.mjs http://127.0.0.1:8097/index.html ws://127.0.0.1:9080
//
// Exit 0 (prints WEBRTC_BROWSER_VERDICT: GREEN) iff:
//   - host console: WEBRTC_CONNECTED role=host my_id=1     (after BOTH joiners' channels open)
//   - each joiner : WEBRTC_CONNECTED role=join my_id=<cid> (distinct, != 0, != 1 — and each
//                   joiner saw TWO peers, so the host relayed its sibling into the roster)
//   - each joiner received the host's broadcast ping : RPC_RECV ping on=<cid> from=1 value=99
//   - host received BOTH joiners' targeted pings     : RPC_RECV ping on=1 from=<cid> value=22
//   - host's call_local echo ran locally             : RPC_RECV echo on=1 ... value=88
//   - each joiner received its SIBLING's broadcast   : RPC_RECV echo on=<a> from=<b> value=44
//     (the star's money shot: joiner->joiner transits the host)
//   - all three printed WEBRTC_DONE.
import puppeteer from "puppeteer-core";

const PAGE = process.argv[2] || "http://127.0.0.1:8097/index.html";
const WSURL = process.argv[3] || "ws://127.0.0.1:9080";
const CHROME = process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const TIMEOUT_MS = 75000;

const LAUNCH_ARGS = [
  "--no-sandbox",
  "--enable-features=SharedArrayBuffer",
  // Force raw 127.0.0.1 host ICE candidates instead of mDNS *.local (which separate
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

// Every page waits for TWO remote peers (?peers=2): the host for both joiners' channels, each
// joiner for the host plus the host-relayed roster entry of its sibling.
const url = (role, room) =>
  `${PAGE}?role=${role}&peers=2&url=${encodeURIComponent(WSURL)}` +
  (room ? `&room=${encodeURIComponent(room)}` : "");

const hostBrowser = await puppeteer.launch({ executablePath: CHROME, headless: "new", args: LAUNCH_ARGS });
const c1Browser = await puppeteer.launch({ executablePath: CHROME, headless: "new", args: LAUNCH_ARGS });
const c2Browser = await puppeteer.launch({ executablePath: CHROME, headless: "new", args: LAUNCH_ARGS });

const host = makePeer("HOST");
const c1 = makePeer("C1");
const c2 = makePeer("C2");

let green = false;
try {
  const hostPage = await hostBrowser.newPage();
  const c1Page = await c1Browser.newPage();
  const c2Page = await c2Browser.newPage();
  await host.attach(hostPage);
  await c1.attach(c1Page);
  await c2.attach(c2Page);

  // Bring the host up first: it `create`s a room and the signaling server replies with a CODE,
  // which the host page prints as "WEBRTC_ROOM <code>". Scrape that code, then point both
  // joiners at ?room=<code> so the three pages pair via the room-code lobby (the real deploy flow).
  await hostPage.goto(url("host"), { waitUntil: "domcontentloaded", timeout: TIMEOUT_MS });
  let roomCode = null;
  const roomDeadline = Date.now() + 30000;
  while (Date.now() < roomDeadline && !roomCode) {
    const m = host.firstMatch(/WEBRTC_ROOM (\S+)/);
    if (m) roomCode = m[1];
    else await new Promise((r) => setTimeout(r, 250));
  }
  if (!roomCode) throw new Error("host never produced a room code");
  console.log("room code from host:", roomCode);
  await c1Page.goto(url("join", roomCode), { waitUntil: "domcontentloaded", timeout: TIMEOUT_MS });
  await c2Page.goto(url("join", roomCode), { waitUntil: "domcontentloaded", timeout: TIMEOUT_MS });

  const start = Date.now();
  const done = () =>
    (host.has(/WEBRTC_DONE/) && c1.has(/WEBRTC_DONE/) && c2.has(/WEBRTC_DONE/)) ||
    host.has(/WEBRTC_TIMEOUT/) || c1.has(/WEBRTC_TIMEOUT/) || c2.has(/WEBRTC_TIMEOUT/);
  while (Date.now() - start < TIMEOUT_MS && !done()) {
    await new Promise((r) => setTimeout(r, 500));
  }

  for (const p of [host, c1, c2]) {
    console.log(`==== ${p.tag} console ====`);
    for (const l of p.lines) console.log(l);
  }
  console.log("==== end console ====");

  // ---- assertions ----
  const idOf = (p) => {
    const m = p.firstMatch(/WEBRTC_CONNECTED role=join my_id=(\d+)/);
    return m ? m[1] : null;
  };
  const cid1 = idOf(c1);
  const cid2 = idOf(c2);

  const hostConnected = host.has(/WEBRTC_CONNECTED role=host my_id=1\b/);
  const joinersConnected = !!cid1 && !!cid2 && cid1 !== cid2 && ![cid1, cid2].some((c) => c === "0" || c === "1");
  const joinersGotHostPing =
    !!cid1 && !!cid2 &&
    c1.has(new RegExp(`RPC_RECV ping on=${cid1} from=1 value=99`)) &&
    c2.has(new RegExp(`RPC_RECV ping on=${cid2} from=1 value=99`));
  const hostGotBothPings =
    !!cid1 && !!cid2 &&
    host.has(new RegExp(`RPC_RECV ping on=1 from=${cid1} value=22`)) &&
    host.has(new RegExp(`RPC_RECV ping on=1 from=${cid2} value=22`));
  const hostCallLocalEcho = host.has(/RPC_RECV echo on=1 .*value=88/);
  const siblingsRelayed =
    !!cid1 && !!cid2 &&
    c1.has(new RegExp(`RPC_RECV echo on=${cid1} from=${cid2} value=44`)) &&
    c2.has(new RegExp(`RPC_RECV echo on=${cid2} from=${cid1} value=44`));
  const allDone = host.has(/WEBRTC_DONE/) && c1.has(/WEBRTC_DONE/) && c2.has(/WEBRTC_DONE/);

  console.log("\n==== VERDICT ====");
  console.log("joiner ids                 :", cid1, cid2);
  console.log("host connected (id 1)      :", hostConnected);
  console.log("joiners connected, distinct:", joinersConnected);
  console.log("host->joiners ping 99      :", joinersGotHostPing);
  console.log("joiners->host ping 22      :", hostGotBothPings);
  console.log("host call_local echo 88    :", hostCallLocalEcho);
  console.log("joiner<->joiner echo 44    :", siblingsRelayed, " (relayed through the host)");
  console.log("all done                   :", allDone);

  green = hostConnected && joinersConnected && joinersGotHostPing && hostGotBothPings &&
    hostCallLocalEcho && siblingsRelayed && allDone;
} finally {
  await hostBrowser.close().catch(() => {});
  await c1Browser.close().catch(() => {});
  await c2Browser.close().catch(() => {});
}

if (green) { console.log("WEBRTC_BROWSER_VERDICT: GREEN"); process.exit(0); }
console.log("WEBRTC_BROWSER_VERDICT: FAIL");
process.exit(1);
