//gd:extends Node3D
//gd:class Owned3Probe
package owned3_probe

import "core:fmt"
import "core:math"
import gd "godot:godot"
import r "godot:replay"
import own "godot:replay/owned"
import rgd "godot:replay/godot"
import sample "../shared"

Owned3Probe :: struct {
	owner: gd.Node3d,
	session: rgd.Session(sample.World, sample.Control, u8, u8, 2),
	body: [1]rgd.Body3,
	ready, seeded, reported: bool,
	started, done_at: u64,
}

owned3_probe_ready :: proc(self: ^Owned3Probe) {
	options := rgd.SESSION_OPTIONS
	options.role = gd.env_string("OWN3_ROLE", "host") == "host" ? .Host : .Client
	options.port = u16(gd.env_int("OWN3_PORT", 49591))
	options.token = rgd.session_token(options.role == .Host ? "own-host" : "own-client")
	options.latency_ms, options.jitter_ms, options.loss_permyriad, options.duplicate_permyriad = 120, 20, 1000, 1000
	options.network.content, options.network.snapshot_every = sample.CONTENT, 1
	if rgd.session_open(&self.session, r.Frame(sample.World){state = sample.initial()}, sample.model(), options) != .None {probe_fail(self, "session"); return}
	node := rgd.scene_instance(self.owner, "res://body.tscn")
	if !rgd.body3_attach(&self.body[0], cast(gd.Physics_Body3d)node, .Rigid) {probe_fail(self, "body"); return}
	self.ready, self.started = true, gd.time_get_ticks_msec(gd.singleton_time())
	gd.print_str("OWNED3_PROBE_READY")
}

owned3_probe_process :: proc(self: ^Owned3Probe, dt: f64) {
	if !self.ready {return}
	now := gd.time_get_ticks_msec(gd.singleton_time())
	if self.done_at != 0 && now >= self.done_at {gd.scene_tree_quit(gd.get_tree(self.owner), 0); return}
	if now - self.started > 20000 {probe_fail(self, "timeout"); return}
	control, err := rgd.body3_sample(&self.body[0], gd.engine_get_physics_frames(gd.singleton_engine()))
	if err != .None {probe_fail(self, "sample"); return}
	if rgd.session_frame(&self.session, dt, control) != .None {probe_fail(self, "frame"); return}
	frame, available := rgd.session_authority_state(&self.session)
	if !available {return}
	before := self.body[0].driver.role
	if rgd.body3_sync(&self.body[0], frame.state.body, rgd.session_seat(&self.session), 1, frame.tick, true, dt) != .None {probe_fail(self, "sync"); return}
	if before != .Preparing && self.body[0].driver.role == .Preparing {
		wanted := frame.state.body.pending.baseline
		actual := rgd.body3_read(&self.body[0])
		linear_error, angular_error, rotation_dot, spin := f32(0), f32(0), f32(0), f32(0)
		for i in 0 ..< 3 {
			linear_error += abs(actual.linear[i] - wanted.linear[i]); angular_error += abs(actual.angular[i] - wanted.angular[i]); spin += abs(wanted.angular[i])
		}
		for i in 0 ..< 4 {rotation_dot += actual.rotation[i] * wanted.rotation[i]}
		if linear_error > 0.0001 || angular_error > 0.0001 || abs(rotation_dot) < 0.99999 || spin < 0.1 || abs(wanted.linear[1]) < 1 {probe_fail(self, "momentum/orientation seed"); return}
		self.seeded = true
		gd.print_str(fmt.tprintf("OWNED3_PROBE_SEED vx=%.6f vy=%.6f vz=%.6f ax=%.6f ay=%.6f az=%.6f linear_error=%.9f angular_error=%.9f rotation_dot=%.9f", actual.linear[0], actual.linear[1], actual.linear[2],
		                        actual.angular[0], actual.angular[1], actual.angular[2], linear_error, angular_error, abs(rotation_dot)))
	}
	if frame.tick >= 300 && !self.reported {
		if frame.state.body.owner != 2 || frame.state.transfers != 1 || (!self.session.authority && !self.seeded) {probe_fail(self, "transfer"); return}
		if self.session.authority && rgd.body3_simulating(&self.body[0]) {probe_fail(self, "old solver active"); return}
		self.reported, self.done_at = true, now + 1000
		gd.print_str(fmt.tprintf("OWNED3_PROBE_OK seat=%d owner=%d revision=%d transfers=%d", rgd.session_seat(&self.session), frame.state.body.owner, frame.state.body.revision, frame.state.transfers))
	}
	if self.done_at != 0 && now >= self.done_at {gd.scene_tree_quit(gd.get_tree(self.owner), 0)}
}

probe_fail :: proc(self: ^Owned3Probe, message: string) {gd.print_str(fmt.tprintf("OWNED3_PROBE_FAIL %s", message)); gd.scene_tree_quit(gd.get_tree(self.owner), 1)}
owned3_probe_exit_tree :: proc(self: ^Owned3Probe) {rgd.body3_destroy(&self.body[0]); rgd.session_close(&self.session)}
