package replay_scrapyard

import "core:math"
import gd "godot:godot"
import rgd "godot:replay/godot"
import flow "../shared/flow"

Screen_Fx :: struct {
    state: flow.Screen_State,
    base_zoom: [2]f32,
}

screen_ready :: proc(self: ^ReplayScrapyard) {
    self.screen_fx[0].base_zoom = gd.camera2d_get_zoom(self.camera)
}

screen_motion_setting :: proc(self: ^ReplayScrapyard) {
    if self.settings[0].value.shake_off {
        self.screen_fx[0].state.kick = 0
        self.audio[0].shake = 0
        gd.camera2d_set_zoom(self.camera, self.screen_fx[0].base_zoom)
        gd.camera2d_set_offset(self.camera, {})
    }
}

screen_frame :: proc(self: ^ReplayScrapyard, dt: f64) {
    s := &self.screen_fx[0]
    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        gd.canvas_item_set_visible(self.vignette, false)
        gd.canvas_item_set_visible(self.floor_veil, false)
        return
    }

    epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
    seat := rgd.session_seat(self.session)
    active := seat > 0 && frame.state.players[seat - 1].in_yard
    hp := active ? frame.state.players[seat - 1].hp : u8(0)
    boss := false

    for alive, i in frame.state.mobs.alive {
        if alive && frame.state.mobs.values[i].kind == 4 && frame.state.mobs.values[i].hp > 0 {
            boss = true
            break
        }
    }

    view := flow.screen_step(
        &s.state,
        epoch,
        frame.state.run,
        frame.state.floor,
        hp,
        active,
        boss,
        self.settings[0].value.shake_off,
        dt,
    )
    gd.camera2d_set_zoom(self.camera, s.base_zoom + [2]f32{view.zoom_add, view.zoom_add})
    gd.canvas_item_set_visible(self.vignette, view.vignette > 0)
    gd.canvas_item_set_modulate(self.vignette, {1, 1, 1, view.vignette})
    gd.canvas_item_set_visible(self.floor_veil, view.fade > 0)
    gd.canvas_item_set_modulate(self.floor_veil, {1, 1, 1, view.fade})
}

screen_death :: proc(self: ^ReplayScrapyard, position: [2]f32, boss: bool) {
    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || seat == 0 {
        return
    }

    delta := position - frame.state.players[seat - 1].position

    if boss || math.sqrt(delta[0] * delta[0] + delta[1] * delta[1]) < 260 {
        flow.screen_kick(&self.screen_fx[0].state, boss ? 0.1 : 0.035, self.settings[0].value.shake_off)
    }
}
