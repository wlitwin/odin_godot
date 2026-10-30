// Local acceptance fixture, not a public room/authentication service.
import { WebSocketServer, WebSocket } from 'ws';
import { randomBytes } from 'node:crypto';
const port = Number(process.argv[2] || 9080);
const wss = new WebSocketServer({ host: '127.0.0.1', port, maxPayload: 32768 });
const rooms = new Map();
const send = (ws, data) => { if (ws.readyState === WebSocket.OPEN && ws.bufferedAmount < 131072) ws.send(JSON.stringify(data)); };
const leave = ws => {
  const room = ws.room;
  if (!room) return;
  room.peers.delete(ws.id);
  for (const p of room.peers.values()) send(p, { type: 'peer_left', id: ws.id });
  if (!room.peers.size) rooms.delete(room.code);
  ws.room = null;
};
wss.on('connection', ws => {
  ws.count = 0; ws.window = Date.now();
  ws.on('message', (bytes, binary) => {
    if (Date.now() - ws.window > 1000) { ws.count = 0; ws.window = Date.now(); }
    if (binary || ++ws.count > 256) { ws.close(1008); return; }
    let msg;
    try { msg = JSON.parse(bytes.toString()); } catch { ws.close(1008); return; }
    if (!msg || typeof msg !== 'object') { ws.close(1008); return; }
    if (msg.type === 'create' || msg.type === 'join') {
      if (ws.room) { send(ws, { type: 'error', reason: 'bad_msg' }); return; }
      let room;
      if (msg.type === 'create') {
        if (rooms.size >= 16) { send(ws, { type: 'error', reason: 'full' }); return; }
        const code = randomBytes(4).toString('hex').toUpperCase();
        room = { code, next: 1, peers: new Map() }; rooms.set(code, room);
      } else {
        if (typeof msg.room !== 'string' || msg.room.length > 64) { ws.close(1008); return; }
        room = rooms.get(msg.room);
      }
      if (!room) { send(ws, { type: 'error', reason: 'no_room' }); return; }
      if (room.peers.size >= 16 || room.next > 2147483647) { send(ws, { type: 'error', reason: 'full' }); return; }
      ws.room = room; ws.id = room.next++;
      send(ws, { type: msg.type === 'create' ? 'created' : 'joined', room: room.code, id: ws.id });
      // Full mesh: each socket receives authenticated numeric identities before
      // any SDP. Peers negotiate directly; this relay never carries game packets.
      for (const [id, peer] of room.peers) {
        send(ws, { type: 'peer', id }); send(peer, { type: 'peer', id: ws.id });
      }
      room.peers.set(ws.id, ws);
    } else if (msg.type === 'signal') {
      if (!ws.room || !Number.isSafeInteger(msg.to) || msg.to === ws.id || !msg.data || typeof msg.data !== 'object') { ws.close(1008); return; }
      const peer = ws.room.peers.get(msg.to);
      if (peer) send(peer, { type: 'signal', from: ws.id, data: msg.data });
    } else if (msg.type === 'leave') { leave(ws); }
    else { ws.close(1008); }
  });
  ws.on('close', () => leave(ws));
  ws.on('error', () => leave(ws));
});
wss.on('listening', () => console.log(`REPLAY_SIGNAL_READY ${port}`));
