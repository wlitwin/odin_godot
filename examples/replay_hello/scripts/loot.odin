//gd:extends Node2D
//gd:class ReplayLoot
package replay_hello

// The existing M1 gameplay model, unchanged, now viewed through Godot.
import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"
import rgd "godot:replay/godot"
import loot "godot:examples/replay_loot/game"

ReplayLoot :: struct {
	owner: gd.Node2d,
	status: gd.Label `gd:"onready=Status"`,
	timeline: r.Timeline(loot.World, loot.Input, loot.Event),
	journal: v.Journal(loot.Event),
	views: rgd.Nodes2,
	epoch: u64,
	begins, cancels: u32,
	ready: bool,
}

replay_loot_ready :: proc(self: ^ReplayLoot) {
	self.ready = rgd.nodes_load(&self.views, self.owner, "res://actor.tscn", 18)
	if self.ready {replay_loot_contest(self)}
}

replay_loot_process :: proc(self: ^ReplayLoot, dt: f64) {
	if !self.ready {return}
	if gd.is_action_just_pressed("ui_accept") {replay_loot_correct(self)}
	if gd.is_action_just_pressed("ui_cancel") {replay_loot_contest(self)}
	replay_loot_paint(self)
}

// Start one speculative interaction so its correction can be inspected without
// racing a confirmation deadline. This fixture advances on commands, not time.
@(gd_method)
replay_loot_contest :: proc(self: ^ReplayLoot) {
	r.destroy(&self.timeline)
	v.journal_destroy(&self.journal)
	self.epoch += 1
	err := r.init(&self.timeline, r.Frame(loot.World){state = loot.initial()}, loot.step, epoch = self.epoch)
	assert(err == .None)
	jerr := v.journal_init(&self.journal, epoch = self.epoch)
	assert(jerr == .None)
	input: loot.Input
	input.players[0] = {take = true, fire = true, seq = 1}
	result := r.advance(&self.timeline, input)
	assert(result.error == .None)
	replay_loot_sync(self)
}

@(gd_method)
replay_loot_correct :: proc(self: ^ReplayLoot) {
	input: loot.Input
	input.players[0] = {fire = true, seq = 1}
	input.players[1] = {take = true, seq = 1}
	result := r.revise_input(&self.timeline, 1, input)
	assert(result.error == .None)
	replay_loot_sync(self)
}

replay_loot_sync :: proc(self: ^ReplayLoot) {
	events: [8]r.Occurrence(loot.Event)
	n, err := r.copy_events(&self.timeline, 1, events[:])
	assert(err == .None)
	jerr := v.sync_tick(&self.journal, 1, events[:n])
	assert(jerr == .None)
	changes: [16]v.Change(loot.Event)
	count := v.drain(&self.journal, changes[:])
	for change in changes[:count] {
		switch change.kind {
		case .Begin: self.begins += 1
		case .Cancel: self.cancels += 1
		case .Update, .Confirm:
		}
	}
	replay_loot_paint(self)
}

replay_loot_paint :: proc(self: ^ReplayLoot) {
	frame, ok := r.current(&self.timeline)
	if !ok {return}
	instances: [18]rgd.Instance2
	for player, i in frame.state.players {
		instances[i] = {
			key = u64(i + 1), pose = {position = {320 + f32(player.x) * 80, 220}}, scale = {2, 2},
			color = i == 0 ? gd.Color{0.35, 0.85, 1, 1} : gd.Color{1, 0.62, 0.3, 1},
		}
	}
	n := 2
	for entity, i in frame.state.entities.values {
		if !frame.state.entities.alive[i] {continue}
		instances[n] = {
			key = u64(frame.state.entities.generations[i]) << 32 | u64(i + 1),
			pose = {position = {320 + f32(entity.x) * 80, 165}}, scale = {0.6, 1.2},
			color = {1, 0.95, 0.62, 1},
		}
		n += 1
	}
	assert(rgd.nodes_present(&self.views, instances[:n]))
	gd.set_string(self.status, "text", fmt.ctprintf("REPLAY / LOOT\nBlue inventory: %d   Orange inventory: %d\nSpace corrects the winner   Esc restarts\nEffects begun: %d   canceled: %d", frame.state.players[0].bag, frame.state.players[1].bag, self.begins, self.cancels))
}

replay_loot_exit_tree :: proc(self: ^ReplayLoot) {
	if !self.ready {return}
	rgd.nodes_destroy(&self.views)
	v.journal_destroy(&self.journal)
	r.destroy(&self.timeline)
	self.ready = false
}

@(gd_method)
replay_loot_probe_blue :: proc(self: ^ReplayLoot) -> gd.Int {
	frame, _ := r.current(&self.timeline)
	return gd.Int(frame.state.players[0].bag)
}

@(gd_method)
replay_loot_probe_orange :: proc(self: ^ReplayLoot) -> gd.Int {
	frame, _ := r.current(&self.timeline)
	return gd.Int(frame.state.players[1].bag)
}

@(gd_method)
replay_loot_probe_begins :: proc(self: ^ReplayLoot) -> gd.Int {return gd.Int(self.begins)}

@(gd_method)
replay_loot_probe_cancels :: proc(self: ^ReplayLoot) -> gd.Int {return gd.Int(self.cancels)}
