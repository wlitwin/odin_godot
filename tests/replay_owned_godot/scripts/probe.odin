//gd:extends Node2D
//gd:class OwnedProbe
package owned_probe

import "core:fmt"
import "core:math"
import gd "godot:godot"
import r "godot:replay"
import own "godot:replay/owned"
import rgd "godot:replay/godot"
import sample "../shared"
import scenegd "godot:replay/godot/scene"
import storagegd "godot:replay/godot/storage"

OwnedProbe :: struct {
	owner: gd.Node2d,
	session: rgd.Session(sample.World, sample.Control, u8, u8, 2),
	body: [1]scenegd.Body2,
	ready, seeded, reported: bool,
	started, done_at: u64,
}

owned_probe_ready :: proc(self: ^OwnedProbe) {
	options := rgd.SESSION_OPTIONS
	options.role = gd.env_string("OWN_ROLE", "host") == "host" ? .Host : .Client
	options.port = u16(gd.env_int("OWN_PORT", 49590))
	options.token = storagegd.session_token(options.role == .Host ? "own-host" : "own-client")
	options.latency_ms, options.jitter_ms, options.loss_permyriad, options.duplicate_permyriad = 120, 20, 1000, 1000
	options.network.content, options.network.snapshot_every = sample.CONTENT, 1
	if rgd.session_open(&self.session, r.Frame(sample.World){state = sample.initial()}, sample.model(), options) != .None {probe_fail(self, "session"); return}
	node := scenegd.scene_instance(self.owner, "res://body.tscn")
	if !scenegd.body2_attach(&self.body[0], cast(gd.Physics_Body2d)node, .Rigid) {probe_fail(self, "body"); return}
	self.ready, self.started = true, gd.time_get_ticks_msec(gd.singleton_time())
	gd.print_str("OWNED_PROBE_READY")
}

owned_probe_process :: proc(self: ^OwnedProbe, dt: f64) {
	if !self.ready {return}
	now := gd.time_get_ticks_msec(gd.singleton_time())
	if self.done_at != 0 && now >= self.done_at {gd.scene_tree_quit(gd.get_tree(self.owner), 0); return}
	if now - self.started > 20000 {probe_fail(self, "timeout"); return}
	control, err := scenegd.body2_sample(&self.body[0], gd.engine_get_physics_frames(gd.singleton_engine()))
	if err != .None {probe_fail(self, "sample"); return}
	if rgd.session_frame(&self.session, dt, control) != .None {probe_fail(self, "frame"); return}
	frame, available := rgd.session_authority_state(&self.session)
	if !available {return}
	before := self.body[0].driver.role
	if scenegd.body2_sync(&self.body[0], frame.state.body, rgd.session_seat(&self.session), 1, frame.tick, true, dt) != .None {probe_fail(self, "sync"); return}
	if before != .Preparing && self.body[0].driver.role == .Preparing {
		wanted := frame.state.body.pending.baseline
		actual := scenegd.body2_read(&self.body[0])
		linear_error := math.sqrt((actual.linear[0] - wanted.linear[0]) * (actual.linear[0] - wanted.linear[0]) + (actual.linear[1] - wanted.linear[1]) * (actual.linear[1] - wanted.linear[1]))
		angular_error := abs(actual.angular - wanted.angular)
		if linear_error > 0.0001 || angular_error > 0.0001 || abs(wanted.angular) < 0.1 || abs(wanted.linear[0]) < 5 {probe_fail(self, "momentum seed"); return}
		self.seeded = true
		gd.print_str(fmt.tprintf("OWNED_PROBE_SEED vx=%.6f vy=%.6f spin=%.6f linear_error=%.9f angular_error=%.9f", actual.linear[0], actual.linear[1], actual.angular, linear_error, angular_error))
	}
	if frame.tick >= 300 && !self.reported {
		if frame.state.body.owner != 2 || frame.state.transfers != 1 || (!self.session.authority && !self.seeded) {probe_fail(self, "transfer"); return}
		if self.session.authority && scenegd.body2_simulating(&self.body[0]) {probe_fail(self, "old solver active"); return}
		self.reported, self.done_at = true, now + 1000
		gd.print_str(fmt.tprintf("OWNED_PROBE_OK seat=%d owner=%d revision=%d transfers=%d", rgd.session_seat(&self.session), frame.state.body.owner, frame.state.body.revision, frame.state.transfers))
	}
	if self.done_at != 0 && now >= self.done_at {gd.scene_tree_quit(gd.get_tree(self.owner), 0)}
}

probe_fail :: proc(self: ^OwnedProbe, message: string) {gd.print_str(fmt.tprintf("OWNED_PROBE_FAIL %s", message)); gd.scene_tree_quit(gd.get_tree(self.owner), 1)}
owned_probe_exit_tree :: proc(self: ^OwnedProbe) {scenegd.body2_destroy(&self.body[0]); rgd.session_close(&self.session)}
