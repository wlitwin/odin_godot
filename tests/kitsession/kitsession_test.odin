package kit_session_test

// Standalone tests for kit/session — player identity, join/leave/reconnect,
// roster sync. No Godot runtime:
//
//   odin test tests/kitsession -collection:godot=$PWD
//
// Sessions are wired through an in-memory pipe (Peer_Box), so the full wire
// path — JOIN/WELCOME/UPSERT/LEFT bytes included — is exercised exactly as it
// runs over the real transport, minus the socket.

import "core:testing"
import knet "godot:kit/net"
import ksess "godot:kit/session"

Envelope :: struct {
	to:   int,
	data: []u8,
}

Peer_Box :: struct {
	peer: int,
	s:    ksess.Session,
	out:  [dynamic]Envelope,
}

box_send :: proc(user: rawptr, to_peer: int, bytes: []u8) {
	b := cast(^Peer_Box)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&b.out, Envelope{to = to_peer, data = cloned})
}

box_make :: proc(b: ^Peer_Box, peer: int) {
	b.peer = peer
	b.s.send = box_send
	b.s.send_user = b
}

box_destroy :: proc(b: ^Peer_Box) {
	for e in b.out {
		delete(e.data)
	}
	delete(b.out)
	ksess.session_destroy(&b.s)
}

// Deliver every queued message (including ones queued by handling) until the
// network is quiet.
pump :: proc(boxes: []^Peer_Box) {
	for progress := true; progress; {
		progress = false
		for b in boxes {
			for len(b.out) > 0 {
				e := b.out[0]
				ordered_remove(&b.out, 0)
				for dst in boxes {
					if dst.peer == e.to {
						r := knet.reader_make(e.data)
						ksess.session_handle_packet(&dst.s, b.peer, &r)
						break
					}
				}
				delete(e.data)
				progress = true
			}
		}
	}
}

drain :: proc(s: ^ksess.Session) -> [dynamic]ksess.Event {
	evs := make([dynamic]ksess.Event, context.temp_allocator)
	for {
		ev, ok := ksess.session_poll(s)
		if !ok {break}
		append(&evs, ev)
	}
	return evs
}

TOKEN_ALICE :: u64(0xA11CE)
TOKEN_BOB :: u64(0xB0B)

@(test)
join_builds_the_roster_everywhere :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "hosty")
	testing.expect_value(t, host.s.me, knet.Player_Id(1))
	testing.expect_value(t, ksess.session_count(&host.s), 1)

	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	testing.expect_value(t, alice.s.me, knet.Player_Id(2))
	testing.expect(t, alice.s.joined)
	testing.expect_value(t, ksess.session_count(&alice.s), 2) // host + self
	hp, _ := ksess.session_player(&alice.s, 1)
	testing.expect_value(t, hp.name, "hosty")

	aev := drain(&alice.s)
	testing.expect_value(t, len(aev), 1)
	_, welcomed := aev[0].(ksess.Ev_Welcomed)
	testing.expect(t, welcomed)

	hev := drain(&host.s)
	testing.expect_value(t, len(hev), 1)
	j, joined := hev[0].(ksess.Ev_Player_Joined)
	testing.expect(t, joined && j.id == 2 && !j.rejoin)

	// Bob joins: alice must hear about him WITHOUT rejoining anything.
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump(boxes)

	testing.expect_value(t, bob.s.me, knet.Player_Id(3))
	testing.expect_value(t, ksess.session_count(&bob.s), 3)
	testing.expect_value(t, ksess.session_count(&alice.s), 3)
	bp, _ := ksess.session_player(&alice.s, 3)
	testing.expect_value(t, bp.name, "bob")
	testing.expect(t, bp.connected)

	aev2 := drain(&alice.s)
	testing.expect_value(t, len(aev2), 1)
	j2, _ := aev2[0].(ksess.Ev_Player_Joined)
	testing.expect(t, j2.id == 3 && !j2.rejoin)
}

@(test)
reconnect_reclaims_identity :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 200)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob.s)
	pump([]^Peer_Box{&host, &alice, &bob})
	drain(&host.s)
	drain(&alice.s)
	drain(&bob.s)

	// Bob's transport drops. He stays in every roster, disconnected.
	ksess.session_peer_disconnected(&host.s, 200)
	pump([]^Peer_Box{&host, &alice})

	hleft := drain(&host.s)
	testing.expect_value(t, len(hleft), 1)
	l, _ := hleft[0].(ksess.Ev_Player_Left)
	testing.expect_value(t, l.id, knet.Player_Id(3))
	bp, still := ksess.session_player(&alice.s, 3)
	testing.expect(t, still, "departed players stay in the roster")
	testing.expect(t, !bp.connected)
	testing.expect_value(t, ksess.session_count(&host.s, connected_only = true), 2)
	drain(&alice.s)

	// Bob returns — NEW process, NEW transport peer, SAME persisted token.
	bob2: Peer_Box
	box_make(&bob2, 300)
	defer box_destroy(&bob2)
	ksess.session_client_start(&bob2.s, TOKEN_BOB, "bob")
	ksess.session_client_join(&bob2.s)
	pump([]^Peer_Box{&host, &alice, &bob2})

	testing.expect_value(t, bob2.s.me, knet.Player_Id(3)) // identity reclaimed
	testing.expect_value(t, ksess.session_count(&host.s, connected_only = true), 3)

	hj := drain(&host.s)
	testing.expect_value(t, len(hj), 1)
	j, _ := hj[0].(ksess.Ev_Player_Joined)
	testing.expect(t, j.id == 3 && j.rejoin, "host must see a REJOIN, not a new player")
	aj := drain(&alice.s)
	testing.expect_value(t, len(aj), 1)
	ja, _ := aj[0].(ksess.Ev_Player_Joined)
	testing.expect(t, ja.id == 3 && ja.rejoin)
	rb, _ := ksess.session_player(&alice.s, 3)
	testing.expect(t, rb.connected)

	// The host never allocated a fourth id for the returning bob.
	testing.expect_value(t, host.s.next_player, knet.Player_Id(4))
}

@(test)
zombie_takeover_same_token :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	drain(&host.s)
	drain(&alice.s)

	// Alice's machine crashed and reconnected before the old socket timed out:
	// the same token arrives from a new peer while the roster still shows her
	// connected. The new connection takes over; the zombie peer is unmapped.
	alice2: Peer_Box
	box_make(&alice2, 400)
	defer box_destroy(&alice2)
	ksess.session_client_start(&alice2.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice2.s)
	pump([]^Peer_Box{&host, &alice2})

	testing.expect_value(t, alice2.s.me, knet.Player_Id(2))
	p, _ := ksess.session_player(&host.s, 2)
	testing.expect_value(t, p.peer, 400)
	testing.expect(t, p.connected)

	// The zombie's eventual transport timeout must NOT mark the player gone —
	// its peer id is no longer mapped to anyone.
	ksess.session_peer_disconnected(&host.s, 100)
	p2, _ := ksess.session_player(&host.s, 2)
	testing.expect(t, p2.connected, "stale peer timeout must not disconnect the taken-over player")
	testing.expect_value(t, len(drain(&host.s)), 1) // only the rejoin event queued
}

@(test)
graceful_bye_and_host_loss :: proc(t: ^testing.T) {
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	drain(&host.s)
	drain(&alice.s)

	// Polite exit: BYE lands as an immediate departure.
	ksess.session_client_leave(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	hev := drain(&host.s)
	testing.expect_value(t, len(hev), 1)
	l, left := hev[0].(ksess.Ev_Player_Left)
	testing.expect(t, left && l.id == 2)

	// The later transport disconnect for the same peer is a no-op.
	ksess.session_peer_disconnected(&host.s, 100)
	testing.expect_value(t, len(drain(&host.s)), 0)

	// Client side: the host's peer dropping ends the run.
	ksess.session_peer_disconnected(&alice.s, ksess.HOST_PEER)
	aev := drain(&alice.s)
	testing.expect_value(t, len(aev), 1)
	_, over := aev[0].(ksess.Ev_Host_Left)
	testing.expect(t, over)
}

@(test)
rename_on_rejoin :: proc(t: ^testing.T) {
	host: Peer_Box
	box_make(&host, 1)
	defer box_destroy(&host)
	ksess.session_host_start(&host.s, "hosty")

	alice: Peer_Box
	box_make(&alice, 100)
	defer box_destroy(&alice)
	ksess.session_client_start(&alice.s, TOKEN_ALICE, "alice")
	ksess.session_client_join(&alice.s)
	pump([]^Peer_Box{&host, &alice})
	ksess.session_peer_disconnected(&host.s, 100)

	// Same identity, new display name: the token wins, the name refreshes.
	alice2: Peer_Box
	box_make(&alice2, 101)
	defer box_destroy(&alice2)
	ksess.session_client_start(&alice2.s, TOKEN_ALICE, "alicia")
	ksess.session_client_join(&alice2.s)
	pump([]^Peer_Box{&host, &alice2})

	testing.expect_value(t, alice2.s.me, knet.Player_Id(2))
	p, _ := ksess.session_player(&host.s, 2)
	testing.expect_value(t, p.name, "alicia")
}
