package dockyard_duo

import b "godot:box3d"
import rgd "godot:replay/godot"
import ph "godot:replay/physics"
import r "godot:replay"
import v "godot:replay/view"

Remote_Robot_Scope :: struct {
    epoch, reset, generation, serial: u64,
    body: b.Body_Key,
    lifetime: u32,
    seat: u16,
}

Remote_Robot_View :: struct {
    scope: Remote_Robot_Scope,
    tick, corrections: u64,
    raw: [3]f32,
    smoother: v.Smoother3,
}

@(private)
revised_remote_position :: proc(self: ^DockyardDuo, scope: Remote_Robot_Scope, tick: u64) -> ([3]f32, bool) {
    checkpoint, error := rgd.session_checkpoint(self.state.session, tick)
    if error != .None {return {}, false}
    defer r.complete_checkpoint_destroy(&checkpoint)
    if checkpoint.epoch != scope.epoch || checkpoint.frame.state.lives[scope.seat] != scope.lifetime ||
       checkpoint.frame.state.bodies[scope.seat] != scope.body {return {}, false}

    body, read_error := ph.body_state(&checkpoint, scope.body)
    p := body.pose.position
    return {p.x, p.y, p.z}, read_error == .None
}

// Only reconcile an already displayed tick. Comparing consecutive ticks would
// smooth ordinary driving and introduce a delay even on a perfect connection.
remote_robot_present :: proc(self: ^DockyardDuo, state: ^Game, epoch, tick: u64, positions: [2][3]f32, dt: f64) {
    track := &self.remote_robot
    s := self.state.session
    local := rgd.session_seat(s)
    if s.authority || s.client.spectator || local < 1 || local > 2 {
        track^ = {}
        return
    }

    seat := 3 - local
    raw := positions[seat - 1]
    scope := Remote_Robot_Scope{
        epoch = epoch, reset = s.client.view_reset, generation = s.client.generation,
        serial = s.client.serial, body = state.bodies[seat], lifetime = state.lives[seat], seat = seat,
    }
    corrections := s.client.stats.corrections
    if track.scope != scope || tick < track.tick || corrections < track.corrections {
        track.smoother = {}
    } else if corrections != track.corrections {
        revised := raw
        found := true
        if track.tick != tick {
            revised, found = revised_remote_position(self, scope, track.tick)
        }
        v.smooth3_correct(&track.smoother, track.raw, revised, discontinuity = !found)
    }
    v.smooth3_present(&track.smoother, {raw, {0, 0, 0, 1}}, dt)
    track.scope, track.tick, track.corrections, track.raw = scope, tick, corrections, raw
}
