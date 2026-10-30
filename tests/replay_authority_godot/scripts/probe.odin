//gd:extends Node
//gd:class ReplayLeaseProbe
package replay_lease_probe

import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import view "godot:replay/view"
import auth "godot:replay/authority"
import rgd "godot:replay/godot"
import game "godot:examples/replay_cavecrawl/shared/cave"

ReplayLeaseProbe :: struct {
	owner: gd.Node,
	ledger: auth.Record,
	coordinator: auth.Coordinator,
	lease: auth.Lease,
	clock: auth.Clock_Source,
	session: rgd.Session(game.World, game.Control, game.Action, game.Event, game.SEATS),
	ready: bool,
	started, stopped_at, stopped_tick: u64,
}

persist :: proc(user: rawptr, expected: u64, next: auth.Record) -> bool {
	self := cast(^ReplayLeaseProbe)user
	if self.ledger.revision != expected {return false}
	self.ledger = next
	return true // in-memory test store; production must make this durable
}

replay_lease_probe_ready :: proc(self: ^ReplayLeaseProbe) {
	self.clock = auth.native_clock()
	now, ok := self.clock.read(self.clock.user)
	if !ok {replay_lease_probe_fail(self, "native clock unavailable"); return}
	self.started = now
	id := auth.Identity{1, 8}
	policy := auth.DEFAULT_POLICY; policy.lease_ms = 1000
	self.ledger = auth.record_make(71, 72, id, policy)
	if auth.coordinator_init(&self.coordinator, self.ledger, persist, self, now) != .None {replay_lease_probe_fail(self, "coordinator"); return}
	address, _ := auth.endpoint("127.0.0.1", 49440)
	auth.coordinator_member(&self.coordinator, {identity = id, endpoint = address, enabled = true, can_host = true, trusted_authority = true}, now)
	auth.lease_init(&self.lease, id, 71, 72, self.clock, true)
	request, _ := auth.lease_request(&self.lease)
	now, _ = self.clock.read(self.clock.user)
	if auth.coordinator_start(&self.coordinator, id, request, now) != .None {replay_lease_probe_fail(self, "initial grant"); return}
	grant, _ := auth.coordinator_view(&self.coordinator, now)
	auth.lease_accept(&self.lease, request, grant)
	opts := rgd.SESSION_OPTIONS
	opts.network.content, opts.network.hz, opts.network.lead, opts.network.require_permit = 72, game.HZ, 4, true
	opts.permit = auth.lease_permit(&self.lease)
	if rgd.session_open(&self.session, r.Frame(game.World){state = game.initial()}, game.model(), opts) != .None {replay_lease_probe_fail(self, "session"); return}
	self.ready = true
}

replay_lease_probe_process :: proc(self: ^ReplayLeaseProbe, dt: f64) {
	if !self.ready {return}
	now, ok := self.clock.read(self.clock.user)
	if !ok || now - self.started > 5000 {replay_lease_probe_fail(self, "timeout/clock"); return}
	if err := rgd.session_frame(&self.session, dt, game.Control{move = {1, 0}}); err != .None {replay_lease_probe_fail(self, fmt.tprintf("frame %v", err)); return}
	changes: [320]view.Change(net.Net_Event(game.Event))
	rgd.session_changes(&self.session, changes[:])
	frame, _ := rgd.session_state(&self.session)
	if self.session.fenced {
		if self.stopped_at == 0 {self.stopped_at, self.stopped_tick = now, frame.tick}
		if self.stopped_tick == 0 || frame.tick != self.stopped_tick {replay_lease_probe_fail(self, "simulation advanced after expiry"); return}
		if now - self.stopped_at > 200 {
			if auth.coordinator_renew(&self.coordinator, {1, 8}, 1, 2, frame.tick, now) != .Denied {replay_lease_probe_fail(self, "expired renewal"); return}
			gd.print_str(fmt.tprintf("REPLAY_LEASE_GODOT_OK stopped_tick=%d elapsed_ms=%d", frame.tick, now - self.started))
			self.ready = false
			gd.scene_tree_quit(gd.get_tree(self.owner), 0)
		}
	}
}

replay_lease_probe_fail :: proc(self: ^ReplayLeaseProbe, message: string) {
	self.ready = false
	gd.print_str(fmt.tprintf("REPLAY_LEASE_FAIL %s", message))
	gd.scene_tree_quit(gd.get_tree(self.owner), 1)
}

replay_lease_probe_exit_tree :: proc(self: ^ReplayLeaseProbe) {rgd.session_close(&self.session)}
