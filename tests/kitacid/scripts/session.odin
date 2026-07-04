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

MSG_SPAWN :: u8(0) // [net_id][full fields]           host -> joining peer, reliable
MSG_STATE :: u8(1) // [count]([net_id][mask][dirty])  host -> all, per net tick
MSG_CMD :: u8(2) // command header + args             client -> host
MSG_RESULT :: u8(3) // confirm / reject+truth         host -> issuing client
MSG_PING :: u8(4) // [local_send]                     client -> host, ~1/s
MSG_PONG :: u8(5) // [echoed_send][remote_time]       host -> client
MSG_DONE :: u8(6) // client scenario finished         client -> host

Delayed_Packet :: struct {
	due:  f64,
	from: int,
	data: []u8,
}

AcidSession :: struct {
	owner:       gd.Node,
	orb:         ^Orb,
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

// latency_ms: the injected one-way receive delay. orb_node: the entity node
// (pre-created by the driver — dynamic spawn-by-type is the phase-1 session's).
@(gd_method)
acid_session_setup :: proc(self: ^AcidSession, latency_ms: gd.Int, orb_node: gd.Node) {
	self.latency = f64(latency_ms) / 1000.0
	self.min_rtt = 1.5 * self.latency // 2x is the theoretical floor; 1.5x absorbs jitter
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
	// Scenario setup: the authority spawns THE orb (allocates its net id) and
	// sets the initial state clients must see in their join snapshot.
	self.orb.net_id = knet.registry_spawn(&self.reg, self.orb, &orb_command_set)
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

// Host: one peer's join snapshot — [net_id][full fields] on the reliable
// channel, BEFORE any delta can name that id (the pinned ordering contract).
@(gd_method)
acid_session_send_spawn :: proc(self: ^AcidSession, peer: gd.Int) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_SPAWN)
	knet.write_net_id(&w, self.orb.net_id)
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
		// Join snapshot: mirror the wire id onto the local orb, apply the full
		// state, and commit shadows (migration-ready bookkeeping).
		id := knet.read_net_id(&r)
		knet.registry_insert(&self.reg, id, self.orb, &orb_command_set)
		self.orb.net_id = id
		knet.apply_full(&r, self.orb, &orb_net_desc)
		knet.registry_commit_shadows(&self.reg)
		gd.print_str(fmt.tprintf("ACID_SPAWN ok=%v id=%d hp=%d st=%d", !r.err, u32(id), self.orb.hp, self.orb.stamina))
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
	case MSG_DONE:
		self.dones += 1
	case:
		gd.print_str("ACID_ERR unknown msg")
	}
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
acid_session_get_hp :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(self.orb.hp)
}

@(gd_method)
acid_session_get_st :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(self.orb.stamina)
}
