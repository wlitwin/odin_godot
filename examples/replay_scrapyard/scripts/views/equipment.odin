//gd:extends Node2D
//gd:class ScrapEquipmentView
package scrap_views

import "core:math"
import gd "godot:godot"

// Reused for a reload flag and a downed beacon. Shape/texture, origin, scale and
// colors are authored on the scene; only the local bob/pulse is procedural.
ScrapEquipmentView :: struct {
    owner: gd.Node2d,
    speed: f32 `gd:"export,range=0:30:0.1"`,
    height: f32 `gd:"export,range=0:30:0.1"`,
    scale_pulse: f32 `gd:"export,range=0:1:0.01"`,
    fade_pulse: bool `gd:"export"`,
    origin, base_scale: gd.Vector2,
    base_color: gd.Color,
    clock: f64,
    active, ready: bool,
}

scrap_equipment_view_ready :: proc(self: ^ScrapEquipmentView) {
    self.origin = gd.node2d_get_position(self.owner)
    self.base_scale = gd.node2d_get_scale(self.owner)
    self.base_color = gd.canvas_item_get_modulate(self.owner)
    self.ready = true
}

equipment_view_present :: proc(self: ^ScrapEquipmentView, active: bool, reset: bool = false) {
    if self == nil || !self.ready {
        return
    }

    if reset {
        self.clock = 0
    }

    self.active = active
    gd.canvas_item_set_visible(self.owner, active)
}

scrap_equipment_view_process :: proc(self: ^ScrapEquipmentView, dt: f64) {
    if !self.ready || !self.active {
        return
    }

    self.clock += dt * f64(self.speed)
    pulse := math.sin(f32(self.clock))
    gd.node2d_set_position(self.owner, self.origin + [2]f32{0, -pulse * self.height})
    gd.node2d_set_scale(self.owner, self.base_scale * (1 + pulse * self.scale_pulse))
    color := self.base_color

    if self.fade_pulse {
        color.a *= .6 + pulse * .4
    }

    gd.canvas_item_set_modulate(self.owner, color)
}
