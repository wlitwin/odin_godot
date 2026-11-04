package scrapyard_upgrade

import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import d "godot:replay/diagnostic"
import game "../game"

RECORDING_50 :: d.Recording_Context {
    content = CONTENT_50,
    build = 1,
    tick_hz = game.HZ,
}

// Frozen content-50 catalog plus existing authority observation policy. New
// turret definitions/pool are zero, preserving old behavior.
model_50 :: proc() -> net.Model(World_50, game.Control, Action_50, game.Event, game.SEATS) {
    current := game.model()
    return {
        authority = {
            id = game.SUCCESSION_POLICY,
            apply = proc(old: ^World_50, observation: net.Authority_Observation, ctx: ^r.Step(game.Event)) {
                w, _ := map_world_50(old^)
                game.observe_authority(&w, observation, ctx)
                old^ = world_50(w)
            },
        },
        control_valid = game.control_valid,
        state_valid = state_50_valid,
        action_valid = action_50_valid,
        action_schedule = schedule_50(),
        hold = current.hold,
        event_owner = current.event_owner,
        event_policy = current.event_policy,
        action_admit = action_50_admit,
        step_view = proc(
            old: ^World_50,
            c: [game.SEATS]game.Control,
            v: [game.SEATS]net.View_Time,
            j, l: u64,
            ctx: ^r.Step(game.Event),
        ) {
            w, _ := map_world_50(old^)
            game.step_view(&w, c, v, j, l, ctx)
            old^ = world_50(w)
        },
        action = proc(old: ^World_50, seat: u16, a: Action_50, ctx: ^r.Step(game.Event)) -> bool {
            w, _ := map_world_50(old^)
            mapped, valid := map_action_50(a)

            if !valid {
                return false
            }

            ok := game.action(&w, seat, mapped, ctx)
            old^ = world_50(w)
            return ok
        },
        reset_player = proc(old: ^World_50, seat: u16, ctx: ^r.Step(game.Event)) {
            w, _ := map_world_50(old^)
            game.reset_player(&w, seat, ctx)
            old^ = world_50(w)
        },
        replication = {
            id = game.PUBLIC_WORLD_POLICY,
            project = proc(
                frame: r.Frame(World_50),
                held: [game.SEATS]game.Control,
                _: net.Recipient,
            ) -> (
                net.Replica(World_50, game.Control, game.SEATS),
                bool,
            ) {
                w := frame.state
                w.hit_history = {}
                return {w, held}, true
            },
            valid = proc(v: net.Replica(World_50, game.Control, game.SEATS), _: net.Recipient) -> bool {
                if !state_50_valid(v.state) || !reflect.equal(v.state.hit_history, World_50{}.hit_history) {
                    return false
                }

                for c in v.held {
                    if !game.control_valid(c) {
                        return false
                    }
                }

                return true
            },
            event = proc(_: r.Frame(World_50), _: net.Recipient, e: r.Occurrence(game.Event)) -> (game.Event, bool) {
                return e.value, true
            },
        },
        group = {id = game.PUBLIC_PREDICTION, project = proc(frame: r.Frame(World_50), _: u16) -> World_50 {
                w := frame.state
                w.hit_history = {}
                return w
            }, valid = proc(w: World_50, seat: u16) -> bool {
                return seat > 0 && seat <= game.SEATS && state_50_valid(w)
            }},
    }
}
