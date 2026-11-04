package cave_upgrade

import net "godot:replay/net"
import r "godot:replay"
import game "../cave"

CONTENT_4 :: u64(0x4341564552504c34)

// C5 changes transition policy, not the value layout or valid-state predicate.
model4 :: proc() -> net.Model(World_7, game.Control, game.Action, game.Event, game.SEATS) {
    return {
        control_valid = game.control_valid,
        action_valid = game.action_valid,
        state_valid = world7_valid,
        action = proc(_: ^World_7, _: u16, _: game.Action, _: ^r.Step(game.Event)) -> bool {
            panic("archive-only C4 model cannot execute")
        },
    }
}

convert_world4 :: proc(world: World_7) -> (game.World, bool) {
    return convert_world7(world)
}
