package kit_xfer

// kit/xfer — LARGE PAYLOADS over the session, chunked. The piece entity blobs
// deliberately are not: a blob rides whole on every version bump and is meant
// for state a joiner must see; a TRANSFER is a one-shot shipment of something
// big — a user-drawn spray, a custom skin, a shared level file — that must not
// stall the reliable channel behind one giant packet, and must fit the web
// transport at all (WebRTC data channels cap a message around 16KB).
//
// THE SHAPE (kit/comms' shape, sized up): everything routes through the host.
// A client sends paced XF_CHUNK frames to the host; the host assembles its own
// copy AND relays each frame to everyone as XF_CAST, stamped with the sender —
// so every peer receives every payload exactly once, over any transport, and a
// spoofed "cast" from a non-host peer drops on the floor.
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
	tag:     u8,
	outbox:  [dynamic]Out,
	inbox:   map[u32]Asm, // key: sender<<8 | id
	events:  [dynamic]Event,
	// Superseded DONE buffers whose Ev_Done still sits in `events` (a fast
	// restart landed before the consumer polled): kept alive until the event
	// drains, freed by the next pump — never yanked from under a queued event.
	retired: [dynamic][dynamic]u8,
}

// ---- wire (inside the session's SES_APP framing) ---------------------------

@(private)
XF_CHUNK :: u8(0) // client -> host  [id u8][seq u16][chunks u16][total u32][bytes]
@(private)
XF_CAST :: u8(1) // host -> all      [from player_id][id][seq][chunks][total][bytes]

@(private)
key_of :: proc "contextless" (from: knet.Player_Id, id: u8) -> u32 {
	return u32(from) << 8 | u32(id)
}

xfer_init :: proc(x: ^Xfer, ses: ^ksess.Session, tag := XFER_TAG) {
	x.ses = ses
	x.tag = tag
	ksess.session_app_route(ses, tag, x, xfer_handle)
}

xfer_destroy :: proc(x: ^Xfer) {
	if x.ses != nil {
		ksess.session_app_route(x.ses, x.tag, nil, nil)
	}
	for out in x.outbox {
		delete(out.data)
	}
	delete(x.outbox)
	for _, asm_ in x.inbox {
		delete(asm_.buf)
	}
	delete(x.inbox)
	delete(x.events)
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
	for ev in x.events {
		if d, ok := ev.(Ev_Done); ok && d.from == from && d.id == id {
			return true
		}
	}
	return false
}

// Ship up to `budget` chunks. Call once per NET TICK — the pacing is the
// point (one giant reliable packet stalls everything queued behind it).
xfer_pump :: proc(x: ^Xfer, budget := PUMP_CHUNKS) {
	// Free retired buffers whose Ev_Done has drained — the one-frame grace a
	// polled consumer gets to copy (see Ev_Done's ownership note).
	for i := len(x.retired) - 1; i >= 0; i -= 1 {
		referenced := false
		for ev in x.events {
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
		chunks := (len(out.data) + CHUNK - 1) / CHUNK
		lo := out.seq * CHUNK
		hi := min(lo + CHUNK, len(out.data))
		w := ksess.session_app_begin(x.ses, x.tag)
		if x.ses.is_host {
			knet.write_u8(w, XF_CAST)
			knet.write_player_id(w, x.ses.me)
		} else {
			knet.write_u8(w, XF_CHUNK)
		}
		knet.write_u8(w, out.id)
		knet.write_u16(w, u16(out.seq))
		knet.write_u16(w, u16(chunks))
		knet.write_u32(w, u32(len(out.data)))
		knet.write_bytes(w, out.data[lo:hi])
		ksess.session_app_flush(x.ses, x.ses.is_host ? ksess.BROADCAST_PEER : ksess.HOST_PEER)
		out.seq += 1
		left -= 1
		if out.seq >= chunks {
			delete(out.data)
			ordered_remove(&x.outbox, 0)
		}
	}
}

// Drain one queued event (call until ok=false each frame).
xfer_poll :: proc(x: ^Xfer) -> (ev: Event, ok: bool) {
	if len(x.events) == 0 {
		return nil, false
	}
	ev = x.events[0]
	ordered_remove(&x.events, 0)
	return ev, true
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
		append(&x.events, Ev_Started{from = from, id = id, total = total})
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
		append(&x.events, Ev_Done{from = from, id = id, bytes = asm_.buf[:]})
	}
}

@(private = "file")
xfer_handle :: proc(user: rawptr, from: knet.Player_Id, from_peer: ksess.Peer_Id, r: ^knet.Reader) {
	x := cast(^Xfer)user
	kind := knet.read_u8(r)
	if r.err {
		return
	}
	switch kind {
	case XF_CHUNK:
		// Client -> host only; the session vouched for `from`.
		if !x.ses.is_host {
			return
		}
		id := knet.read_u8(r)
		seq := int(knet.read_u16(r))
		chunks := int(knet.read_u16(r))
		total := int(knet.read_u32(r))
		piece := knet.read_bytes(r)
		if r.err {
			return
		}
		// Relay THIS frame to everyone (the sender skips its own echo), then
		// keep the host's own copy growing.
		w := ksess.session_app_begin(x.ses, x.tag)
		knet.write_u8(w, XF_CAST)
		knet.write_player_id(w, from)
		knet.write_u8(w, id)
		knet.write_u16(w, u16(seq))
		knet.write_u16(w, u16(chunks))
		knet.write_u32(w, u32(total))
		knet.write_bytes(w, piece)
		ksess.session_app_flush(x.ses, ksess.BROADCAST_PEER)
		ingest(x, from, id, seq, chunks, total, piece)
	case XF_CAST:
		// Only the host casts; a peer casting directly is spoofing.
		if x.ses.is_host || from_peer != ksess.HOST_PEER {
			return
		}
		cast_from := knet.read_player_id(r)
		id := knet.read_u8(r)
		seq := int(knet.read_u16(r))
		chunks := int(knet.read_u16(r))
		total := int(knet.read_u32(r))
		piece := knet.read_bytes(r)
		if r.err || cast_from == x.ses.me {
			return // malformed, or my own upload coming back around
		}
		ingest(x, cast_from, id, seq, chunks, total, piece)
	}
}
