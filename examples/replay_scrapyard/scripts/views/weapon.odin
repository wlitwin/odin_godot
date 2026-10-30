//gd:extends Sprite2D
//gd:class ScrapWeaponView
package scrap_views

import "core:math"
import gd "godot:godot"
import r "godot:replay"
import v "godot:replay/view"
import flow "../../shared/flow"
import display "../../shared/presentation"

ScrapWeaponView :: struct {
	owner: gd.Sprite2d,
	flash: gd.Sprite2d `gd:"onready=Flash"`,
	muzzle_seconds: f32 `gd:"export,range=0.01:1:0.01"`,
	muzzle: flow.Actor_Cue,
	value: display.Weapon_View,
	authored_angle: f32,
	ready, active: bool,
}

scrap_weapon_view_ready :: proc(self: ^ScrapWeaponView) {
	self.authored_angle = f32(gd.node2d_get_rotation(self.owner))
	self.ready = self.flash != nil && self.muzzle_seconds > 0
	gd.canvas_item_set_visible(self.flash, false)
}

weapon_view_cue :: proc(self: ^ScrapWeaponView, kind: v.Change_Kind, id: r.Event_Id, generation: u32) {
	if self == nil {
		return
	}
	flow.actor_cue(&self.muzzle, kind, id, generation, self.muzzle_seconds)
}

weapon_view_reset :: proc(self: ^ScrapWeaponView) {
	self.muzzle = {}
}

weapon_view_present :: proc(self: ^ScrapWeaponView, value: display.Weapon_View) {
	if self == nil || !self.ready {
		return
	}
	self.value, self.active = value, true
	if self.muzzle.id.epoch != value.epoch || self.muzzle.generation != value.generation || !value.visible {
		self.muzzle.left = 0
	}
	gd.canvas_item_set_visible(self.owner, value.visible)
	gd.sprite2d_set_region_rect(
		self.owner,
		{{f32(value.region[0]), f32(value.region[1])}, {f32(value.region[2]), f32(value.region[3])}},
	)
	gd.node2d_set_rotation(self.owner, gd.Float(self.authored_angle + math.atan2(value.aim[1], value.aim[0])))
	gd.sprite2d_set_flip_v(self.owner, value.aim[0] < 0)
}

scrap_weapon_view_process :: proc(self: ^ScrapWeaponView, dt: f64) {
	if !self.ready || !self.active {
		return
	}
	gd.canvas_item_set_visible(self.flash, self.value.visible && self.muzzle.left > 0)
	if self.muzzle.left > 0 {
		cell := clamp(int((1 - self.muzzle.left / self.muzzle_seconds) * 4), 0, 3)
		gd.sprite2d_set_region_rect(self.flash, {{f32(cell * 16), 0}, {16, 16}})
		self.muzzle.left = max(0, self.muzzle.left - f32(dt))
	}
}
