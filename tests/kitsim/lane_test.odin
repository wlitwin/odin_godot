package kit_sim_test

// The lane on a live session pair: host + client wired through the same
// in-memory pipe the kitsession suite uses, exchanging real SES_APP bytes.
// Proves the driver's whole conversation — anchor, predict-ahead, input
// upload, per-client batches, reconcile, watched entities — with the game
// reduced to its honest minimum: a sample proc, a step proc, lane_track.

import "core:testing"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import ksim "godot:kit/sim"

Lane_Parcel :: struct {
	to:   ksess.Peer_Id,
	data: []u8,
}

Lane_Box :: struct {
	peer:   ksess.Peer_Id,
	s:      ksess.Session,
	lane:   ksim.Lane,
	out:    [dynamic]Lane_Parcel,
	movers: map[knet.Net_Id]^Mover,
	owners: map[knet.Net_Id]knet.Player_Id,
	ax:     i8, // the local player's current intent

	// (a) input-class-by-TYPE probe: what lane_input_of resolved for two
	// same-size, distinct-type classes (see lane_input_of_routes_by_type_not_size)
	two_steer: i16,
	two_aim:   i16,

	// two-step-slot probe: how often each world pass ran on this peer
	step_calls: int, // the EVERYWHERE pass (live + resim)
	auth_calls: int, // the AUTHORITY pass (host only, live only)

	// predicted-spawn (projectile) probe
	proj_set:     ^ksim.Sim_Set,
	cli_proj:     ^Mover, // this client's predicted projectile
	cli_proj_id:  knet.Net_Id, // its provisional id
	host_proj:    ^Mover, // the authority's projectile
	host_proj_id: knet.Net_Id,
	proj_ids:     int, // authoritative projectile id counter (host)

	// lag-comp probe (host): at step `fire_at`, judge `probe_id` through a
	// rewound query for `shooter` and record what both worlds showed.
	fire_at:      u64,
	shooter:      knet.Player_Id,
	probe_id:     knet.Net_Id,
	fired:        bool,
	rewound_to:   u64,
	saw_live:     f32,
	saw_past:     f32,
	saw_restored: f32,

	// the same judgment through the inline pair — must agree to the byte
	inline_to:       u64,
	saw_inline:      f32,
	inline_restored: f32,

	// every-screen fact probe (mine-form _fx): what fired here, and when
	fx_calls:  int,
	fx_mine:   bool,
	fx_x:      f32, // the fact's wire-decoded payload

	// declared world-pass fact probe (@(gd_fact) doors): one recorder slot
	// per kind under test — calls, the mine bit, the watch clock at fire,
	// and whether the thunk saw a nil entity (the anchorless form)
	df_calls: [4]int,
	df_mine:  [4]bool,
	df_clock: [4]f64,
	df_nil:   [4]bool,
	fx_clock:  f64, // lane.watch_clock at the fire (0 on a live-pass fire)
	fx_newest: u64, // rx.newest at the fire — proves the watcher fired BEHIND the wire
}

lbox_probe :: proc(user: rawptr) {
	b := cast(^Lane_Box)user
	b.saw_past = b.movers[b.probe_id].x
}

lbox_send :: proc(user: rawptr, to_peer: ksess.Peer_Id, bytes: []u8, channel: ksess.Channel) {
	b := cast(^Lane_Box)user
	cloned := make([]u8, len(bytes))
	copy(cloned, bytes)
	append(&b.out, Lane_Parcel{to = to_peer, data = cloned})
}

lbox_make :: proc(b: ^Lane_Box, peer: ksess.Peer_Id) {
	b.peer = peer
	b.s.send = lbox_send
	b.s.send_user = b
}

lbox_destroy :: proc(b: ^Lane_Box) {
	ksim.lane_destroy(&b.lane) // before the session it rides (the comms rule)
	for p in b.out {
		delete(p.data)
	}
	delete(b.out)
	for _, m in b.movers {
		free(m)
	}
	delete(b.movers)
	delete(b.owners)
	ksess.session_destroy(&b.s)
}

lane_pump :: proc(boxes: []^Lane_Box) {
	for progress := true; progress; {
		progress = false
		for b in boxes {
			for len(b.out) > 0 {
				p := b.out[0]
				ordered_remove(&b.out, 0)
				for dst in boxes {
					if dst.peer == b.peer {
						continue
					}
					if p.to == ksess.BROADCAST_PEER || dst.peer == p.to {
						r := knet.reader_make(p.data)
						ksess.session_handle_packet(&dst.s, b.peer, &r)
					}
				}
				delete(p.data)
				progress = true
			}
		}
	}
}

// Direct-velocity step so a zero intent FREEZES the world — quiescence makes
// the convergence assertions exact instead of chasing a moving sum.
lane_mover_step :: proc(m: ^Mover, ax: i8) {
	m.vx = f32(ax) * 2
	m.x += m.vx
}

lbox_sample :: proc(user: rawptr, tick: u64, dst: rawptr) {
	b := cast(^Lane_Box)user
	(cast(^i8)dst)^ = b.ax
}

// The single-player-shaped step: every mover advances on its owner's input.
// No input here (a client looking at a remote player) means don't touch it —
// its truth is on the way.
lbox_step :: proc(user: rawptr, tick: u64) {
	b := cast(^Lane_Box)user
	b.step_calls += 1
	for id, m in b.movers {
		ax, drives := ksim.lane_input_of(&b.lane, b.owners[id], i8)
		if !drives {
			continue
		}
		lane_mover_step(m, ax)
	}
	if b.fire_at != 0 && tick == b.fire_at && b.s.is_host {
		b.saw_live = b.movers[b.probe_id].x
		b.rewound_to = ksim.lane_rewound(&b.lane, b.shooter, b, lbox_probe)
		b.saw_restored = b.movers[b.probe_id].x
		// The inline pair is the same judgment written at the call site:
		// same view, same bytes, same restore.
		b.inline_to = ksim.lane_rewound_begin(&b.lane, b.shooter)
		b.saw_inline = b.movers[b.probe_id].x
		ksim.lane_rewound_end(&b.lane)
		b.inline_restored = b.movers[b.probe_id].x
		b.fired = true
	}
}

// The AUTHORITY world pass: the host alone runs it, once per real tick (never
// a resim). Just counts here — a real game adjudicates, sweeps respawns, ticks
// a match clock.
lbox_step_auth :: proc(user: rawptr, tick: u64) {
	b := cast(^Lane_Box)user
	b.auth_calls += 1
}

lbox_track :: proc(b: ^Lane_Box, id: knet.Net_Id, owner: knet.Player_Id, desc: ^knet.Entity_Desc) {
	m := new(Mover)
	b.movers[id] = m
	b.owners[id] = owner
	ksim.lane_track(&b.lane, id, m, desc, owner)
}

@(test)
lane_two_peers_converge :: proc(t: ^testing.T) {
	desc := mover_desc()
	host, alice: Lane_Box
	lbox_make(&host, 1) // HOST_PEER
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)
	testing.expect_value(t, alice.s.me, knet.Player_Id(2))

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, lbox_step)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, lbox_step)

	// Two avatars, tracked on both peers with their owners: on alice's side
	// hers is predicted, the host's is watched; the host ledgers truth for
	// both.
	HOSTY :: knet.Net_Id(10)
	ALICE :: knet.Net_Id(20)
	lbox_track(&host, HOSTY, 1, &desc)
	lbox_track(&host, ALICE, 2, &desc)
	lbox_track(&alice, HOSTY, 1, &desc)
	lbox_track(&alice, ALICE, 2, &desc)

	DT :: 1.0 / 60.0
	for i in 1 ..= 240 {
		// Intents: alice flips hard mid-run; everyone stops at 180 so the
		// world freezes for the convergence check.
		host.ax = i <= 180 ? 1 : 0
		alice.ax = i <= 120 ? 1 : (i <= 180 ? -2 : 0)

		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT) // watched fields belong to the presenter

		// Blackout: alice's packets vanish for 20 frames STRADDLING her
		// intent flip — wider than the redundancy window, so the server
		// provably holds her stale +1 while she predicted -2.
		if i >= 115 && i < 135 {
			for p in alice.out {
				delete(p.data)
			}
			clear(&alice.out)
		} else {
			lane_pump(boxes)
		}
	}

	testing.expect(t, alice.lane.anchored, "first batch anchors the client")
	testing.expect(t, alice.lane.stat_resims > 0, "the blackout must force real replays")
	testing.expect_value(t, host.lane.stat_resims, 0) // truth never resims

	// The clock only ever bends, never jumps.
	nudged := abs(alice.lane.ticker.scale - 1.0)
	testing.expect(t, nudged <= ksim.SCALE_NUDGE_MAX + 1e-12, "lead corrections stay inside the nudge")

	// Frozen world, byte-equal on both screens: alice's own avatar through
	// prediction + reconcile, the host's avatar through watched truth.
	for id in ([]knet.Net_Id{HOSTY, ALICE}) {
		hm, am := host.movers[id], alice.movers[id]
		testing.expect_value(t, am.x, hm.x)
		testing.expect_value(t, am.vx, hm.vx)
	}
}

// Shared two-peer setup for the focused lane tests: joined session pair,
// lanes wired, both avatars tracked (HOSTY=10 owned by 1, ALICE=20 by 2).
lane_pair :: proc(host: ^Lane_Box, alice: ^Lane_Box, desc: ^knet.Entity_Desc) {
	lbox_make(host, 1)
	lbox_make(alice, 100)
	boxes := []^Lane_Box{host, alice}
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)
	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, host, lbox_sample, lbox_step)
	ksim.lane_set_sim(&alice.lane, alice, lbox_sample, lbox_step)
	lbox_track(host, 10, 1, desc)
	lbox_track(host, 20, 2, desc)
	lbox_track(alice, 10, 1, desc)
	lbox_track(alice, 20, 2, desc)
}

// The hand-built stand-in for what scriptgen emits from @(gd_tick): cast,
// call, coast on nil input. Entities carrying this need NO game step proc.
mover_tick_thunk :: proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane, owner: knet.Player_Id) {
	if input == nil {
		return
	}
	lane_mover_step(cast(^Mover)entity, (cast(^i8)input)^)
}

// A projectile that spawns mid-run and is owned by someone ELSE (watched on
// this peer, like the muzzle-fired lob a remote duelist throws): the observer
// must present it at its spawn pose (the muzzle) and let it fly from there in
// step with the delayed barrel — NOT hold the node's stale default and pop it
// into place a watch_delay late, off the barrel that fired it. The shooter's
// own screen predicts it correctly; this is the OTHER screens' view.
@(test)
lane_watched_fresh_spawn_holds_at_muzzle :: proc(t: ^testing.T) {
	desc := mover_desc()
	av_set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1}
	fly_set := ksim.Sim_Set{entity_desc = &desc, tick = proj_fly_thunk, input_size = 0}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	for b in boxes {
		ksim.lane_init(&b.lane, &b.s, 1, cfg = cfg)
		ksim.lane_set_sim(&b.lane, b, lbox_sample, nil)
	}
	AV :: knet.Net_Id(20) // an avatar keeps batches (and the watch clock) flowing
	for b in boxes {
		m := new(Mover)
		b.movers[AV] = m
		b.owners[AV] = 2
		ksim.lane_track_set(&b.lane, AV, m, &av_set, 2)
	}

	DT :: 1.0 / 60.0
	alice.ax = 0
	for i in 1 ..= 60 { // warm up: batches + watch_clock established
		for b in boxes {ksim.lane_frame(&b.lane, DT)}
		ksim.lane_present(&alice.lane, DT)
		lane_pump(boxes)
	}

	// MID-RUN spawn: a host-owned flyer at the muzzle x=100, vx=3. On the host
	// it's real and flying; on alice it's a fresh WATCHED spawn whose node still
	// holds its default (x=0) — exactly the game's uninitialized bullet node.
	MUZZLE :: f32(100)
	FLY :: knet.Net_Id(50)
	for b in boxes {
		m := new(Mover)
		if b.s.is_host {
			m.x = MUZZLE // the authority sets the muzzle; the observer's node is DEFAULT
			m.vx = 3
		}
		b.movers[FLY] = m
		b.owners[FLY] = 1
		ksim.lane_track_set(&b.lane, FLY, m, &fly_set, 1)
	}

	// The reveal hook must fire ON CUE — the tick the delayed clock reaches the
	// spawn, which is a render delay AFTER the shot left the host's muzzle (so
	// the boot hides the node until exactly then). Record the host's downrange
	// distance at the reveal: it must be well past the muzzle, proving the node
	// was kept hidden through the hold rather than shown early.
	reveal_hostx := f32(-1)
	ksim.lane_set_present_ready(&alice.lane, &reveal_hostx, proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
		if (cast(^f32)user)^ < 0 {
			(cast(^f32)user)^ = 0 // marker: fired (host.x filled in by the loop)
		}
	})

	// The muzzle-hold signature the fix produces and the bug cannot: at some
	// frame the observer presents the flyer NEAR THE MUZZLE while the host has
	// already flown it well downrange. Without the fix the observer sits at the
	// stale default (0) through the whole hold and only appears once the delayed
	// clock reaches the spawn — never near the muzzle while the host is ahead.
	held_at_muzzle := false
	reveal_frame_hostx := f32(-1)
	for i in 1 ..= 20 {
		for b in boxes {ksim.lane_frame(&b.lane, DT)}
		reveal_hostx = -1 // reset the per-frame fired marker
		ksim.lane_present(&alice.lane, DT)
		lane_pump(boxes)
		ax := alice.movers[FLY].x
		hx := host.movers[FLY].x
		if reveal_hostx == 0 && reveal_frame_hostx < 0 {
			reveal_frame_hostx = hx // the host's downrange distance the tick the reveal fired
		}
		// The observer must NEVER present a flown-ahead ghost: once it shows
		// anything, it is between the muzzle and the host's truth.
		if ax != 0 {
			testing.expectf(t, ax >= MUZZLE - 1 && ax <= hx + 0.5,
				"frame %d: observer presented %v outside [muzzle, truth]=[%v, %v] — a stale or ahead ghost", i, ax, MUZZLE, hx)
		}
		if ax >= MUZZLE - 1 && ax <= MUZZLE + 12 && hx > MUZZLE + 18 {
			held_at_muzzle = true // held at the muzzle while the shot is well downrange
		}
	}
	testing.expect(t, held_at_muzzle,
		"the observer never held the fresh watched projectile at the muzzle — it popped in a watch_delay late off the barrel")
	// The reveal fired, and it fired a render delay LATE — the host had already
	// carried the shot well past the muzzle by the time the node was uncovered.
	testing.expectf(t, reveal_frame_hostx > MUZZLE + 10,
		"present_ready fired too early (host at %v, muzzle %v) — the node would appear before the delayed barrel fired it", reveal_frame_hostx, MUZZLE)
}

// The reveal-gate's edge: if a possession hands a still-HIDDEN fresh watched
// entity to me before the delayed clock uncovered it, gaining ownership must
// reveal it — a predicted entity is shown at once, and the watched present loop
// that would otherwise fire the reveal no longer runs for it.
@(test)
lane_gaining_a_hidden_spawn_reveals_it :: proc(t: ^testing.T) {
	desc := mover_desc()
	av_set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1}
	fly_set := ksim.Sim_Set{entity_desc = &desc, tick = proj_fly_thunk, input_size = 0}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	for b in boxes {
		ksim.lane_init(&b.lane, &b.s, 1, cfg = cfg)
		ksim.lane_set_sim(&b.lane, b, lbox_sample, nil)
	}
	AV :: knet.Net_Id(20)
	for b in boxes {
		m := new(Mover)
		b.movers[AV] = m
		b.owners[AV] = 2
		ksim.lane_track_set(&b.lane, AV, m, &av_set, 2)
	}
	DT :: 1.0 / 60.0
	alice.ax = 0
	for i in 1 ..= 60 {
		for b in boxes {ksim.lane_frame(&b.lane, DT)}
		ksim.lane_present(&alice.lane, DT)
		lane_pump(boxes)
	}

	// Record which ids the reveal hook fires for.
	revealed_fly := false
	ksim.lane_set_present_ready(&alice.lane, &revealed_fly, proc(user: rawptr, id: knet.Net_Id, entity: rawptr) {
		if id == 50 {(cast(^bool)user)^ = true}
	})

	// A host-owned flyer spawns (watched + hidden on alice). Hand it to alice
	// BEFORE any present could uncover it — the reveal must come from the gain.
	FLY :: knet.Net_Id(50)
	for b in boxes {
		m := new(Mover)
		if b.s.is_host {m.x = 100; m.vx = 3}
		b.movers[FLY] = m
		b.owners[FLY] = 1
		ksim.lane_track_set(&b.lane, FLY, m, &fly_set, 1)
	}
	testing.expect(t, !revealed_fly, "the flyer revealed before it was even owned — the setup is wrong")
	ksim.lane_set_owner(&alice.lane, FLY, 2) // alice gains it, still hidden
	testing.expect(t, revealed_fly,
		"gaining a hidden fresh spawn didn't reveal it — a possession during its first render delay would leave it invisible")
}

// The active-intent window sits AFTER join startup (~5 ticks of neutral held
// input before alice's stream reaches the host) and ends before the run does,
// so every active tick is simulated with fresh confirmed input on both peers —
// the fingerprint is then exact, not a startup-eaten approximation.
MC_LO :: 40 // first active tick
MC_FLIP :: 120 // class 1 flips here
MC_HI :: 180 // last active tick

// The SECOND input class: a 2-byte i16 intent driving its entity by +ax16/tick
// (deliberately a different width, value, and gain than class 0's i8 ×2, so a
// crossed input would land the entity somewhere impossible). Intent is a pure
// function of the TICK it samples for, so predict, resim, and the host's
// consumption all agree per tick.
mc_sample0 :: proc(user: rawptr, tick: u64, dst: rawptr) {
	(cast(^i8)dst)^ = (tick >= MC_LO && tick <= MC_HI) ? 3 : 0
}

mc_sample1 :: proc(user: rawptr, tick: u64, dst: rawptr) {
	v: i16 = 0
	if tick >= MC_LO && tick <= MC_FLIP {
		v = -5
	} else if tick > MC_FLIP && tick <= MC_HI {
		v = 4 // a hard flip mid-run: class 1's entity resims independent of class 0
	}
	(cast(^i16)dst)^ = v
}

mover16_tick_thunk :: proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane, owner: knet.Player_Id) {
	if input == nil {
		return
	}
	m := cast(^Mover)entity
	m.vx = f32((cast(^i16)input)^)
	m.x += m.vx
}

// Two input CLASSES on one lane, one player driving BOTH kinds: alice owns an
// i8-driven mover (class 0) and an i16-driven mover (class 1). Each tick her
// packet carries two windows; the host de-jitters each into its own buffer and
// routes it to the matching entity. The proof is a fingerprint — class 1's
// entity ends where ONLY its own i16 intent (flipped mid-run to force an
// independent resim) could put it — plus byte-equal convergence on both peers.
@(test)
lane_two_input_classes_route_per_entity :: proc(t: ^testing.T) {
	desc := mover_desc()
	set0 := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1, input_class = 0}
	set1 := ksim.Sim_Set{entity_desc = &desc, tick = mover16_tick_thunk, input_size = 2, input_class = 1}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)
	testing.expect_value(t, alice.s.me, knet.Player_Id(2))

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	for b in boxes {
		ksim.lane_init(&b.lane, &b.s, 1, cfg = cfg) // primary class 0 (i8)
		ksim.lane_add_input_class(&b.lane, 1, 2, mc_sample1) // class 1 (i16)
		ksim.lane_set_sim(&b.lane, b, mc_sample0, nil) // no world pass: sets drive themselves
	}

	A :: knet.Net_Id(10) // class 0, alice's
	B :: knet.Net_Id(11) // class 1, alice's
	for b in boxes {
		for id in ([?]knet.Net_Id{A, B}) {
			m := new(Mover)
			b.movers[id] = m
			b.owners[id] = 2
			ksim.lane_track_set(&b.lane, id, m, id == A ? &set0 : &set1, 2)
		}
	}

	DT :: 1.0 / 60.0
	for i in 1 ..= 240 {
		for b in boxes {
			ksim.lane_frame(&b.lane, DT)
		}
		lane_pump(boxes)
	}

	// Byte-equal convergence on BOTH entities across both peers — the resim
	// churn (predict-ahead + the class-1 flip) settled to one timeline.
	for id in ([?]knet.Net_Id{A, B}) {
		ha := host.movers[id]
		al := alice.movers[id]
		testing.expectf(t, abs(ha.x - al.x) < 0.001,
			"entity %d disagrees: host x=%v alice x=%v", id, ha.x, al.x)
	}

	// The fingerprint: class 1's entity moved ONLY by its i16 intent (−5 over
	// [40,120], then +4 over [121,180]), never by class 0's i8 ×2. A crossed
	// input could not land here — class 0's +6/tick would drive B strongly
	// POSITIVE instead of to its own net-negative spot.
	want_b := f32(-5) * (MC_FLIP - MC_LO + 1) + f32(4) * (MC_HI - MC_FLIP)
	testing.expectf(t, abs(host.movers[B].x - want_b) < 0.001,
		"class-1 entity should sit at its own i16 fingerprint %v, got %v (input crossed classes?)", want_b, host.movers[B].x)
	// Class 0's entity likewise sits at its i8 ×2 fingerprint over [40,180].
	want_a := f32(3) * 2 * (MC_HI - MC_LO + 1)
	testing.expectf(t, abs(host.movers[A].x - want_a) < 0.001,
		"class-0 entity should sit at its own i8 fingerprint %v, got %v", want_a, host.movers[A].x)
}

// (a) lane_input_of resolves the input class by TYPE, not by struct SIZE.
// Two classes of the SAME size (2 bytes) but DISTINCT types: the old resolver
// keyed on size_of(T), found two size-2 classes, and asserted "ambiguous" — the
// footgun that lay in wait until someone grew one input struct to another's
// size. scriptgen stamps each class's type (lane_class_set_type), so the typed
// accessor routes each to its own class. TEETH: delete the two set_type lines
// and this test asserts instead of passing (the pre-fix behaviour).
Steer_In :: distinct i16
Aim_In :: distinct i16 // same size as Steer_In (2 bytes), different type

two_steer_sample :: proc(user: rawptr, tick: u64, dst: rawptr) {(cast(^Steer_In)dst)^ = 7}
two_aim_sample :: proc(user: rawptr, tick: u64, dst: rawptr) {(cast(^Aim_In)dst)^ = 9}

// Read both classes' local input by TYPE inside the world pass and record them.
two_class_probe_step :: proc(user: rawptr, tick: u64) {
	b := cast(^Lane_Box)user
	s, ds := ksim.lane_input_of(&b.lane, b.s.me, Steer_In)
	a, da := ksim.lane_input_of(&b.lane, b.s.me, Aim_In)
	if ds {b.two_steer = i16(s)}
	if da {b.two_aim = i16(a)}
}

@(test)
lane_input_of_routes_by_type_not_size :: proc(t: ^testing.T) {
	box: Lane_Box
	lbox_make(&box, 1)
	defer lbox_destroy(&box)
	ksess.session_host_start(&box.s, "hosty")

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&box.lane, &box.s, size_of(Steer_In), cfg = cfg) // primary class 0
	ksim.lane_add_input_class(&box.lane, 1, size_of(Aim_In), two_aim_sample) // class 1, SAME size
	// The stamps that make type the resolver key. Remove these two lines and the
	// test asserts "input size ambiguous" — the pre-fix behaviour, on purpose.
	ksim.lane_class_set_type(&box.lane, 0, typeid_of(Steer_In))
	ksim.lane_class_set_type(&box.lane, 1, typeid_of(Aim_In))
	ksim.lane_set_sim(&box.lane, &box, two_steer_sample, two_class_probe_step)

	DT :: 1.0 / 60.0
	for _ in 1 ..= 8 {
		ksim.lane_frame(&box.lane, DT)
	}
	// Each type resolved to ITS class's sampled value — no cross, no assert.
	testing.expectf(t, box.two_steer == 7, "Steer_In must resolve to class 0's input (got %v, want 7)", box.two_steer)
	testing.expectf(t, box.two_aim == 9, "Aim_In must resolve to class 1's input (got %v, want 9) — size resolution could not tell these apart", box.two_aim)
}

// The surge verb — the full tick-command shape in one proc: rejectable
// (an empty purse says no), cross-lane (hp is the delta-lane purse), with
// a predicted effect (x jumps). Check-then-mutate, the verb contract.
mover_surge_exec :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane, by: knet.Player_Id) -> bool {
	m := cast(^Mover)entity
	if m.hp <= 0 {return false}
	m.hp -= 1
	m.x += 50
	return true
}

@(test)
lane_commands_predict_reject_and_revert :: proc(t: ^testing.T) {
	desc := mover_desc()
	cmds := [?]ksim.Sim_Cmd{{exec = mover_surge_exec}}
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1, commands = cmds[:]}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)
	for b in boxes {
		for id in ([]knet.Net_Id{10, 20}) {
			m := new(Mover)
			b.movers[id] = m
			b.owners[id] = id == 10 ? 1 : 2
			ksim.lane_track_set(&b.lane, id, m, &set, b.owners[id])
		}
	}

	// A QUIET world — intent stays zero throughout, so x moves ONLY by verbs.
	DT :: 1.0 / 60.0
	settle :: proc(boxes: []^Lane_Box, frames: int) {
		for _ in 0 ..< frames {
			ksim.lane_frame(&boxes[0].lane, DT)
			lane_pump(boxes)
			ksim.lane_frame(&boxes[1].lane, DT)
			// Watched fields belong to the presenter once a bracket exists —
			// without this, a remote verb's effect never reaches the fields.
			ksim.lane_present(&boxes[1].lane, DT)
			lane_pump(boxes)
		}
	}
	settle(boxes, 60) // anchor + converge
	host.movers[20].hp = 1 // alice's purse, seeded on BOTH copies (spawn-time
	alice.movers[20].hp = 1 // state; the delta WALK is kit/net's job, absent here)

	// 1) SPECULATION: the effect lands on alice's screen before any round trip.
	testing.expect(t, ksim.lane_command(&alice.lane, 20, 0, nil), "the verb schedules")
	ksim.lane_frame(&alice.lane, DT) // executes at her next tick — nothing delivered yet
	testing.expect_value(t, alice.movers[20].x, f32(50))
	testing.expect_value(t, alice.movers[20].hp, i32(0))
	testing.expect_value(t, host.movers[20].x, f32(0))

	// ...and the authority's execution converges with it, resims included.
	// (Alice's fields hold PRESENTED values after settle — sim truth plus a
	// decaying glide that never quite zeroes — so her floats get a hair of
	// tolerance; the host's are sim-exact.)
	near :: proc(a, b: f32) -> bool {return abs(a - b) < 0.01}
	lane_pump(boxes)
	settle(boxes, 90)
	testing.expect_value(t, host.movers[20].x, f32(50))
	testing.expect_value(t, host.movers[20].hp, i32(0))
	testing.expect(t, near(alice.movers[20].x, 50), "alice converged on the accepted surge")
	testing.expect_value(t, alice.movers[20].hp, i32(0))

	// 2) HONEST REJECTION: an empty purse says no on both timelines; nothing moves.
	testing.expect(t, ksim.lane_command(&alice.lane, 20, 0, nil), "a rejectable verb still schedules")
	settle(boxes, 90)
	testing.expect(t, near(alice.movers[20].x, 50), "an empty purse moved nothing")
	testing.expect_value(t, host.movers[20].x, f32(50))

	// 3) DIVERGENT REJECTION — the revert path: alice's stale purse says yes,
	// the authority's truth says no. Her speculation applies, the verdict
	// unwinds the delta-lane write, the reconcile scrubs the predicted one.
	alice.movers[20].hp = 1 // stale client-side delta state, deliberately
	testing.expect(t, ksim.lane_command(&alice.lane, 20, 0, nil), "schedules on stale state")
	ksim.lane_frame(&alice.lane, DT)
	testing.expect_value(t, alice.movers[20].x, f32(100)) // speculated
	testing.expect_value(t, alice.movers[20].hp, i32(0))
	lane_pump(boxes)
	settle(boxes, 90)
	testing.expect(t, near(alice.movers[20].x, 50), "predicted half: scrubbed") // reconcile + glide
	testing.expect_value(t, alice.movers[20].hp, i32(1)) // delta half: reverted
	testing.expect_value(t, host.movers[20].x, f32(50))

	// 4) The AUTHORITY's own verb: no wire, no speculation — its execution is
	// the truth, and the watched view carries it to every client.
	host.movers[10].hp = 1
	testing.expect(t, ksim.lane_command(&host.lane, 10, 0, nil), "the host schedules its own verb")
	settle(boxes, 90)
	testing.expect_value(t, host.movers[10].x, f32(50))
	testing.expect(t, near(alice.movers[10].x, 50), "the watched view carried the verb") // blended
}

// Patch-mode, ungated: a relative nudge (chain-test filler).
mover_dash_exec :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane, by: knet.Player_Id) -> bool {
	m := cast(^Mover)entity
	m.x += 25
	return true
}

// Apply-mode pair: the verb keeps the predicate + the delta write (execute
// once); the apply half carries the RELATIVE predicted effect and is what
// resims re-run. The exec calls the apply on success — the generated
// thunks' contract, mimicked by hand here.
mover_boost_exec :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane, by: knet.Player_Id) -> bool {
	m := cast(^Mover)entity
	if m.hp <= 0 {return false}
	m.hp -= 1
	mover_boost_apply(entity, args, lane)
	return true
}
mover_boost_apply :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane) {
	m := cast(^Mover)entity
	m.x += 50 // relative — exactly what recorded-bytes replay can't express
}

@(test)
lane_contested_and_chained_verbs :: proc(t: ^testing.T) {
	desc := mover_desc()
	cmds := [?]ksim.Sim_Cmd{{id = 0, exec = mover_surge_exec}, {id = 1, exec = mover_dash_exec}}
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1, commands = cmds[:]}
	// The contested table opts its verbs in (`any_seat`) — contested widens
	// PREDICTION to every seat, never command authority; id 2 stays closed to
	// pin the split.
	cmds_c := [?]ksim.Sim_Cmd{
		{id = 0, exec = mover_surge_exec, any_seat = true},
		{id = 1, exec = mover_dash_exec, any_seat = true},
		{id = 2, exec = mover_surge_exec},
	}
	set_c := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1, commands = cmds_c[:], contested = true}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)
	for b in boxes {
		for id in ([]knet.Net_Id{10, 30}) {
			m := new(Mover)
			b.movers[id] = m
			b.owners[id] = 1 // both the host's — 30 is CONTESTED, 10 is not
			ksim.lane_track_set(&b.lane, id, m, id == 30 ? &set_c : &set, 1)
		}
	}

	DT :: 1.0 / 60.0
	settle :: proc(boxes: []^Lane_Box, frames: int) {
		for _ in 0 ..< frames {
			ksim.lane_frame(&boxes[0].lane, DT)
			lane_pump(boxes)
			ksim.lane_frame(&boxes[1].lane, DT)
			ksim.lane_present(&boxes[1].lane, DT)
			lane_pump(boxes)
		}
	}
	near :: proc(a, b: f32) -> bool {return abs(a - b) < 0.01}
	settle(boxes, 60)

	// Not contested, not mine: the gate holds.
	testing.expect(t, !ksim.lane_command(&alice.lane, 10, 0, nil), "a host-owned entity refuses a client's verb")

	// Contested but the verb never opted in: prediction scope is not command
	// scope — predict-world marks avatars contested, and their verbs must not
	// open to every seat for free.
	testing.expect(t, !ksim.lane_command(&alice.lane, 30, 2, nil), "a contested entity's closed verb still refuses a non-owner")

	// CONTESTED: any seat's verb speculates on its own predicted timeline.
	host.movers[30].hp = 1
	alice.movers[30].hp = 1
	testing.expect(t, ksim.lane_command(&alice.lane, 30, 0, nil), "a contested entity takes any seat's verb")
	ksim.lane_frame(&alice.lane, DT)
	testing.expect_value(t, alice.movers[30].x, f32(50)) // before any round trip
	testing.expect_value(t, host.movers[30].x, f32(0))
	lane_pump(boxes)
	settle(boxes, 90)
	testing.expect_value(t, host.movers[30].x, f32(50))
	testing.expect(t, near(alice.movers[30].x, 50), "the contested verb converged")

	// THE CHAIN: two verbs in flight; the FIRST is rejected on divergent
	// state, the second survives — the unwind must not clobber it.
	alice.movers[30].hp = 1 // stale purse: the authority's is spent
	testing.expect(t, ksim.lane_command(&alice.lane, 30, 0, nil), "surge schedules on stale state")
	testing.expect(t, ksim.lane_command(&alice.lane, 30, 1, nil), "a second verb queues behind it")
	ksim.lane_frame(&alice.lane, DT)
	testing.expect_value(t, alice.movers[30].x, f32(125)) // 50 kept + 50 spec + 25 spec
	testing.expect_value(t, alice.movers[30].hp, i32(0))
	lane_pump(boxes)
	settle(boxes, 90)
	testing.expect_value(t, host.movers[30].x, f32(75)) // truth: dash only
	testing.expect_value(t, host.movers[30].hp, i32(0))
	testing.expect(t, near(alice.movers[30].x, 75), "the rejected surge scrubbed; the dash survived")
	testing.expect_value(t, alice.movers[30].hp, i32(1)) // the unwound stale purse
}

@(test)
lane_apply_verbs_ride_resims :: proc(t: ^testing.T) {
	desc := mover_desc()
	cmds := [?]ksim.Sim_Cmd{{exec = mover_boost_exec, apply = mover_boost_apply}}
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1, commands = cmds[:]}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)
	for b in boxes {
		m := new(Mover)
		b.movers[20] = m
		b.owners[20] = 2
		ksim.lane_track_set(&b.lane, 20, m, &set, 2)
	}

	DT :: 1.0 / 60.0
	near :: proc(a, b: f32) -> bool {return abs(a - b) < 0.01}
	for _ in 0 ..< 60 {
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT)
		lane_pump(boxes)
	}
	host.movers[20].hp = 1
	alice.movers[20].hp = 1

	// Issue INTO a blackout: the verb and ten frames of traffic sit HELD
	// (reliable = delayed, never lost — the pipe has no retransmit to model
	// loss with) while alice keeps simulating. The server executes the late
	// verb at ITS next tick — the reschedule path — and every replay re-RUNS
	// the apply half against corrected state instead of re-pinning bytes.
	testing.expect(t, ksim.lane_command(&alice.lane, 20, 0, nil), "the boost schedules")
	for _ in 0 ..< 10 {
		alice.ax = 1 // moving through the blackout: corrections will cross the verb tick
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT)
		ksim.lane_frame(&host.lane, DT)
		// no pumping: both queues accumulate and land in one late burst
	}
	testing.expect_value(t, alice.movers[20].hp, i32(0)) // the delta half, once
	alice.ax = 0
	for _ in 0 ..< 120 {
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT)
		lane_pump(boxes)
	}
	testing.expect_value(t, host.movers[20].hp, i32(0))
	testing.expect(t, near(alice.movers[20].x, host.movers[20].x), "the relative apply converged exactly through the blackout")
	testing.expect(t, host.movers[20].x >= 50, "the boost is in the truth")

	// An empty purse says no on both timelines — apply never fires.
	before := host.movers[20].x
	testing.expect(t, ksim.lane_command(&alice.lane, 20, 0, nil), "a rejectable boost still schedules")
	for _ in 0 ..< 90 {
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT)
		lane_pump(boxes)
	}
	testing.expect_value(t, host.movers[20].x, before)
	testing.expect(t, near(alice.movers[20].x, before), "the second boost moved nothing")
}

@(test)
lane_auto_tick_drives_entities :: proc(t: ^testing.T) {
	desc := mover_desc()
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	// NO step proc: the entities drive themselves through their Sim_Set.
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)
	for b in boxes {
		for id in ([]knet.Net_Id{10, 20}) {
			m := new(Mover)
			b.movers[id] = m
			b.owners[id] = id == 10 ? 1 : 2
			ksim.lane_track_set(&b.lane, id, m, &set, b.owners[id])
		}
	}

	// Same weather as the converge acid: an intent flip inside an input
	// blackout, then a frozen world — auto-ticked entities must reconcile
	// and converge exactly like step-proc-driven ones (resim runs the same
	// run_tick path).
	DT :: 1.0 / 60.0
	for i in 1 ..= 240 {
		host.ax = i <= 180 ? 1 : 0
		alice.ax = i <= 120 ? 1 : (i <= 180 ? -2 : 0)
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT) // watched fields belong to the presenter
		if i >= 115 && i < 135 {
			for p in alice.out {
				delete(p.data)
			}
			clear(&alice.out)
		} else {
			lane_pump(boxes)
		}
	}

	testing.expect(t, alice.lane.stat_resims > 0, "auto-ticked entities reconcile too")
	for id in ([]knet.Net_Id{10, 20}) {
		hm, am := host.movers[id], alice.movers[id]
		testing.expect_value(t, am.x, hm.x)
		testing.expect_value(t, am.vx, hm.vx)
	}
}

// Two world passes, split by role: the EVERYWHERE step runs live and in every
// resim, on both peers; the AUTHORITY step runs on the host alone, once per
// real tick. No hand-written `if is_host` — the lane holds the gate.
@(test)
lane_two_step_slots_split_by_role :: proc(t: ^testing.T) {
	desc := mover_desc()
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	// Both slots wired: lbox_step everywhere, lbox_step_auth on the authority.
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, lbox_step, lbox_step_auth)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, lbox_step, lbox_step_auth)
	HOSTY :: knet.Net_Id(10)
	ALICE :: knet.Net_Id(20)
	lbox_track(&host, HOSTY, 1, &desc)
	lbox_track(&host, ALICE, 2, &desc)
	lbox_track(&alice, HOSTY, 1, &desc)
	lbox_track(&alice, ALICE, 2, &desc)

	// The converge weather: an intent flip inside an input blackout forces
	// alice to reconcile and resim — the everywhere pass must re-run there.
	DT :: 1.0 / 60.0
	for i in 1 ..= 240 {
		host.ax = i <= 180 ? 1 : 0
		alice.ax = i <= 120 ? 1 : (i <= 180 ? -2 : 0)
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		if i >= 115 && i < 135 {
			for p in alice.out {
				delete(p.data)
			}
			clear(&alice.out)
		} else {
			lane_pump(boxes)
		}
	}

	// The authority pass is host-only, full stop.
	testing.expect_value(t, alice.auth_calls, 0)
	testing.expect(t, host.auth_calls > 0, "the host runs the authority pass")
	// On the host both passes fire once per real tick — it never resims.
	testing.expect_value(t, host.step_calls, host.auth_calls)
	// The client resimmed, and the everywhere pass re-ran through those resims
	// (step_calls = live ticks + every resimmed tick > the resim count alone).
	testing.expect(t, alice.lane.stat_resims > 0, "the blackout forced resims")
	testing.expect(t, alice.step_calls > alice.lane.stat_resims, "the everywhere pass rode the resims")
}

@(test)
lane_rewound_judges_the_shooters_view :: proc(t: ^testing.T) {
	desc := mover_desc()
	host, alice: Lane_Box
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	lane_pair(&host, &alice, &desc)
	boxes := []^Lane_Box{&host, &alice}

	// Alice fires at the host's avatar, which moves +2/tick the whole time —
	// so truth at any ledger tick k is exactly x = 2k, and the rewound view
	// must land on it to the byte.
	host.fire_at = 100
	host.shooter = 2
	host.probe_id = 10

	DT :: 1.0 / 60.0
	for _ in 1 ..= 120 {
		host.ax = 1
		alice.ax = 1
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		lane_pump(boxes)
	}

	testing.expect(t, host.fired, "the probe tick ran")
	// The rewind view is alice's bound ack minus her render offset:
	// confirmed, recent, and bounded.
	testing.expect(t, host.rewound_to < 100, "a remote shooter's view is in the past")
	testing.expect(t, host.rewound_to >= 100 - u64(host.lane.rewind_max), "clamped to the rewind ceiling")
	// The rewound world showed the ledgered truth AT the view — interpolated
	// rewind blends toward the next tick, so allow one blended tick (the
	// mover moves 2/tick).
	diff := host.saw_live - host.saw_past
	expected := f32(2 * (100 - host.rewound_to))
	testing.expect(t, abs(diff - expected) <= 2.0, "rewound pose within one blended tick of the ledger")
	// ...and the live world came back untouched.
	testing.expect_value(t, host.saw_restored, host.saw_live)
	// The inline begin/end pair is the identical judgment: same tick, same
	// rewound bytes, same byte-exact restore.
	testing.expect_value(t, host.inline_to, host.rewound_to)
	testing.expect_value(t, host.saw_inline, host.saw_past)
	testing.expect_value(t, host.inline_restored, host.saw_live)
	// The shooter's own avatar is never wound back (its owner IS the view).
	testing.expect_value(t, ksim.lane_rewind_tick(&host.lane, 1), host.lane.ticker.tick)
}

@(test)
predict_error_blob_math :: proc(t: ^testing.T) {
	desc := mover_desc()
	shown := []u8{0, 0, 0, 0, 0, 0, 0, 0}
	truth := []u8{0, 0, 0, 0, 0, 0, 0, 0}
	err := []u8{0, 0, 0, 0, 0, 0, 0, 0}
	(^f32)(rawptr(&shown[0]))^ = 15 // x (interp): shown 15, truth 5 → err 10
	(^f32)(rawptr(&truth[0]))^ = 5
	(^f32)(rawptr(&shown[4]))^ = 9 // vx (predicted, NOT interp): never smoothed
	(^f32)(rawptr(&truth[4]))^ = 1

	ksim.predict_error(err, shown, truth, &desc, 0)
	testing.expect_value(t, (^f32)(rawptr(&err[0]))^, 10)
	testing.expect_value(t, (^f32)(rawptr(&err[4]))^, 0) // discrete fields carry no error

	ksim.predict_error_decay(err, &desc, 1.0, 1.0) // dt == half-life → k = 0.5
	testing.expect_value(t, (^f32)(rawptr(&err[0]))^, 5)

	m := Mover{x = 5, vx = 1}
	ksim.predict_error_apply(&m, &desc, err)
	testing.expect_value(t, m.x, 10) // truth + decayed error
	testing.expect_value(t, m.vx, 1)

	// Past the cut: a deliberate discontinuity zeroes the whole error — the
	// snap shows, because smoothing a cut looks worse than the cut.
	ksim.predict_error(err, shown, truth, &desc, 8)
	testing.expect_value(t, (^f32)(rawptr(&err[0]))^, 0)
}

// A PREDICTED quaternion glides its reconcile correction — the rotational twin
// of predict_error_blob_math. The error is a ROTATION (shown ⊗ conj(truth)),
// eased toward identity and re-applied, so the drawn orientation starts at the
// old pose (no jump) and converges to truth. TEETH: without the .Quat arms in
// present.odin the drawn pose would snap to truth on the first present.
QBox :: struct {
	rot: [4]f32, // [x, y, z, w] — quaternion128 layout
}

quat_desc :: proc() -> knet.Entity_Desc {
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(QBox, rot), size = 16, flags = {.Predicted, .Interp}, lerp = .Quat},
	}
	return knet.Entity_Desc{fields = fields[:]}
}

@(test)
predicted_quat_glides_its_correction :: proc(t: ^testing.T) {
	desc := quat_desc()
	HALF_PI :: f32(1.5707963) // 90° about Z: sin/cos(π/4) = 0.70710678
	S :: f32(0.70710678)
	// truth = identity, shown = 90° about Z. err must be that 90° rotation.
	truth := []u8{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	shown := []u8{0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
	err := make([]u8, 16);defer delete(err)
	(^f32)(rawptr(&truth[12]))^ = 1 // identity w
	(^f32)(rawptr(&shown[8]))^ = S // z
	(^f32)(rawptr(&shown[12]))^ = S // w

	// The error is the full 90° turn from truth to shown.
	ksim.predict_error(err, shown, truth, &desc, 0)
	testing.expectf(t, abs(knet.quat_angle(([^]f32)(&err[0])) - HALF_PI) < 0.01,
		"quat error should be the 90° turn, got %v rad", knet.quat_angle(([^]f32)(&err[0])))

	// Applied with NO decay onto the truth pose: the drawn orientation is the OLD
	// shown pose, not truth — a glide starts where the eye already was (no jump).
	// This is the line that would fail if .Quat snapped.
	q := QBox{rot = {0, 0, 0, 1}} // truth restored, as the presenter does each frame
	ksim.predict_error_apply(&q, &desc, err)
	testing.expectf(t, abs(knet.quat_angle(([^]f32)(&q.rot[0])) - HALF_PI) < 0.01,
		"first present must draw the OLD pose (90° off truth), not snap to truth — got %v rad", knet.quat_angle(([^]f32)(&q.rot[0])))

	// One half-life of decay eases the error strictly toward truth (0 < a < 90°).
	ksim.predict_error_decay(err, &desc, 1.0, 1.0) // dt == half-life
	a1 := knet.quat_angle(([^]f32)(&err[0]))
	testing.expectf(t, a1 > 0.05 && a1 < HALF_PI - 0.05,
		"one half-life should ease the rotation error partway (0<a<90°), got %v rad", a1)
	q = QBox{rot = {0, 0, 0, 1}}
	ksim.predict_error_apply(&q, &desc, err)
	testing.expectf(t, abs(knet.quat_angle(([^]f32)(&q.rot[0])) - a1) < 0.01,
		"the drawn pose eases with the error, got %v want %v", knet.quat_angle(([^]f32)(&q.rot[0])), a1)

	// Several more half-lives: the error all but vanishes — the pose has glided
	// home to truth.
	for _ in 0 ..< 6 {ksim.predict_error_decay(err, &desc, 1.0, 1.0)}
	testing.expectf(t, knet.quat_angle(([^]f32)(&err[0])) < 0.05,
		"the rotation error should decay to ~0 (glided home), got %v rad", knet.quat_angle(([^]f32)(&err[0])))

	// The SNAP path: a cut below the turn zeroes the error — the pose stays at
	// truth (a snapped quat error reads as identity, not garbage).
	ksim.predict_error(err, shown, truth, &desc, 0.7854) // cut 45° < the 90° turn
	q = QBox{rot = {0, 0, 0, 1}}
	ksim.predict_error_apply(&q, &desc, err)
	testing.expectf(t, knet.quat_angle(([^]f32)(&q.rot[0])) < 0.001,
		"past the cut the pose snaps to truth (error zeroed → identity), got %v rad", knet.quat_angle(([^]f32)(&q.rot[0])))
}

// Per-field glide + cut: with the lane default in play, one field decays at its
// OWN half-life and snaps at its OWN threshold, while its neighbor uses the
// lane's — a slow avatar and a snappy ball in one lane. The cut stays entity-
// coherent: any field past ITS threshold snaps the whole pose.
@(test)
predict_error_per_field_glide_and_cut :: proc(t: ^testing.T) {
	// Two interp float fields (x fast-gliding + a low cut, vx on the lane default).
	@(static) fields := [?]knet.Field_Desc{
		{offset = offset_of(Mover, x), size = size_of(f32), flags = {.Predicted, .Interp}, lerp = .F32, glide = 0.5, cut = 5},
		{offset = offset_of(Mover, vx), size = size_of(f32), flags = {.Predicted, .Interp}, lerp = .F32},
	}
	desc := knet.Entity_Desc{fields = fields[:]}
	shown := []u8{0, 0, 0, 0, 0, 0, 0, 0}
	truth := []u8{0, 0, 0, 0, 0, 0, 0, 0}
	err := []u8{0, 0, 0, 0, 0, 0, 0, 0}

	// Errors of 4 on both fields — under x's cut (5), so nothing snaps yet.
	(^f32)(rawptr(&shown[0]))^ = 4 // x
	(^f32)(rawptr(&shown[4]))^ = 4 // vx
	ksim.predict_error(err, shown, truth, &desc, 0) // lane cut 0 = never
	testing.expect_value(t, (^f32)(rawptr(&err[0]))^, 4)
	testing.expect_value(t, (^f32)(rawptr(&err[4]))^, 4)

	// One decay, dt = 1s. x uses its 0.5s half-life → k = 0.5^2 = 0.25 (4→1);
	// vx uses the lane default 1s → k = 0.5 (4→2). Same lane, different glides.
	ksim.predict_error_decay(err, &desc, 1.0, 1.0)
	testing.expect_value(t, (^f32)(rawptr(&err[0]))^, 1)
	testing.expect_value(t, (^f32)(rawptr(&err[4]))^, 2)

	// x's error jumps past ITS cut (5) while vx has none — the WHOLE pose snaps
	// (entity-coherent), even though the lane default cut is still 0.
	(^f32)(rawptr(&shown[0]))^ = 6 // x: 6 > its cut 5
	(^f32)(rawptr(&shown[4]))^ = 3 // vx: no cut of its own
	ksim.predict_error(err, shown, truth, &desc, 0)
	testing.expect_value(t, (^f32)(rawptr(&err[0]))^, 0)
	testing.expect_value(t, (^f32)(rawptr(&err[4]))^, 0)
}

@(test)
lane_smoothing_glides_reconcile_corrections :: proc(t: ^testing.T) {
	desc := mover_desc()
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)
	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)
	for b in boxes {
		for id in ([]knet.Net_Id{10, 20}) {
			m := new(Mover)
			b.movers[id] = m
			b.owners[id] = id == 10 ? 1 : 2
			ksim.lane_track_set(&b.lane, id, m, &set, b.owners[id])
		}
	}

	// The same blackout-straddles-the-flip weather that forces corrections;
	// this time we watch what alice's own avatar DRAWS versus what it IS.
	DT :: 1.0 / 60.0
	prev_draw, max_draw_d, max_sim_d, max_glide := f32(0), f32(0), f32(0), f32(0)
	prev_sim := f32(0)
	for i in 1 ..= 240 {
		host.ax = i <= 180 ? 1 : 0
		alice.ax = i <= 120 ? 1 : (i <= 180 ? -2 : 0)
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		sim_x := alice.movers[20].x // fields are sim truth right after the frame
		ksim.lane_present(&alice.lane, DT)
		draw_x := alice.movers[20].x // and presented truth after the present

		if i > 10 {
			if abs(draw_x - prev_draw) > max_draw_d {
				max_draw_d = abs(draw_x - prev_draw)
			}
			if abs(sim_x - prev_sim) > max_sim_d {
				max_sim_d = abs(sim_x - prev_sim)
			}
			if abs(draw_x - sim_x) > max_glide {
				max_glide = abs(draw_x - sim_x)
			}
		}
		prev_draw = draw_x
		prev_sim = sim_x

		if i >= 115 && i < 135 {
			for p in alice.out {
				delete(p.data)
			}
			clear(&alice.out)
		} else {
			lane_pump(boxes)
		}
	}

	testing.expect(t, alice.lane.stat_resims > 0, "corrections happened")
	testing.expect(t, max_glide > 3, "the presentation genuinely diverged from the snapped sim")
	testing.expect(t, max_draw_d < max_sim_d, "the eye saw a smaller jump than the sim took")
	testing.expect(t, max_draw_d < 10, "drawn motion stays bounded through corrections")
	// Quiet tail: the error has decayed away — drawn equals sim again.
	testing.expect(t, abs(alice.movers[20].x - host.movers[20].x) < 0.01, "presentation converged to truth")
}

@(test)
lane_possession_switches_the_driver :: proc(t: ^testing.T) {
	desc := mover_desc()
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)
	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)
	for b in boxes {
		for id in ([]knet.Net_Id{10, 20}) {
			m := new(Mover)
			b.movers[id] = m
			b.owners[id] = id == 10 ? 1 : 2
			ksim.lane_track_set(&b.lane, id, m, &set, b.owners[id])
		}
	}

	// At iteration 100 entity 10 changes hands, host → alice (both peers
	// apply it, as they would off Ev_Owner_Changed). From then on ALICE'S
	// stick drives it everywhere: her buffered inputs on the server, her
	// prediction ledger on her own screen.
	DT :: 1.0 / 60.0
	x10_at_transfer, x10_late := f32(0), f32(0)
	for i in 1 ..= 240 {
		host.ax = i <= 180 ? 1 : 0
		alice.ax = i <= 120 ? 1 : (i <= 180 ? -2 : 0)
		if i == 100 {
			testing.expect(t, ksim.lane_set_owner(&host.lane, 10, 2), "host applies the transfer")
			testing.expect(t, ksim.lane_set_owner(&alice.lane, 10, 2), "client applies the transfer")
			for b in boxes {
				b.owners[10] = 2
			}
			x10_at_transfer = host.movers[10].x
		}
		if i == 180 {
			x10_late = host.movers[10].x
		}
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		lane_pump(boxes)
	}

	// Alice's brake (ax=-2 from 121) pulled the possessed entity BACKWARD on
	// the authority — the input source really switched.
	testing.expect(t, x10_late < x10_at_transfer, "the new owner's intent moves the entity")
	// And both entities converge byte-equal on both peers, the handed-off
	// one now via alice's prediction.
	for id in ([]knet.Net_Id{10, 20}) {
		hm, am := host.movers[id], alice.movers[id]
		testing.expect_value(t, am.x, hm.x)
		testing.expect_value(t, am.vx, hm.vx)
	}
}

// A contested entity is SELF-SIMULATING (a ball integrates its own motion —
// that's what makes every peer's prediction good between batches; an
// input-driven avatar would coast frozen and fight corrections forever).
glide_thunk :: proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane, owner: knet.Player_Id) {
	m := cast(^Mover)entity
	m.x += m.vx
}

// A contested entity presents on the CLAIM-weighted timeline: the watched
// view while nobody local drives it (so remote touches land beside remote
// avatars), the predicted pose while claimed (so YOUR touches answer now —
// and legitimately FRONT-RUN the server: it is your timeline).
@(test)
lane_contested_presents_on_the_claim :: proc(t: ^testing.T) {
	desc := mover_desc()
	set_c := ksim.Sim_Set{entity_desc = &desc, tick = glide_thunk, input_size = 0, contested = true}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)
	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)
	for b in boxes {
		m := new(Mover)
		b.movers[10] = m
		b.owners[10] = 1
		ksim.lane_track_set(&b.lane, 10, m, &set_c, 1)
	}
	host.movers[10].vx = 2 // the authority sets it rolling; every sim integrates it

	DT :: 1.0 / 60.0
	gap_unclaimed, gap_claimed := f32(0), f32(0)
	for i in 1 ..= 190 {
		host.ax = 0
		alice.ax = 0
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		if i > 150 {
			ksim.lane_claim(&alice.lane, 10) // my sim "touches" it now
		}
		ksim.lane_present(&alice.lane, DT)
		if i == 150 {
			gap_unclaimed = host.movers[10].x - alice.movers[10].x
		}
		if i == 190 {
			gap_claimed = host.movers[10].x - alice.movers[10].x
		}
		lane_pump(boxes)
	}

	// Unclaimed: the watched view, a real render delay behind the live world.
	testing.expect(t, gap_unclaimed >= 6, "unclaimed contested pose rides the delayed watched view")
	// Claimed: the predicted timeline — decisively fresher, and allowed to
	// front-run the server's live pose (the client runs AHEAD by its lead).
	testing.expect(t, gap_claimed <= gap_unclaimed - 4, "a claim pulls presentation onto the predicted timeline")
	testing.expect(t, gap_claimed >= -30, "bounded by the lead, not runaway")
}

// PREDICT-WORLD (echo mode): batches carry every player's held input, so a
// client ticks a REMOTE-owned contested entity every tick with them — one
// timeline, presentation = predicted pose, legitimately front-running the
// server instead of trailing a watched view.
@(test)
lane_echo_extrapolates_remote_avatars :: proc(t: ^testing.T) {
	desc := mover_desc()
	set_c := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1, contested = true}
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}
	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)
	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2, echo_inputs = true}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)
	for b in boxes {
		m := new(Mover)
		b.movers[10] = m
		b.owners[10] = 1 // the HOST's avatar — remote from alice's seat
		ksim.lane_track_set(&b.lane, 10, m, &set_c, 1)
	}

	DT :: 1.0 / 60.0
	moved_frames := 0
	prev := f32(0)
	gap := f32(0)
	for i in 1 ..= 190 {
		host.ax = 1 // the echoed held input alice extrapolates with
		alice.ax = 0
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT)
		if i > 120 {
			if alice.movers[10].x > prev + 0.5 {
				moved_frames += 1
			}
			gap = host.movers[10].x - alice.movers[10].x
		}
		prev = alice.movers[10].x
		lane_pump(boxes)
	}

	// Extrapolation, not batch-stepping: the remote avatar advances nearly
	// every frame on alice's screen...
	testing.expect(t, moved_frames > 55, "held-input extrapolation moves the remote avatar per-frame")
	// ...on the PREDICTED timeline: at or ahead of the server's live pose,
	// never trailing a watched view.
	testing.expect(t, gap <= 4, "echo-mode presentation front-runs or matches the live world")
	testing.expect(t, gap >= -30, "bounded by the lead")
}

@(test)
lane_present_smooths_watched_motion :: proc(t: ^testing.T) {
	desc := mover_desc()
	host, alice: Lane_Box
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	lane_pair(&host, &alice, &desc)
	boxes := []^Lane_Box{&host, &alice}

	// The host avatar cruises at +2/tick; alice WATCHES it. Without
	// lane_present it steps +4 every second frame (the snap rate); with it,
	// the watch clock should hand her ~+2 every frame, a few ticks behind.
	DT :: 1.0 / 60.0
	prev_x := f32(0)
	steps, jumps := 0, 0
	max_deficit := f32(0)
	for i in 1 ..= 120 {
		host.ax = 1
		alice.ax = 1
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		lane_pump(boxes)
		ksim.lane_present(&alice.lane, DT)

		if i > 60 { // judge only the settled window
			x := alice.movers[10].x
			d := x - prev_x
			testing.expect(t, d >= 0, "watched motion never runs backwards")
			if d > 3 {
				jumps += 1 // a snap-rate step (+4) leaking through
			}
			if d > 0.5 {
				steps += 1
			}
			deficit := host.movers[10].x - x
			if deficit > max_deficit {
				max_deficit = deficit
			}
			prev_x = x
		} else {
			prev_x = alice.movers[10].x
		}
	}

	testing.expect(t, steps > 40, "the watched avatar moves nearly every frame, not every batch")
	testing.expect_value(t, jumps, 0)
	// Rendered a bounded few ticks in the past: the price of the bracket.
	testing.expect(t, max_deficit > 0, "watched view trails the live world")
	testing.expect(t, max_deficit < 2 * f32(host.lane.watch_delay + 8), "but only by the watch delay plus transit slack")
}

// ---- predicted spawns: a fired projectile ---------------------------------------

PROJ_TYPE :: ksess.Entity_Type(7)
PROJ_LAND :: f32(200) // the projectile flies +vx/tick until it lands here, then rests

// A self-integrating projectile: no input, flies its own arc (like the ball),
// landing at PROJ_LAND so convergence is a clean equality, not a moving target.
proj_fly_thunk :: proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane, owner: knet.Player_Id) {
	m := cast(^Mover)entity
	if m.vx == 0 {return}
	m.x += m.vx
	if m.x >= PROJ_LAND {
		m.x = PROJ_LAND
		m.vx = 0
	}
}

// The shooter's FIRE verb: spawn a projectile at the muzzle — authoritative on
// the host (a real id, lane_track_set), predicted on the client (a provisional
// id, lane_spawn_predicted). A real game hides this role branch behind a boot
// helper; the test spells it out. The projectile's Sim_Set rides the Lane_Box.
shooter_fire_exec :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane, by: knet.Player_Id) -> bool {
	b := cast(^Lane_Box)ksim.lane_game(lane)
	shooter := cast(^Mover)entity
	if shooter.hp <= 0 {return false} // out of ammo — the authority may refuse a stale-purse fire
	shooter.hp -= 1
	p := new(Mover)
	p.x = shooter.x
	p.vx = 3
	if ksim.lane_is_authority(lane) {
		b.proj_ids += 1
		id := knet.Net_Id(600 + b.proj_ids)
		b.movers[id] = p
		ksim.lane_track_set(&b.lane, id, p, b.proj_set, by)
		b.host_proj = p
		b.host_proj_id = id
	} else {
		id := ksim.lane_spawn_predicted(&b.lane, p, b.proj_set, by, PROJ_TYPE)
		b.movers[id] = p
		b.cli_proj = p
		b.cli_proj_id = id
	}
	return true
}

@(test)
lane_predicted_projectile :: proc(t: ^testing.T) {
	desc := mover_desc()
	proj_set := ksim.Sim_Set{entity_desc = &desc, tick = proj_fly_thunk, input_size = 0}
	fire := [?]ksim.Sim_Cmd{{exec = shooter_fire_exec}}
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1, commands = fire[:]}

	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	host.proj_set = &proj_set
	alice.proj_set = &proj_set
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)

	// The shooter, owned by alice (predicted on her screen, truth on the host),
	// parked at the muzzle x=100 (intent stays 0 — only verbs and flight move x).
	SHOOTER :: knet.Net_Id(20)
	for b in boxes {
		s := new(Mover)
		s.x = 100
		s.hp = 10 // ammo (delta-lane state; the walk is kit/net's job, seeded here)
		b.movers[SHOOTER] = s
		b.owners[SHOOTER] = 2
		ksim.lane_track_set(&b.lane, SHOOTER, s, &set, 2)
	}

	DT :: 1.0 / 60.0
	settle :: proc(boxes: []^Lane_Box, frames: int) {
		for _ in 0 ..< frames {
			ksim.lane_frame(&boxes[0].lane, DT)
			lane_pump(boxes)
			ksim.lane_frame(&boxes[1].lane, DT)
			ksim.lane_present(&boxes[1].lane, DT)
			lane_pump(boxes)
		}
	}
	settle(boxes, 60) // anchor + converge

	// FIRE — the shot leaves alice's screen this instant, before any round trip.
	testing.expect(t, ksim.lane_command(&alice.lane, SHOOTER, 0, nil), "the fire schedules")
	ksim.lane_frame(&alice.lane, DT) // executes at her next tick
	born := alice.lane.ticker.tick
	testing.expect(t, alice.cli_proj != nil, "alice's projectile exists the instant she fires")
	testing.expect(t, ksim.lane_id_provisional(knet.Net_Id(0x8000_0001)), "provisional ids are high-bit tagged")
	testing.expect(t, host.host_proj == nil, "the authority hasn't seen the fire yet")
	spawn_x := alice.cli_proj.x
	lane_pump(boxes) // the reliable fire reaches the host

	// A short INPUT blackout right after the fire: alice's shooter mispredicts,
	// so reconciles land BEFORE the projectile's spawn tick (the host runs a
	// transit behind) — the born-gating path. The reliable fire already landed.
	for i in 0 ..< 16 {
		ksim.lane_frame(&host.lane, DT)
		ksim.lane_frame(&alice.lane, DT)
		for p in alice.out {delete(p.data)}
		clear(&alice.out) // drop alice's outgoing (inputs) — host holds-last
		lane_pump(boxes) // host -> alice batches still flow
	}
	// BORN-GATING, exactly: through those reconciles the projectile flew its own
	// deterministic arc, ONE step per tick since birth — no over-integration.
	flown := alice.lane.ticker.tick - born
	testing.expect_value(t, alice.cli_proj.x, spawn_x + f32(flown) * 3)
	testing.expect(t, host.host_proj != nil, "the authority spawned its projectile")

	// MATCH — the authority's spawn arrives (a real game fires this on Ev_Spawned).
	entity, _, matched := ksim.lane_spawn_match(&alice.lane, host.host_proj_id, 2, PROJ_TYPE)
	testing.expect(t, matched, "the authority's spawn matched alice's prediction")
	testing.expect(t, entity == rawptr(alice.cli_proj), "and it rekeyed the very projectile she predicted")

	// After the match the projectile reconciles against the authority, and both
	// land at the wall — a clean quiescent convergence.
	settle(boxes, 160)
	near :: proc(a, b: f32) -> bool {return abs(a - b) < 0.01}
	testing.expect_value(t, host.host_proj.x, PROJ_LAND)
	testing.expect(t, near(alice.cli_proj.x, PROJ_LAND), "alice's projectile converged on the authority's")
}

@(test)
lane_predicted_projectile_rejected :: proc(t: ^testing.T) {
	desc := mover_desc()
	proj_set := ksim.Sim_Set{entity_desc = &desc, tick = proj_fly_thunk, input_size = 0}
	fire := [?]ksim.Sim_Cmd{{exec = shooter_fire_exec}}
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1, commands = fire[:]}

	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	host.proj_set = &proj_set
	alice.proj_set = &proj_set
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)

	SHOOTER :: knet.Net_Id(20)
	for b in boxes {
		s := new(Mover)
		s.x = 100
		b.movers[SHOOTER] = s
		b.owners[SHOOTER] = 2
		ksim.lane_track_set(&b.lane, SHOOTER, s, &set, 2)
	}

	DT :: 1.0 / 60.0
	settle :: proc(boxes: []^Lane_Box, frames: int) {
		for _ in 0 ..< frames {
			ksim.lane_frame(&boxes[0].lane, DT)
			lane_pump(boxes)
			ksim.lane_frame(&boxes[1].lane, DT)
			ksim.lane_present(&boxes[1].lane, DT)
			lane_pump(boxes)
		}
	}
	settle(boxes, 60)

	// Divergent ammo: alice's client thinks she has a round, the authority knows
	// the magazine is empty (delta-lane state, seeded by hand here).
	alice.movers[SHOOTER].hp = 1
	host.movers[SHOOTER].hp = 0
	testing.expect(t, ksim.lane_command(&alice.lane, SHOOTER, 0, nil), "the fire schedules on stale ammo")
	ksim.lane_frame(&alice.lane, DT) // client speculates the spawn
	testing.expect(t, alice.cli_proj != nil, "the shot leaves alice's screen optimistically")
	testing.expect(t, ksim.lane_tracks(&alice.lane, alice.cli_proj_id), "and it's tracked, flying, provisional")

	// The authority refuses (empty magazine); the verdict despawns the projectile.
	lane_pump(boxes)
	settle(boxes, 90)
	testing.expect(t, !ksim.lane_tracks(&alice.lane, alice.cli_proj_id), "the refused fire culled its projectile")
	testing.expect(t, host.host_proj == nil, "and the authority never spawned one")
}

// ---------------------------------------------------------------------------
// The reject-chain pair: an early rejection makes cmd_settle unwind and
// RE-EXECUTE the surviving verbs. A survivor that spawned must hand back the
// projectile it already minted — lane_spawn_of_exec, the boot door's check —
// never a second provisional (a ghost the FIFO match can't pair); and the
// settle re-resolves its ^Tracked per survivor, because a spawn's append can
// reallocate the track list under it.

// The rejectable gate: predicated on delta-lane hp (the authority's purse
// says no), spawns nothing.
chain_gate_exec :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane, by: knet.Player_Id) -> bool {
	m := cast(^Mover)entity
	if m.hp <= 0 {
		return false
	}
	m.hp -= 1
	return true
}

// The surviving fire: spawns — through the boot door's contract (reuse the
// exec's existing spawn on a re-execution, never mint a ghost).
chain_fire_exec :: proc(entity: rawptr, args: []u8, lane: ^ksim.Lane, by: knet.Player_Id) -> bool {
	b := cast(^Lane_Box)ksim.lane_game(lane)
	shooter := cast(^Mover)entity
	if ksim.lane_is_authority(lane) {
		p := new(Mover)
		p.x = shooter.x
		p.vx = 3
		b.proj_ids += 1
		id := knet.Net_Id(600 + b.proj_ids)
		b.movers[id] = p
		ksim.lane_track_set(&b.lane, id, p, b.proj_set, by)
		b.host_proj = p
		b.host_proj_id = id
		return true
	}
	if e0, id0, exists := ksim.lane_spawn_of_exec(lane); exists {
		b.cli_proj = cast(^Mover)e0
		b.cli_proj_id = id0
		return true
	}
	p := new(Mover)
	p.x = shooter.x
	p.vx = 3
	id := ksim.lane_spawn_predicted(&b.lane, p, b.proj_set, by, PROJ_TYPE)
	b.movers[id] = p
	b.cli_proj = p
	b.cli_proj_id = id
	return true
}

@(test)
lane_reject_chain_keeps_one_projectile :: proc(t: ^testing.T) {
	desc := mover_desc()
	proj_set := ksim.Sim_Set{entity_desc = &desc, tick = proj_fly_thunk, input_size = 0}
	cmds := [?]ksim.Sim_Cmd{{id = 1, exec = chain_gate_exec}, {id = 2, exec = chain_fire_exec}}
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1, commands = cmds[:]}

	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	host.proj_set = &proj_set
	alice.proj_set = &proj_set
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	lane_pump(boxes)

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, nil)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, nil)

	SHOOTER :: knet.Net_Id(20)
	for b in boxes {
		s := new(Mover)
		s.x = 100
		b.movers[SHOOTER] = s
		b.owners[SHOOTER] = 2
		ksim.lane_track_set(&b.lane, SHOOTER, s, &set, 2)
	}

	DT :: 1.0 / 60.0
	settle :: proc(boxes: []^Lane_Box, frames: int) {
		for _ in 0 ..< frames {
			ksim.lane_frame(&boxes[0].lane, DT)
			lane_pump(boxes)
			ksim.lane_frame(&boxes[1].lane, DT)
			ksim.lane_present(&boxes[1].lane, DT)
			lane_pump(boxes)
		}
	}
	settle(boxes, 60)

	// Divergent purse: alice's screen says the gate is legal; the authority
	// refuses it. The fire behind it survives either way — the verb burst.
	alice.movers[SHOOTER].hp = 1
	host.movers[SHOOTER].hp = 0
	testing.expect(t, ksim.lane_command(&alice.lane, SHOOTER, 1, nil), "the gate schedules")
	testing.expect(t, ksim.lane_command(&alice.lane, SHOOTER, 2, nil), "the fire schedules behind it")
	ksim.lane_frame(&alice.lane, DT) // both speculate; the fire spawns ONE provisional
	testing.expect(t, alice.cli_proj != nil, "the shot left her screen this tick")
	first_id := alice.cli_proj_id

	prov_count :: proc(l: ^ksim.Lane) -> int {
		n := 0
		for tr in l.tracked {
			if tr.provisional {
				n += 1
			}
		}
		return n
	}
	testing.expect_value(t, prov_count(&alice.lane), 1)

	// The reject lands; cmd_settle unwinds the gate and RE-EXECUTES the fire.
	settle(boxes, 90)
	testing.expect_value(t, prov_count(&alice.lane), 1) // reused, never a ghost
	testing.expect(t, ksim.lane_tracks(&alice.lane, first_id), "the original projectile still flies")
	testing.expect_value(t, alice.cli_proj_id, first_id) // the re-exec handed back the same spawn
	// Truth healed the purse: the refused gate never spent on the authority.
	testing.expect_value(t, host.movers[SHOOTER].hp, i32(0))
}

// ---------------------------------------------------------------------------
// Every-screen facts (the mine-form _fx): the owner's live pass fires
// mine=true instantly; the authority presents everyone else's facts as its
// own live pass (mine=false); a WATCHING third peer receives SIM_FACT and
// fires when its watch clock reaches the fact's tick — beside the delayed
// avatar that caused it, never on packet arrival.

FACT_AT :: u64(60) // the event tick: alice's mover "fires" here, exactly once

// Mirrors the generated mine-form thunk: tick the entity, and on the event
// tick encode the fact tuple, broadcast from the authority, and fire the fx
// locally where this screen's own simulation presented it live.
fact_tick_thunk :: proc(entity: rawptr, input: rawptr, lane: ^ksim.Lane, owner: knet.Player_Id) {
	if input == nil {
		return
	}
	m := cast(^Mover)entity
	lane_mover_step(m, (cast(^i8)input)^)
	fired := ksim.lane_now(lane) == FACT_AT && owner == 2 // alice's avatar only
	if fired {
		w := knet.writer_make(16, context.temp_allocator)
		knet.write_bool(&w, true)
		knet.write_f32(&w, m.x)
		blob := knet.writer_bytes(&w)
		if ksim.lane_is_authority(lane) {
			ksim.lane_fact(lane, entity, blob)
		}
		if !lane.resimming {
			mine := owner == ksim.lane_me(lane)
			if mine || ksim.lane_is_authority(lane) {
				box_fact_fx(entity, lane, mine, blob)
			}
		}
	}
}

// Mirrors the generated fx decode thunk: bytes → typed facts → the author's
// presentation proc (recorded into the box here).
box_fact_fx :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8) {
	b := cast(^Lane_Box)ksim.lane_game(lane)
	r := knet.reader_make(args)
	fired := knet.read_bool(&r)
	x := knet.read_f32(&r)
	if r.err || !fired {
		return
	}
	b.fx_calls += 1
	b.fx_mine = mine
	b.fx_x = x
	b.fx_clock = lane.watch_clock
	b.fx_newest = lane.rx.newest
}

@(test)
lane_facts_reach_every_screen_on_time :: proc(t: ^testing.T) {
	desc := mover_desc()
	host, alice, bob: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	lbox_make(&bob, 101)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	defer lbox_destroy(&bob)
	boxes := []^Lane_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, 0xB0B, "bob")
	ksess.session_client_join(&bob.s)
	lane_pump(boxes)
	testing.expect_value(t, alice.s.me, knet.Player_Id(2))
	testing.expect_value(t, bob.s.me, knet.Player_Id(3))

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	fact_set := ksim.Sim_Set{entity_desc = &desc, tick = fact_tick_thunk, input_size = 1, fx = box_fact_fx}
	pairs := [?]struct {
		id:    knet.Net_Id,
		owner: knet.Player_Id,
	}{{10, 1}, {20, 2}}
	for b in boxes {
		ksim.lane_init(&b.lane, &b.s, 1, cfg = cfg)
		ksim.lane_set_sim(&b.lane, b, lbox_sample, nil)
		for p in pairs {
			m := new(Mover)
			b.movers[p.id] = m
			b.owners[p.id] = p.owner
			ksim.lane_track_set(&b.lane, p.id, m, &fact_set, p.owner)
		}
	}

	DT :: 1.0 / 60.0
	for i in 1 ..= 240 {
		host.ax = 1
		alice.ax = 1
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT)
		ksim.lane_frame(&bob.lane, DT)
		ksim.lane_present(&bob.lane, DT)
		lane_pump(boxes)
	}

	// Alice's own screen: the live pass, mine=true, exactly once — and no
	// SIM_FACT echo ever re-fires it (the authority excludes the owner).
	testing.expect_value(t, alice.fx_calls, 1)
	testing.expect(t, alice.fx_mine, "the owner's fire is mine")

	// The authority's screen: its live pass presents everyone, mine=false.
	testing.expect_value(t, host.fx_calls, 1)
	testing.expect(t, !host.fx_mine, "the authority presents a remote fact")

	// Bob watches: SIM_FACT fired once, mine=false, and ON THE WATCH CLOCK —
	// at the fact's tick in render time, provably behind the wire (batches
	// newer than the fact had already landed when it presented).
	testing.expect_value(t, bob.fx_calls, 1)
	testing.expect(t, !bob.fx_mine, "a watcher's fact is never mine")
	testing.expect(t, bob.fx_clock >= f64(FACT_AT), "fires once the watch clock reaches the fact")
	testing.expect(t, bob.fx_clock <= f64(FACT_AT) + 3, "and not meaningfully later")
	testing.expect(t, f64(bob.fx_newest) > bob.fx_clock, "the fire happened behind the newest batch — delayed, not on arrival")

	// The payload crossed intact: every screen decoded the authoritative x.
	testing.expect_value(t, host.fx_x, alice.fx_x) // prediction matched truth (no loss)
	testing.expect_value(t, bob.fx_x, host.fx_x)
}

// ---------------------------------------------------------------------------
// Declared world-pass facts (@(gd_fact) doors): the same every-screen laws as
// tick facts, minted from the WORLD passes. Four laws pinned:
//   (1) everywhere-pass anchored fact — the anchor owner's live pass fires
//       mine=true once (broadcast skips them: no echo double-fire), the
//       authority fires live mine=false, a watcher fires at the watch clock,
//       and a screen with no part stays silent at announce time;
//   (2) PROVENANCE — the same door called from an AUTHORITY-ONLY context
//       (in_auth) INCLUDES the anchor's owner in the broadcast: their screen
//       never ran the announcing code, so the wire copy is their only fire;
//   (3) anchorless world fact — the authority's live pass is the causer
//       (mine=true there), every client presents at the watch clock with a
//       nil entity;
//   (4) despawn-drop — an anchored fact whose anchor untracks before the
//       watch clock arrives is dropped, never fired against a dead entity.

DF_BUMP :: u16(0x1001) // slot 0: everywhere-pass anchored
DF_ADJU :: u16(0x1002) // slot 1: authority-context anchored (provenance)
DF_HORN :: u16(0x1003) // slot 2: anchorless
DF_LATE :: u16(0x1004) // slot 3: despawn-drop (must never fire)

DF_BUMP_AT :: u64(60)
DF_ADJU_AT :: u64(120)
DF_HORN_AT :: u64(150)
DF_LATE_AT :: u64(180)

df_record :: proc(slot: int, entity: rawptr, lane: ^ksim.Lane, mine: bool) {
	b := cast(^Lane_Box)ksim.lane_game(lane)
	b.df_calls[slot] += 1
	b.df_mine[slot] = mine
	b.df_clock[slot] = lane.watch_clock
	b.df_nil[slot] = entity == nil
}

df_fx_bump :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8) {df_record(0, entity, lane, mine)}
df_fx_adju :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8) {df_record(1, entity, lane, mine)}
df_fx_horn :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8) {df_record(2, entity, lane, mine)}
df_fx_late :: proc(entity: rawptr, lane: ^ksim.Lane, mine: bool, args: []u8) {df_record(3, entity, lane, mine)}

df_table := [?]ksim.Fact_Desc{
	{id = DF_BUMP, fx = df_fx_bump},
	{id = DF_ADJU, fx = df_fx_adju},
	{id = DF_HORN, fx = df_fx_horn},
	{id = DF_LATE, fx = df_fx_late},
}

// Mirrors the generated ANCHORED door: authority broadcasts, the live pass
// fires where this screen's own simulation caused it.
df_door :: proc(l: ^ksim.Lane, entity: rawptr, kind: u16, slot: int) {
	if ksim.lane_is_authority(l) {
		ksim.lane_fact(l, entity, {}, kind)
	}
	if ksim.lane_live(l) {
		owner := ksim.lane_owner_of(l, entity)
		mine := owner != knet.PLAYER_ID_INVALID && owner == ksim.lane_me(l)
		if mine || ksim.lane_is_authority(l) {
			df_record(slot, entity, l, mine)
		}
	}
}

// Mirrors the generated ANCHORLESS door: the world (the authority's own
// simulation) is the causer.
df_door_horn :: proc(l: ^ksim.Lane) {
	if ksim.lane_is_authority(l) {
		ksim.lane_fact(l, nil, {}, DF_HORN)
		if ksim.lane_live(l) {
			df_record(2, nil, l, true)
		}
	}
}

// The EVERYWHERE pass: every peer announces the bump at its tick — the door's
// gates sort the screens (that is the whole point of the channel).
df_step :: proc(user: rawptr, tick: u64) {
	b := cast(^Lane_Box)user
	if tick == DF_BUMP_AT {
		m := b.movers[20] // alice's avatar — she caused it
		df_door(&b.lane, m, DF_BUMP, 0)
	}
}

// The AUTHORITY pass: adjudication facts — the lane marks in_auth around this
// pass, so the broadcast must INCLUDE alice (she never ran this code).
df_step_auth :: proc(user: rawptr, tick: u64) {
	b := cast(^Lane_Box)user
	switch tick {
	case DF_ADJU_AT:
		df_door(&b.lane, b.movers[20], DF_ADJU, 1)
	case DF_HORN_AT:
		df_door_horn(&b.lane)
	case DF_LATE_AT:
		df_door(&b.lane, b.movers[20], DF_LATE, 3)
	}
}

@(test)
lane_declared_facts_world_pass :: proc(t: ^testing.T) {
	desc := mover_desc()
	host, alice, bob: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	lbox_make(&bob, 101)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	defer lbox_destroy(&bob)
	boxes := []^Lane_Box{&host, &alice, &bob}

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	ksess.session_client_start(&bob.s, 0xB0B, "bob")
	ksess.session_client_join(&bob.s)
	lane_pump(boxes)
	testing.expect_value(t, alice.s.me, knet.Player_Id(2))
	testing.expect_value(t, bob.s.me, knet.Player_Id(3))

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = 2}
	set := ksim.Sim_Set{entity_desc = &desc, tick = mover_tick_thunk, input_size = 1}
	pairs := [?]struct {
		id:    knet.Net_Id,
		owner: knet.Player_Id,
	}{{10, 1}, {20, 2}}
	for b in boxes {
		ksim.lane_init(&b.lane, &b.s, 1, cfg = cfg)
		ksim.lane_set_sim(&b.lane, b, lbox_sample, df_step, df_step_auth)
		ksim.lane_set_facts(&b.lane, df_table[:])
		for p in pairs {
			m := new(Mover)
			b.movers[p.id] = m
			b.owners[p.id] = p.owner
			ksim.lane_track_set(&b.lane, p.id, m, &set, p.owner)
		}
	}

	DT :: 1.0 / 60.0
	for i in 1 ..= 300 {
		host.ax = 1
		alice.ax = 1
		ksim.lane_frame(&host.lane, DT)
		lane_pump(boxes)
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT)
		ksim.lane_frame(&bob.lane, DT)
		ksim.lane_present(&bob.lane, DT)
		lane_pump(boxes)
		if i == int(DF_LATE_AT) + 1 {
			// The despawn races the render delay: bob loses the anchor before
			// his watch clock reaches the fact — the filed fact must drop.
			ksim.lane_untrack(&bob.lane, 20)
		}
	}

	// (1) The everywhere-pass bump: alice (the causer) fired mine, live, once
	// — the broadcast skipped her, so no echo double-fire; the authority
	// presented it live (mine=false); bob presented it ON the watch clock.
	testing.expect_value(t, alice.df_calls[0], 1)
	testing.expect(t, alice.df_mine[0], "the causer's bump is mine")
	testing.expect_value(t, host.df_calls[0], 1)
	testing.expect(t, !host.df_mine[0], "the authority presents a remote bump")
	testing.expect_value(t, bob.df_calls[0], 1)
	testing.expect(t, !bob.df_mine[0], "a watcher's bump is never mine")
	testing.expect(t, bob.df_clock[0] >= f64(DF_BUMP_AT), "bob fires once the watch clock reaches the bump")
	testing.expect(t, bob.df_clock[0] <= f64(DF_BUMP_AT) + 3, "and not meaningfully later")

	// (2) PROVENANCE: the adjudication fact was minted in the authority pass —
	// alice never ran that code, so the broadcast included her; her only fire
	// is the wire copy, at her watch clock, mine=false. (The tick-fact skip
	// here would have orphaned it on exactly the screen it is most about.)
	testing.expect_value(t, host.df_calls[1], 1)
	testing.expect(t, !host.df_mine[1], "the authority's adjudication is not mine (alice's avatar)")
	testing.expect_value(t, alice.df_calls[1], 1)
	testing.expect(t, !alice.df_mine[1], "alice presents the authority's word, not a prediction")
	testing.expect(t, alice.df_clock[1] >= f64(DF_ADJU_AT), "on her watch clock")
	testing.expect_value(t, bob.df_calls[1], 1)

	// (3) The anchorless horn: the authority's own live pass is the causer;
	// both clients present at the watch clock with a nil entity.
	testing.expect_value(t, host.df_calls[2], 1)
	testing.expect(t, host.df_mine[2], "the world's horn is the authority's own simulation")
	testing.expect_value(t, alice.df_calls[2], 1)
	testing.expect(t, !alice.df_mine[2], "a client presents the world's horn")
	testing.expect(t, alice.df_nil[2], "anchorless: the thunk sees a nil entity")
	testing.expect_value(t, bob.df_calls[2], 1)
	testing.expect(t, bob.df_clock[2] >= f64(DF_HORN_AT), "on the watch clock")

	// (4) Despawn-drop: bob lost the anchor before his watch clock arrived —
	// the filed fact dropped instead of firing against a dead entity. The
	// authority (live) and alice (still tracking) both presented it.
	testing.expect_value(t, host.df_calls[3], 1)
	testing.expect_value(t, alice.df_calls[3], 1)
	testing.expect_value(t, bob.df_calls[3], 0)
}

// ---------------------------------------------------------------------------
// THE DELAYED WIRE — transit that costs something.
//
// `lane_pump` above drains TO QUIET: every packet lands the instant it is
// sent, so the ack round trip is zero frames and a client's cold start pays
// nothing. That is why the whole suite was blind to the deep-surplus bug: the
// lead error never goes deep on a zero-transit wire, so
// `lane_two_peers_converge`'s "corrections stay inside the nudge" assertion
// passed happily with a 25% rung sitting in the tree, unentered.
//
// This wire holds every parcel a fixed number of frames EACH WAY instead. The
// cold start then pays a real round trip: the anchor seeds from a cold clock
// (rtt 0 — nobody pings here), the `+= 3` unacked probe runs for the whole
// flight time before the first ack comes back, and the client lands far over
// target. Shedding that is exactly what SCALE_NUDGE_DEEP is for.
//
// Ownership: the box's send clones into `out`; this wire takes those clones
// and owns them from there — including whatever is still in flight when the
// test ends (wire_destroy).
Lane_Wire :: struct {
	frame:  int,
	hold:   int, // frames of one-way transit
	flight: [dynamic]Wire_Parcel,
}

Wire_Parcel :: struct {
	from: ksess.Peer_Id,
	to:   ksess.Peer_Id,
	data: []u8,
	due:  int, // the wire frame it lands on
}

wire_make :: proc(hold: int) -> Lane_Wire {
	return Lane_Wire{hold = hold, flight = make([dynamic]Wire_Parcel)}
}

wire_destroy :: proc(w: ^Lane_Wire) {
	for p in w.flight {
		delete(p.data) // still in flight at teardown — ours to free
	}
	delete(w.flight)
}

// One frame of wire: everything sent since the last step lifts off (landing
// `hold` frames from now), then everything due lands. Send and receive can
// never happen on the same frame, which is the whole point.
wire_step :: proc(w: ^Lane_Wire, boxes: []^Lane_Box) {
	for b in boxes {
		for len(b.out) > 0 {
			p := b.out[0]
			ordered_remove(&b.out, 0)
			append(&w.flight, Wire_Parcel{from = b.peer, to = p.to, data = p.data, due = w.frame + w.hold})
		}
	}
	for i := 0; i < len(w.flight); {
		p := w.flight[i]
		if p.due > w.frame {
			i += 1
			continue
		}
		ordered_remove(&w.flight, i)
		for dst in boxes {
			if dst.peer == p.from {
				continue
			}
			if p.to == ksess.BROADCAST_PEER || dst.peer == p.to {
				r := knet.reader_make(p.data)
				ksess.session_handle_packet(&dst.s, p.from, &r)
			}
		}
		delete(p.data)
	}
	w.frame += 1
}


// THE COLD START OVER REAL TRANSIT — the deep-surplus rung's pin.
//
// WHAT THIS WOULD CATCH: a lead controller that can only bend ±SCALE_NUDGE_MAX.
// A client's cold start lands far OVER target (the anchor seeds from a cold
// clock, then the unacked `+= 3` probe runs for a whole round trip before the
// first ack can correct it) — measured here at peak ~42 ticks against a target
// of 9. At 2% that sheds ~1.2 ticks/s: with the deep rung removed this same
// harness measures 34 ticks still standing at frame 480 and 24 at frame 900,
// i.e. half a minute parked over target. (It also catches a rung that is merely
// too GENTLE: at the 8% first tried it reads 16 here, still bleeding.) That is
// not just latency — every lane_rewound query clamps to rewind_max while it
// lasts, so the authority
// judges hitscan against a world half a second stale and lands nothing,
// silently, with no error anywhere.
//
// WHY THE REST OF THE SUITE CANNOT CATCH IT: `lane_pump` drains to quiet, so
// transit is zero, the probe costs nothing, and the head lands on target by
// accident. `lane_two_peers_converge` even asserts "corrections stay inside the
// nudge" and passes with the 25% rung in the tree — the error never goes deep
// there. Only a wire that HOLDS packets makes the pathology exist at all, which
// is why the peak assertion below is load-bearing: a harness that stopped
// reproducing the overshoot would make the convergence assertion vacuous.
@(test)
lane_deep_surplus_sheds_cold_start :: proc(t: ^testing.T) {
	desc := mover_desc()
	host, alice: Lane_Box
	lbox_make(&host, 1)
	lbox_make(&alice, 100)
	defer lbox_destroy(&host)
	defer lbox_destroy(&alice)
	boxes := []^Lane_Box{&host, &alice}

	// 7 frames each way — 14 frames of round trip at 60 Hz, ~230ms, the RTT the
	// pathology was measured at. Nobody pings here, so the session clock stays
	// cold (rtt 0) and the anchor seeds from margin alone: the honest cold start.
	HOLD :: 7
	MARGIN :: 2
	w := wire_make(HOLD)
	defer wire_destroy(&w)

	ksess.session_host_start(&host.s, "hosty")
	ksess.session_client_start(&alice.s, 0xA11CE, "alice")
	ksess.session_client_join(&alice.s)
	for _ in 0 ..< 40 { // the join handshake, at 7 frames a hop
		wire_step(&w, boxes)
	}
	testing.expect_value(t, alice.s.me, knet.Player_Id(2))

	cfg := ksim.Lane_Config{hz = 60, snap_every = 2, margin = MARGIN}
	ksim.lane_init(&host.lane, &host.s, 1, cfg = cfg)
	ksim.lane_init(&alice.lane, &alice.s, 1, cfg = cfg)
	ksim.lane_set_sim(&host.lane, &host, lbox_sample, lbox_step)
	ksim.lane_set_sim(&alice.lane, &alice, lbox_sample, lbox_step)
	lbox_track(&host, 10, 1, &desc)
	lbox_track(&host, 20, 2, &desc)
	lbox_track(&alice, 10, 1, &desc)
	lbox_track(&alice, 20, 2, &desc)

	// The lead the controller is actually driving to. It closes the loop on
	// (input_ack − batch tick) → margin, and the ack is one one-way transit
	// stale by the time the client reads it, so the settled tick gap is
	// margin + HOLD. Derived, not tuned: change HOLD and it moves with it.
	TARGET :: MARGIN + HOLD

	DT :: 1.0 / 60.0
	FRAMES :: 480 // 8 seconds — the fine bend alone has shed ~9 ticks by here
	SETTLE :: 60 // the last second is the "stays there" window
	peak, settled_hi, settled_lo := i64(0), min(i64), max(i64)
	for f in 1 ..= FRAMES {
		host.ax = 1
		alice.ax = 1
		ksim.lane_frame(&host.lane, DT)
		ksim.lane_frame(&alice.lane, DT)
		ksim.lane_present(&alice.lane, DT)
		wire_step(&w, boxes)
		if !alice.lane.anchored {
			continue
		}
		lead := i64(alice.lane.ticker.tick) - i64(host.lane.ticker.tick)
		peak = max(peak, lead)
		if f > FRAMES - SETTLE {
			settled_hi = max(settled_hi, lead)
			settled_lo = min(settled_lo, lead)
		}
	}

	// (1) The harness genuinely built the hole. Without this the rest is
	// vacuous — exactly the failure mode of the to-quiet pump.
	testing.expectf(t, peak >= 2 * TARGET,
		"the delayed wire must reproduce the cold-start overshoot — peak lead %d against target %d", peak, TARGET)

	// (2) And the client CAME DOWN out of it, to target, and stayed. The
	// broken controller is still 33 ticks up at this frame, so a bound anywhere
	// near TARGET discriminates by a mile; these are the measured settled
	// values (a flat 10) with a tick of slack either side.
	testing.expectf(t, settled_hi <= TARGET + 3,
		"the deep surplus must be shed, not bled: settled lead %d (peak %d) against target %d", settled_hi, peak, TARGET)
	testing.expectf(t, settled_lo >= TARGET - 2,
		"and not overshot the other way: settled lead %d against target %d", settled_lo, TARGET)

	// (3) The deep rung HANDS BACK. Once inside LEAD_DEEP_TICKS the fine bend
	// owns the clock again — a rung that stayed engaged would leave the scale
	// parked at 0.75 and the whole session in slow motion.
	testing.expect(t, abs(alice.lane.ticker.scale - 1.0) <= ksim.SCALE_NUDGE_MAX + 1e-12,
		"a settled client is back on the fine bend, not stuck in the deep rung")
}
