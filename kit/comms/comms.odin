package kit_comms

// kit/comms — how friends talk while they play (toolkit phase 2): text chat,
// positional pings/markers, and system lines ("alice joined the cave"). Small
// on purpose — it is the end-to-end shakedown of app messaging + kit/ui
// before the big system clusters.
//
// THE SHAPE: everything routes through the host, which stamps the speaker and
// rebroadcasts — so every peer sees the same lines in the same order (the
// host's order), on any transport. Your own chat line comes back with the
// broadcast rather than echoing locally: authoritative order beats a few
// milliseconds, and it means what you see IS what everyone sees. Markers ride
// the same way but are transient events, not log lines.
//
// It rides the session's SES_APP extension point — zero extra game wiring:
//
//     kcomms.comms_init(&self.comms, &self.ses)      // once, next to the session
//     kcomms.comms_say(&self.comms, "found a torch") // anyone
//     kcomms.comms_ping(&self.comms, MARK_LOOT, pos) // anyone
//     kcomms.comms_system(&self.comms, "...")        // host only (flavor text —
//                                                    // the game words its own
//                                                    // join/leave lines)
//     for ev in comms_poll(...) { ... }              // repaint chat, spawn markers
//
// Chat lines live in a bounded log the UI repaints from (kit/ui's chat box);
// markers are poll-once events the game turns into world visuals. Late
// joiners see history when the host calls comms_catchup on their join event.

import knet "godot:kit/net"
import ksess "godot:kit/session"
import "core:strings"

// The default SES_APP tag; pass another to comms_init if the game claims 0.
COMMS_TAG :: u8(0)

// One chat message's byte budget (clipped at a rune boundary, both ends).
MAX_SAY :: 240

// The log keeps this many lines; older ones evict.
LOG_MAX :: 64

// A player-id sentinel for system lines (real ids start at 1).
SYSTEM_LINE :: knet.Player_Id(0)

Line :: struct {
	player: knet.Player_Id, // SYSTEM_LINE for system text
	text:   string, // owned by the log
}

Ev_Line :: struct {
	player: knet.Player_Id,
	text:   string, // points into the log — copy it if you keep it past a frame
}

Ev_Marker :: struct {
	player: knet.Player_Id,
	kind:   u8, // game-defined (loot here! / danger / come here / ...)
	pos:    [3]f32, // games in 2D leave z zero
}

Event :: union {
	Ev_Line,
	Ev_Marker,
}

Comms :: struct {
	ses:    ^ksess.Session,
	tag:    u8,
	log:    [dynamic]Line,
	events: [dynamic]Event,
}

// ---- wire (inside the session's SES_APP framing) ------------------------------

@(private)
CO_SAY :: u8(0) // client -> host  [text string]
@(private)
CO_MARK :: u8(1) // client -> host  [kind u8][x f32][y f32][z f32]
@(private)
CO_LINE :: u8(2) // host -> all     [player u64][text string] (player 0 = system)
@(private)
CO_MARKED :: u8(3) // host -> all   [player u64][kind u8][x][y][z]

// Bind to a session (host or client, before or after it starts). The comms
// must outlive the session's traffic — destroy it before the session.
comms_init :: proc(c: ^Comms, ses: ^ksess.Session, tag := COMMS_TAG) {
	c.ses = ses
	c.tag = tag
	ksess.session_app_route(ses, tag, c, comms_handle)
}

comms_destroy :: proc(c: ^Comms) {
	if c.ses != nil {
		ksess.session_app_route(c.ses, c.tag, nil, nil)
	}
	for line in c.log {
		delete(line.text)
	}
	delete(c.log)
	delete(c.events)
	c^ = {}
}

// Clip to `max_bytes` WITHOUT splitting a UTF-8 rune (back off continuation
// bytes). Never empties a non-empty string at sane budgets.
@(private = "file")
clip :: proc(text: string, max_bytes: int) -> string {
	if len(text) <= max_bytes {
		return text
	}
	n := max_bytes
	for n > 0 && (text[n] & 0xC0) == 0x80 {
		n -= 1
	}
	return text[:n]
}

// Say something. On the host it lands (and broadcasts) immediately; on a
// client it comes back with the host's broadcast, in everyone's shared order.
comms_say :: proc(c: ^Comms, text: string) {
	said := clip(text, MAX_SAY)
	if said == "" {
		return
	}
	if c.ses.is_host {
		host_line(c, c.ses.me, said)
		return
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, CO_SAY)
	knet.write_string(&w, said)
	ksess.session_app_send(c.ses, ksess.HOST_PEER, c.tag, knet.writer_bytes(&w))
}

// A system line: host-authored flavor text with no speaker ("bob joined the
// cave", "the door opened"). The GAME words these — comms just ships them.
comms_system :: proc(c: ^Comms, text: string) {
	assert(c.ses.is_host, "system lines come from the authority")
	host_line(c, SYSTEM_LINE, clip(text, MAX_SAY))
}

// Drop a positional marker everyone sees (poll Ev_Marker to visualize it).
comms_ping :: proc(c: ^Comms, kind: u8, pos: [3]f32) {
	if c.ses.is_host {
		host_marker(c, c.ses.me, kind, pos)
		return
	}
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, CO_MARK)
	knet.write_u8(&w, kind)
	knet.write_f32(&w, pos.x)
	knet.write_f32(&w, pos.y)
	knet.write_f32(&w, pos.z)
	ksess.session_app_send(c.ses, ksess.HOST_PEER, c.tag, knet.writer_bytes(&w))
}

// Host: replay the whole log to one player — call on Ev_Player_Joined so a
// drop-in joiner sees what they missed. Skip it when `rejoin` is true if the
// player might still hold this run's log (same-session reconnect duplicates).
comms_catchup :: proc(c: ^Comms, player: knet.Player_Id) {
	assert(c.ses.is_host)
	p, ok := ksess.session_player(c.ses, player)
	if !ok || !p.connected || p.id == c.ses.me {
		return
	}
	for line in c.log {
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		write_line(&w, line.player, line.text)
		ksess.session_app_send(c.ses, p.peer, c.tag, knet.writer_bytes(&w))
	}
}

// Drain one queued event (call until ok=false each frame).
comms_poll :: proc(c: ^Comms) -> (ev: Event, ok: bool) {
	if len(c.events) == 0 {
		return nil, false
	}
	ev = c.events[0]
	ordered_remove(&c.events, 0)
	return ev, true
}

// The log, oldest first — what a chat box repaints from.
comms_lines :: proc(c: ^Comms) -> []Line {
	return c.log[:]
}

// Who said a line, for display ("" for system lines; departed players stay
// in the roster, so names stay resolvable).
comms_line_name :: proc(c: ^Comms, line: Line) -> string {
	if line.player == SYSTEM_LINE {
		return ""
	}
	if p, ok := ksess.session_player(c.ses, line.player); ok {
		return p.name
	}
	return "???"
}

// ---- internals -----------------------------------------------------------------

@(private = "file")
write_line :: proc(w: ^knet.Writer, player: knet.Player_Id, text: string) {
	knet.write_u8(w, CO_LINE)
	knet.write_player_id(w, player)
	knet.write_string(w, text)
}

// Host: land a line locally and broadcast it — the one place lines are minted,
// so the host's log order IS the shared order.
@(private = "file")
host_line :: proc(c: ^Comms, player: knet.Player_Id, text: string) {
	deliver_line(c, player, text)
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	write_line(&w, player, text)
	ksess.session_app_send(c.ses, ksess.BROADCAST_PEER, c.tag, knet.writer_bytes(&w))
}

@(private = "file")
host_marker :: proc(c: ^Comms, player: knet.Player_Id, kind: u8, pos: [3]f32) {
	append(&c.events, Ev_Marker{player = player, kind = kind, pos = pos})
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, CO_MARKED)
	knet.write_player_id(&w, player)
	knet.write_u8(&w, kind)
	knet.write_f32(&w, pos.x)
	knet.write_f32(&w, pos.y)
	knet.write_f32(&w, pos.z)
	ksess.session_app_send(c.ses, ksess.BROADCAST_PEER, c.tag, knet.writer_bytes(&w))
}

@(private = "file")
deliver_line :: proc(c: ^Comms, player: knet.Player_Id, text: string) {
	if len(c.log) >= LOG_MAX {
		delete(c.log[0].text)
		ordered_remove(&c.log, 0)
	}
	owned := strings.clone(text)
	append(&c.log, Line{player = player, text = owned})
	append(&c.events, Ev_Line{player = player, text = owned})
}

@(private = "file")
comms_handle :: proc(user: rawptr, from: knet.Player_Id, from_peer: ksess.Peer_Id, r: ^knet.Reader) {
	c := cast(^Comms)user
	kind := knet.read_u8(r)
	if r.err {
		return
	}
	if c.ses.is_host {
		// The session already vouched for `from` (seated player).
		switch kind {
		case CO_SAY:
			said := clip(knet.read_string(r), MAX_SAY) // clip again: trust boundary
			if r.err || said == "" {
				return
			}
			host_line(c, from, said)
		case CO_MARK:
			kind_byte := knet.read_u8(r)
			pos := [3]f32{knet.read_f32(r), knet.read_f32(r), knet.read_f32(r)}
			if r.err {
				return
			}
			host_marker(c, from, kind_byte, pos)
		}
		return
	}
	// Client: only the host mints lines and markers — a peer broadcasting
	// these directly (transport relay allows it) is spoofing; drop it.
	if from_peer != ksess.HOST_PEER {
		return
	}
	switch kind {
	case CO_LINE:
		player := knet.read_player_id(r)
		text := knet.read_string(r)
		if r.err {
			return
		}
		deliver_line(c, player, text)
	case CO_MARKED:
		player := knet.read_player_id(r)
		kind_byte := knet.read_u8(r)
		pos := [3]f32{knet.read_f32(r), knet.read_f32(r), knet.read_f32(r)}
		if r.err {
			return
		}
		append(&c.events, Ev_Marker{player = player, kind = kind_byte, pos = pos})
	}
}
