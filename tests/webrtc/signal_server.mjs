// Minimal WebSocket signaling server for the WebRTC co-op transport (tests/webrtc).
//
// Brokers a 2-peer lobby: it assigns peer ids (host = 1, client = a random id > 1), tells each
// peer its id and — once both are present — the OTHER peer's id, then relays the SDP offer/
// answer + trickled ICE candidates between the two peers VERBATIM (it never parses their
// contents). This is the whole "matchmaking" surface; the actual media path is peer-to-peer
// WebRTC, so this server only needs to be reachable by both friends during connection setup.
//
// Wire protocol (text frames; field separator = ASCII Unit Separator 0x1f):
//   client -> server (first frame) : "HELLO\x1f<role>"      role = "host" | "join"
//   server -> client               : "ID\x1f<peer_id>"
//   server -> client (both ready)  : "PEER\x1f<other_id>"
//   peer  <-> peer (relayed)       : "SDP\x1f<type>\x1f<sdp>" | "ICE\x1f<media>\x1f<index>\x1f<name>"
//
// Self-contained: uses the `ws` package (a transitive dependency of puppeteer-core, already in
// tests/web/node_modules). Run:  node signal_server.mjs [PORT]   (default 9080)
//
// DEPLOYMENT NOTE: for real internet co-op (no port-forwarding for the GAME traffic — WebRTC
// punches through NAT itself), this tiny server still must be reachable by both players, e.g.
// hosted at a public ws:// / wss:// URL. Add public STUN/TURN ICE servers in the Odin
// WebRTCPeerConnection config for cross-NAT cases; localhost needs neither.

import { WebSocketServer } from "ws";

const SEP = "\x1f";
const PORT = parseInt(process.argv[2] || "9080", 10);

const wss = new WebSocketServer({ host: "127.0.0.1", port: PORT });

// One lobby: a single host slot + a single client slot.
const lobby = { host: null, client: null };

function send(sock, ...parts) {
  if (sock && sock.readyState === sock.OPEN) sock.send(parts.join(SEP));
}

wss.on("connection", (sock) => {
  sock._role = null;
  sock._id = 0;

  sock.on("message", (data, isBinary) => {
    const msg = isBinary ? data.toString("utf8") : data.toString();

    // First frame from this socket assigns its role/id; everything after is relayed.
    if (sock._role === null) {
      const fields = msg.split(SEP);
      if (fields[0] !== "HELLO") {
        console.error("signal: expected HELLO, got:", JSON.stringify(msg.slice(0, 32)));
        sock.close();
        return;
      }
      const role = fields[1];
      if (role === "host") {
        if (lobby.host) { console.error("signal: host already present; rejecting"); sock.close(); return; }
        sock._role = "host"; sock._id = 1; lobby.host = sock;
      } else if (role === "join") {
        if (lobby.client) { console.error("signal: client already present; rejecting"); sock.close(); return; }
        sock._role = "join"; sock._id = Math.floor(Math.random() * 1_000_000) + 2; lobby.client = sock;
      } else {
        console.error("signal: unknown role:", role); sock.close(); return;
      }
      send(sock, "ID", String(sock._id));
      console.log(`signal: ${sock._role} joined as id=${sock._id}`);

      // Both present -> tell each about the other; the host (id 1) then creates the offer.
      if (lobby.host && lobby.client) {
        send(lobby.host, "PEER", String(lobby.client._id));
        send(lobby.client, "PEER", String(lobby.host._id));
        console.log("signal: both peers present; handshake begins");
      }
      return;
    }

    // Relay SDP / ICE verbatim to the OTHER peer.
    const dst = sock === lobby.host ? lobby.client : lobby.host;
    if (dst) send(dst, ...msg.split(SEP));
  });

  sock.on("close", () => {
    if (sock === lobby.host) lobby.host = null;
    if (sock === lobby.client) lobby.client = null;
    console.log(`signal: ${sock._role || "unknown"} (id=${sock._id}) disconnected`);
  });

  sock.on("error", (e) => console.error("signal: socket error:", e.message));
});

wss.on("listening", () => console.log(`signal: listening on ws://127.0.0.1:${PORT}`));
wss.on("error", (e) => { console.error("signal: server error:", e.message); process.exit(1); });
