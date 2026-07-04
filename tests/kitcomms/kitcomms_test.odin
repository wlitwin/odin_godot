package kit_comms_test

// Standalone tests for kit/comms — chat, markers, system lines — and the
// session's SES_APP extension point they ride on. No Godot runtime:
//
//   odin test tests/kitcomms -collection:godot=$PWD
//
// Same in-memory pipe as the kitsession tests (Peer_Box): the full wire path
// runs exactly as over the real transport, minus the socket.

import "core:strings"
import "core:testing"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"

Envelope :: struct {
	to:   int,
	data: []u8,
}

Peer_Box :: struct {
	peer: int,
	s:    ksess.Session,
	c:    kcomms.Comms,
	out:  [dynamic]Envelope,
}

box_send :: proc(user: rawptr, to_peer: int, bytes: []u8, channel: ksess.Channel) {
	b := cast(^Peer_Box)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&b.out, Envelope{to = to_peer, data = cloned})
}

box_make :: proc(b: ^Peer_Box, peer: int) {
	b.peer = peer
	b.s.send = box_send
	b.s.send_user = b
	kcomms.comms_init(&b.c, &b.s)
}

box_destroy :: proc(b: ^Peer_Box) {
	for e in b.out {
		delete(e.data)
	}
	delete(b.out)
	kcomms.comms_destroy(&b.c)
	ksess.session_destroy(&b.s)
}

pump :: proc(boxes: []^Peer_Box) {
	for progress := true; progress; {
		progress = false
		for b in boxes {
			for len(b.out) > 0 {
				e := b.out[0]
				ordered_remove(&b.out, 0)
				for dst in boxes {
					if dst.peer == b.peer {
						continue
					}
					if e.to == ksess.BROADCAST_PEER || dst.peer == e.to {
						r := knet.reader_make(e.data)
						ksess.session_handle_packet(&dst.s, b.peer, &r)
					}
				}
				delete(e.data)
				progress = true
			}
		}
	}
}

drain :: proc(c: ^kcomms.Comms) -> [dynamic]kcomms.Event {
	evs := make([dynamic]kcomms.Event, context.temp_allocator)
	for {
		ev, ok := kcomms.comms_poll(c)
		if !ok {break}
		append(&evs, ev)
	}
	return evs
}

// Host + two seated clients, events drained — the standard chat room.
seat_trio :: proc(host, alice, bob: ^Peer_Box) {
	box_make(host, 1)
	box_make(alice, 100)
	box_make(bob, 200)
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, 0xB0B, "bob")
	ksess.session_client_join(&bob.s)
	pump([]^Peer_Box{host, alice, bob})
	for ok := true; ok; _, ok = ksess.session_poll(&host.s) {}
	for ok := true; ok; _, ok = ksess.session_poll(&alice.s) {}
	for ok := true; ok; _, ok = ksess.session_poll(&bob.s) {}
}

@(test)
chat_relays_in_host_order :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	seat_trio(&host, &alice, &bob)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	kcomms.comms_say(&alice.c, "hi")
	pump(boxes)
	kcomms.comms_say(&host.c, "welcome")
	pump(boxes)
	kcomms.comms_say(&bob.c, "yo")
	pump(boxes)

	// Everyone holds the SAME log in the SAME order — the host's order.
	for b in boxes {
		lines := kcomms.comms_lines(&b.c)
		testing.expect_value(t, len(lines), 3)
		testing.expect_value(t, lines[0].player, knet.Player_Id(2))
		testing.expect_value(t, lines[0].text, "hi")
		testing.expect_value(t, lines[1].player, knet.Player_Id(1))
		testing.expect_value(t, lines[1].text, "welcome")
		testing.expect_value(t, lines[2].player, knet.Player_Id(3))
		testing.expect_value(t, lines[2].text, "yo")
		testing.expect_value(t, kcomms.comms_line_name(&b.c, lines[0]), "alice")
	}

	// Alice's own line arrived exactly once (the broadcast IS the echo), and
	// every line raised exactly one poll event.
	aev := drain(&alice.c)
	testing.expect_value(t, len(aev), 3)
	l0, _ := aev[0].(kcomms.Ev_Line)
	testing.expect(t, l0.player == 2 && l0.text == "hi")
}

@(test)
system_lines_reach_everyone :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	seat_trio(&host, &alice, &bob)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	kcomms.comms_system(&host.c, "the cave rumbles")
	pump(boxes)

	for b in boxes {
		lines := kcomms.comms_lines(&b.c)
		testing.expect_value(t, len(lines), 1)
		testing.expect_value(t, lines[0].player, kcomms.SYSTEM_LINE)
		testing.expect_value(t, lines[0].text, "the cave rumbles")
		testing.expect_value(t, kcomms.comms_line_name(&b.c, lines[0]), "")
	}
}

@(test)
markers_relay_with_position :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	seat_trio(&host, &alice, &bob)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	kcomms.comms_ping(&bob.c, 3, {1.5, -2, 0})
	pump(boxes)

	// Everyone (bob included, via the authoritative echo) sees the marker;
	// nobody's chat log grew — markers are transient events.
	for b in boxes {
		evs := drain(&b.c)
		testing.expect_value(t, len(evs), 1)
		m, is_marker := evs[0].(kcomms.Ev_Marker)
		testing.expect(t, is_marker)
		testing.expect_value(t, m.player, knet.Player_Id(3))
		testing.expect_value(t, m.kind, u8(3))
		testing.expect_value(t, m.pos, [3]f32{1.5, -2, 0})
		testing.expect_value(t, len(kcomms.comms_lines(&b.c)), 0)
	}

	// And the host can ping too.
	kcomms.comms_ping(&host.c, 1, {9, 9, 9})
	pump(boxes)
	aev := drain(&alice.c)
	testing.expect_value(t, len(aev), 1)
	hm, _ := aev[0].(kcomms.Ev_Marker)
	testing.expect(t, hm.player == 1 && hm.kind == 1)
}

@(test)
oversize_say_clips_at_rune_boundary :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	seat_trio(&host, &alice, &bob)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	// 239 ASCII bytes, then a 2-byte rune straddling the MAX_SAY boundary:
	// a naive byte cut at 240 would split it — the clip must back off to 239.
	b := strings.builder_make(context.temp_allocator)
	for _ in 0 ..< 239 {
		strings.write_byte(&b, 'a')
	}
	strings.write_string(&b, "é and plenty more text past the limit")
	kcomms.comms_say(&alice.c, strings.to_string(b))
	pump(boxes)

	for box in boxes {
		lines := kcomms.comms_lines(&box.c)
		testing.expect_value(t, len(lines), 1)
		testing.expect_value(t, len(lines[0].text), 239)
		testing.expect_value(t, lines[0].text[238], u8('a'))
	}
}

@(test)
unseated_peer_chat_is_dropped :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	seat_trio(&host, &alice, &bob)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)

	// Charlie is CONNECTED but never JOINed — his chat is from nobody.
	charlie: Peer_Box
	box_make(&charlie, 300)
	defer box_destroy(&charlie)
	ksess.session_client_start(&charlie.s, 0xC7A12, "charlie")

	kcomms.comms_say(&charlie.c, "sneaking in")
	pump([]^Peer_Box{&host, &alice, &bob, &charlie})

	testing.expect_value(t, len(kcomms.comms_lines(&host.c)), 0)
	testing.expect_value(t, len(kcomms.comms_lines(&alice.c)), 0)
}

@(test)
log_evicts_oldest :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	seat_trio(&host, &alice, &bob)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	for i in 0 ..< 70 {
		b := strings.builder_make(context.temp_allocator)
		strings.write_string(&b, "m")
		strings.write_int(&b, i)
		kcomms.comms_say(&host.c, strings.to_string(b))
	}
	pump(boxes)

	for box in boxes {
		lines := kcomms.comms_lines(&box.c)
		testing.expect_value(t, len(lines), kcomms.LOG_MAX)
		testing.expect_value(t, lines[0].text, "m6") // m0..m5 evicted
		testing.expect_value(t, lines[len(lines) - 1].text, "m69")
	}
}

@(test)
late_joiner_catches_up :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	for ok := true; ok; _, ok = ksess.session_poll(&host.s) {}

	kcomms.comms_system(&host.c, "the run began")
	kcomms.comms_say(&host.c, "good luck")
	pump([]^Peer_Box{&host, &alice})

	// Bob drops in later: empty log until the host's join-event handler
	// replays history for him.
	bob: Peer_Box
	box_make(&bob, 200)
	defer box_destroy(&bob)
	ksess.session_client_start(&bob.s, 0xB0B, "bob")
	ksess.session_client_join(&bob.s)
	pump([]^Peer_Box{&host, &alice, &bob})
	testing.expect_value(t, len(kcomms.comms_lines(&bob.c)), 0)

	for {
		ev, ok := ksess.session_poll(&host.s)
		if !ok {break}
		if j, joined := ev.(ksess.Ev_Player_Joined); joined && !j.rejoin {
			kcomms.comms_catchup(&host.c, j.id)
		}
	}
	pump([]^Peer_Box{&host, &alice, &bob})

	lines := kcomms.comms_lines(&bob.c)
	testing.expect_value(t, len(lines), 2)
	testing.expect_value(t, lines[0].player, kcomms.SYSTEM_LINE)
	testing.expect_value(t, lines[0].text, "the run began")
	testing.expect_value(t, lines[1].player, knet.Player_Id(1))
	testing.expect_value(t, lines[1].text, "good luck")
	// Alice heard nothing new.
	testing.expect_value(t, len(kcomms.comms_lines(&alice.c)), 2)
}

// ---- the SES_APP contract itself (session-level) --------------------------------

App_Probe :: struct {
	calls: int,
	from:  knet.Player_Id,
	value: u32,
}

probe_handle :: proc(user: rawptr, from: knet.Player_Id, from_peer: int, r: ^knet.Reader) {
	p := cast(^App_Probe)user
	p.calls += 1
	p.from = from
	p.value = knet.read_u32(r)
}

@(test)
app_routes_resolve_the_sender :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	seat_trio(&host, &alice, &bob)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	// A second package on tag 1, next to comms on tag 0.
	probe: App_Probe
	ksess.session_app_route(&host.s, 1, &probe, probe_handle)

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u32(&w, 0xC0FFEE)
	ksess.session_app_send(&alice.s, ksess.HOST_PEER, 1, knet.writer_bytes(&w))
	pump(boxes)

	testing.expect_value(t, probe.calls, 1)
	testing.expect_value(t, probe.from, knet.Player_Id(2)) // the SEATED sender, resolved
	testing.expect_value(t, probe.value, u32(0xC0FFEE))

	// An unrouted tag is dropped without ceremony (and without touching comms).
	ksess.session_app_send(&alice.s, ksess.HOST_PEER, 5, knet.writer_bytes(&w))
	pump(boxes)
	testing.expect_value(t, probe.calls, 1)
	testing.expect_value(t, len(kcomms.comms_lines(&host.c)), 0)
}
