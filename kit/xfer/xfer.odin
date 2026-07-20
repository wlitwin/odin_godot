package kit_xfer

// kit/xfer — LARGE PAYLOADS over the session, chunked. The piece entity blobs
// deliberately are not: a blob rides whole on every version bump and is meant
// for state a joiner must see; a TRANSFER is a one-shot shipment of something
// big — a user-drawn spray, a custom skin, a shared level file — that must not
// stall the reliable channel behind one giant packet, and must fit the web
// transport at all (WebRTC data channels cap a message around 16KB).
//
// THE SHAPE: everything routes through the host. A client sends paced frames
// to the host; the host assembles its own copy AND relays each frame to
// everyone, stamped with the sender — so every peer receives every payload
// exactly once, over any transport, and a spoofed cast from a non-host peer
// drops on the floor.
//
// That used to read "kit/comms' shape, sized up", and it was: the same state
// machine, typed out twice. It is `ksess.Host_Relay` now — stamp, spoof-drop,
// echo policy, addressed replay — and what is left here is a payload codec
// (chunking, assembly, supersede) over a queue. xfer runs the relay with
// `echo = false`: you already hold the bytes you sent, so your own upload
// coming back around is dropped, on both roles, by the same rule.
//
//     kxfer.xfer_init(&self.xfer, &self.ses)            // once, by the session
//     kxfer.xfer_send(&self.xfer, SPRAY_ID, png_bytes)  // anyone, once
//     kxfer.xfer_pump(&self.xfer)                       // once per net tick
//     for ev in kxfer.xfer_poll(&self.xfer) { ... }     // Ev_Started / Ev_Done
//
// Payloads are identified by a game-chosen id byte per sender — (sender, id)
// is the key. Re-sending the same id restarts that assembly on every receiver
// (seq 0 resets). The reliable channel is ORDERED per sender, so chunks arrive
// sequential; a gap means a restarted send, never loss.

import knet "godot:kit/net"
import ksess "godot:kit/session"

// The default SES_APP tag; pass another to xfer_init if the game claims 2.
XFER_TAG :: u8(2)

// One frame's payload budget. WebRTC data channels reject messages ~16KB and
// up on some paths; half that leaves headroom for the session's own framing.
CHUNK :: 8 * 1024

// The ceiling a receiver will assemble. A hostile or fat-fingered total past
// this drops the transfer at the first frame.
MAX_PAYLOAD :: 512 * 1024

// How many chunks one xfer_pump ships (per net tick: 2 at 60Hz ≈ 960KB/s cap,
// gentle enough that gameplay traffic never queues behind a spray).
PUMP_CHUNKS :: 2

Ev_Started :: struct {
	from:  knet.Player_Id,
	id:    u8,
	total: int, // bytes incoming
}

Ev_Done :: struct {
	from:  knet.Player_Id,
	id:    u8,
	// Owned by the xfer. Valid through the frame you polled the event —
	// copy to keep. (A fast supersede — the next payload's first chunk
	// landing in the same pump window as this one's last — RETIRES the
	// buffer; it stays alive until its event drains, then frees on the
	// next pump. Holding bytes across frames was never survivable: the
	// old contract freed them on restart with the event still queued.)
	bytes: []u8,
}

Event :: union {
	Ev_Started,
	Ev_Done,
}

@(private)
Out :: struct {
	id:   u8,
	data: []u8, // owned copy
	seq:  int, // next chunk to ship
}

@(private)
Asm :: struct {
	total:  int, // bytes expected
	chunks: int, // frames expected
	seq:    int, // next frame wanted (ordered channel: gaps = a restart)
	buf:    [dynamic]u8,
	done:   bool,
}

Xfer :: struct {
	ses:     ^ksess.Session,
	relay:   ksess.Host_Relay,
	outbox:  [dynamic]Out,
	inbox:   map[Xfer_Key]Asm, // keyed by (sender, id)
	events:  ksess.App_Queue(Event),
	// Superseded DONE buffers whose Ev_Done still sits in `events` (a fast
	// restart landed before the consumer polled): kept alive until the event
	// drains, freed by the next pump — never yanked from under a queued event.
	retired: [dynamic][dynamic]u8,
}

// ---- wire (the payload inside the relay's envelope) ------------------------
//
// ONE frame shape, not two: the relay's [RELAY_UP|RELAY_CAST][author] envelope
// carries the direction and the sender, so the old chunk/cast pair — the same
// frame twice, once unstamped and once with a Player_Id glued on the front —
// is a single layout on both arms.
//
//     [id u8][seq u16][chunks u16][total u32][bytes]

// A struct key, never a packed int: `u32(from) << 8 | id` kept only 24 bits of
// the u64 Player_Id — two players colliding mod 2^24 would cross-assemble each
// other's transfers. Same rule as the session's Interest_Key.
Xfer_Key :: struct {
	from: knet.Player_Id,
	id:   u8,
}

@(private)
key_of :: proc "contextless" (from: knet.Player_Id, id: u8) -> Xfer_Key {
	return Xfer_Key{from, id}
}

xfer_init :: proc(x: ^Xfer, ses: ^ksess.Session, tag := XFER_TAG) {
	x.ses = ses
	// echo = false: nothing I send comes back to me — my own upload's cast is
	// dropped on arrival, and the host's own broadcast never lands locally.
	ksess.relay_route(&x.relay, ses, tag, x, xfer_deliver, echo = false)
}

xfer_destroy :: proc(x: ^Xfer) {
	ksess.relay_unroute(&x.relay)
	for out in x.outbox {
		delete(out.data)
	}
	delete(x.outbox)
	for _, asm_ in x.inbox {
		delete(asm_.buf)
	}
	delete(x.inbox)
	ksess.appq_destroy(&x.events)
	for buf in x.retired {
		delete(buf)
	}
	delete(x.retired)
	x^ = {}
}

// Queue a payload for everyone (a copy is taken). Ships over the next pumps.
// Sending an id again supersedes the older queued copy and restarts the
// assembly on every receiver.
xfer_send :: proc(x: ^Xfer, id: u8, bytes: []u8) -> bool {
	if len(bytes) == 0 || len(bytes) > MAX_PAYLOAD {
		return false
	}
	for i := len(x.outbox) - 1; i >= 0; i -= 1 {
		if x.outbox[i].id == id {
			delete(x.outbox[i].data)
			ordered_remove(&x.outbox, i)
		}
	}
	data := make([]u8, len(bytes))
	copy(data, bytes)
	append(&x.outbox, Out{id = id, data = data})
	return true
}

// A queued Ev_Done for (from,id)? The retire path asks before freeing a
// superseded buffer from under it.
@(private = "file")
done_queued :: proc(x: ^Xfer, from: knet.Player_Id, id: u8) -> bool {
	for ev in ksess.appq_items(&x.events) {
		if d, ok := ev.(Ev_Done); ok && d.from == from && d.id == id {
			return true
		}
	}
	return false
}

// One chunk of `data` framed and flushed — the pacing atom shared by
// xfer_pump (my own outbox, over my role's arm of the relay) and the album's
// replay_pump (host, addressed, under the original author); the two loops were
// line-for-line twins before it. The caller opens the frame — relay_begin for
// mine, relay_begin_as for a replay — and this writes the payload. Returns
// true when the payload completed, so the caller retires it.
@(private)
chunk_send :: proc(w: ^knet.Writer, hr: ^ksess.Host_Relay, id: u8, seq: ^int, data: []u8, to: ksess.Peer_Id) -> (done: bool) {
	chunks := (len(data) + CHUNK - 1) / CHUNK
	lo := seq^ * CHUNK
	hi := min(lo + CHUNK, len(data))
	knet.write_u8(w, id)
	knet.write_u16(w, u16(seq^))
	knet.write_u16(w, u16(chunks))
	knet.write_u32(w, u32(len(data)))
	knet.write_bytes(w, data[lo:hi])
	ksess.relay_flush(hr, to)
	seq^ += 1
	return seq^ >= chunks
}

// Ship up to `budget` chunks. Call once per NET TICK — the pacing is the
// point (one giant reliable packet stalls everything queued behind it).
xfer_pump :: proc(x: ^Xfer, budget := PUMP_CHUNKS) {
	// Free retired buffers whose Ev_Done has drained — the one-frame grace a
	// polled consumer gets to copy (see Ev_Done's ownership note).
	for i := len(x.retired) - 1; i >= 0; i -= 1 {
		referenced := false
		for ev in ksess.appq_items(&x.events) {
			if d, ok := ev.(Ev_Done); ok && raw_data(d.bytes) == raw_data(x.retired[i][:]) {
				referenced = true
				break
			}
		}
		if !referenced {
			delete(x.retired[i])
			unordered_remove(&x.retired, i)
		}
	}
	if x.ses == nil || len(x.outbox) == 0 {
		return
	}
	left := budget
	for left > 0 && len(x.outbox) > 0 {
		out := &x.outbox[0]
		// No role branch: relay_begin frames a host's stamped cast and a
		// client's upload from the same call, and relay_flush picks the peer.
		if chunk_send(ksess.relay_begin(&x.relay), &x.relay, out.id, &out.seq, out.data, ksess.BROADCAST_PEER) {
			delete(out.data)
			ordered_remove(&x.outbox, 0)
		}
		left -= 1
	}
}

// Drain one queued event (call until ok=false each frame).
xfer_poll :: proc(x: ^Xfer) -> (ev: Event, ok: bool) {
	return ksess.appq_poll(&x.events)
}

// ---- internals --------------------------------------------------------------

// Fold one frame into (from,id)'s assembly; emits Started at seq 0 and Done
// at the last byte. An out-of-order seq poisons the assembly until the next
// seq-0 restart (the ordered channel makes gaps mean RESTART, not loss).
@(private = "file")
ingest :: proc(x: ^Xfer, from: knet.Player_Id, id: u8, seq, chunks: int, total: int, piece: []u8) {
	if total <= 0 || total > MAX_PAYLOAD || chunks <= 0 || seq >= chunks {
		return
	}
	k := key_of(from, id)
	asm_, has := &x.inbox[k]
	if seq == 0 {
		if has {
			if asm_.done && done_queued(x, from, id) {
				// The fast supersede: this payload's Ev_Done is still queued
				// (the consumer never polled between the last chunk and this
				// restart) — freeing now would hand it dangling bytes. Retire
				// the buffer; the pump frees it once the event drains.
				append(&x.retired, asm_.buf)
			} else {
				delete(asm_.buf)
			}
		}
		x.inbox[k] = Asm{total = total, chunks = chunks, buf = make([dynamic]u8, 0, total)}
		asm_ = &x.inbox[k]
		ksess.appq_push(&x.events, Event(Ev_Started{from = from, id = id, total = total}))
	} else if !has || asm_.done || seq != asm_.seq + 1 || total != asm_.total {
		return // a straggler from a superseded send, or nothing to grow
	}
	asm_.seq = seq
	append(&asm_.buf, ..piece)
	if len(asm_.buf) > asm_.total {
		delete(asm_.buf)
		delete_key(&x.inbox, k)
		return // liar totals: drop the whole thing
	}
	if seq == asm_.chunks - 1 {
		if len(asm_.buf) != asm_.total {
			delete(asm_.buf)
			delete_key(&x.inbox, k)
			return
		}
		asm_.done = true
		ksess.appq_push(&x.events, Event(Ev_Done{from = from, id = id, bytes = asm_.buf[:]}))
	}
}

// The whole receive half, both roles, one parse. The relay did the rest: it
// forwarded the client's frame to everyone stamped with `author` BEFORE
// handing it here (the host's own copy grows after the hop, never before it),
// it dropped the spoofed casts, and with echo = false it dropped my own upload
// coming back around.
@(private = "file")
xfer_deliver :: proc(user: rawptr, author: knet.Player_Id, r: ^knet.Reader) {
	x := cast(^Xfer)user
	id := knet.read_u8(r)
	seq := int(knet.read_u16(r))
	chunks := int(knet.read_u16(r))
	total := int(knet.read_u32(r))
	piece := knet.read_bytes(r)
	if r.err {
		return
	}
	ingest(x, author, id, seq, chunks, total, piece)
}
