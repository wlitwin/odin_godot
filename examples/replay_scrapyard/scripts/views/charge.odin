//gd:extends Node2D
//gd:class ScrapChargeView
package scrap_views

import "core:math"
import gd "godot:godot"

// Cosmetic component. Only the model can finish an attack or deal damage.
ScrapChargeView :: struct {
	owner: gd.Node2d,
	playback: f64,
	spin: f32 `gd:"export,range=0:20:0.1"`,
	value: f32,
	clock: f64,
	active: bool,
	base_scale: gd.Vector2,
}

scrap_charge_view_ready :: proc(self: ^ScrapChargeView) {
	self.playback = 1
	self.base_scale = gd.node2d_get_scale(self.owner)
	gd.canvas_item_set_visible(self.owner, false)
}

charge_present :: proc(self: ^ScrapChargeView, active: bool, fraction: f32) {
	if self == nil {
		return
	}
	self.active, self.value = active, clamp(fraction, 0, 1)
	if !active {
		self.clock = 0
	}
	gd.canvas_item_set_visible(self.owner, active)
}

scrap_charge_view_process :: proc(self: ^ScrapChargeView, dt: f64) {
	if !self.active {
		return
	}
	self.clock += dt * self.playback
	gd.node2d_set_rotation(self.owner, gd.Float(self.clock * f64(self.spin)))
	size := .4 + self.value * .8 + math.sin(f32(self.clock) * 28) * .06
	gd.node2d_set_scale(self.owner, self.base_scale * size)
	gd.canvas_item_set_modulate(self.owner, {.45, .85, 1, .4 + self.value * .6})
}
