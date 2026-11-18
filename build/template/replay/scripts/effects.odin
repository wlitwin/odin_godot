package scripts

import gd "godot:godot"
import net "godot:replay/net"
import v "godot:replay/view"
import scene "godot:replay/godot/scene"
import game "../shared/game"

Starter_Effects :: struct {
    flash:          scene.Effect_Route2(net.Net_Event(game.Event), u16, gd.Node2d),
    sound:          scene.Audio_Route(net.Net_Event(game.Event)),
    pickup:         gd.Audio_Stream,
    epoch, retired: u64,
    ready:          bool,
}

effects_open :: proc(fx: ^Starter_Effects, parent: gd.Node, epoch: u64) -> bool {
    fx.pickup = cast(gd.Audio_Stream)gd.load("res://effects/pickup.wav")
    if fx.pickup == nil {return false}
    binding := scene.Effect_Binding(net.Net_Event(game.Event), u16, gd.Node2d) {
        project = proc(event: net.Net_Event(game.Event)) -> (v.Entity_View(u16), bool) {
            if event.kind != .Gameplay {return {}, false}
            color: [4]f32 = event.value.seat == 1 ? [4]f32{0.25, 0.75, 1, 1} : [4]f32{1, 0.5, 0.25, 1}
            return {pose = {position = {320, 180}}, scale = {1, 1}, color = color, value = event.value.seat}, true
        },
        animate = proc(value: v.Entity_View(u16), age, seconds: f64) -> v.Entity_View(u16) {
            value := value
            fraction := f32(clamp(age / seconds, 0, 1))
            value.scale = {1 + 2 * fraction, 1 + 2 * fraction}
            value.color[3] = 1 - fraction
            value.pose.position[1] -= 20 * fraction
            return value
        },
        view = {
            attach = proc(_: rawptr, node: gd.Node2d) -> (gd.Node2d, bool) {return node, true},
            paint = proc(_: rawptr, _: ^gd.Node2d, _: scene.Effect_State(u16)) {},
        },
    }
    if !scene.effect_route_load(&fx.flash, parent, "res://effects/pickup.tscn", epoch, 0.45, binding, capacity = 8) {
        effects_close(fx); return false
    }
    if !scene.audio_route_init(
        &fx.sound,
        parent,
        epoch,
        pickup_sound,
        fx,
        .Confirmed,
        world_voices = 0,
        screen_voices = 2,
    ) {
        effects_close(fx); return false
    }
    fx.epoch = epoch
    fx.ready = true
    return true
}

pickup_sound :: proc(raw: rawptr, event: net.Net_Event(game.Event)) -> (scene.Audio_Cue, bool) {
    if event.kind != .Gameplay {return {}, false}
    fx := cast(^Starter_Effects)raw
    return {stream = fx.pickup, pitch = 1, gain_db = -8}, true
}

effects_change :: proc(fx: ^Starter_Effects, change: v.Change(net.Net_Event(game.Event))) {
    if !fx.ready {return}
    epoch := change.occurrence.id.epoch
    if epoch > fx.epoch {
        scene.effect_route_epoch(&fx.flash, epoch, 0)
        scene.audio_route_epoch(&fx.sound, epoch, 0)
        fx.epoch = epoch; fx.retired = 0
    }
    // Pass the original ID/kind/confirmation to both routes. False normally
    // means update, cancel, filtering or duplicate suppression, not an error.
    scene.effect_route_change(&fx.flash, change)
    scene.audio_route_change(&fx.sound, change)
}

// Call after draining the Session's delivered changes. The journal can still
// have another bounded chunk queued; do not retire past those delayed Begins.
// This frontier is for gameplay events, not recovered Action_Result notices.
effects_retire :: proc(self: ^ReplayStarter) {
    fx := &self.effects
    s := &self.session
    if !fx.ready || s.change_count != 0 || s.reset_index < len(s.reset_changes) {return}
    epoch, through: u64
    if s.authority {
        epoch = s.server.cfg.epoch; through = s.server.timeline.head
    } else {
        if !s.client.has_world || s.client.phase != .Running || s.client.journal.queue_count != 0 {return}
        epoch = s.client.cfg.epoch
        through = min(s.client.journal.confirmed, s.client.journal.watch_tick)
    }
    if epoch == fx.epoch && through > fx.retired {
        scene.effect_route_retire(&fx.flash, through)
        scene.audio_route_retire(&fx.sound, through)
        fx.retired = through
    }
}

effects_frame :: proc(fx: ^Starter_Effects, dt: f64) -> bool {
    return fx.ready && scene.effect_route_frame(&fx.flash, dt) == .None
}

effects_close :: proc(fx: ^Starter_Effects) {
    scene.effect_route_destroy(&fx.flash)
    scene.audio_route_destroy(&fx.sound)
    if fx.pickup != nil {gd.release_ref(fx.pickup)}
    fx^ = {}
}
