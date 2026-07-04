//gd:extends Node
//gd:class AcidSession
package kitacid_scripts

// ----------------------------------------------------------------------------
// AcidSession — the acid test's session node, now a THIN DELEGATE around
// kit/session (phase 1). Everything the pre-promotion version hand-rolled —
// registry, command ctx, ticker, state/command/stream/ping routing, clock —
// lives in ksess.Session; what remains here is exactly what a real game
// writes:
//
//   * transport glue: gd.host/gd.join, netgd.listen_packets, and ONE send
//     proc that prefixes the game's session kind byte and picks the channel.
//   * gameplay: the Orb, driving it when we own it, reacting to session
//     events (this test turns them into sentinels; a game turns them into
//     effects/UI).
//   * game-level messages that predate their toolkit brick: MSG_SPAWN
//     (spawn-by-type factories are the next brick) and MSG_DONE (test
//     sequencing).
//
// The injected-latency queue also stays here: it buffers RECEIVED packets
// before routing, which is a test-driver concern, not a session one.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import netgd "godot:kit/netgd"
import "core:fmt"
import "core:time"

MSG_SESSION :: u8(0) // ALL kit/session traffic rides this one game byte
MSG_SPAWN :: u8(1) // [net_id][owner][full fields]  host -> joined peer
MSG_DONE :: u8(2) // client scenario finished       client -> host

TOKEN_OWNER :: u64(0xACED_0001)
TOKEN_OBSERVER :: u64(0xACED_0002)

Delayed_Packet :: struct {
	due:  f64,
	from: int,
	data: []u8,
}

AcidSession :: struct {
	owner:   gd.Node,
	orb:     ^Orb,
	ses:     ksess.Session,
	delayed: [dynamic]Delayed_Packet,
	latency: f64, // injected one-way receive delay, seconds
	min_rtt: f64, // proof threshold: measured round trips must exceed this
	started: bool,

	// scenario bookkeeping (drivers poll; sentinels grep)
	got:            int, // client milestones: spawn + each command result
	cmds:           int, // host: commands answered
	dones:          int, // host: clients that reported scenario complete
	issues:         int,
	issue_at:       f64,
	clock_reported: bool,

	// owner-stream scenario
	moving:       bool, // owner only
	move_start:   f64,
	last_x:       f32,
	samples:      int,
	incs:         int,
	big_steps:    int,
	mono_bad:     int,
	stream_state: int, // 0 unverified, 1 ok, -1 failed (driver polls)
}

@(private = "file")
now_s :: proc "contextless" () -> f64 {
	return f64(time.tick_now()._nsec) / 1e9
}

// THE session glue a game writes: prefix our kind byte, pick the channel.
@(private = "file")
session_send :: proc(user: rawptr, to_peer: int, bytes: []u8, channel: ksess.Channel) {
	self := cast(^AcidSession)user
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_SESSION)
	append(&w.buf, ..bytes)
	err: gd.Error
	if channel == .Stream {
		err = netgd.send_stream(self.owner, to_peer, knet.writer_bytes(&w))
	} else {
		err = netgd.send_reliable(self.owner, to_peer, knet.writer_bytes(&w))
	}
	if err != .Ok {
		gd.print_str(fmt.tprintf("ACID_ERR session send err=%v", err))
	}
}

@(gd_method)
acid_session_setup :: proc(self: ^AcidSession, latency_ms: gd.Int, orb_node: gd.Node) {
	self.latency = f64(latency_ms) / 1000.0
	self.min_rtt = 1.5 * self.latency
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
	self.ses.send = session_send
	self.ses.send_user = self
	ksess.session_host_start(&self.ses, "host")
	self.started = true
	gd.print_str("ACID_HOST_OK")
}

@(private = "file")
start_client :: proc(self: ^AcidSession, port: int, token: u64, name: string) {
	if !gd.join(self.owner, "127.0.0.1", port) {
		gd.print_str("JOIN_FAIL")
		return
	}
	if err := netgd.listen_packets(self.owner, "on_packet"); err != .Ok {
		gd.print_str(fmt.tprintf("LISTEN_FAIL err=%v", err))
		return
	}
	self.ses.send = session_send
	self.ses.send_user = self
	ksess.session_client_start(&self.ses, token, name)
	self.started = true
	gd.print_str("JOIN_OK")
}

@(gd_method)
acid_session_start_owner :: proc(self: ^AcidSession, port: gd.Int) {
	start_client(self, int(port), TOKEN_OWNER, "owner")
}

@(gd_method)
acid_session_start_observer :: proc(self: ^AcidSession, port: gd.Int) {
	start_client(self, int(port), TOKEN_OBSERVER, "observer")
}

// Client: the transport is up — ask the host to seat us.
@(gd_method)
acid_session_join :: proc(self: ^AcidSession) {
	ksess.session_client_join(&self.ses)
}

// Host: both players are seated — announce the world to each of them (the
// orb, owned by the player NAMED "owner"), then start replicating. Spawn and
// deltas share the reliable channel, so ids are known before any batch.
@(gd_method)
acid_session_announce_world :: proc(self: ^AcidSession) {
	owner_pid := knet.PLAYER_ID_INVALID
	for _, p in self.ses.players {
		if p.name == "owner" {
			owner_pid = p.id
		}
	}
	if owner_pid == knet.PLAYER_ID_INVALID {
		gd.print_str("ACID_ERR no seated player named owner")
		return
	}
	self.orb.net_id = ksess.session_spawn(&self.ses, self.orb, &orb_command_set, owner_pid)
	self.orb.hp = 100
	self.orb.stamina = 10

	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_SPAWN)
	knet.write_net_id(&w, self.orb.net_id)
	knet.write_player_id(&w, owner_pid)
	knet.write_full(&w, self.orb, &orb_net_desc)
	sent := 0
	for _, p in self.ses.players {
		if !p.connected || p.id == self.ses.me {
			continue
		}
		if err := netgd.send_reliable(self.owner, p.peer, knet.writer_bytes(&w)); err == .Ok {
			sent += 1
		}
	}
	ksess.session_start_replicating(&self.ses)
	gd.print_str(fmt.tprintf("ACID_WORLD id=%d spawns=%d", u32(self.orb.net_id), sent))
}

// Driven every frame by the driver: drain due delayed packets, run the
// session (its net ticks + stream sampling), drive owned motion, translate
// events into sentinels.
@(gd_method)
acid_session_tick :: proc(self: ^AcidSession, dt: gd.Float) {
	if !self.started {return}
	now := now_s()
	for len(self.delayed) > 0 && self.delayed[0].due <= now {
		p := self.delayed[0]
		ordered_remove(&self.delayed, 0)
		route_packet(self, p.from, p.data)
		delete(p.data)
	}
	if self.moving {
		// The owner's ENTIRE author surface for streamed state: write fields.
		self.orb.x = f32((now - self.move_start) * 20.0)
		self.orb.y = -0.5 * self.orb.x
	}
	_, sampled := ksess.session_tick(&self.ses, f64(dt), now)
	if sampled > 0 {
		stream_stats(self)
	}
	drain_events(self, now)
	if !self.clock_reported && self.ses.pongs >= 3 {
		self.clock_reported = true
		c := ksess.session_clock(&self.ses, ksess.HOST_PEER)
		ok := c.rtt >= self.min_rtt && abs(c.offset) < 0.1
		gd.print_str(
			fmt.tprintf("ACID_CLOCK ok=%v rtt_ms=%d off_ms=%d", ok, int(c.rtt * 1000), int(c.offset * 1000)),
		)
	}
}

@(private = "file")
drain_events :: proc(self: ^AcidSession, now: f64) {
	for {
		ev, ok := ksess.session_poll(&self.ses)
		if !ok {break}
		switch e in ev {
		case ksess.Ev_Welcomed:
			gd.print_str(fmt.tprintf("ACID_SEATED me=%d", u64(e.me)))
		case ksess.Ev_Player_Joined:
			p, _ := ksess.session_player(&self.ses, e.id)
			gd.print_str(fmt.tprintf("ACID_PLAYER name=%s rejoin=%v", p.name, e.rejoin))
		case ksess.Ev_Player_Left:
			gd.print_str(fmt.tprintf("ACID_PLAYER_LEFT id=%d", u64(e.id)))
		case ksess.Ev_Host_Left:
			gd.print_str("ACID_HOST_LEFT")
		case ksess.Ev_State_Applied:
			gd.print_str(
				fmt.tprintf("ACID_DELTA ok=true n=%d hp=%d st=%d", e.entities, self.orb.hp, self.orb.stamina),
			)
		case ksess.Ev_Command_Executed:
			self.cmds += 1
			gd.print_str(fmt.tprintf("ACID_EXEC ok=%v hp=%d st=%d", e.ok, self.orb.hp, self.orb.stamina))
		case ksess.Ev_Command_Confirmed:
			self.got += 1
			dt_ms := int((now - self.issue_at) * 1000)
			gd.print_str(
				fmt.tprintf(
					"ACID_CONFIRM n=%d ok=true hp=%d st=%d pending=%d lat_ok=%v dt_ms=%d",
					self.issues, self.orb.hp, self.orb.stamina,
					knet.pending_count(&self.ses.ctx.pending),
					now - self.issue_at >= self.min_rtt, dt_ms,
				),
			)
		case ksess.Ev_Command_Rejected:
			if e.seq == 0 {
				gd.print_str("ACID_EXPIRED") // pending timeout — must never fire here
				continue
			}
			self.got += 1
			dt_ms := int((now - self.issue_at) * 1000)
			gd.print_str(
				fmt.tprintf(
					"ACID_REJECT n=%d ok=true hp=%d st=%d pending=%d lat_ok=%v dt_ms=%d",
					self.issues, self.orb.hp, self.orb.stamina,
					knet.pending_count(&self.ses.ctx.pending),
					now - self.issue_at >= self.min_rtt, dt_ms,
				),
			)
		}
	}
}

// Verify the SAMPLED motion is genuinely interpolated (unchanged from the
// pre-promotion test: monotone, mostly sub-tick steps, y on its exact line).
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
				self.big_steps += 1
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

// Every received packet is BUFFERED (injected latency), then routed.
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
	case MSG_SESSION:
		ksess.session_handle_packet(&self.ses, from, &r)
	case MSG_SPAWN:
		id := knet.read_net_id(&r)
		who := knet.read_player_id(&r)
		ksess.session_bind(&self.ses, id, self.orb, &orb_command_set, who)
		self.orb.net_id = id
		knet.apply_full(&r, self.orb, &orb_net_desc)
		knet.registry_commit_shadows(&self.ses.reg)
		gd.print_str(
			fmt.tprintf(
				"ACID_SPAWN ok=%v id=%d mine=%v hp=%d st=%d",
				!r.err, u32(id), who == self.ses.me, self.orb.hp, self.orb.stamina,
			),
		)
		if !r.err {self.got += 1}
	case MSG_DONE:
		self.dones += 1
	case:
		gd.print_str("ACID_ERR unknown msg")
	}
}

// Owner: THE author-surface call — identical on every peer.
@(gd_method)
acid_session_issue_strike :: proc(self: ^AcidSession, cost: gd.Int) {
	self.issues += 1
	self.issue_at = now_s()
	applied := orb_strike_cmd(&self.ses.ctx, self.orb, i32(cost))
	gd.print_str(
		fmt.tprintf(
			"ACID_ISSUE n=%d predicted=%v hp=%d st=%d pending=%d",
			self.issues, applied, self.orb.hp, self.orb.stamina,
			knet.pending_count(&self.ses.ctx.pending),
		),
	)
}

@(gd_method)
acid_session_start_moving :: proc(self: ^AcidSession) {
	self.moving = true
	self.move_start = now_s()
	gd.print_str("ACID_MOVING")
}

@(gd_method)
acid_session_send_done :: proc(self: ^AcidSession) {
	w := knet.writer_make()
	defer knet.writer_destroy(&w)
	knet.write_u8(&w, MSG_DONE)
	_ = netgd.send_reliable(self.owner, 1, knet.writer_bytes(&w))
}

// ---- driver polls ----

@(gd_method)
acid_session_get_players :: proc(self: ^AcidSession) -> gd.Int {
	return gd.Int(ksess.session_count(&self.ses, connected_only = true))
}

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
	return gd.Int(self.ses.pongs)
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
