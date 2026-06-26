// Lobby UX driver (web) — headlessly proves the two lobby fixes in a REAL browser running the
// exported arena.tscn, using the in-page lobby self-test hooks (?lobbytest=retry / ?lobbytest=paste)
// which drive the SAME code paths the real Host/Join buttons + Ctrl/Cmd+V trigger:
//
//   RETRY (Bug 1): a Join to a NONEXISTENT room code makes the real signaling server reply `no_room`,
//     the WebRTC session goes Failed, and the lobby RESETS to the connectable start screen
//     (LOBBY_RESET / LOBBY_RETRY_RESET_OK). A SECOND attempt (Host) then reaches a room code
//     (LOBBY_RETRY_OK) — all with NO page reload. Proves attempt -> fail -> attempt-again recovers.
//
//   PASTE (Bug 2): focus the room-code field, put text on the page clipboard
//     (navigator.clipboard.writeText), synthesize Ctrl+V into the gui_input handler, and assert the
//     field receives the pasted text via the navigator.clipboard.readText() JS-bridge path
//     (LOBBY_PASTE_APPLIED / LOBBY_PASTE_OK).
//
// What this auto-verifies vs what still needs a human: it drives the real reset+timeout recovery and
// the real clipboard-read bridge + field insertion. The ONE thing it can't synthesize headlessly is
// the OS delivering a physical Cmd/Ctrl+V keystroke to the canvas (engine plumbing, not our code) —
// so the keystroke is fed straight into the same on_lobby_input handler the engine would call. A
// human mashing retry / doing a real OS paste on itch.io is the final manual check.
//
// Usage: node lobby_drive.mjs <pageURL> <signalingWsURL>
import puppeteer from "puppeteer-core";

const PAGE = process.argv[2] || "http://127.0.0.1:8099/index.html";
const WSURL = process.argv[3] || "ws://127.0.0.1:9080";
const CHROME = process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const STEP_TIMEOUT_MS = 60000;

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

const url = (mode) => `${PAGE}?lobbytest=${mode}&url=${encodeURIComponent(WSURL)}`;

const browser = await puppeteer.launch({ executablePath: CHROME, headless: "new", args: LAUNCH_ARGS });

// Grant the clipboard permissions the paste path needs (itch.io is HTTPS; 127.0.0.1 is a secure
// context for the Clipboard API, so a real deploy gets these the same way).
const origin = new URL(PAGE).origin;
try { await browser.defaultBrowserContext().overridePermissions(origin, ["clipboard-read", "clipboard-write"]); } catch {}

async function runStep(tag, mode, okRe, extraRe) {
  const peer = makePeer(tag);
  const page = await browser.newPage();
  await peer.attach(page);
  await page.bringToFront();
  await page.goto(url(mode), { waitUntil: "domcontentloaded", timeout: STEP_TIMEOUT_MS });
  const start = Date.now();
  const done = () => peer.has(okRe) || peer.has(/LOBBY_RETRY_FAIL|LOBBY_PASTE_FAIL/);
  while (Date.now() - start < STEP_TIMEOUT_MS && !done()) {
    await new Promise((r) => setTimeout(r, 400));
  }
  console.log(`==== ${tag} console ====`);
  for (const l of peer.lines) console.log(l);
  const ok = peer.has(okRe) && (!extraRe || peer.has(extraRe));
  await page.close().catch(() => {});
  return ok;
}

let retryOk = false, pasteOk = false;
try {
  retryOk = await runStep("RETRY", "retry", /LOBBY_RETRY_OK/, /LOBBY_RETRY_RESET_OK/);
  pasteOk = await runStep("PASTE", "paste", /LOBBY_PASTE_OK/, /LOBBY_PASTE_APPLIED field=room/);
} finally {
  await browser.close().catch(() => {});
}

console.log("\n==== LOBBY VERDICT ====");
console.log(`${retryOk ? "PASS" : "FAIL"}  retry recovery (fail -> reset -> second attempt, no reload)`);
console.log(`${pasteOk ? "PASS" : "FAIL"}  web paste (Ctrl/Cmd+V -> JS clipboard bridge -> field)`);

if (retryOk && pasteOk) { console.log("LOBBY_WEB_VERDICT: GREEN"); process.exit(0); }
console.log("LOBBY_WEB_VERDICT: FAIL");
process.exit(1);
