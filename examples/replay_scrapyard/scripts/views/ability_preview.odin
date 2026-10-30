//gd:extends Node2D
//gd:class ScrapAbilityPreview
package scrap_views

import "core:fmt"
import "core:math"
import gd "godot:godot"
import rgd "godot:replay/godot"
import d "godot:replay/definitions"
import defs "../defs"
import content "../../shared/content"

// An isolated visual projection of an authored ability, not a second simulation.
ScrapAbilityPreview :: struct {
	owner: gd.Node2d,
	definition: ^gd.Resource `gd:"export,resource=AbilityDef"`,
	area: gd.Line2d `gd:"onready=Area"`,
	info: gd.Label `gd:"onready=Info"`,
	value: content.Ability,
	color: gd.Color,
	report: d.Report,
	phase: gd.Int,
	fraction, speed, clock: f64,
	ready: bool,
}

scrap_ability_preview_ready :: proc(self: ^ScrapAbilityPreview) {
	self.phase, self.fraction, self.speed = 1, .7, 1
	scrap_ability_preview_preview_refresh(self)
	preview_controls(self.owner)
}

@(gd_method)
scrap_ability_preview_preview_refresh :: proc(self: ^ScrapAbilityPreview) -> bool {
	ctx: rgd.Bake_Context
	_, value := defs.bake_ability(cast(gd.Resource)self.definition, &ctx, "$ability")
	self.report = ctx.report
	if ctx.report.error != .None {
		return false
	}
	color := gd.Color{.2, .9, .6, .8}
	authored := rgd.bake_resource(&ctx, cast(gd.Resource)self.definition, defs.AbilityDef, "$ability")
	if authored != nil && authored.status != nil {
		status := rgd.bake_resource(&ctx, cast(gd.Resource)authored.status, defs.StatusDef, "$ability.status")
		if status != nil {
			color = status.tint
			color.a = .85
		}
	}
	self.report = ctx.report
	if ctx.report.error != .None {
		return false
	}
	self.value, self.color, self.clock, self.ready = value, color, 0, self.area != nil && self.info != nil
	gd.set_text(
		self.info,
		fmt.ctprintf(
			"%s | radius %.0f | range %.0f\ncooldown %d | duration %d | pulse %d | status %d",
			content.name_string(&self.value.name),
			value.radius,
			value.range,
			value.cooldown,
			value.duration,
			value.pulse,
			value.status,
		),
	)
	return self.ready
}

@(gd_method)
scrap_ability_preview_preview_apply :: proc(self: ^ScrapAbilityPreview, phase: gd.Int, fraction, speed: gd.Float) {
	self.phase = clamp(phase, 0, 4)
	self.fraction = clamp(f64(fraction), 0, 1)
	self.speed = clamp(f64(speed), 0, 4)
}

@(gd_method)
scrap_ability_preview_preview_phase :: proc(self: ^ScrapAbilityPreview) -> gd.Int {
	return self.phase
}

@(gd_method)
scrap_ability_preview_preview_radius :: proc(self: ^ScrapAbilityPreview) -> gd.Float {
	return gd.Float(self.value.radius)
}

@(gd_method)
scrap_ability_preview_preview_range :: proc(self: ^ScrapAbilityPreview) -> gd.Float {
	return gd.Float(self.value.range)
}

@(gd_method)
scrap_ability_preview_preview_message :: proc(self: ^ScrapAbilityPreview) -> string {
	if self.report.error != .None {
		return fmt.tprintf("%s: %s", d.report_path(&self.report), d.report_message(&self.report))
	}
	return "Validated preview refreshed. Use an isolated encounter to test gameplay."
}

scrap_ability_preview_process :: proc(self: ^ScrapAbilityPreview, dt: f64) {
	if !self.ready {
		return
	}
	self.clock += dt * self.speed
	gd.canvas_item_set_visible(self.area, self.phase != 4)
	radius := self.value.radius > 0 ? self.value.radius : self.value.range
	if self.phase == 2 {
		radius *= f32(self.fraction)
	}
	gd.line2d_clear_points(self.area)
	for i in 0 ..= 64 {
		angle := f32(i) * math.PI * 2 / 64
		gd.line2d_add_point(self.area, {math.cos(angle) * radius, math.sin(angle) * radius}, -1)
	}
	color := self.color
	color.a *= .65 + .35 * math.sin(f32(self.clock) * 4)
	if self.phase == 3 {
		color = {1, .3, .2, .9}
	}
	gd.line2d_set_default_color(self.area, color)
}
