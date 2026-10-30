//gd:extends Node2D
//gd:class ScrapRunnerView
//gd:replay_view value=value,present=runner_view_present,validate=runner_view_validate
package scrap_views

import "core:fmt"
import gd "godot:godot"
import d "godot:replay/definitions"
import rgd "godot:replay/godot"
import r "godot:replay"
import v "godot:replay/view"
import flow "../../shared/flow"
import display "../../shared/presentation"

// A view represents a roster seat across body respawns. Its immutable display
// carries body generation/warp; rebind resets only local transient presentation.
ScrapRunnerView :: struct {
	owner: gd.Node2d,
	body: gd.Sprite2d `gd:"onready=Body"`,
	label: gd.Label `gd:"onready=Nameplate"`,
	appearances: gd.Array `gd:"export,array=Resource"`,
	fps: f32 `gd:"export,range=1:60:1"`,
	down_angle: f32 `gd:"export,range=-3.14:3.14:0.01"`,
	preview: bool `gd:"export"`,
	preview_down: bool `gd:"export"`,
	preview_reload: bool `gd:"export"`,
	weapon: ^ScrapWeaponView `gd:"onready=Gun"`,
	reload_view: ^ScrapEquipmentView `gd:"onready=Reload"`,
	beacon_view: ^ScrapEquipmentView `gd:"onready=Beacon"`,
	idle, run: [3]gd.Texture2d,
	value: display.Runner_View,
	hurt: flow.Actor_Cue,
	previous: [2]f32,
	body_angle: f32,
	look: u8,
	clock: f64,
	running, ready, active, live: bool,
}

scrap_runner_view_ready :: proc(self: ^ScrapRunnerView) {
	seen: [3]bool
	for i in 0 ..< gd.array_size(&self.appearances) {
		value := gd.array_get(&self.appearances, i)
		resource := gd.variant_to_object(&value)
		style, report := rgd.resource_script(cast(gd.Resource)resource, ScrapRunnerStyle, "$appearances")
		gd.variant_destroy(&value)
		if report.error != .None || style.id < 0 || style.id >= len(seen) || seen[style.id] {
			gd.print_str("SCRAP_RUNNER_STYLE_INVALID duplicate/missing/out-of-range style ID")
			return
		}
		seen[style.id] = true
		self.idle[style.id] = cast(gd.Texture2d)style.idle
		self.run[style.id] = cast(gd.Texture2d)style.run
	}
	if self.body != nil {
		self.body_angle = f32(gd.node2d_get_rotation(self.body))
	}
	self.look = 255
	self.ready =
		self.weapon != nil &&
		self.reload_view != nil &&
		self.beacon_view != nil &&
		self.body != nil &&
		self.label != nil &&
		self.fps > 0
	for i in 0 ..< 3 {
		self.ready = self.ready && self.idle[i] != nil && self.run[i] != nil
	}
	if !self.ready {
		gd.print_str("SCRAP_RUNNER_VIEW_INVALID required component/appearance")
		return
	}
}

runner_view_cue :: proc(self: ^ScrapRunnerView, shot: bool, kind: v.Change_Kind, id: r.Event_Id, generation: u32) {
	if self == nil || !self.ready {
		return
	}
	if shot {
		weapon_view_cue(self.weapon, kind, id, generation)
	} else {
		flow.actor_cue(&self.hurt, kind, id, generation, .3)
	}
}

runner_view_present :: proc(self: ^ScrapRunnerView, value: display.Runner_View) {
	if !self.ready {
		return
	}
	self.live = true
	reset :=
		self.value.generation != value.generation || self.value.warp != value.warp || self.value.epoch != value.epoch
	if reset {
		if self.value.generation == value.generation &&
		   self.value.epoch == value.epoch &&
		   self.value.warp != value.warp {
			self.hurt = {}
			weapon_view_reset(self.weapon)
		}
		self.clock, self.running, self.look = 0, false, 255
		if self.hurt.id.epoch != value.epoch || self.hurt.generation != value.generation {
			self.hurt = {}
		}
	}
	self.value, self.active = value, true
	gd.canvas_item_set_visible(self.owner, value.visible)
	if !value.visible {
		return
	}
	gd.node2d_set_position(self.owner, value.position)
	weapon_view_present(self.weapon, value.weapon)
	equipment_view_present(self.reload_view, value.reloading, reset)
	equipment_view_present(self.beacon_view, !value.alive, reset)
	name := value.name
	text :=
		value.name.count > 0 ? fmt.ctprintf("%s", transmute(string)name.bytes[:name.count]) : fmt.ctprintf("runner %d", value.seat)
	if value.revive_percent > 0 {
		text = fmt.ctprintf("Reviving %d%%", value.revive_percent)
	}
	gd.set_string(self.label, "text", text)
}

scrap_runner_view_process :: proc(self: ^ScrapRunnerView, dt: f64) {
	if !self.ready {
		return
	}
	if self.preview && !self.live {
		position := gd.node2d_get_position(self.owner)
		runner_view_present(
			self,
			{
				position = position,
				tint = {1, 1, 1, self.preview_down ? f32(.45) : f32(1)},
				seat = 1,
				visible = true,
				alive = !self.preview_down,
				reloading = self.preview_reload && !self.preview_down,
				weapon = {aim = {1, 0}, region = {0, 16, 16, 16}, visible = !self.preview_down},
			},
		)
		self.live = false
	}
	if !self.active || !self.value.visible {
		return
	}
	value := self.value
	moving :=
		value.alive && (abs(value.position[0] - self.previous[0]) + abs(value.position[1] - self.previous[1]) > .5)
	if self.look != value.look || self.running != moving {
		self.look, self.running, self.clock = value.look, moving, 0
		gd.sprite2d_set_texture(self.body, moving ? self.run[self.look] : self.idle[self.look])
		gd.sprite2d_set_hframes(self.body, moving ? 8 : 6)
		gd.sprite2d_set_frame(self.body, 0)
	}
	if value.alive {
		self.clock += dt * f64(self.fps)
		gd.sprite2d_set_frame(self.body, gd.Int(u64(self.clock) % (moving ? 8 : 6)))
	}
	gd.sprite2d_set_flip_h(self.body, value.weapon.aim[0] < 0)
	gd.node2d_set_rotation(self.body, gd.Float(self.body_angle + (value.alive ? f32(0) : self.down_angle)))
	tint := gd.Color(value.tint)
	if self.hurt.left > 0 {
		fraction := self.hurt.left / .3
		tint.r += (2 - tint.r) * fraction
		tint.g += (.6 - tint.g) * fraction
		tint.b += (.6 - tint.b) * fraction
		self.hurt.left = max(0, self.hurt.left - f32(dt))
	}
	gd.canvas_item_set_modulate(self.owner, tint)
	self.previous = value.position
}

runner_view_validate :: proc(self: ^ScrapRunnerView) -> d.Report {
	if self.weapon == nil {
		return d.problem(.Missing, "Gun", "expected ScrapWeaponView")
	}
	if self.reload_view == nil {
		return d.problem(.Missing, "Reload", "expected ScrapEquipmentView")
	}
	if self.beacon_view == nil {
		return d.problem(.Missing, "Beacon", "expected ScrapEquipmentView")
	}
	if self.body == nil || self.label == nil {
		return d.problem(.Missing, "Body/Nameplate", "missing runner scene component")
	}
	if !self.ready {
		return d.problem(.Invalid, "$appearance", "invalid runner textures or frame rate")
	}
	return {}
}
