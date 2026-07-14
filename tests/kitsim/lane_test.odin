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

	ksim.predict_error_decay(err, &desc, 0.5)
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
