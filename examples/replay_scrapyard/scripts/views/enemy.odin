//gd:extends Node2D
//gd:class ScrapEnemyView
//gd:replay_view value=value,present=enemy_view_present,validate=enemy_view_validate,retired=enemy_view_retire,appearance=skin,configure=enemy_view_configure
package scrap_views

import "core:math"
import "core:fmt"
import gd "godot:godot"
import rt "godot:runtime"
import display "../../shared/presentation"
import d "godot:replay/definitions"

ScrapEnemyView :: struct {
    owner: gd.Node2d,
    body: gd.Sprite2d `gd:"onready=Body"`,
    appearance: ^gd.Resource `gd:"export,resource=ScrapEnemyStyle"`,
    skin: ^ScrapEnemyStyle,
    charge: ^ScrapChargeView `gd:"onready=Charge"`,
    preview: bool `gd:"export"`,
    preview_state: ^gd.Resource `gd:"export,resource=ScrapEnemyPreview"`,
    preview_value: display.Mob_View,
    preview_error: d.Report,
    preview_appearance: gd.Resource,
    preview_phase: gd.Int,
    preview_fraction, preview_speed: f64,
    telegraph: ^ScrapTelegraphView `gd:"onready=Telegraph"`,
    value: display.Mob_View,
    body_scale: gd.Vector2,
    body_angle: f32,
    kind, row: u8,
    clock, flick: f64,
    previous: [2]f32,
    hp: u16,
    tick: u64,
    hurt, wobble: f32,
    ready, painted, live, retired: bool,
    impact: Enemy_Impact,
}

Enemy_Impact :: struct {
    value: display.Mob_View,
    damage: u16,
    ready: bool,
}

scrap_enemy_view_ready :: proc(self: ^ScrapEnemyView) {
    self.skin = rt.script_of(cast(gd.Object)self.appearance, ScrapEnemyStyle)

    if self.body != nil {
        self.body_scale = gd.node2d_get_scale(self.body)
        self.body_angle = f32(gd.node2d_get_rotation(self.body))
    }

    self.kind, self.row = 255, 255
    self.ready = self.body != nil && self.telegraph != nil && self.charge != nil

    if self.preview {
        value, report := enemy_preview_value(cast(gd.Resource)self.preview_state)
        self.preview_value = value
        self.preview_error = report
        self.ready = self.ready && report.error == .None && enemy_preview_capture_style(self)
        self.preview_phase = value.telegraph ? 2 : value.near ? 1 : 0
        self.preview_fraction = f64(value.growth)
        self.preview_speed = 1
        preview_controls(self.owner)
    }

    if !self.ready {
        gd.print_str("SCRAP_ENEMY_VIEW_INVALID Body/Telegraph or appearance Resource")
        return
    }
}

enemy_view_configure :: proc(self: ^ScrapEnemyView, appearance: ^ScrapEnemyStyle) -> d.Report {
    if !enemy_style_valid(appearance) {
        return d.problem(.Invalid, "$appearance", "invalid ScrapEnemyStyle frames, texture or timing")
    }

    self.skin = appearance
    self.kind = 255
    return {}
}

enemy_view_validate :: proc(self: ^ScrapEnemyView) -> d.Report {
    if self.body == nil {
        return d.problem(.Missing, "Body", "expected Sprite2D")
    }

    if self.telegraph == nil || !self.telegraph.ready {
        return d.problem(.Missing, "Telegraph", "expected ready ScrapTelegraphView")
    }

    if self.charge == nil {
        return d.problem(.Missing, "Charge", "expected ScrapChargeView")
    }

    if !self.ready {
        return d.problem(.Invalid, "$preview", "invalid authored preview or required scene component")
    }

    return {}
}

enemy_view_retire :: proc(self: ^ScrapEnemyView) {
    self.retired = true
    self.impact = {}
    charge_present(self.charge, false, 0)
    gd.node_set_process(self.owner, false)
}

enemy_view_take_impact :: proc(self: ^ScrapEnemyView) -> Enemy_Impact {
    result := self.impact
    self.impact = {}
    return result
}

enemy_view_present :: proc(self: ^ScrapEnemyView, value: display.Mob_View) {
    if !self.ready || self.retired || !enemy_style_valid(self.skin) {
        return
    }

    self.live = true

    if self.painted && value.tick > self.tick && value.hp < self.hp {
        self.hurt, self.wobble = .3, .4
        self.impact = {value, self.hp - value.hp, true}
    }

    if !self.painted {
        self.previous = value.position
    }

    self.hp, self.tick, self.painted = value.hp, value.tick, true
    self.value = value
    skin := self.skin

    if self.kind != value.kind {
        self.kind, self.clock, self.row = value.kind, 0, 255
        gd.sprite2d_set_region_enabled(self.body, value.prop)
        gd.sprite2d_set_texture(self.body, cast(gd.Texture2d)skin.texture)
        gd.sprite2d_set_hframes(self.body, value.prop ? 1 : skin.columns)
        gd.sprite2d_set_vframes(self.body, value.prop ? 1 : 4)

        if value.prop {
            gd.sprite2d_set_region_rect(self.body, {skin.region_position, skin.region_size})
        }
    }

    gd.node2d_set_scale(self.body, self.body_scale * value.scale)
    gd.canvas_item_set_visible(self.body, !value.prop || value.hp > 0)
    telegraph_present(
        self.telegraph,
        value.telegraph,
        value.charged_attack ? f32(1) : value.growth,
        value.telegraph_radius,
    )
    charge_present(self.charge, value.charged_attack && value.telegraph, value.growth)
}

scrap_enemy_view_process :: proc(self: ^ScrapEnemyView, dt: f64) {
    dt := dt

    if !self.ready || self.retired {
        return
    }

    if self.preview && !self.live {
        dt *= self.preview_speed
        sample := self.preview_value
        sample.growth = f32(self.preview_fraction)
        sample.near = self.preview_phase == 1
        sample.telegraph = self.preview_phase == 2 && self.preview_value.telegraph

        if self.preview_phase == 4 {
            sample.hp = 0
        }

        enemy_view_present(self, sample)
        self.live = false
    }

    if !self.painted {
        return
    }

    value := self.value
    skin := self.skin
    tint := gd.Color(value.tint)
    self.flick += dt * 22

    if value.pulse {
        tint.g = min(tint.g + (1 + math.sin(f32(self.flick))) * .125, 1)
    }

    tint *= skin.tint

    if self.hurt > 0 && value.hp > 0 {
        fraction := self.hurt / .3
        tint.r += (1.8 - tint.r) * fraction
        tint.g += (1.4 - tint.g) * fraction
        tint.b += (1.4 - tint.b) * fraction
    }

    self.hurt = max(0, self.hurt - f32(dt))
    gd.canvas_item_set_modulate(self.body, tint)

    if value.prop {
        return
    }

    moving := abs(value.position[0] - self.previous[0]) + abs(value.position[1] - self.previous[1]) > .2
    attacking := !moving && value.near || value.telegraph
    row := value.hp == 0 ? u8(3) : attacking ? u8(1) : moving ? u8(0) : u8(2)

    if row != self.row {
        self.row, self.clock = row, 0
    }

    self.clock += dt * f64(row == 3 ? skin.death_fps : skin.fps)
    frames :=
        row == 3 ? skin.death_frames : row == 2 ? skin.idle_frames : row == 1 ? skin.attack_frames : skin.walk_frames
    frame := row == 3 ? min(int(self.clock), int(frames) - 1) : int(self.clock) % int(frames)
    gd.sprite2d_set_frame(self.body, gd.Int(int(row) * int(skin.columns) + frame))

    if row == 1 {
        gd.sprite2d_set_flip_h(self.body, value.prey_left)
    } else if moving {
        gd.sprite2d_set_flip_h(self.body, value.position[0] < self.previous[0])
    }

    if row == 3 {
        tint = skin.tint
        tint.a *= 1 - min(f32(self.clock) / skin.death_fps * 1.2, 1) * .35
        gd.canvas_item_set_modulate(self.body, tint)
        gd.node2d_set_rotation(self.body, gd.Float(self.body_angle))
    } else {
        self.wobble = max(0, self.wobble - f32(dt))
        gd.node2d_set_rotation(
            self.body,
            gd.Float(self.body_angle + math.sin(self.wobble * 34) * .12 * self.wobble / .5),
        )
    }

    self.previous = value.position
}

@(gd_method)
scrap_enemy_view_preview_refresh :: proc(self: ^ScrapEnemyView) -> bool {
    if !self.preview || self.live || self.retired {
        return false
    }

    value, report := enemy_preview_value(cast(gd.Resource)self.preview_state)
    self.preview_error = report

    if report.error != .None || !enemy_preview_capture_style(self) {
        return false
    }

    self.preview_value = value
    self.ready = self.body != nil && self.telegraph != nil && self.charge != nil
    self.kind, self.row, self.painted = 255, 255, false
    return self.ready
}

@(gd_method)
scrap_enemy_view_preview_apply :: proc(self: ^ScrapEnemyView, phase: gd.Int, fraction, speed: gd.Float) {
    if !self.preview || self.live || self.retired {
        return
    }

    if self.preview_phase != phase {
        self.clock = 0
        self.row = 255
    }

    self.preview_phase = clamp(phase, 0, 4)
    self.preview_fraction = clamp(f64(fraction), 0, 1)
    self.preview_speed = clamp(f64(speed), 0, 4)

    if self.charge != nil {
        self.charge.playback = self.preview_speed
    }

    if phase == 3 {
        self.hurt, self.wobble = .3, .4
    }
}

@(gd_method)
scrap_enemy_view_preview_radius :: proc(self: ^ScrapEnemyView) -> gd.Float {
    return gd.Float(self.preview_value.telegraph_radius)
}

@(gd_method)
scrap_enemy_view_preview_message :: proc(self: ^ScrapEnemyView) -> string {
    if self.preview_error.error != .None {
        return fmt.tprintf("%s: %s", d.report_path(&self.preview_error), d.report_message(&self.preview_error))
    }

    return "Preview refreshed. Live games are unchanged."
}

@(gd_method)
scrap_enemy_view_preview_phase :: proc(self: ^ScrapEnemyView) -> gd.Int {
    return self.preview_phase
}

// Preview owns a validated Resource copy, so a rejected appearance refresh also
// preserves prior frames/texture/tuning instead of borrowing a mutated candidate.
enemy_preview_capture_style :: proc(self: ^ScrapEnemyView) -> bool {
    source := rt.script_of(cast(gd.Object)self.appearance, ScrapEnemyStyle)

    if !enemy_style_valid(source) {
        self.preview_error = d.problem(.Invalid, "$appearance", "invalid frame counts, texture or timing")
        return false
    }

    candidate := gd.resource_duplicate(cast(gd.Resource)self.appearance, false)
    style := rt.script_of(cast(gd.Object)candidate, ScrapEnemyStyle)

    if !enemy_style_valid(style) {
        gd.release_ref(candidate)
        return false
    }

    prior := self.preview_appearance
    self.preview_appearance = candidate
    self.skin = style
    gd.release_ref(prior)
    return true
}

scrap_enemy_view_exit_tree :: proc(self: ^ScrapEnemyView) {
    gd.release_ref(self.preview_appearance)
    self.preview_appearance = nil
}

@(gd_method)
scrap_enemy_view_preview_can_refresh :: proc(self: ^ScrapEnemyView) -> bool {
    return self.preview && !self.live && !self.retired
}
