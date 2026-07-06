package kit_stress_test

// The kit's SCALE benchmark — numbers before vibes. Everything to date proved
// the toolkit correct at friendslop scale (dozens of entities); a
// survival-sandbox-shaped game means hundreds to thousands of persistent
// entities, and these are the pressure points that grow with N:
//
//   1. the delta walk    — every net tick diffs EVERY entity against its shadow
//   2. the join snapshot — SES_WORLD ships the whole registry to a joiner
//   3. save/resume       — the same snapshot, written and replayed
//
// This test measures all three at N = 100 / 500 / 2000 through the same
// in-memory pipe as the kitsession tests (full wire path, no socket) and
// prints a table. Correctness is asserted hard (a joiner materializes all N
// with intact fields; a resume rebuilds all N). Timing asserts are DELIBERATE
// TRIPWIRES with generous ceilings — they exist to catch an accidental
// O(n^2), not to benchmark the host machine.
//
//   odin test tests/kitstress -collection:godot=$PWD

import "core:fmt"
import "core:testing"
import "core:time"
import knet "godot:kit/net"
import ksess "godot:kit/session"

// ---- the in-memory pipe (the kitsession pattern, trimmed) ----------------------

Envelope :: struct {
	to:   ksess.Peer_Id,
	data: []u8,
}

Peer_Box :: struct {
	peer:  ksess.Peer_Id,
	s:     ksess.Session,
	out:   [dynamic]Envelope,
	props: map[knet.Net_Id]^Prop, // factory-created (clients + resumed hosts)
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
	ksess.session_set_factory(&b.s, b, box_make_entity, box_free_entity)
}

box_destroy :: proc(b: ^Peer_Box) {
	for e in b.out {delete(e.data)}
	delete(b.out)
	for _, p in b.props {free(p)}
	delete(b.props)
	ksess.session_destroy(&b.s)
}

box_clear_out :: proc(b: ^Peer_Box) {
	for e in b.out {delete(e.data)}
	clear(&b.out)
}

// Deliver every message queued on `from` to `to` (point-to-point or broadcast).
deliver :: proc(from, to: ^Peer_Box) {
	for len(from.out) > 0 {
		e := from.out[0]
		ordered_remove(&from.out, 0)
		if e.to == ksess.BROADCAST_PEER || e.to == to.peer {
			r := knet.reader_make(e.data)
			ksess.session_handle_packet(&to.s, from.peer, &r)
		}
		delete(e.data)
	}
}

// ---- the fixture entity: a survival-game "structure" ---------------------------
//
// 16 replicated bytes — kind/hp/state/position/aux — the realistic shape of a
// placed wall, a chest, a sapling. Host-authoritative (no owner streams: built
// things belong to the world), no commands (the walk, snapshot, and join costs
// under test don't care, and desc-only entities are a supported shape).

Prop :: struct {
	kind:  u8,
	state: u8,
	hp:    u16,
	x, y:  f32,
	aux:   u32,
}

prop_fields := [?]knet.Field_Desc {
	{offset = offset_of(Prop, kind), size = size_of(u8)},
	{offset = offset_of(Prop, state), size = size_of(u8)},
	{offset = offset_of(Prop, hp), size = size_of(u16)},
	{offset = offset_of(Prop, x), size = size_of(f32)},
	{offset = offset_of(Prop, y), size = size_of(f32)},
	{offset = offset_of(Prop, aux), size = size_of(u32)},
}
prop_desc := knet.Entity_Desc {
	fields = prop_fields[:],
}
prop_command_set := knet.Command_Set {
	entity_desc = &prop_desc,
}

PROP_TYPE :: ksess.Entity_Type(11)

box_make_entity :: proc(user: rawptr, type: ksess.Entity_Type, id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	b := cast(^Peer_Box)user
	if type != PROP_TYPE {return nil, nil}
	p := new(Prop)
	b.props[id] = p
	return p, &prop_command_set
}

box_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	b := cast(^Peer_Box)user
	delete_key(&b.props, id)
	free(entity)
}

// ---- measurement helpers --------------------------------------------------------

ms :: proc(d: time.Duration) -> f64 {return time.duration_milliseconds(d)}

// One 20 Hz net tick on the host, with `dirty_every`-th entity mutated first
// (0 = touch nothing). Returns the tick's wall time.
dirty_tick :: proc(host: ^Peer_Box, props: []^Prop, dirty_every: int, now: ^f64) -> time.Duration {
	if dirty_every > 0 {
		for i := 0; i < len(props); i += dirty_every {
			props[i].hp -= 1
			props[i].x += 0.25
		}
	}
	now^ += 0.05
	start := time.tick_now()
	_, _ = ksess.session_tick(&host.s, 0.05, now^)
	d := time.tick_since(start)
	box_clear_out(host) // shipped bytes aren't under test here
	return d
}

TICKS :: 50

Row :: struct {
	n:                                  int,
	spawn_ms:                           f64,
	tick0_ms, tick10_ms, tick100_ms:    f64, // avg per net tick at 0/10/100% dirty
	join_bytes:                         int, // everything the joiner receives
	world_bytes:                        int, // the single SES_WORLD message
	join_apply_ms:                      f64, // client materializes the world
	snap_bytes:                         int,
	snap_write_ms, resume_ms:           f64,
}

measure :: proc(t: ^testing.T, n: int) -> Row {
	row := Row {
		n = n,
	}
	now := f64(1000)

	host: Peer_Box
	box_make(&host, 1)
	defer box_destroy(&host)
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_start_replicating(&host.s) // go live: spawns broadcast, joiners get SES_WORLD

	// -- spawn N (the "loaded a big base" burst) --
	props := make([]^Prop, n)
	defer {
		for p in props {free(p)}
		delete(props)
	}
	start := time.tick_now()
	for i in 0 ..< n {
		p := new(Prop)
		p.kind = u8(i % 7)
		p.hp = 100
		p.x = f32(i % 64) * 16
		p.y = f32(i / 64) * 16
		p.aux = u32(i)
		props[i] = p
		_ = ksess.session_spawn(&host.s, PROP_TYPE, p, &prop_command_set)
	}
	row.spawn_ms = ms(time.tick_since(start))
	box_clear_out(&host)

	// -- the delta walk at three dirty rates --
	total: time.Duration
	for _ in 0 ..< TICKS {total += dirty_tick(&host, props, 0, &now)}
	row.tick0_ms = ms(total) / TICKS
	total = 0
	for _ in 0 ..< TICKS {total += dirty_tick(&host, props, 10, &now)}
	row.tick10_ms = ms(total) / TICKS
	total = 0
	for _ in 0 ..< TICKS {total += dirty_tick(&host, props, 1, &now)}
	row.tick100_ms = ms(total) / TICKS

	// -- a client joins INTO the standing world --
	client: Peer_Box
	box_make(&client, 100)
	defer box_destroy(&client)
	ksess.session_client_start(&client.s, u64(0xA11CE), "joiner")
	ksess.session_client_join(&client.s)
	deliver(&client, &host) // the JOIN reaches the host...
	for e in host.out { // ...and everything it answers with is the join payload
		row.join_bytes += len(e.data)
		row.world_bytes = max(row.world_bytes, len(e.data)) // SES_WORLD dwarfs the rest
	}
	start = time.tick_now()
	deliver(&host, &client)
	row.join_apply_ms = ms(time.tick_since(start))

	testing.expect_value(t, len(client.props), n) // every prop materialized
	// Spot-check field integrity on an arbitrary survivor of the dirty ticks.
	found := false
	for _, p in client.props {
		if p.aux == 42 {
			found = true
			testing.expect_value(t, p.kind, u8(42 % 7))
			// 42 % 10 != 0, so only the 100%-dirty pass moved it: TICKS nudges.
			testing.expect_value(t, p.x, f32(42 % 64) * 16 + 0.25 * TICKS)
		}
	}
	testing.expect(t, found, "prop aux=42 crossed the join snapshot")

	// -- snapshot to bytes, and a cold resume from them --
	w := knet.writer_make(cap = 64 * 1024)
	defer knet.writer_destroy(&w)
	start = time.tick_now()
	ksess.session_snapshot(&host.s, &w)
	row.snap_write_ms = ms(time.tick_since(start))
	row.snap_bytes = len(knet.writer_bytes(&w))

	resumed: Peer_Box
	box_make(&resumed, 7)
	defer box_destroy(&resumed)
	start = time.tick_now()
	testing.expect(t, ksess.session_host_resume(&resumed.s, host.s.me, "hosty", knet.writer_bytes(&w)))
	row.resume_ms = ms(time.tick_since(start))
	testing.expect_value(t, len(resumed.props), n) // the whole world, rebuilt

	return row
}

@(test)
scale_numbers :: proc(t: ^testing.T) {
	fmt.println("")
	fmt.println("STRESS      N   spawn   tick0%  tick10% tick100%     join    world    apply     snap    write   resume")
	for n in ([]int{100, 500, 2000}) {
		r := measure(t, n)
		fmt.printfln(
			"STRESS %6d %6.2fms %7.3fms %7.3fms %7.3fms %7dB %7dB %7.2fms %7dB %7.2fms %7.2fms",
			r.n, r.spawn_ms, r.tick0_ms, r.tick10_ms, r.tick100_ms,
			r.join_bytes, r.world_bytes, r.join_apply_ms,
			r.snap_bytes, r.snap_write_ms, r.resume_ms,
		)

		// The O(n^2) tripwires — ceilings are ~10x a healthy laptop run, NOT
		// perf targets. If one fires, something changed complexity class.
		testing.expect(t, r.tick100_ms < 25, "delta walk blew its complexity budget")
		testing.expect(t, r.join_apply_ms < 250, "join apply blew its complexity budget")
		testing.expect(t, r.resume_ms < 250, "resume blew its complexity budget")
	}
}
