package owner_cave_upgrade
import r "godot:replay"
import sc "godot:replay/schema"
import net "godot:replay/net"
import base "../cave"
import game "../owner_cave"

CONTENT_1 :: u64(0x434156454f574e31)

// O1 used exactly C8's action shape. State and control shapes are unchanged.
// These are archive validation callbacks, not a historical gameplay runner.
model_1 :: proc() -> net.Model(game.World, game.Control, base.Action, game.Event, game.SEATS) {
    return {
        control_timing = .Latest_Observation,
        action_timing = .Receipt,
        control_valid = game.control_valid,
        action_valid = base.action_valid,
        state_valid = game.state_valid,
        authority = {id = 1, apply = game.observe_authority},
        step = proc(_: ^game.World, _: [game.SEATS]game.Control, _, _: u64, _: ^r.Step(game.Event)) {
            panic("archive-only model")
        },
        action = proc(_: ^game.World, _: u16, _: base.Action, _: ^r.Step(game.Event)) -> bool {
            panic("archive-only model")
        },
    }
}

map_action :: proc(old: base.Action) -> (game.Action, bool) {
    // Never fabricate the original owner's issue-time pose. O1 actions retain
    // their old accepted-pose interpretation, including refused pending payloads.
    return {
            verb = old.verb,
            index = old.index,
            generation = old.generation,
            aim = old.aim,
            lobby = old.lobby,
            origin_kind = .Accepted_Pose,
        },
        true
}

convert_archive :: proc(bytes: []u8) -> ([]u8, net.Error) {
    meta, _, report := sc.inspect(bytes)

    if report.error != .None {
        return nil, .Invalid_Checkpoint
    }

    if meta.content == CONTENT_2 {
        return net.checkpoint_convert_state(bytes, model_2(), CONTENT_2, game.model(), game.CONTENT, map_world)
    }

    return net.checkpoint_convert_actions(bytes, model_1(), CONTENT_1, game.model(), game.CONTENT, map_action)
}

CONTENT_2 :: u64(0x434156454f574e32)

// O2 recordings execute their original no-dweller-impact rule. Never silently
// verify a historical recording with the new event-producing model.
model_2 :: proc() -> net.Model(game.World, game.Control, game.Action, game.Event, game.SEATS) {
    m := game.model()
    m.step = proc(w: ^game.World, c: [game.SEATS]game.Control, j, l: u64, ctx: ^r.Step(game.Event)) {
        game.step_impacts(w, c, j, l, ctx, false)
    }
    return m
}

map_world :: proc(w: game.World) -> (game.World, bool) {
    return w, game.state_valid(w)
}
