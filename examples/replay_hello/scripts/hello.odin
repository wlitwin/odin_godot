//gd:extends Node2D
//gd:class ReplayHello
package replay_hello

import "core:fmt"
import "core:reflect"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"
import game "../shared/hello"
import debuggd "godot:replay/godot/debug"
import scenegd "godot:replay/godot/scene"

ReplayHello :: struct {
	owner: gd.Node2d,
	debug_enabled:bool `gd:"export"`,
	debug:debuggd.Debug_Overlay,
	scrubber:debuggd.Debug_Scrubber,
	field_editor:debuggd.Debug_Field_Editor(game.World),
	recording:debuggd.Debug_Recording,
	playback:debuggd.Debug_Playback(game.World,game.Input,game.Event),
	playback_was_paused:bool,
	inspect_was_paused,debug_input_gate:bool,
	status: gd.Label `gd:"onready=Status"`,
	effect: gd.Node2d `gd:"onready=Flash"`,
	clock: r.Clock,
	buttons: r.Buttons,
	timeline: game.Timeline,
	journal: v.Journal(game.Event),
	views: scenegd.View_Pool2(game.Actor,u8,gd.Node2d),
	epoch: u64,
	begins, confirms: u32,
	flash: f64,
	ready: bool,
}

replay_hello_ready :: proc(self: ^ReplayHello) {
	if self.debug_enabled || gd.launch_param("REPLAY_DEBUG","debug","0")=="1" {debuggd.debug_overlay_init(&self.debug,self.owner,true);debuggd.debug_scrubber_init(&self.scrubber,self.owner);debuggd.debug_field_editor_init(&self.field_editor,self.owner,game.network_state_valid);debuggd.debug_recording_init(&self.recording,gd.node_get_parent(self.scrubber.branch));debuggd.debug_playback_init(&self.playback,self.owner)}
	if !scenegd.view_pool_load(&self.views,self.owner,"res://actor.tscn",game.CAPACITY,scenegd.View_Binding(u8,gd.Node2d){
		attach=proc(_:rawptr,node:gd.Node2d)->(gd.Node2d,bool){return node,true},
		paint=proc(_:rawptr,node:^gd.Node2d,owner:u8){}, // root properties come from the projection
	}) {return}
	r.clock_init(&self.clock)
	self.ready = true
	replay_hello_reset_to(self, r.Frame(game.World){state = game.initial()})
}

replay_hello_reset_to :: proc(self: ^ReplayHello, frame: r.Frame(game.World)) {
	if self.playback.owns_pause {replay_hello_playback_leave(self);debuggd.debug_playback_end(&self.playback)}
	if self.scrubber.active {replay_hello_debug_leave(self);debuggd.debug_scrubber_end(&self.scrubber)}
	r.destroy(&self.timeline)
	v.journal_destroy(&self.journal)
	self.epoch += 1
	err := r.init(&self.timeline, frame, game.step, epoch = self.epoch)
	assert(err == .None)
	jerr := v.journal_init(&self.journal, epoch = self.epoch, baseline = frame.tick)
	assert(jerr == .None)
	self.buttons = {}
	self.clock.accumulator = 0
	self.flash = 0
	replay_hello_paint(self)
}

replay_hello_process :: proc(self: ^ReplayHello, dt: f64) {
	defer if !self.playback.owns_pause {debuggd.debug_timeline_frame(&self.debug,&self.timeline)}
	if !self.ready {return}
	switch debuggd.debug_playback_frame(&self.playback,game.RECORDING_CONTEXT,game.recording_model(),dt) {
 case .Enter:
  if self.scrubber.active {replay_hello_debug_leave(self);debuggd.debug_scrubber_end(&self.scrubber)}
  self.playback_was_paused=self.clock.paused;self.clock.paused=true;self.clock.accumulator=0;self.buttons={};self.flash=0
 case .Leave:replay_hello_playback_leave(self);replay_hello_paint(self);return
 case .Branch:
  frame,ok:=debuggd.debug_playback_read(&self.playback)
  if ok && self.epoch<max(u64) {replay_hello_reset_to(self,frame)}
  replay_hello_paint(self);return
 case .None:
 }
 if self.debug.layer!=nil {gd.canvas_layer_set_visible(self.debug.layer,!self.playback.owns_pause && self.debug.visible)}
 if self.scrubber.layer!=nil {gd.canvas_layer_set_visible(self.scrubber.layer,!self.playback.owns_pause)}
 if self.playback.owns_pause {gd.canvas_item_set_visible(self.effect,false);replay_hello_paint(self);return}
	if self.recording.pending {debuggd.debug_recording_frame(&self.recording,&self.timeline,game.RECORDING_CONTEXT,gd.launch_param("REPLAY_RECORDING_PATH","recording_path","user://hello.rplrec"),"hello.rplrec")}
	action:=debuggd.debug_scrubber_frame(&self.scrubber,&self.timeline)
	debuggd.debug_field_editor_frame(&self.field_editor,&self.scrubber,&self.timeline)
	switch action {
	case .Inspect:
		self.inspect_was_paused=self.clock.paused;self.clock.paused=true
		self.clock.accumulator=0;self.buttons={}
	case .Resume,.Invalidated:
		replay_hello_debug_leave(self)
		replay_hello_paint(self);return
	case .Branch:
		frame,ok:=debuggd.debug_field_editor_read(&self.field_editor)
		if ok && self.epoch<max(u64) {replay_hello_reset_to(self,frame)}
		replay_hello_paint(self);return
	case .None:
	}
	if self.scrubber.active {
		gd.canvas_item_set_visible(self.effect,false)
		replay_hello_paint(self);return
	}
	if gd.is_action_just_pressed("ui_cancel") {replay_hello_restart(self)}
	if self.clock.paused {
		self.buttons={};self.clock.accumulator=0
		self.flash=max(self.flash-dt,0);gd.canvas_item_set_visible(self.effect,self.flash>0)
		replay_hello_paint(self);return
	}
	if self.debug_input_gate && !replay_hello_input_active() {self.debug_input_gate=false}
	held := !self.debug_input_gate && gd.is_action_pressed("ui_accept") ? u64(1) : u64(0)
	r.buttons_set(&self.buttons, held)
	// Device edges can occur together in one render frame.
	if !self.debug_input_gate && gd.is_action_just_pressed("ui_accept") {self.buttons.pressed |= 1}
	if !self.debug_input_gate && gd.is_action_just_released("ui_accept") {self.buttons.released |= 1}
	steps, _ := r.clock_add(&self.clock, dt)
	for _ in 0 ..< steps {
		input: game.Input
		if !self.debug_input_gate && gd.is_action_pressed("ui_left") {input.players[0].move[0] -= 1}
		if !self.debug_input_gate && gd.is_action_pressed("ui_right") {input.players[0].move[0] += 1}
		if !self.debug_input_gate && gd.is_action_pressed("ui_up") {input.players[0].move[1] -= 1}
		if !self.debug_input_gate && gd.is_action_pressed("ui_down") {input.players[0].move[1] += 1}
		input.players[0].fire = self.buttons.held & 1 != 0 || self.buttons.pressed & 1 != 0
		result := r.advance(&self.timeline, input)
		assert(result.error == .None)
		if result.error != .None {break}
		r.clock_consume(&self.clock)
		r.buttons_consume(&self.buttons)
		events: [32]r.Occurrence(game.Event)
		n, err := r.copy_events(&self.timeline, result.tick, events[:])
		assert(err == .None)
		jerr := v.sync_tick(&self.journal, result.tick, events[:n])
		assert(jerr == .None)
		// Offline results commit immediately. A network runner will supply this frontier.
		err = r.confirm_through(&self.timeline, result.tick)
		assert(err == .None)
		jerr = v.advance_time(&self.journal, result.tick, result.tick)
		assert(jerr == .None)
		replay_hello_effects(self)
	}
	self.flash = max(self.flash - dt, 0)
	gd.canvas_item_set_visible(self.effect, self.flash > 0)
	replay_hello_paint(self)
}

replay_hello_debug_leave :: proc(self:^ReplayHello) {
	debuggd.debug_field_editor_end(&self.field_editor)
	self.clock.paused=self.inspect_was_paused;self.clock.accumulator=0
	self.buttons={};self.flash=0;self.debug_input_gate=true
	gd.canvas_item_set_visible(self.effect,false)
}

replay_hello_playback_leave :: proc(self:^ReplayHello) {
 self.clock.paused=self.playback_was_paused;self.clock.accumulator=0;self.buttons={};self.flash=0;self.debug_input_gate=true
 gd.canvas_item_set_visible(self.effect,false)
}

replay_hello_effects :: proc(self: ^ReplayHello) {
	changes: [16]v.Change(game.Event)
	n := v.drain(&self.journal, changes[:])
	for change in changes[:n] {
		switch change.kind {
		case .Begin:
			self.begins += 1
			self.flash = 0.16
			gd.node2d_set_position(self.effect, change.occurrence.value.position)
		case .Confirm: self.confirms += 1
		case .Update: gd.node2d_set_position(self.effect, change.occurrence.value.position)
		case .Cancel: self.flash = 0
		}
	}
}

replay_hello_paint :: proc(self: ^ReplayHello) {
	tick:=self.timeline.head
	projected,error:=r.project(&self.timeline,tick,game.project_actor_views)
	if error!=.None {return}
	if self.scrubber.active {
		frame,ok:=debuggd.debug_field_editor_read(&self.field_editor);if !ok {return}
		projected,tick=game.project_actor_views(frame.state),frame.tick
	}
	if self.playback.owns_pause && self.playback.player.recording.ready {
		frame,ok:=debuggd.debug_playback_read(&self.playback);if !ok {return}
		projected,tick=game.project_actor_views(frame.state),frame.tick
	}
	for &item in projected.items[:projected.count] {item.tick=tick}
	presented:=scenegd.view_pool_present(&self.views,{self.epoch,0},projected.items[:projected.count])
	assert(presented==.None)
	gd.set_string(self.status, "text", fmt.ctprintf("REPLAY / HELLO    tick %d    shots %d\nArrows move   Space fires   Esc restarts", tick, projected.shots))
}

replay_hello_exit_tree :: proc(self: ^ReplayHello) {
 debuggd.debug_playback_destroy(&self.playback)
	debuggd.debug_recording_destroy(&self.recording)
	debuggd.debug_field_editor_destroy(&self.field_editor)
	debuggd.debug_scrubber_destroy(&self.scrubber)
	debuggd.debug_overlay_destroy(&self.debug)
	if !self.ready {return}
	scenegd.view_pool_destroy(&self.views)
	v.journal_destroy(&self.journal)
	r.destroy(&self.timeline)
	self.ready = false
}

@(gd_method)
replay_hello_restart :: proc(self: ^ReplayHello) {
	replay_hello_reset_to(self, r.Frame(game.World){state = game.initial()})
}

replay_hello_input_active :: proc()->bool {
 return gd.is_action_pressed("ui_accept") || gd.is_action_just_pressed("ui_accept") || gd.is_action_just_released("ui_accept") ||
        gd.is_action_pressed("ui_left") || gd.is_action_pressed("ui_right") || gd.is_action_pressed("ui_up") || gd.is_action_pressed("ui_down")
}

@(gd_method)
replay_hello_pause :: proc(self: ^ReplayHello, paused: bool) {
 if self.clock.paused==paused {return}
 self.clock.paused=paused;self.clock.accumulator=0;self.buttons={}
 // Controls already held across either transition must be released first.
 self.debug_input_gate=replay_hello_input_active()
}

@(gd_method)
replay_hello_rewind_to :: proc(self: ^ReplayHello, tick: gd.Int) -> bool {
	if tick < 0 {return false}
	frame, ok := r.read(&self.timeline, u64(tick))
	if !ok {return false}
	replay_hello_reset_to(self, frame)
	return true
}

@(gd_method)
replay_hello_probe_tick :: proc(self: ^ReplayHello) -> gd.Int {
	frame, _ := r.current(&self.timeline)
	return gd.Int(frame.tick)
}

@(gd_method)
replay_hello_probe_x :: proc(self: ^ReplayHello) -> f64 {
	frame, _ := r.current(&self.timeline)
	actor, ok := r.pool_get(&frame.state.actors, frame.state.players[0])
 if !ok {return 0}
	return f64(actor.body.position[0])
}

@(gd_method)
replay_hello_probe_views :: proc(self: ^ReplayHello) -> gd.Int {return gd.Int(self.views.nodes.count)}

@(gd_method)
replay_hello_probe_shots :: proc(self: ^ReplayHello) -> gd.Int {
	frame, _ := r.current(&self.timeline)
	return gd.Int(frame.state.shots)
}

@(gd_method)
replay_hello_probe_begins :: proc(self: ^ReplayHello) -> gd.Int {return gd.Int(self.begins)}

@(gd_method)
replay_hello_probe_audit :: proc(self: ^ReplayHello) -> bool {
	frame, _ := r.current(&self.timeline)
	if frame.tick == 0 {return true}
	before := frame
	result := r.audit(&self.timeline, frame.tick)
	after, _ := r.current(&self.timeline)
	return result.error == .None && reflect.equal(before, after)
}

@(gd_method)
replay_hello_probe_history :: proc(self:^ReplayHello,key:string)->gd.Int {
	s:=&self.scrubber
	switch key {
	case "active":return gd.Int(s.active)
	case "playback":return gd.Int(self.playback.owns_pause)
 case "playback_selected":return gd.Int(self.playback.player.selected)
 case "playback_first":return gd.Int(self.playback.player.recording.base.tick)
 case "playback_head":return gd.Int(self.playback.player.recording.header.head)
 case "playback_loads":return gd.Int(self.playback.loads)
 case "playback_rejections":return gd.Int(self.playback.rejections)
 case "playback_playing":return gd.Int(self.playback.player.playing)
 case "exports":return gd.Int(self.recording.exports)
	case "export_bytes":return gd.Int(self.recording.last.bytes)
	case "edited":return gd.Int(self.field_editor.dirty)
	case "first":return gd.Int(s.first)
	case "selected":return gd.Int(s.selected)
	case "last":return gd.Int(s.last)
	case "epoch":return gd.Int(self.epoch)
	}
	return -1
}
