//gd:extends Node2D
//gd:class ReplayDuel
package replay_duel

import "core:fmt"
import "core:reflect"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import rb "godot:replay/p2p"
import tr "godot:replay/transport"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import game "../shared/duel"

ReplayDuel :: struct {
	owner: gd.Node2d,
	status: gd.Label `gd:"onready=Status"`,
	room_label: gd.Label `gd:"onready=Room"`,
	online: rgd.P2P_Party,
	direct: rgd.P2P_Direct,
	online_storage: rawptr,
	online_tls: gd.Tls_Options,
	online_enabled, online_launched: bool,
	rtc, watch_rtc: rgd.Rtc,
 admission:rgd.Rtc_P2P_Auth,authenticated:bool,
	room_reported, watch_room_reported: bool,
	player_paused, player_resumed, player_stall_reported: bool,
	player_pause_start, player_pause_until, player_stall_head: u64,
	failed: bool,
	live_rejoin,rejoin_wait_reported:bool,
	rejoin_physical:tr.Peer_Id,
	rejoin_count:u32,
 rejoin_generation:u64,
	rejoin_storage:rawptr,
	native_rejoining:bool,
	native_retry_at:u64,
	native_rejoin_attempts:u32,
	enet: rgd.Enet,
	delay: tr.Delay,
	identities: tr.Remap,
	wire: tr.Transport,
	peer: rb.Runner(game.World, game.Input, game.Event, 2),
	journal: v.Journal(game.Event),
	clock: r.Clock,
	buttons: r.Buttons,
	fighters, bullets: rgd.Nodes2,
	listening, ready, test, reported: bool,
	started, done_at, test_until, neutral_until: u64,
	shots_begun, shots_canceled: u32,
	baseline_shots: u32,
	saving, resuming, saved, save_requested: bool,
	archive_path: string,
	spectator, watch_enabled, watch_join_reported, watch_paused, watch_resumed, watch_source_failed: bool,
	watch_pause_until, watch_reset: u64,
	watch_enet: rgd.Enet,
	watch_delay: tr.Delay,
	watch_wire: tr.Transport,
	watch: rb.Watch(game.World, game.Input, game.Event, 2),
	watch_source: rb.Watch_Source(game.World, game.Input, game.Event, 2),
	watch_failover,watch_rebound,watch_retired:bool,
}

replay_duel_ready :: proc(self: ^ReplayDuel) {
	self.listening = duel_param("RDP_ROLE", "listen") == "listen"
	self.spectator = duel_param("RDP_ROLE", "listen") == "watch"
	self.watch_enabled = duel_int("RDP_WATCH", 0) == 1
	self.watch_failover=duel_int("RDP_WATCH_FAILOVER",0)==1
	when gd.IS_WEB {if self.watch_failover {duel_fail(self,"native spectator failover fixture required");return}}
	self.test = duel_int("RDP_TEST", 0) == 1
 self.live_rejoin=duel_int("RDP_LIVE_REJOIN",0)==1
	until := duel_int("RDP_UNTIL", 600)
	if until < 1 || until > 10000 {duel_fail(self, "test duration"); return}
	self.test_until = u64(until)
	self.neutral_until = u64(max(duel_int("RDP_NEUTRAL", 0), duel_int("RDP_DELAY", 2)))
	stage := duel_param("RDP_STAGE", "")
	self.saving, self.resuming = stage == "save", stage == "resume"
	self.archive_path = strings.clone(duel_param("RDP_ARCHIVE", ""))
	self.started = gd.time_get_ticks_msec(gd.singleton_time())
	if duel_online_ready(self) {return}
	duel_start(self)
}

duel_start :: proc(self: ^ReplayDuel) {
	port := duel_int("RDP_PORT", 49520)
	if port < 1 || port > (self.watch_failover ? 65533 : 65534) {duel_fail(self, "port"); return}
	base: tr.Transport
	when gd.IS_WEB {
		url, room := duel_param("RDP_URL", "ws://127.0.0.1:9080/rtc"), duel_param("RDP_ROOM", "")
		config,valid:=duel_admission_open(self,url)
  if !valid {duel_fail(self,"admission credential");return}
  if !self.authenticated {config={url=url,room=room,host=self.listening}}
  config.ice_json=duel_param("RDP_ICE", "")
  if !rgd.rtc_open(&self.rtc, config) {duel_fail(self,"WebRTC open");return}
		base=rgd.rtc_transport(&self.rtc)
	} else {
		if self.online_enabled {
			options,valid:=duel_direct_options()
			if !valid || !rgd.p2p_direct_open(&self.direct,&self.online,options) {duel_fail(self,"native authenticated transport");return}
			base=rgd.p2p_direct_transport(&self.direct)
		} else {
		connected := self.listening ? rgd.enet_host(&self.enet, u16(port), 1, bind_ip = "127.0.0.1") : rgd.enet_join(&self.enet, "127.0.0.1", u16(self.spectator ? port + 1 : port))
		if !connected {duel_fail(self, "transport"); return}
		base = rgd.enet_transport(&self.enet)
		}
	}
	if !tr.delay_init(&self.delay, base, u32(duel_int("RDP_LATENCY", 0))) {tr.close(&base); duel_fail(self, "delay"); return}
	tr.delay_faults(&self.delay, u32(duel_int("RDP_JITTER", 0)), u32(duel_int("RDP_LOSS", 0)), u32(duel_int("RDP_DUPLICATE", 0)), 42)
	self.wire = tr.delay_transport(&self.delay)
	if !self.spectator && self.watch_enabled && (self.listening || self.watch_failover) {
		watch_base: tr.Transport
		when gd.IS_WEB {
			if !rgd.rtc_open(&self.watch_rtc, {url=duel_param("RDP_URL", "ws://127.0.0.1:9080/rtc"),host=true,ice_json=duel_param("RDP_ICE", "")}) {duel_fail(self,"spectator WebRTC open");return}
			watch_base=rgd.rtc_transport(&self.watch_rtc)
		} else {
			if !rgd.enet_host(&self.watch_enet, u16(port + (self.listening ? 1 : 2)), 1, bind_ip = "127.0.0.1") {duel_fail(self, "spectator transport"); return}
			watch_base=rgd.enet_transport(&self.watch_enet)
		}
		if !tr.delay_init(&self.watch_delay, watch_base, u32(duel_int("RDP_LATENCY", 0))) {tr.close(&watch_base);duel_fail(self, "spectator delay"); return}
		tr.delay_faults(&self.watch_delay, u32(duel_int("RDP_JITTER", 0)), u32(duel_int("RDP_LOSS", 0)), u32(duel_int("RDP_DUPLICATE", 0)), 77)
		self.watch_wire = tr.delay_transport(&self.watch_delay)
	}
	self.ready = rgd.nodes_load(&self.fighters, self.owner, "res://views/fighter.tscn", 2) && rgd.nodes_load(&self.bullets, self.owner, "res://views/bullet.tscn", 16)
	if !gd.has_action("rdp_left") {
		rgd.bind_key("rdp_left", .A); rgd.bind_key("rdp_right", .D)
		rgd.bind_key("rdp_jump", .Space); rgd.bind_key("rdp_fire", .J)
	}
	r.clock_init(&self.clock, 60)
	if self.listening {gd.print_str("REPLAY_DUEL_LISTENING")}
}

replay_duel_process :: proc(self: ^ReplayDuel, dt: f64) {
	if self.online_enabled && !self.failed {duel_online_frame(self)}
	when !gd.IS_WEB {if self.online_launched && self.direct.error!=.None {duel_fail(self,fmt.tprintf("native connection %v",self.direct.error));return}}
	if !self.ready || self.failed {return}
	now := gd.time_get_ticks_msec(gd.singleton_time())
	if self.test && now - self.started > (gd.IS_WEB ? u64(100000) : self.watch_enabled ? u64(50000) : u64(35000)) {duel_fail(self, "timeout"); return}
	tr.delay_time(&self.delay, now)
	if self.spectator {duel_watch_process(self, now); duel_browser_rooms(self); return}
	if !self.peer.ready {
		tr.poll(&self.wire)
		duel_browser_rooms(self)
		remotes:[16]tr.Peer_Id
		if tr.status(&self.wire) != .Connected || duel_remotes(self,false,remotes[:]) != 1 {return}
		if self.resuming && !duel_archive_ready(self) {return}
		if !duel_admitted_remote(self,remotes[0]) {return}
		physical := self.online_enabled && !gd.IS_WEB ? tr.Peer_Id(2) : self.listening ? remotes[0] : gd.IS_WEB ? self.rtc.id : rgd.enet_id(&self.enet)
		self.rejoin_physical=remotes[0]
  self.rejoin_generation=tr.peer_generation(&self.delay.base,remotes[0])
		bindings := [2]tr.Peer_Mapping{{1, 1}, {2, physical}}
		if !tr.remap_init(&self.identities, self.wire, bindings[:]) {duel_fail(self, "identity bindings"); return}
		self.wire = tr.remap_transport(&self.identities)
		roster := [2]tr.Peer_Id{1, 2}
		cfg := duel_config(self)
		if self.resuming {
			bytes, read_error := duel_archive_read(self)
			defer delete(bytes)
			archive: rb.Archive(game.World, game.Input, game.Event, 2)
			defer rb.archive_destroy(&archive)
			if read_error != .None || rb.archive_decode(&archive, bytes, game.model(), cfg.content) != .None || archive.settings.session != cfg.session || archive.settings.epoch != cfg.epoch {
				duel_fail(self, "archive read"); return
			}
			if err := rb.restore(&self.peer, &archive, game.model(), roster, self.listening ? 0 : 1, self.wire); err != .None {duel_fail(self, fmt.tprintf("restore %v", err)); return}
			baseline, _ := r.read(&self.peer.timeline, self.peer.timeline.confirmed)
			self.baseline_shots = baseline.state.shots
			gd.print_str(fmt.tprintf("RDP_RESTORED seat=%d head=%d confirmed=%d sampled=%d", self.peer.local, self.peer.timeline.head, self.peer.timeline.confirmed, self.peer.sampled))
		} else {
			if err := rb.init(&self.peer, r.Frame(game.World){state = game.initial(42)}, game.model(), roster, self.listening ? 0 : 1, self.wire, cfg); err != .None {duel_fail(self, fmt.tprintf("init %v", err)); return}
		}
		self.rejoin_storage=raw_data(self.peer.timeline.records)
		self.neutral_until = max(self.neutral_until, u64(self.peer.cfg.delay))
		if duel_int("RDP_PROFILE", 0) == 1 {
			rb.profile_set(&self.peer, r.Profile_Clock{read = proc(user: rawptr) -> (u64, bool) {return gd.time_get_ticks_usec(gd.singleton_time()), true}})
		}
		v.journal_init(&self.journal, baseline = self.peer.timeline.confirmed, cfg = {128, 32, 8192})
	}
	duel_live_rejoin(self,now)
	if self.failed {return}
	duel_player_blackout(self,now)
	if self.failed {return}
	if err := rb.pump(&self.peer, now); err != .None {
  if self.live_rejoin && self.peer.phase==.Disconnected && err==.Transport {
   if !self.rejoin_wait_reported {self.rejoin_wait_reported=true;gd.print_str(fmt.tprintf("RDP_REJOIN_WAIT head=%d confirmed=%d sampled=%d",self.peer.timeline.head,self.peer.timeline.confirmed,self.peer.sampled))}
   gd.set_string(self.status,"text","Waiting for the peer to rejoin…");r.clock_init(&self.clock,60);return
  }
  duel_fail(self,fmt.tprintf("pump %v",err));return
 }
	if self.peer.phase != .Running {r.clock_init(&self.clock, 60); return}
	held := u64(0)
	if gd.is_action_pressed("rdp_jump") {held |= 1}; if gd.is_action_pressed("rdp_fire") {held |= 2}
	r.buttons_set(&self.buttons, held)
	if gd.is_action_just_pressed("rdp_jump") {self.buttons.pressed |= 1}
	if gd.is_action_just_pressed("rdp_fire") {self.buttons.pressed |= 2}
	steps, valid := r.clock_add(&self.clock, dt)
	if !valid {duel_fail(self, "clock"); return}
	for _ in 0 ..< steps {
		if self.saved || self.save_requested || (self.test && self.peer.timeline.head >= (self.saving ? u64(240) : self.test_until)) {r.clock_consume(&self.clock); continue}
		input: game.Input
		if self.test {
			target := self.peer.timeline.head + u64(self.peer.cfg.delay) + 1
			if target > self.neutral_until {input = game.corpus_input(target, int(self.peer.local))}
		} else {
			if gd.is_action_pressed("rdp_left") {input.axis -= 1}; if gd.is_action_pressed("rdp_right") {input.axis += 1}
			input.jump, input.fire = self.buttons.pressed & 1 != 0, (self.buttons.held | self.buttons.pressed) & 2 != 0
		}
		result := rb.advance(&self.peer, input)
		if result.captured {r.buttons_consume(&self.buttons)}
		if result.error == .Waiting || result.error == .Capacity {break}
		if result.error != .None {duel_fail(self, fmt.tprintf("advance %v", result.error)); return}
		r.clock_consume(&self.clock)
	}
	for tick := self.journal.confirmed + 1; tick <= self.peer.timeline.head; tick += 1 {
		events: [32]r.Occurrence(game.Event)
		n, err := r.copy_events(&self.peer.timeline, tick, events[:])
		if err != .None || v.sync_tick(&self.journal, tick, events[:n]) != .None {duel_fail(self, "event history"); return}
	}
	if v.advance_time(&self.journal, self.peer.timeline.confirmed, self.peer.timeline.confirmed) != .None {duel_fail(self, "event time"); return}
	changes: [256]v.Change(game.Event)
	for {
		n := v.drain(&self.journal, changes[:]); if n == 0 {break}
		for change in changes[:n] {if change.occurrence.value.kind == .Shot {
			if change.kind == .Begin {self.shots_begun += 1}; if change.kind == .Cancel {self.shots_canceled += 1}
		}}
	}
	frame, _ := r.current(&self.peer.timeline)
	paint(self, frame.state)
	if self.watch_enabled && (self.listening || self.watch_failover) {duel_watch_source(self, now)}
	duel_browser_rooms(self)
	if !self.saved && (self.save_requested || (self.saving && frame.tick == 240)) {
		archive: rb.Archive(game.World, game.Input, game.Event, 2)
		defer rb.archive_destroy(&archive)
		if rb.archive_capture(&self.peer, &archive) != .None {duel_fail(self, "capture"); return}
		bytes, err := rb.archive_encode(&archive, game.model()); defer delete(bytes)
		if err != .None || duel_archive_write(self, bytes) != .None {duel_fail(self, "archive write"); return}
		self.saved, self.save_requested = true, false
		gd.print_str(fmt.tprintf("RDP_SAVED seat=%d head=%d confirmed=%d sampled=%d bytes=%d", self.peer.local, frame.tick, self.peer.timeline.confirmed, self.peer.sampled, len(bytes)))
	}
	if self.saved {gd.set_string(self.status, "text", "Paused. Keep your downloaded participant file before closing.")}
	if self.test && self.peer.timeline.confirmed == self.test_until && self.peer.remote_hash[1 - self.peer.local].tick == self.test_until {
		if !self.reported {
			self.reported = true
			if !reference_equal(frame.state, self.test_until, self.neutral_until) {duel_fail(self, "reference state"); return}
			if self.baseline_shots + self.shots_begun - self.shots_canceled != frame.state.shots {duel_fail(self, "shot reconciliation"); return}
			gd.print_str(fmt.tprintf("RDP_RESULT seat=%d tick=%d hash=%d shots=%d hits=%d kills=%d,%d rollbacks=%d replayed=%d stalls=%d rx=%d tx=%d dropped=%d duplicated=%d",
			                        self.peer.local, frame.tick, self.peer.chain, frame.state.shots, frame.state.hits, frame.state.kills[0], frame.state.kills[1],
			                        self.peer.stats.rollbacks, self.peer.stats.replayed_ticks, self.peer.stats.stalls, self.peer.stats.rx_bytes, self.peer.stats.tx_bytes,
			                        self.delay.dropped, self.delay.duplicated))
			gd.print_str("REPLAY_DUEL_PEER_OK")
			duel_profile_report(self, now)
			self.done_at = now + (self.watch_enabled ? u64(3000) : u64(750))
		}
	}
	if self.done_at != 0 && now >= self.done_at {
		if self.watch_enabled && (self.listening || self.watch_failover) && !self.watch_source_failed && (!self.watch_source.ready || self.watch_source.transfer.acknowledged.archive.tick != self.test_until) {return}
		when !gd.IS_WEB {gd.scene_tree_quit(gd.get_tree(self.owner), 0)}
	}
}

duel_config :: proc(self: ^ReplayDuel) -> rb.Config {
	cfg := rb.DEFAULT_CONFIG; cfg.session, cfg.content = 123, game.CONTENT
	if self.authenticated {cfg.session, cfg.epoch = self.admission.match.session, self.admission.match.epoch}
	cfg.delay, cfg.max_prediction = u32(duel_int("RDP_DELAY", 2)), u32(duel_int("RDP_PREDICTION", 8))
	return cfg
}

duel_profile_report :: proc(self: ^ReplayDuel, now: u64) {
	if self.peer.profile.clock.read == nil {return}
	gd.print_str(fmt.tprintf("RDP_PROFILE_CONFIG delay=%d prediction=%d neutral=%d elapsed_ms=%d dropped_clock_ms=%d max_replay_depth=%d",
	                        self.peer.cfg.delay, self.peer.cfg.max_prediction, self.neutral_until, now - self.started, u64(self.clock.dropped_seconds * 1000), self.peer.stats.max_replay_depth))
	for metric in rb.Profile_Metric {
		t := self.peer.profile.metrics[metric]
		gd.print_str(fmt.tprintf("RDP_PROFILE metric=%v samples=%d total_us=%d max_us=%d p95_upper_us=%d p99_upper_us=%d errors=%d", metric,
		                        t.samples, t.total_us, t.max_us, r.timing_percentile_upper(t, 95), r.timing_percentile_upper(t, 99), t.errors))
	}
}

reference_equal :: proc(actual: game.World, until: u64 = 600, neutral_until: u64 = 2) -> bool {
	w := game.initial(42)
	for tick in u64(1) ..= until {
		inputs: [2]game.Input
		if tick > neutral_until {for &input, i in inputs {input = game.corpus_input(tick, i)}}
		storage: [32]r.Occurrence(game.Event)
		ctx := r.Step(game.Event){tick = tick, epoch = 1, events = storage[:]}
		game.step(&w, inputs, &ctx)
		if ctx.error != .None {return false}
	}
	return reflect.equal(w, actual)
}

paint :: proc(self: ^ReplayDuel, w: game.World) {
	players: [2]rgd.Instance2
	colors := [2]gd.Color{{0.4, 0.65, 1, 1}, {1, 0.55, 0.25, 1}}
	for f, i in w.fighters {players[i] = {key = u64(i + 1), pose = {position = {f32(f.position[0]) / 256, f32(f.position[1]) / 256}},
	                         scale = {f32(f.facing), 1}, color = f.hp == 0 ? gd.Color{0.3, 0.3, 0.3, 0.5} : colors[i]}}
	rgd.nodes_present(&self.fighters, players[:])
	shots: [16]rgd.Instance2; count := 0
	for bullet, i in w.bullets.values {if w.bullets.alive[i] {
		shots[count] = {key = u64(bullet.id), pose = {position = {f32(bullet.position[0]) / 256, f32(bullet.position[1]) / 256}}, scale = {1, 1}, color = colors[bullet.owner]}
		count += 1
	}}
	rgd.nodes_present(&self.bullets, shots[:count])
	gd.set_string(cast(gd.Object)self.status, "text", fmt.ctprintf("HP %d : %d   Kills %d : %d   Confirmed %d", w.fighters[0].hp, w.fighters[1].hp, w.kills[0], w.kills[1], self.peer.timeline.confirmed))
}

duel_fail :: proc(self: ^ReplayDuel, message: string) {
 self.failed=true;gd.print_str(fmt.tprintf("REPLAY_DUEL_FAIL %s",message))
 gd.set_string(cast(gd.Object)self.status,"text",fmt.ctprintf("Connection stopped: %s",message))
 when !gd.IS_WEB {gd.scene_tree_quit(gd.get_tree(self.owner),1)}
}
replay_duel_exit_tree :: proc(self: ^ReplayDuel) {
	rgd.nodes_destroy(&self.fighters); rgd.nodes_destroy(&self.bullets)
	v.journal_destroy(&self.journal); rb.destroy(&self.peer); tr.close(&self.wire)
	rb.watch_destroy(&self.watch); rb.watch_source_destroy(&self.watch_source); tr.close(&self.watch_wire)
	delete(self.archive_path)
	rgd.p2p_party_close(&self.online)
	duel_online_storage_close(self)
}

// Trusted loopback fixture provider. The logical roster remains {1,2}; a fresh
// ENet/WebRTC connection ID replaces the retired one. A deployment must verify
// this admission decision before invoking the core reconnect API.
duel_live_rejoin :: proc(self:^ReplayDuel,now:u64) {
 if !self.live_rejoin || !self.peer.ready {return}
 when !gd.IS_WEB {if !self.listening && !self.online_enabled {duel_native_rejoin_transport(self,now);if self.failed {return}}}
 tr.poll(&self.delay.base)
 remotes:[16]tr.Peer_Id
 if duel_remotes(self,false,remotes[:])!=1 {return}
 generation:=tr.peer_generation(&self.delay.base,remotes[0])
 if !self.native_rejoining && remotes[0]==self.rejoin_physical && generation==self.rejoin_generation {return}
 if !duel_admitted_remote(self,remotes[0]) {return}
 prior:=self.rejoin_physical;prior_generation:=self.rejoin_generation
 before,_:=r.current(&self.peer.timeline);sampled:=self.peer.sampled;confirmed:=self.peer.timeline.confirmed
 received,acknowledged:=self.peer.received,self.peer.acknowledged
 chain,local,roster:=self.peer.chain,self.peer.local,self.peer.roster
 inputs,hashes:=raw_data(self.peer.inputs),raw_data(self.peer.hashes)
 self.identities={}
 player_two:=self.online_enabled && !gd.IS_WEB ? tr.Peer_Id(2) : self.listening ? remotes[0] : gd.IS_WEB ? self.rtc.id : rgd.enet_id(&self.enet)
 bindings:=[2]tr.Peer_Mapping{{1,1},{2,player_two}}
 if !tr.remap_init(&self.identities,tr.delay_transport(&self.delay),bindings[:]) {duel_fail(self,"rejoin mapping");return}
 self.wire=tr.remap_transport(&self.identities)
 if rb.reconnect(&self.peer,self.wire,now)!=.None {duel_fail(self,"rejoin handshake");return}
 after,_:=r.current(&self.peer.timeline)
 if !reflect.equal(before,after) || sampled!=self.peer.sampled || confirmed!=self.peer.timeline.confirmed || self.rejoin_storage!=raw_data(self.peer.timeline.records) {duel_fail(self,"rejoin changed retained state");return}
 if received!=self.peer.received || acknowledged!=self.peer.acknowledged || chain!=self.peer.chain || local!=self.peer.local || roster!=self.peer.roster || inputs!=raw_data(self.peer.inputs) || hashes!=raw_data(self.peer.hashes) {duel_fail(self,"rejoin changed protocol history");return}
 reopened:=self.native_rejoining;self.native_rejoining=false
 self.rejoin_physical,self.rejoin_generation=remotes[0],generation;self.rejoin_count+=1;self.rejoin_wait_reported=false;r.clock_init(&self.clock,60)
 gd.print_str(fmt.tprintf("RDP_LIVE_REBOUND count=%d old=%d new=%d head=%d confirmed=%d sampled=%d retained=true old_generation=%d generation=%d",self.rejoin_count,prior,self.rejoin_physical,self.peer.timeline.head,self.peer.timeline.confirmed,self.peer.sampled,prior_generation,generation))
 if reopened {gd.print_str(fmt.tprintf("RDP_NATIVE_CREATOR_REBOUND local=%d physical_local=%d retired_transport=true frontiers_retained=true",self.peer.local,player_two))}
}

// Stop sampling first; the next settled process boundary captures the complete
// retained protocol state. The browser owns completion of the requested download.
@(gd_method)
replay_duel_save_participant :: proc(self:^ReplayDuel)->bool {
 if self.failed || self.spectator || !self.peer.ready || self.peer.phase!=.Running || self.saved || self.save_requested {return false}
 self.save_requested=true
 return true
}
