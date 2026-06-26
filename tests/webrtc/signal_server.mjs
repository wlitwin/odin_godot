// Minimal WebSocket signaling RELAY for the WebRTC co-op transport (tests/webrtc).
//
// This is the LOCAL test stand-in for the production Elixir relay: it speaks the EXACT same
// JSON + ROOM-CODE wire protocol so the headless tests exercise the REAL client protocol. It
// brokers room-code lobbies — a host `create`s a room and gets a short CODE to share; a friend
// `join`s that CODE — assigns peer ids (host = 1, joiner = 2), tells both peers about each other
// once two are present, then relays the SDP/ICE `data` between them VERBATIM (never parsing it).
// The actual media path is peer-to-peer WebRTC, so this server only needs to be reachable by both
// friends during connection setup.
//
// Wire protocol (raw WebSocket, JSON text frames; production server path is `/rtc`):
//   client -> server:
//     {"type":"create"}                                  // make a room, become host (id 1)
//     {"type":"join","room":"<CODE>"}                    // join a room
//     {"type":"signal","to":<peerId>,"data":<opaque>}    // relay SDP/ICE to a peer
//     {"type":"leave"}
//   server -> client:
//     {"type":"created","room":"<CODE>","id":1}
//     {"type":"joined","room":"<CODE>","id":<n>}
//     {"type":"peer","id":<peerId>}                      // both sides get it once 2 are in
//     {"type":"signal","from":<peerId>,"data":<opaque>}
//     {"type":"peer_left","id":<peerId>}
//     {"type":"error","reason":"no_room"|"full"|"bad_msg"}
//
// Self-contained: uses the `ws` package (a transitive dependency of puppeteer-core, already in
// tests/web/node_modules). This stand-in ignores the request path; the Elixir relay serves `/rtc`.
// Run:  node signal_server.mjs [PORT]   (default 9080)
//
// DEPLOYMENT NOTE: for real internet co-op (WebRTC punches through NAT itself — no port-forwarding
// for the GAME traffic), this relay must be reachable by both players at a public ws:// / wss://
// URL. Add public STUN/TURN ICE servers in the Odin WebRTCPeerConnection config (Ergonomics_WebRtc
// .odin, _ICE_CONFIG_JSON) for cross-NAT cases; localhost needs neither.

import { WebSocketServer } from "ws";

const PORT = parseInt(process.argv[2] || "9080", 10);
const wss = new WebSocketServer({ host: "127.0.0.1", port: PORT });

// rooms: CODE -> { host: sock|null, client: sock|null }
const rooms = new Map();

// ICE servers shipped in created/joined (the client uses these as its WebRTCPeerConnection
// iceServers). The production Elixir relay also mints an ephemeral-cred TURN entry here from a
// shared coturn secret; this LOCAL stand-in has no TURN secret, so it sends STUN-only — enough
// for localhost (host candidates) and it exercises the client's server-provided-ICE path.
const ICE = [{ urls: ["stun:stun.l.google.com:19302"] }];

// Short, human-shareable, unambiguous room code (no 0/O/1/I).
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
function newCode() {
  let code;
  do {
    code = "";
    for (let i = 0; i < 4; i++) code += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
  } while (rooms.has(code));
  return code;
}

function send(sock, obj) {
  if (sock && sock.readyState === sock.OPEN) sock.send(JSON.stringify(obj));
}

function roomPeers(code) {
  const r = rooms.get(code);
  return r ? [r.host, r.client].filter(Boolean) : [];
}

function partOf(code, sock) {
  const r = rooms.get(code);
  if (!r) return null;
  return sock === r.host ? r.client : sock === r.client ? r.host : null;
}

function leave(sock) {
  const code = sock._room;
  const r = code && rooms.get(code);
  if (!r) return;
  const other = partOf(code, sock);
  if (sock === r.host) r.host = null;
  if (sock === r.client) r.client = null;
  if (other) send(other, { type: "peer_left", id: sock._id });
  if (!r.host && !r.client) rooms.delete(code);
  console.log(`signal: id=${sock._id} left room ${code}`);
}

wss.on("connection", (sock) => {
  sock._room = null;
  sock._id = 0;

  sock.on("message", (data, isBinary) => {
    const text = isBinary ? data.toString("utf8") : data.toString();
    let msg;
    try {
      msg = JSON.parse(text);
    } catch {
      send(sock, { type: "error", reason: "bad_msg" });
      return;
    }
    if (!msg || typeof msg.type !== "string") {
      send(sock, { type: "error", reason: "bad_msg" });
      return;
    }

    switch (msg.type) {
      case "create": {
        if (sock._room) { send(sock, { type: "error", reason: "bad_msg" }); return; }
        const code = newCode();
        rooms.set(code, { host: sock, client: null });
        sock._room = code; sock._id = 1;
        send(sock, { type: "created", room: code, id: 1, ice: ICE });
        console.log(`signal: host created room ${code} (id=1)`);
        break;
      }

      case "join": {
        const code = typeof msg.room === "string" ? msg.room.toUpperCase() : "";
        const r = rooms.get(code);
        if (!r) { send(sock, { type: "error", reason: "no_room" }); return; }
        if (r.client) { send(sock, { type: "error", reason: "full" }); return; }
        sock._room = code; sock._id = 2; r.client = sock;
        send(sock, { type: "joined", room: code, id: 2, ice: ICE });
        console.log(`signal: client joined room ${code} (id=2)`);
        // Both present -> tell each about the other; the host (id 1) then creates the offer.
        send(r.host, { type: "peer", id: r.client._id });
        send(r.client, { type: "peer", id: r.host._id });
        console.log(`signal: room ${code} full; handshake begins`);
        break;
      }

      case "signal": {
        const code = sock._room;
        const r = code && rooms.get(code);
        if (!r) return;
        // Relay to the addressed peer (or, in a 2-peer room, simply the other side).
        let dst = null;
        if (r.host && r.host._id === msg.to) dst = r.host;
        else if (r.client && r.client._id === msg.to) dst = r.client;
        else dst = partOf(code, sock);
        if (dst) send(dst, { type: "signal", from: sock._id, data: msg.data });
        break;
      }

      case "leave":
        leave(sock);
        sock._room = null;
        break;

      default:
        send(sock, { type: "error", reason: "bad_msg" });
    }
  });

  sock.on("close", () => leave(sock));
  sock.on("error", (e) => console.error("signal: socket error:", e.message));
});

wss.on("listening", () => console.log(`signal: listening on ws://127.0.0.1:${PORT}/rtc`));
wss.on("error", (e) => { console.error("signal: server error:", e.message); process.exit(1); });
