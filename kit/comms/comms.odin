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
// That shape is not written here anymore — it is `ksess.Host_Relay` (stamp,
// spoof-drop, echo policy, addressed replay), which kit/comms and kit/xfer had
// hand-rolled twice. What is left in this file is a PAYLOAD CODEC over a
// queue: two message kinds and a bounded log. Note what vanished with it —
// every `if c.ses.is_host` at a send door: comms_say writes the same bytes on
// both roles and the relay picks the arm.
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
	relay:  ksess.Host_Relay,
	log:    [dynamic]Line,
	events: ksess.App_Queue(Event),
}

// ---- wire (the payload inside the relay's envelope) ---------------------------
//
// Two kinds, not four: the relay's [RELAY_UP|RELAY_CAST][author] envelope
// carries the direction and the speaker, so the old say/line and mark/marked
// pairs — the same message twice, once unstamped and once stamped — collapse
// into one each.

@(private)
CO_SAY :: u8(0) // [text string]
@(private)
CO_MARK :: u8(1) // [kind u8][x f32][y f32][z f32]

// Bind to a session (host or client, before or after it starts). The comms
// must outlive the session's traffic — destroy it before the session.
comms_init :: proc(c: ^Comms, ses: ^ksess.Session, tag := COMMS_TAG) {
	c.ses = ses
	// echo = true: your own line lands in YOUR log the same way it lands in
	// everyone else's — through the host's broadcast, in the host's order.
	ksess.relay_route(&c.relay, ses, tag, c, comms_deliver, echo = true)
}

comms_destroy :: proc(c: ^Comms) {
	ksess.relay_unroute(&c.relay)
	for line in c.log {
		delete(line.text)
	}
	delete(c.log)
	ksess.appq_destroy(&c.events)
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

// Say something. Role-free at the call site AND in here: the host's own line
// broadcasts and lands locally, a client's goes up and comes back with the
// broadcast — one set of bytes, the relay picks the arm.
comms_say :: proc(c: ^Comms, text: string) {
	said := clip(text, MAX_SAY)
	if said == "" {
		return
	}
	w := ksess.relay_begin(&c.relay)
	knet.write_u8(w, CO_SAY)
	knet.write_string(w, said)
	ksess.relay_flush(&c.relay)
}

// A system line: host-authored flavor text with no speaker ("bob joined the
// cave", "the door opened"). The GAME words these — comms just ships them.
comms_system :: proc(c: ^Comms, text: string) {
	assert(c.ses.is_host, "system lines come from the authority")
	w := ksess.relay_begin_as(&c.relay, SYSTEM_LINE)
	knet.write_u8(w, CO_SAY)
	knet.write_string(w, clip(text, MAX_SAY))
	ksess.relay_flush(&c.relay)
}

// Drop a positional marker everyone sees (poll Ev_Marker to visualize it).
comms_ping :: proc(c: ^Comms, kind: u8, pos: [3]f32) {
	w := ksess.relay_begin(&c.relay)
	knet.write_u8(w, CO_MARK)
	knet.write_u8(w, kind)
	knet.write_f32(w, pos.x)
	knet.write_f32(w, pos.y)
	knet.write_f32(w, pos.z)
	ksess.relay_flush(&c.relay)
}

// The whole drop-in ritual, in the one order that works: replay the log to
// the joiner FIRST (skipped on rejoin — they may still hold this run's log),
// THEN mint the join line, so the replay cannot duplicate the line it is
// about to receive from the broadcast. The GAME words the line ("" = say
// nothing). Call from Ev_Player_Joined and stop thinking about ordering.
comms_welcome :: proc(c: ^Comms, player: knet.Player_Id, rejoin: bool, line: string) {
	assert(c.ses.is_host)
	if !rejoin {
		comms_catchup(c, player)
	}
	if line != "" {
		comms_system(c, line)
	}
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
		// Each line re-cast under its ORIGINAL speaker, addressed to the one
		// joiner: an addressed cast never echoes, so replaying history can't
		// re-file it into the host's own log.
		w := ksess.relay_begin_as(&c.relay, line.player)
		knet.write_u8(w, CO_SAY)
		knet.write_string(w, line.text)
		ksess.relay_flush(&c.relay, p.peer)
	}
}

// Drain one queued event (call until ok=false each frame).
comms_poll :: proc(c: ^Comms) -> (ev: Event, ok: bool) {
	return ksess.appq_poll(&c.events)
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
deliver_line :: proc(c: ^Comms, player: knet.Player_Id, text: string) {
	if len(c.log) >= LOG_MAX {
		delete(c.log[0].text)
		ordered_remove(&c.log, 0)
	}
	owned := strings.clone(text)
	append(&c.log, Line{player = player, text = owned})
	ksess.appq_push(&c.events, Event(Ev_Line{player = player, text = owned}))
}

// The whole receive half, both roles, one switch: the relay already resolved
// `author` (the host's stamp on a client's word, or the host's own name), and
// already dropped the spoofs. This proc only FILES — the game drains with
// comms_poll on its own stack.
@(private = "file")
comms_deliver :: proc(user: rawptr, author: knet.Player_Id, r: ^knet.Reader) {
	c := cast(^Comms)user
	kind := knet.read_u8(r)
	if r.err {
		return
	}
	switch kind {
	case CO_SAY:
		said := clip(knet.read_string(r), MAX_SAY) // clip again: trust boundary
		if r.err || said == "" {
			return
		}
		deliver_line(c, author, said)
	case CO_MARK:
		kind_byte := knet.read_u8(r)
		pos := [3]f32{knet.read_f32(r), knet.read_f32(r), knet.read_f32(r)}
		if r.err {
			return
		}
		ksess.appq_push(&c.events, Event(Ev_Marker{player = author, kind = kind_byte, pos = pos}))
	}
}
