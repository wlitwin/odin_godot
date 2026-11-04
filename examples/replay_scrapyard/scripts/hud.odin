//gd:extends Control
//gd:class ReplayScrapyardHud
package replay_scrapyard

import "core:fmt"
import "core:math"
import gd "godot:godot"
import display "../shared/presentation"
import content "../shared/content"

// The authored scene owns layout, animation time and child references. It
// receives a detached HUD value and never reads a World or Session.
ReplayScrapyardHud :: struct {
    owner: gd.Control,
    vitals: gd.Nine_Patch_Rect `gd:"onready=Vitals"`,
    health_fill: gd.Color_Rect `gd:"onready=Vitals/Fill"`,
    health_text: gd.Label `gd:"onready=Vitals/Text"`,
    pips: [3]gd.Color_Rect `gd:"onready=Vitals/Pip%d/Fill"`,
    statuses: [4]gd.Color_Rect `gd:"onready=Vitals/St%d"`,
    ammo: gd.Nine_Patch_Rect `gd:"onready=Ammo"`,
    ammo_gun: gd.Label `gd:"onready=Ammo/Gun"`,
    ammo_count: gd.Label `gd:"onready=Ammo/Count"`,
    ammo_state: gd.Label `gd:"onready=Ammo/State"`,
    boss: gd.Nine_Patch_Rect `gd:"onready=BossPlate"`,
    boss_fill: gd.Color_Rect `gd:"onready=BossPlate/Fill"`,
    boss_name: gd.Label `gd:"onready=BossPlate/Name"`,
    prompt: gd.Label `gd:"onready=Prompt"`,
    health_size, boss_size, ammo_offsets: [2]f32,
    pip_sizes: [3][2]f32,
    status_sizes: [4][2]f32,
    clock: f64,
    value: display.Hud_View,
    counter_height: f32,
    fed: bool,
    preview: bool `gd:"export"`,
}

replay_scrapyard_hud_ready :: proc(self: ^ReplayScrapyardHud) {
    self.health_size = gd.control_get_size(self.health_fill)
    self.boss_size = gd.control_get_size(self.boss_fill)
    self.ammo_offsets = {f32(gd.control_get_offset(self.ammo, .Top)), f32(gd.control_get_offset(self.ammo, .Bottom))}

    for i in 0 ..< 3 {
        background := cast(gd.Control)gd.get_node(self.owner, fmt.ctprintf("Vitals/Pip%d/Bg", i))
        self.pip_sizes[i] = gd.control_get_size(background)
    }

    for node, i in self.statuses {
        self.status_sizes[i] = gd.control_get_size(node)
    }
}

hud_present :: proc(self: ^ReplayScrapyardHud, value: display.Hud_View, counter_height: f32) {
    self.value, self.counter_height, self.fed = value, counter_height, true
}

replay_scrapyard_hud_process :: proc(self: ^ReplayScrapyardHud, dt: f64) {
    if !self.fed && self.preview {
        self.value = {
            inside = true,
            personal = true,
            hp = 5,
            maximum = 10,
            pips = {.25, .75, 1},
            gun_name = content.name("Preview Bolt"),
            ammo = 2,
            mag = 8,
        }
    } else if !self.fed {
        return
    }

    hud_paint(self, self.value, dt, self.counter_height)
}

hud_paint :: proc(self: ^ReplayScrapyardHud, value: display.Hud_View, dt: f64, counter_height: f32) {
    value := value
    gd.canvas_item_set_visible(self.owner, value.inside)

    if !value.inside {
        return
    }

    self.clock += dt
    gd.canvas_item_set_visible(self.vitals, value.personal)
    gd.canvas_item_set_visible(self.ammo, value.personal)
    gd.canvas_item_set_visible(self.prompt, false)

    if value.personal {
        fraction := value.maximum > 0 ? clamp(f32(value.hp) / f32(value.maximum), 0, 1) : f32(0)
        gd.control_set_size(self.health_fill, {self.health_size[0] * fraction, self.health_size[1]}, false)
        gd.color_rect_set_color(self.health_fill, {.85 - fraction * .45, .25 + fraction * .55, .3, 1})
        gd.set_string(self.health_text, "text", fmt.ctprintf("%d/%d", value.hp, value.maximum))

        for fill, slot in value.pips {
            gd.control_set_size(self.pips[slot], {self.pip_sizes[slot][0] * fill, self.pip_sizes[slot][1]}, false)
        }

        for status, i in value.statuses[:value.status_count] {
            gd.color_rect_set_color(self.statuses[i], gd.Color(status.color))
            gd.control_set_size(
                self.statuses[i],
                {self.status_sizes[i][0], self.status_sizes[i][1] * status.fill},
                false,
            )
            gd.canvas_item_set_visible(self.statuses[i], true)
        }

        for i in int(value.status_count) ..< 4 {
            gd.canvas_item_set_visible(self.statuses[i], false)
        }

        hud_magazine(self, value)
        climb := value.clear ? counter_height + 30 : f32(0)
        gd.control_set_offset(self.ammo, .Top, gd.Float(self.ammo_offsets[0] - climb))
        gd.control_set_offset(self.ammo, .Bottom, gd.Float(self.ammo_offsets[1] - climb))

        if value.mounted || value.turret_near {
            text :=
                value.mounted ? cstring("Turret — aim/fire · T to dismount") : value.turret_busy ? cstring("Turret occupied") : cstring("T — operate shared turret")
            gd.set_string(self.prompt, "text", text)
            gd.canvas_item_set_visible(self.prompt, true)
        } else if value.revive {
            text :=
                value.revive_percent > 0 ? fmt.ctprintf("Reviving %d%% — hold F", value.revive_percent) : cstring("Hold F — revive your friend")
            gd.set_string(self.prompt, "text", text)
            gd.canvas_item_set_visible(self.prompt, true)
        }
    }

    gd.canvas_item_set_visible(self.boss, value.boss)

    if value.boss {
        fraction := value.boss_maximum > 0 ? clamp(f32(value.boss_hp) / f32(value.boss_maximum), 0, 1) : f32(0)
        gd.control_set_size(self.boss_fill, {self.boss_size[0] * fraction, self.boss_size[1]}, false)
        gd.set_string(self.boss_name, "text", fmt.ctprintf("SCRAP TITAN  %d/%d", value.boss_hp, value.boss_maximum))
    }
}

hud_magazine :: proc(self: ^ReplayScrapyardHud, value: display.Hud_View) {
    name := value.gun_name
    mag := value.mag
    gd.set_string(self.ammo_gun, "text", fmt.ctprintf("%s", content.name_string(&name)))

    switch value.mode {
    case .Reloading:
        gd.set_string(self.ammo_count, "text", fmt.ctprintf("-- / %d", mag))
        gd.canvas_item_set_modulate(self.ammo_count, {0.7, 0.72, 0.8, 0.8})
        gd.set_string(self.ammo_state, "text", "RELOADING...")
        gd.canvas_item_set_modulate(self.ammo_state, {1, 0.8, 0.4, 1})
    case .Jammed:
        flash := 0.5 + 0.5 * math.sin(f32(self.clock) * 10)
        gd.set_string(self.ammo_count, "text", fmt.ctprintf("%d / %d", value.ammo, mag))
        gd.canvas_item_set_modulate(self.ammo_count, {1, 0.35, 0.3, 0.7 + 0.3 * flash})
        gd.set_string(self.ammo_state, "text", "JAMMED — fire")
        gd.canvas_item_set_modulate(self.ammo_state, {1, 0.3, 0.25, 0.55 + 0.45 * flash})
    case .Ready:
        low := value.ammo <= max(mag / 4, 1)
        gd.set_string(self.ammo_count, "text", fmt.ctprintf("%d / %d", value.ammo, mag))
        gd.canvas_item_set_modulate(self.ammo_count, low ? gd.Color{1, 0.75, 0.4, 1} : gd.Color{0.92, 0.95, 1, 1})
        gd.set_string(self.ammo_state, "text", low ? "low" : "")
        gd.canvas_item_set_modulate(self.ammo_state, {1, 0.75, 0.4, 0.8})
    }
}
