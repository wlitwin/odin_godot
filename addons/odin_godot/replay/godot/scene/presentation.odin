package replay_godot_scene

import replaygd "godot:replay/godot"

import r "godot:replay"
import v "godot:replay/view"

// Call once after session_frame/room_frame, outside simulation. Keep the phase
// with the presentation owner and clear it when leaving for a different session.
session_tick_phase :: proc(s: ^replaygd.Session($S, $C, $A, $E, $N), phase: ^v.Tick_Phase, dt: f64) -> bool {
    if s == nil || !s.ready {
        return false
    }

    if s.authority {
        return v.tick_phase(
            phase,
            s.server.cfg.epoch,
            0,
            s.server.timeline.head,
            r.clock_alpha(&s.clock),
            dt,
            s.server.cfg.hz,
            !s.fenced && !s.clock.paused,
        )
    }

    if !s.client.has_world {
        return false
    }

    // Observers do not commit local simulation ticks. A received head starts its
    // own visual interval; the unrelated local clock fraction would jump ahead.
    if s.client.spectator {
        return v.tick_phase(
            phase,
            s.client.cfg.epoch,
            s.client.view_reset,
            s.client.timeline.head,
            0,
            dt,
            s.client.cfg.hz,
            !s.fenced && !s.clock.paused && s.client.phase == .Running,
        )
    }

    return v.tick_phase(
        phase,
        s.client.cfg.epoch,
        s.client.view_reset,
        s.client.timeline.head,
        r.clock_alpha(&s.clock),
        dt * s.client.clock_scale,
        s.client.cfg.hz,
        !s.fenced && !s.clock.paused && s.client.phase == .Running,
    )
}
