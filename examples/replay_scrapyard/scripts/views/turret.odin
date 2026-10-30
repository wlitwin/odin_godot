//gd:extends Node2D
//gd:class ScrapTurretView
//gd:replay_view value=value,present=turret_view_present,validate=turret_view_validate
package scrap_views

import "core:fmt"
import "core:math"
import gd "godot:godot"
import d "godot:replay/definitions"
import display "../../shared/presentation"

ScrapTurretView :: struct {
	owner: gd.Node2d,
	barrel: gd.Node2d `gd:"onready=Barrel"`,
	body: gd.Polygon2d `gd:"onready=Base"`,
	ammo: gd.Label `gd:"onready=Ammo"`,
	value: display.Turret_View,
}

turret_view_validate :: proc(self: ^ScrapTurretView) -> d.Report {
	if self.barrel == nil || self.body == nil || self.ammo == nil {
		return d.problem(.Missing, "Barrel/Base/Ammo", "missing turret scene component")
	}
	return {}
}

turret_view_present :: proc(self: ^ScrapTurretView, value: display.Turret_View) {
	self.value = value
	gd.node2d_set_rotation(self.barrel, gd.Float(math.atan2(value.aim[1], value.aim[0])))
	gd.polygon2d_set_color(self.body, value.operator == 0 ? gd.Color{.35, .5, .55, 1} : gd.Color{.3, .8, .65, 1})
	text :=
		value.operator == 0 ? fmt.ctprintf("%d/%d · available", value.ammo, value.capacity) : fmt.ctprintf("%d/%d · runner %d", value.ammo, value.capacity, value.operator)
	gd.set_text(self.ammo, text)
}
