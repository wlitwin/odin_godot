// Minimal WebSocket signaling RELAY for the WebRTC co-op transport (tests/webrtc).
//
// This is the LOCAL test stand-in for the production Elixir relay: it speaks the EXACT same
// JSON + ROOM-CODE wire protocol so the headless tests exercise the REAL client protocol. It
// brokers room-code lobbies — a host `create`s a room and gets a short CODE to share; friends
// `join` that CODE. The room is a STAR: the host is id 1, joiners get ids 2, 3, … (assigned in
// join order, never reused), and each joiner is introduced to the HOST alone — joiners never
// handshake among themselves (Godot's WebRTCMultiplayerPeer in server mode relays game traffic
// between clients through the host). SDP/ICE `data` is relayed VERBATIM (never parsed). The
// actual media path is peer-to-peer WebRTC, so this server only needs to be reachable during
// connection setup. The room lives exactly as long as its host.
//
// Wire protocol (raw WebSocket, JSON text frames; production server path is `/rtc`):
//   client -> server:
//     {"type":"create"}                                  // make a room, become host (id 1)
//     {"type":"create","native":true,"udp":<port>}       // NATIVE (ENet) room: code + endpoint broker
//     {"type":"join","room":"<CODE>"}                    // join a room (native rooms too; add "udp" for the punch)
//     {"type":"signal","to":<peerId>,"data":<opaque>}    // relay SDP/ICE to a peer (WebRTC rooms)
//     {"type":"leave"}
//   server -> client:
//     {"type":"created","room":"<CODE>","id":1}
//     {"type":"joined","room":"<CODE>","id":<n>}
//     {"type":"native","room":"<CODE>","id":<n>,"host":{"ip":..,"port":..}}  // joiner: point ENet here
//     {"type":"native_peer","id":<n>,"ip":..,"udp":..}   // native host: a joiner's endpoint (punch it)
//     {"type":"peer","id":<peerId>}                      // host: one per joiner; joiner: the host
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

// Host + seven joiners, mirroring the production relay's room cap.
const MAX_PEERS = 8;

// rooms: CODE -> { peers: Map<id, sock>, nextId }  (peer id 1 is the host)
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

function leave(sock) {
  const code = sock._room;
  const r = code && rooms.get(code);
  if (!r || r.peers.get(sock._id) !== sock) return;
  r.peers.delete(sock._id);
  for (const peer of r.peers.values()) send(peer, { type: "peer_left", id: sock._id });
  // The room lives exactly as long as its host — a hostless star can broker no new handshake.
  if (sock._id === 1 || r.peers.size === 0) rooms.delete(code);
  console.log(`signal: id=${sock._id} left room ${code}`);
}

wss.on("connection", (sock, req) => {
  sock._room = null;
  sock._id = 0;
  sock._addr = req?.socket?.remoteAddress ?? "127.0.0.1";

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
        // An optional "room" reserves a code (host migration names tomorrow's
        // room in advance): honored when valid and free, else minted fresh —
        // mirroring the production relay exactly.
        let code = (typeof msg.room === "string" && /^[A-Za-z0-9]{4,8}$/.test(msg.room))
          ? msg.room.toUpperCase() : null;
        if (!code || rooms.has(code)) code = newCode();
        // NATIVE mode: the room brokers an ENet rendezvous instead of SDP —
        // the host declares its UDP port; the relay pairs it with the host's
        // OBSERVED address so a joiner learns where to point ENet. Codes share
        // one namespace with WebRTC rooms.
        const native = msg.native === true && Number.isInteger(msg.udp);
        rooms.set(code, {
          peers: new Map([[1, sock]]), nextId: 2,
          native, udp: native ? msg.udp : 0,
          hostIp: sock._addr,
        });
        sock._room = code; sock._id = 1;
        send(sock, { type: "created", room: code, id: 1, ice: ICE, native });
        console.log(`signal: host created ${native ? "native " : ""}room ${code} (id=1)`);
        break;
      }

      case "join": {
        const code = typeof msg.room === "string" ? msg.room.toUpperCase() : "";
        const r = rooms.get(code);
        if (!r) { send(sock, { type: "error", reason: "no_room" }); return; }
        if (r.peers.size >= MAX_PEERS) { send(sock, { type: "error", reason: "full" }); return; }
        const id = r.nextId++;
        sock._room = code; sock._id = id;
        r.peers.set(id, sock);
        if (r.native) {
          // ENet rendezvous: hand the joiner the host's endpoint, and the host
          // the joiner's observed address + claimed UDP port (for the punch).
          // IPv6-mapped IPv4 ("::ffff:1.2.3.4") is unwrapped for ENet.
          const unmap = (a) => a && a.startsWith("::ffff:") ? a.slice(7) : a;
          const jip = unmap(sock._addr);
          send(sock, { type: "native", room: code, id, host: { ip: unmap(r.hostIp), port: r.udp } });
          send(r.peers.get(1), { type: "native_peer", id, ip: jip, udp: Number.isInteger(msg.udp) ? msg.udp : 0 });
          console.log(`signal: native joiner id=${id} -> room ${code} (host ${unmap(r.hostIp)}:${r.udp})`);
          break;
        }
        send(sock, { type: "joined", room: code, id, ice: ICE });
        // Introduce the joiner and the host to each other — and ONLY to each other: in the
        // star, joiners never handshake among themselves. The host then creates the offer.
        send(sock, { type: "peer", id: 1 });
        send(r.peers.get(1), { type: "peer", id });
        console.log(`signal: joiner id=${id} entered room ${code}; handshake begins`);
        break;
      }

      case "signal": {
        const r = sock._room && rooms.get(sock._room);
        if (!r) return;
        const dst = r.peers.get(msg.to);
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
