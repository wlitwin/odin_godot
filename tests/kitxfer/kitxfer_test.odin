package kit_xfer_test

// Standalone tests for kit/xfer's ALBUM — the latest payload per (player,
// kind), kept and replayed — over the same in-memory session pipe as the
// kitcomms tests. No Godot runtime:
//
//   odin test tests/kitxfer -collection:godot=$PWD
//
// Covers: put→converge on every seat (multi-chunk, paced), the local
// own-copy short circuit, supersede-on-re-put, and the late joiner's
// album_welcome catch-up (the story a one-shot transfer can't tell).

import "core:testing"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import kxfer "godot:kit/xfer"

SPRAY :: u8(1)

Envelope :: struct {
	to:   ksess.Peer_Id,
	data: []u8,
}

Peer_Box :: struct {
	peer:  ksess.Peer_Id,
	s:     ksess.Session,
	album: kxfer.Album,
	out:   [dynamic]Envelope,
}

box_send :: proc(user: rawptr, to_peer: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	b := cast(^Peer_Box)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&b.out, Envelope{to = to_peer, data = cloned})
}

box_make :: proc(b: ^Peer_Box, peer: ksess.Peer_Id) {
	b.peer = peer
	b.s.send = box_send
	b.s.send_user = b
	kxfer.album_init(&b.album, &b.s)
}

box_destroy :: proc(b: ^Peer_Box) {
	kxfer.album_destroy(&b.album)
	for e in b.out {
		delete(e.data)
	}
	delete(b.out)
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

// Enough album_pump+pipe rounds to drain any queued chunks everywhere.
settle :: proc(boxes: []^Peer_Box) {
	for _ in 0 ..< 32 {
		for b in boxes {
			kxfer.album_pump(&b.album)
		}
		pump(boxes)
	}
}

// A recognizable multi-chunk payload (3 chunks at the 8KB CHUNK size).
payload :: proc(seed: u8, n: int) -> []u8 {
	bytes := make([]u8, n)
	for i in 0 ..< n {
		bytes[i] = seed ~ u8(i * 7)
	}
	return bytes
}

@(test)
album_ships_keeps_and_supersedes :: proc(t: ^testing.T) {
	host, alice, bob: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	box_make(&bob, 101)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&bob)
	boxes := []^Peer_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_start(&bob.s, 0xB0B, "bob")
	ksess.session_client_join(&alice.s)
	ksess.session_client_join(&bob.s)
	pump(boxes)

	tag := payload(0x5A, 20_000)
	defer delete(tag)
	testing.expect(t, kxfer.album_put(&alice.album, SPRAY, tag), "put accepted")

	// The own-copy short circuit: alice reads her tag back the same frame,
	// before a single chunk ships.
	mine, mok := kxfer.album_get(&alice.album, alice.s.me, SPRAY)
	testing.expect(t, mok, "alice's own payload is on her shelf immediately")
	testing.expect(t, len(mine) == len(tag), "own copy is whole")

	settle(boxes)

	for b in ([]^Peer_Box{&host, &bob}) {
		got, ok := kxfer.album_get(&b.album, alice.s.me, SPRAY)
		testing.expect(t, ok, "the payload landed on every seat")
		same := len(got) == len(tag)
		if same {
			for v, i in got {
				if v != tag[i] {
					same = false
					break
				}
			}
		}
		testing.expect(t, same, "payload bytes byte-identical after chunked transit")
	}
	// The landed event fired exactly once per seat for the repaint hook.
	from, id, ok := kxfer.album_poll(&bob.album)
	testing.expect(t, ok && from == alice.s.me && id == SPRAY, "bob's poll names the landing")
	_, _, more := kxfer.album_poll(&bob.album)
	testing.expect(t, !more, "one landing, one event")

	// Supersede: a re-put replaces the shelf copy everywhere.
	tag2 := payload(0xC3, 12_000)
	defer delete(tag2)
	testing.expect(t, kxfer.album_put(&alice.album, SPRAY, tag2), "re-put accepted")
	settle(boxes)
	got2, _ := kxfer.album_get(&bob.album, alice.s.me, SPRAY)
	testing.expect(t, len(got2) == len(tag2) && got2[1] == tag2[1], "the fresher payload superseded")
}

@(test)
album_welcomes_the_late_joiner :: proc(t: ^testing.T) {
	host, alice, carol: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	defer box_destroy(&carol)
	early := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	pump(early)

	tag := payload(0x77, 20_000)
	defer delete(tag)
	kxfer.album_put(&alice.album, SPRAY, tag)
	settle(early)
	for {
		_, _, more := kxfer.album_poll(&alice.album)
		if !more {break} // drain alice's own-put landing before the join
	}

	// Carol arrives AFTER the shipment — the one-shot transfer alone would
	// never reach her.
	box_make(&carol, 102)
	boxes := []^Peer_Box{&host, &alice, &carol}
	ksess.session_client_start(&carol.s, 0xCA401, "carol")
	ksess.session_client_join(&carol.s)
	pump(boxes)

	_, before := kxfer.album_get(&carol.album, alice.s.me, SPRAY)
	testing.expect(t, !before, "no catch-up without album_welcome")

	kxfer.album_welcome(&host.album, carol.s.me)
	settle(boxes)

	got, ok := kxfer.album_get(&carol.album, alice.s.me, SPRAY)
	testing.expect(t, ok, "album_welcome replayed the kept payload to the joiner")
	same := len(got) == len(tag)
	if same {
		for v, i in got {
			if v != tag[i] {
				same = false
				break
			}
		}
	}
	testing.expect(t, same, "replayed bytes byte-identical")
	// And nobody else received a duplicate landing.
	_, _, dup := kxfer.album_poll(&alice.album)
	testing.expect(t, !dup, "the catch-up was addressed, not broadcast")
}

@(test)
xfer_fast_supersede_keeps_done_bytes :: proc(t: ^testing.T) {
	// The dangling-Ev_Done hole: payload A's last chunk and payload B's first
	// land in ONE pump window (the ordered channel + a re-put) — the seq-0
	// restart used to free A's buffer with its Ev_Done still queued, and the
	// consumer copied from freed memory. Now the buffer RETIRES: alive until
	// its event drains, freed by the next pump.
	host, alice: Peer_Box
	box_make(&host, 1)
	box_make(&alice, 100)
	defer box_destroy(&host)
	defer box_destroy(&alice)
	boxes := []^Peer_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	pump(boxes)

	hx, ax: kxfer.Xfer
	kxfer.xfer_init(&hx, &host.s, 7)
	kxfer.xfer_init(&ax, &alice.s, 7)
	defer kxfer.xfer_destroy(&hx)
	defer kxfer.xfer_destroy(&ax)

	a := payload(0xAA, 64)
	b := payload(0xBB, 64)
	defer delete(a)
	defer delete(b)
	kxfer.xfer_send(&hx, 3, a)
	kxfer.xfer_pump(&hx) // A ships whole (one chunk)...
	kxfer.xfer_send(&hx, 3, b)
	kxfer.xfer_pump(&hx) // ...and B's restarting chunk rides the same window
	pump(boxes)          // both land before alice ever polls — the hole's window

	saw_a, saw_b := false, false
	for {
		ev, ok := kxfer.xfer_poll(&ax)
		if !ok {break}
		if d, is_done := ev.(kxfer.Ev_Done); is_done {
			if !saw_a {
				saw_a = true
				testing.expect_value(t, len(d.bytes), len(a))
				same := true
				for bt, i in d.bytes {
					if bt != a[i] {same = false; break}
				}
				testing.expect(t, same, "the superseded payload's bytes survive until its event drains")
			} else {
				saw_b = true
				testing.expect_value(t, len(d.bytes), len(b))
			}
		}
	}
	testing.expect(t, saw_a && saw_b, "both payloads completed")
	kxfer.xfer_pump(&ax) // the drain grace expires: the retiree frees
	testing.expect_value(t, len(ax.retired), 0)
}
