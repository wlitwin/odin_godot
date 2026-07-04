//gd:extends Node
//gd:class AcidSession
package kitacid_scripts

// ----------------------------------------------------------------------------
// AcidSession — the SESSION NODE of the phase-0 acid test (tests/kitacid): the
// generic per-peer wiring that graduates into kit/session in phase 1. It owns
// the four toolkit pieces (Registry, Command_Ctx, Ticker, Clock_Sync), routes
// every wire message, and drives the per-net-tick walk. It knows the SCENARIO
// (spawn one Orb, print verification sentinels) but contains no gameplay — the
// Orb is fully defined in orb.odin.
//
// LATENCY INJECTION: every RECEIVED packet is buffered for `latency` seconds
// before it is routed (on every peer, so a round trip costs >= 2x latency).
// That makes the test's asserts meaningful: a prediction provably lands before
// any round trip could, and the clock sync measures a real RTT.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import knet "godot:kit/net"
import netgd "godot:kit/netgd"
import "core:fmt"
import "core:time"

MSG_SPAWN :: u8(0) // [net_id][owner][full fields]    host -> joining peer, reliable
MSG_STATE :: u8(1) // [count]([net_id][mask][dirty])  host -> all, per net tick
MSG_CMD :: u8(2) // command header + args             client -> host
MSG_RESULT :: u8(3) // confirm / reject+truth         host -> issuing client
MSG_PING :: u8(4) // [local_send]                     client -> host, ~1/s
MSG_PONG :: u8(5) // [echoed_send][remote_time]       host -> client
MSG_DONE :: u8(6) // client scenario finished         client -> host
MSG_STREAM :: u8(7) // owner-stream batch             owner -> all, UNRELIABLE, per net tick

// The orb is owned by the OWNER client (player 2) — the host and the observer
// are both just "everyone else" for its streamed fields: the same sampling
// code runs on both, which is the zero-role-branch claim for streams.
OWNER_PLAYER :: knet.Player_Id(2)

// Remote entities render this far in the timeline's past (~3 net ticks): there
// is almost always a bracketing sample pair, so motion stays smooth through
// jitter and drops.
INTERP_DELAY :: 0.15

Delayed_Packet :: struct {
	due:  f64,
	from: int,
	data: []u8,
}

AcidSession :: struct {
	owner:       gd.Node,
	orb:         ^Orb,
	me:          knet.Player_Id,
	reg:         knet.Registry,
	ctx:         knet.Command_Ctx,
	ticker:      knet.Ticker,
	clock:       knet.Clock_Sync,
	delayed:     [dynamic]Delayed_Packet,
	latency:     f64, // injected one-way receive delay, seconds
	min_rtt:     f64, // proof threshold: measured round trips must exceed this
	started:     bool,
	replicating: bool,
	got:         int, // client milestones: spawn + each command result
	cmds:        int, // host: commands answered
	dones:       int, // host: clients that reported scenario complete
	pings:       int, // client: pongs sampled into the clock estimate
	issues:      int,
	issue_at:    f64,

	// owner-stream scenario: the owner drives the orb; everyone else samples
	// and verifies the sampled motion is smooth (interpolated, not snapped).
	moving:       bool, // owner only
	moved_ticks:  int,
	last_x:       f32,
	samples:      int,
	incs:         int, // sampled frames where x increased
	big_steps:    int, // increases near a full tick step (snapping signature)
	mono_bad:     int, // sampled x ever DECREASED (must never happen)
	stream_state: int, // 0 = unverified, 1 = verified ok (driver polls)
}

// Absolute monotonic seconds (mach_absolute_time / CLOCK_MONOTONIC — one clock
// base shared by all three local processes, so the clock-sync offset must come
// out ~0 while the rtt must come out >= 2x the injected latency).
@(private = "file")
now_s :: proc "contextless" () -> f64 {
	return f64(time.tick_now()._nsec) / 1e9
}

acid_session_ready :: proc(self: ^AcidSession) {
	self.reg = knet.registry_make()
	self.ctx = knet.command_ctx_make()
	self.ticker = knet.ticker_make()
}

// latency_ms: the injected one-way receive delay. me: this peer's player id
// (host 1, owner 2, observer 3 — assigned identity is phase 1's job). orb_node:
// the entity node (pre-created by the driver — dynamic spawn-by-type is the
// phase-1 session's).
@(gd_method)
acid_session_setup :: proc(self: ^AcidSession, latency_ms: gd.Int, me: gd.Int, orb_node: gd.Node) {
	self.latency = f64(latency_ms) / 1000.0
	self.min_rtt = 1.5 * self.latency // 2x is the theoretical floor; 1.5x absorbs jitter
	self.me = knet.Player_Id(me)
	self.orb = rt.script_of(orb_node, Orb)
	if self.orb == nil {
		gd.print_str("ACID_ERR adopt failed")
	}
}

@(gd_method)
acid_session_start_host :: proc(self: ^AcidSession, port: gd.Int) {
	if !gd.host(self.owner, int(port)) {
		gd.print_str("HOST_FAIL")
		return
	}
	if err := netgd.listen_packets(self.owner, "on_packet"); err != .Ok {
		gd.print_str(fmt.tprintf("LISTEN_FAIL err=%v", err))
		return
	}
	self.ctx.is_authority = true
	// Scenario setup: the authority spawns THE orb (allocates its net id,
	// records the OWNER whose stream drives x/y) and sets the initial state
	// clients must see in their join snapshot.
	self.orb.net_id = knet.registry_spawn(&self.reg, self.orb, &orb_command_set, OWNER_PLAYER)
	self.orb.hp = 100
	self.orb.stamina = 10
	self.started = true
	gd.print_str(fmt.tprintf("ACID_HOST_OK id=%d", u32(self.orb.net_id)))
}

@(gd_method)
acid_session_start_client :: proc(self: ^AcidSession, port: gd.Int) {
	if !gd.join(self.owner, "127.0.0.1", int(port)) {
		gd.print_str("JOIN_FAIL")
		return
	}
	if err := netgd.listen_packets(self.owner, "on_packet"); err != .Ok {
		gd.print_str(fmt.tprintf("LISTEN_FAIL err=%v", err))
		return
	}
	self.ctx.send = send_command_bytes
	self.ctx.send_user = self
	self.started = true
	gd.print_str("JOIN_OK")
}

// The ctx's send hook: frame raw command bytes and ship them to the host.
@(private = "file")
send_command_bytes :: proc(user: rawptr, bytes: []u8) {
	self := cast(^AcidSession)user
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_CMD)
	append(&w.buf, ..bytes)
	if err := netgd.send_reliable(self.owner, 1, knet.writer_bytes(&w)); err != .Ok {
		gd.print_str(fmt.tprintf("ACID_ERR cmd send err=%v", err))
	}
}

// Host: one peer's join snapshot — [net_id][owner][full fields] on the
// reliable channel, BEFORE any delta can name that id (the pinned ordering
// contract). Ownership travels with the spawn so every peer routes the orb's
// stream the same way.
@(gd_method)
acid_session_send_spawn :: proc(self: ^AcidSession, peer: gd.Int) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_SPAWN)
	knet.write_net_id(&w, self.orb.net_id)
	knet.write_player_id(&w, OWNER_PLAYER)
	knet.write_full(&w, self.orb, &orb_net_desc)
	if err := netgd.send_reliable(self.owner, int(peer), knet.writer_bytes(&w)); err == .Ok {
		gd.print_str(fmt.tprintf("ACID_SPAWN_SENT peer=%d", int(peer)))
	} else {
		gd.print_str(fmt.tprintf("ACID_ERR spawn send err=%v", err))
	}
}

// Host: every peer has its join snapshot — commit shadows so the walk diffs
// against delivered state, then let the per-tick broadcast run.
@(gd_method)
acid_session_start_replicating :: proc(self: ^AcidSession) {
	knet.registry_commit_shadows(&self.reg)
	self.replicating = true
	gd.print_str("ACID_REPLICATING")
}

// Driven every frame by the test driver (a real game's session node would hook
// _process): drain due delayed packets, then fire net ticks.
@(gd_method)
acid_session_tick :: proc(self: ^AcidSession, dt: gd.Float) {
	if !self.started {return}
	now := now_s()
	// Injected latency: route packets whose delay elapsed. FIFO — a constant
	// delay preserves the reliable channel's ordering guarantees.
	for len(self.delayed) > 0 && self.delayed[0].due <= now {
		p := self.delayed[0]
		ordered_remove(&self.delayed, 0)
		route_packet(self, p.from, p.data)
		delete(p.data)
	}
	n := knet.ticker_advance(&self.ticker, f64(dt))
	for _ in 0 ..< n {
		net_tick(self)
	}
	// Remote-owned streams are sampled per FRAME (smoothness is the point):
	// render the owner's timeline INTERP_DELAY in the past. Owners are skipped
	// by the registry (they're authoritative), so this line is role-free.
	if knet.registry_sample_streams(&self.reg, now - INTERP_DELAY, self.me) > 0 {
		stream_stats(self)
	}
}

// Verify the SAMPLED motion is genuinely interpolated: monotone, mostly
// sub-tick steps (snapping to 20 Hz samples from a ~60 Hz frame loop would
// show full-tick jumps), and y tracking its exact linear relation to x.
@(private = "file")
stream_stats :: proc(self: ^AcidSession) {
	x := self.orb.x
	if self.samples > 0 {
		dx := x - self.last_x
		if dx < -0.0001 {
			self.mono_bad += 1
		} else if dx > 0.0001 {
			self.incs += 1
			if dx > 0.9 {
				self.big_steps += 1 // ~a full tick step; rare frame hitches only
			}
		}
	}
	self.last_x = x
	self.samples += 1
	if self.stream_state == 0 && x >= 30 {
		y_ok := abs(self.orb.y + 0.5 * self.orb.x) < 0.01
		ok := self.mono_bad == 0 && self.incs >= 25 && f64(self.big_steps) < 0.5 * f64(self.incs) && y_ok
		gd.print_str(
			fmt.tprintf(
				"ACID_STREAM ok=%v x=%.1f incs=%d big=%d mono_bad=%d y_ok=%v",
				ok, x, self.incs, self.big_steps, self.mono_bad, y_ok,
			),
		)
		self.stream_state = ok ? 1 : -1
	}
}

@(private = "file")
net_tick :: proc(self: ^AcidSession) {
	t := self.ticker.tick
	self.ctx.now_tick = t
	if self.replicating {
		// The per-net-tick walk: ONE batched delta message for every dirty
		// entity, broadcast to all peers (0). Idle ticks send nothing.
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, MSG_STATE)
		if knet.registry_write_deltas(&w, &self.reg) > 0 {
			if err := netgd.send_reliable(self.owner, 0, knet.writer_bytes(&w)); err != .Ok {
				gd.print_str(fmt.tprintf("ACID_ERR state send err=%v", err))
			}
		}
	}
	if !self.ctx.is_authority && self.got > 0 && t % 20 == 5 {
		// Clock ping, ~1/s once joined (got>0 means the spawn arrived, so the
		// connection is provably up).
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, MSG_PING)
		knet.ping_write(&w, now_s())
		_ = netgd.send_reliable(self.owner, 1, knet.writer_bytes(&w))
	}
	if self.moving {
		// THE OWNER'S AUTHOR SURFACE for streamed state: just write the fields.
		// The walk below ships them; everyone else's sampling renders them.
		self.moved_ticks += 1
		self.orb.x = f32(self.moved_ticks)
		self.orb.y = -0.5 * self.orb.x
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, MSG_STREAM)
		if knet.registry_write_streams(&w, &self.reg, self.me, now_s()) > 0 {
			// Broadcast on the UNRELIABLE stream channel: last-value semantics,
			// a drop is superseded by the next tick's snapshot.
			_ = netgd.send_stream(self.owner, 0, knet.writer_bytes(&w))
		}
	}
	// 60 ticks = 3s at 20 Hz — far beyond the injected RTT, so any expiry means
	// a result was genuinely lost. The suite asserts this NEVER fires.
	if n := knet.registry_expire_pending(&self.reg, &self.ctx, 60); n > 0 {
		gd.print_str(fmt.tprintf("ACID_EXPIRED n=%d", n))
	}
}

// Every toolkit packet lands here (netgd.listen_packets) and is BUFFERED — the
// injected latency — until tick() routes it.
@(gd_method)
acid_session_on_packet :: proc(self: ^AcidSession, id: gd.Int, packet: gd.Packed_Byte_Array) {
	packet := packet
	view := netgd.pba_view(&packet)
	data := make([]u8, len(view))
	copy(data, view)
	append(&self.delayed, Delayed_Packet{due = now_s() + self.latency, from = int(id), data = data})
}

@(private = "file")
route_packet :: proc(self: ^AcidSession, from: int, data: []u8) {
	r := knet.reader_make(data)
	switch knet.read_u8(&r) {
	case MSG_SPAWN:
		// Join snapshot: mirror the wire id + ownership onto the local orb,
		// apply the full state, and commit shadows (migration-ready bookkeeping).
		id := knet.read_net_id(&r)
		who := knet.read_player_id(&r)
		knet.registry_insert(&self.reg, id, self.orb, &orb_command_set, who)
		self.orb.net_id = id
		knet.apply_full(&r, self.orb, &orb_net_desc)
		knet.registry_commit_shadows(&self.reg)
		gd.print_str(fmt.tprintf("ACID_SPAWN ok=%v id=%d owner=%d hp=%d st=%d", !r.err, u32(id), u64(who), self.orb.hp, self.orb.stamina))
		if !r.err {self.got += 1}
	case MSG_STATE:
		// The observer's whole job: apply what the authority says. No role code.
		// Passing ctx reconciles in-flight predictions (replayed on top) — the
		// owner's optimistic values survive deltas the host sent before it had
		// executed the command.
		n := knet.registry_apply_deltas(&r, &self.reg, &self.ctx)
		gd.print_str(fmt.tprintf("ACID_DELTA ok=%v n=%d hp=%d st=%d", !r.err, n, self.orb.hp, self.orb.stamina))
	case MSG_CMD:
		// Host: dedup -> resolve -> execute -> result, all via the registry.
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, MSG_RESULT)
		responded, ok := knet.registry_host_command(&self.reg, &self.ctx, u64(from), &r, &w)
		if !responded {return}
		if err := netgd.send_reliable(self.owner, from, knet.writer_bytes(&w)); err != .Ok {
			gd.print_str(fmt.tprintf("ACID_ERR result send err=%v", err))
		}
		self.cmds += 1
		gd.print_str(fmt.tprintf("ACID_EXEC ok=%v hp=%d st=%d", ok, self.orb.hp, self.orb.stamina))
	case MSG_RESULT:
		res := knet.registry_client_result(&self.reg, &self.ctx, &r)
		dt := now_s() - self.issue_at
		lat_ok := dt >= self.min_rtt // the result CANNOT beat the injected RTT
		if res.ok {
			gd.print_str(
				fmt.tprintf(
					"ACID_CONFIRM n=%d ok=true hp=%d st=%d pending=%d lat_ok=%v dt_ms=%d",
					self.issues, self.orb.hp, self.orb.stamina,
					knet.pending_count(&self.ctx.pending), lat_ok, int(dt * 1000),
				),
			)
		} else {
			gd.print_str(
				fmt.tprintf(
					"ACID_REJECT n=%d ok=%v hp=%d st=%d pending=%d lat_ok=%v dt_ms=%d",
					self.issues, !r.err, self.orb.hp, self.orb.stamina,
					knet.pending_count(&self.ctx.pending), lat_ok, int(dt * 1000),
				),
			)
		}
		self.got += 1
	case MSG_PING:
		w := knet.writer_make()
		defer knet.writer_destroy(&w)
		knet.write_u8(&w, MSG_PONG)
		knet.ping_answer(&r, &w, now_s())
		_ = netgd.send_reliable(self.owner, from, knet.writer_bytes(&w))
	case MSG_PONG:
		if knet.pong_apply(&r, &self.clock, now_s()) {
			self.pings += 1
			if self.pings == 3 {
				// rtt must reflect the injected latency; offset must be ~0 (the
				// processes share one monotonic clock base).
				ok := self.clock.rtt >= self.min_rtt && abs(self.clock.offset) < 0.1
				gd.print_str(
					fmt.tprintf(
						"ACID_CLOCK ok=%v rtt_ms=%d off_ms=%d",
						ok, int(self.clock.rtt * 1000), int(self.clock.offset * 1000),
					),
				)
			}
		}
	case MSG_STREAM:
		// The batch carries the OWNER's clock stamp; this session uses the
		// simpler ARRIVAL timeline (constant injected latency preserves shape —
		// a full session maps the sender stamp through a per-peer Clock_Sync).
		_ = knet.registry_stream_time(&r)
		_ = knet.registry_apply_streams(&r, &self.reg, self.me, now_s())
	case MSG_DONE:
		self.dones += 1
	case:
		gd.print_str("ACID_ERR unknown msg")
	}
}

// Owner: start driving the orb (a deterministic ramp the remotes verify).
@(gd_method)
acid_session_start_moving :: proc(self: ^AcidSession) {
	self.moving = true
	gd.print_str("ACID_MOVING")
}

// Owner: THE author-surface call — identical on every peer. On the host it
// would execute directly; here (a client) it predicts + sends.
@(gd_method)
acid_session_issue_strike :: proc(self: ^AcidSession, cost: gd.Int) {
	self.issues += 1
	self.issue_at = now_s()
	applied := orb_strike_cmd(&self.ctx, self.orb, i32(cost))
	gd.print_str(
		fmt.tprintf(
			"ACID_ISSUE n=%d predicted=%v hp=%d st=%d pending=%d",
			self.issues, applied, self.orb.hp, self.orb.stamina,
			knet.pending_count(&self.ctx.pending),
		),
	)
}

// Client: tell the host this peer's scenario is complete (so the server only
// exits once every client has everything it was owed).
@(gd_method)
acid_session_send_done :: proc(self: ^AcidSession) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_DONE)
	_ = netgd.send_reliable(self.owner, 1, knet.writer_bytes(&w))
}

// ---- driver polls ----

@(gd_method)
acid_session_get_got :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(self.got)
}

@(gd_method)
acid_session_get_cmds :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(self.cmds)
}

@(gd_method)
acid_session_get_dones :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(self.dones)
}

@(gd_method)
acid_session_get_pings :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(self.pings)
}

@(gd_method)
acid_session_get_stream :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(self.stream_state)
}

@(gd_method)
acid_session_get_hp :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(self.orb.hp)
}

@(gd_method)
acid_session_get_st :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(self.orb.stamina)
}
