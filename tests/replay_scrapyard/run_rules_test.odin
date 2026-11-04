package replay_scrapyard_test

import "core:testing"
import r "godot:replay"
import game "../../examples/replay_scrapyard/shared/game"
import arena "../../examples/replay_scrapyard/shared/arena"

@(test)
horde_and_boss_plans_keep_the_original_precedence :: proc(t: ^testing.T) {
    w := run_world()
    w.rules = game.RUN_RULES
    w.rules.barrels = 0
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = storage[:],
    }
    w.floor, w.layout = 3, arena.generate(w.seed, 3)
    game.arm_floor(&w, &ctx, false)
    testing.expect_value(t, w.wave_count, u8(1))
    testing.expect_value(t, w.waves[0].count, u16(54))
    w.floor, w.layout = 12, arena.generate(w.seed, 12)
    game.arm_floor(&w, &ctx, false)
    testing.expect_value(t, w.waves[0].count, u16(0))
    testing.expect_value(t, w.mobs.count, u32(1))
    testing.expect_value(t, w.mobs.values[0].kind, u8(4))
}

@(test)
ghosts_do_not_block_gate_and_are_reaped_on_the_turn :: proc(t: ^testing.T) {
    w := clear_world()
    w.players[1].in_yard, w.players[1].connected = true, false
    w.players[1].position, w.players[1].cores, w.players[1].parts = [2]f32{500, 1040}, 5, 1
    testing.expect(t, game.on_gate(&w))
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = storage[:],
    }
    game.turn_floor(&w, false, &ctx)
    testing.expect(t, !w.players[1].in_yard)
    testing.expect_value(t, w.players[1].cores, u32(5))
    testing.expect_value(t, w.players[1].parts, u8(1))
    w.players[1].connected = true
    game.enter(&w, 2, &ctx)
    testing.expect(t, w.players[1].in_yard && w.players[1].warp > 1)
}
