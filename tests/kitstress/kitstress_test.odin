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
import "core:mem"
import "core:testing"
import "core:time"
import "base:runtime"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"

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
	harness: mem.Allocator, // transport/factory scaffolding, excluded from session memory
	sent: int,
}

box_send :: proc(user: rawptr, to_peer: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	b := cast(^Peer_Box)user
	b.sent += len(bytes)
	cloned := make([]u8, len(bytes), b.harness)
	copy(cloned, bytes)
	append(&b.out, Envelope{to = to_peer, data = cloned})
}

box_make :: proc(
	b: ^Peer_Box,
	peer: ksess.Peer_Id,
	session_allocator := mem.Allocator{},
) {
	b.peer = peer
	b.harness = context.allocator
	b.out = make([dynamic]Envelope, b.harness)
	b.props = make(map[knet.Net_Id]^Prop, b.harness)
	if session_allocator.procedure != nil {
		b.s.allocator = session_allocator
	}
	b.s.send = box_send
	b.s.send_user = b
	ksess.session_set_factory(&b.s, b, box_make_entity, box_free_entity)
}

box_destroy :: proc(b: ^Peer_Box) {
	for e in b.out {delete(e.data, b.harness)}
	delete(b.out)
	for _, p in b.props {free(p, b.harness)}
	delete(b.props)
	ksess.session_destroy(&b.s)
}

box_clear_out :: proc(b: ^Peer_Box) {
	for e in b.out {delete(e.data, b.harness)}
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

pump_all :: proc(boxes: []^Peer_Box) {
	for progress := true; progress; {
		progress = false
		for from in boxes {
			for len(from.out) > 0 {
				e := from.out[0]
				ordered_remove(&from.out, 0)
				for to in boxes {
					if to == from {continue}
					if e.to == ksess.BROADCAST_PEER || e.to == to.peer {
						r := knet.reader_make(e.data)
						ksess.session_handle_packet(&to.s, from.peer, &r)
					}
				}
				delete(e.data, from.harness)
				progress = true
			}
		}
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
	p := new(Prop, b.harness)
	b.props[id] = p
	return p, &prop_command_set
}

box_free_entity :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
	b := cast(^Peer_Box)user
	delete_key(&b.props, id)
	free(entity, b.harness)
}

prop_locate :: proc(user: rawptr, id: knet.Net_Id, entity: rawptr) -> (x, y, z: f32, always: bool) {
	p := cast(^Prop)entity
	return p.x, p.y, 0, false
}

Counting_Allocator :: struct {
	backing: mem.Allocator,
	current, peak, total: int,
}

counting_allocator_proc :: proc(
	data: rawptr,
	mode: mem.Allocator_Mode,
	size, alignment: int,
	old_memory: rawptr,
	old_size: int,
	loc := #caller_location,
) -> ([]byte, mem.Allocator_Error) {
	c := cast(^Counting_Allocator)data
	bytes, err := c.backing.procedure(c.backing.data, mode, size, alignment, old_memory, old_size, loc)
	if err != nil {
		return bytes, err
	}
	#partial switch mode {
	case .Alloc, .Alloc_Non_Zeroed:
		c.current += size
		c.total += size
	case .Resize, .Resize_Non_Zeroed:
		c.current += size - old_size
		if size > old_size {c.total += size - old_size}
	case .Free:
		if old_memory != nil {c.current -= old_size}
	case .Free_All:
		c.current = 0
	}
	c.peak = max(c.peak, c.current)
	return bytes, err
}

counting_allocator :: proc(c: ^Counting_Allocator) -> mem.Allocator {
	return {procedure = counting_allocator_proc, data = c}
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
	session_bytes, session_peak_bytes:  int,
}

measure :: proc(t: ^testing.T, n: int) -> Row {
	row := Row {
		n = n,
	}
	now := f64(1000)

	host_mem := Counting_Allocator{backing = context.allocator}
	host: Peer_Box
	box_make(&host, 1, counting_allocator(&host_mem))
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
	row.session_bytes = host_mem.current
	row.session_peak_bytes = host_mem.peak

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
	fmt.println("STRESS      N   spawn   tick0%  tick10% tick100%     join    world    apply     snap    write   resume   session     peak")
	for n in ([]int{100, 500, 2000}) {
		r := measure(t, n)
		fmt.printfln(
			"STRESS %6d %6.2fms %7.3fms %7.3fms %7.3fms %7dB %7dB %7.2fms %7dB %7.2fms %7.2fms %8dB %8dB",
			r.n, r.spawn_ms, r.tick0_ms, r.tick10_ms, r.tick100_ms,
			r.join_bytes, r.world_bytes, r.join_apply_ms,
			r.snap_bytes, r.snap_write_ms, r.resume_ms,
			r.session_bytes, r.session_peak_bytes,
		)

		// The O(n^2) tripwires — ceilings are ~10x a healthy laptop run, NOT
		// perf targets. If one fires, something changed complexity class.
		testing.expect(t, r.tick100_ms < 25, "delta walk blew its complexity budget")
		testing.expect(t, r.join_apply_ms < 250, "join apply blew its complexity budget")
		testing.expect(t, r.resume_ms < 250, "resume blew its complexity budget")
	}
}

@(test)
server_fanout_envelope_by_players_and_entities :: proc(t: ^testing.T) {
	fmt.println("")
	fmt.println("FANOUT players entities  tick cpu    authority tx   session memory")
	for shape in ([3][2]int{{2, 100}, {4, 500}, {8, 2000}}) {
		players, entities := shape[0], shape[1]
		host_mem := Counting_Allocator{backing = context.allocator}
		store := make([]Peer_Box, players)
		boxes := make([]^Peer_Box, players)
		for i in 0 ..< players {
			boxes[i] = &store[i]
			box_make(boxes[i], ksess.Peer_Id(i + 1), i == 0 ? counting_allocator(&host_mem) : mem.Allocator{})
		}
		ksess.session_configure(&boxes[0].s, {max_players = players})
		ksess.session_host_start(&boxes[0].s, "hosty")
		for i in 1 ..< players {
			ksess.session_client_start(&boxes[i].s, u64(0xB000 + i), fmt.tprintf("p%d", i))
			ksess.session_client_join(&boxes[i].s)
		}
		pump_all(boxes)
		// Force the scale-sensitive per-recipient path while keeping every
		// entity relevant. This measures AOI composition + actual fanout, not
		// the transport's single broadcast shortcut.
		ksess.session_set_interest(&boxes[0].s, 1_000_000, 0, nil, prop_locate)
		for i in 1 ..< players {
			ksess.session_set_focus(&boxes[0].s, boxes[i].s.me, 0, 0)
		}
		ksess.session_start_replicating(&boxes[0].s)
		for i in 0 ..< entities {
			p := new(Prop, boxes[0].harness)
			p.hp = 100
			p.aux = u32(i)
			id := ksess.session_spawn(&boxes[0].s, PROP_TYPE, p, &prop_command_set)
			boxes[0].props[id] = p
		}
		pump_all(boxes)
		base_sent := boxes[0].sent
		for _, p in boxes[0].props {p.hp -= 1}
		start := time.tick_now()
		_, _ = ksess.session_tick(&boxes[0].s, 0.05, 1000.0)
		tick_ms := ms(time.tick_since(start))
		tx := boxes[0].sent - base_sent
		fmt.printfln(
			"FANOUT %7d %8d %8.3fms %12dB %16dB",
			players, entities, tick_ms, tx, host_mem.current,
		)
		testing.expect(t, tick_ms < 25, "server fanout exceeded the supported benchmark tripwire")
		for b in boxes {box_destroy(b)}
		delete(boxes)
		delete(store)
	}
}

// ---- resimulation envelope --------------------------------------------------

Bench_Body :: struct {x, vx: f32}

bench_body_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc {
		{offset = offset_of(Bench_Body, x), size = size_of(f32), flags = {.Predicted}},
		{offset = offset_of(Bench_Body, vx), size = size_of(f32), flags = {.Predicted}},
	}
	return {fields = fields[:]}
}

Resim_World :: struct {
	bodies:  []Bench_Body,
	entries: []ksim.Entry,
}

bench_resim :: proc(user: rawptr, tick: u64) {
	w := cast(^Resim_World)user
	for &body, i in w.bodies {
		body.vx += f32((i % 3) - 1)
		body.x += body.vx
	}
}

@(test)
resimulation_cpu_and_memory_envelope :: proc(t: ^testing.T) {
	DESC := bench_body_desc()
	SLOTS :: 32
	AUTH :: u64(8)
	HEAD :: u64(16)
	RUNS :: 25
	fmt.println("")
	fmt.println("RESIM       N   ticks    avg/run  per entity-tick   history")
	for n in ([]int{32, 128, 512}) {
		ledger_mem := Counting_Allocator{backing = context.allocator}
		alloc := counting_allocator(&ledger_mem)
		bodies := make([]Bench_Body, n)
		entries := make([]ksim.Entry, n)
		histories := make([]ksim.History, n)
		truth_bytes := make([]u8, n * 8)
		truths := make([]ksim.Truth, n)
		for i in 0 ..< n {
			bodies[i] = {x = f32(i), vx = f32(i % 5)}
			histories[i] = ksim.history_make(&DESC, SLOTS, alloc)
			entries[i] = {id = knet.Net_Id(i + 1), entity = &bodies[i], hist = &histories[i]}
			truths[i] = {id = knet.Net_Id(i + 1), blob = truth_bytes[i * 8:(i + 1) * 8]}
		}
		world := Resim_World{bodies = bodies, entries = entries}
		for tick in u64(1) ..= HEAD {
			bench_resim(&world, tick)
			ksim.note_all(entries, tick)
		}
		for &truth, i in truths {
			blob, _ := ksim.history_read(&histories[i], AUTH)
			copy(truth.blob, blob)
		}

		start := time.tick_now()
		resim_ticks := 0
		for run in 0 ..< RUNS {
			// Alternate a real authoritative correction so every run exercises
			// rewind + replay, not the memcmp-only clean path.
			truth_body := Bench_Body{x = run % 2 == 0 ? -1000 : 1000, vx = 0}
			ksim.predict_capture(truths[0].blob, &truth_body, &DESC)
			resim_ticks += ksim.reconcile(entries, truths, AUTH, HEAD, &world, bench_resim)
		}
		elapsed_ms := ms(time.tick_since(start)) / RUNS
		entity_ticks := n * int(HEAD - AUTH)
		fmt.printfln(
			"RESIM %6d %7d %9.3fms %12.3fus %9dB",
			n,
			int(HEAD - AUTH),
			elapsed_ms,
			elapsed_ms * 1000.0 / f64(entity_ticks),
			ledger_mem.current,
		)
		testing.expect_value(t, resim_ticks, RUNS * int(HEAD - AUTH))
		testing.expect(t, elapsed_ms < 50, "resimulation exceeded the supported benchmark tripwire")

		for &history in histories {ksim.history_destroy(&history)}
		delete(truths)
		delete(truth_bytes)
		delete(histories)
		delete(entries)
		delete(bodies)
	}
}
