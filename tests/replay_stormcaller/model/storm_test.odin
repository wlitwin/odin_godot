package storm_test
import "core:testing"
import "core:reflect"
import "core:os"
import scenario "godot:replay/testing"
import r "godot:replay"
import net "godot:replay/net"
import p "godot:replay/play"
import game "../../../examples/replay_scrapyard/shared/game"
import content "../../../examples/replay_scrapyard/shared/content"
import display "../../../examples/replay_scrapyard/shared/presentation"
import upgrade "../../../examples/replay_scrapyard/shared/upgrade"

Input :: struct {
    move: [2]f32,
    kill: bool,
}

step :: proc(w: ^game.World, input: Input, ctx: ^r.Step(game.Event)) {
    controls: [game.SEATS]game.Control
    controls[0].move = input.move
    game.step(w, controls, 0, 0, ctx)

    if input.kill {
        n: game.Notices
        game.wound_mob(w, 0, 255, {1, 1}, &n, ctx)
        game.flush(w, &n, ctx)
    }
}

yard :: proc() -> game.World {
    w := game.initial(encounter_count = 0)
    w.stage = .Yard
    w.players[0].connected, w.players[0].in_yard = true, true
    w.players[0].position = {500, 1040}
    w.catalog.mobs[game.STORMCALLER].speed = 0
    assert(game.spawn_mob(&w, game.STORMCALLER, {600, 1040}))
    w.mobs.values[0].next_act = 0
    return w
}

@(test)
windup_is_tick_owned_and_warning_radius_matches_authored_definition :: proc(t: ^testing.T) {
    w := yard()
    tl: r.Timeline(game.World, Input, game.Event)
    assert(r.init(&tl, r.Frame(game.World){state = w}, step) == .None)
    defer r.destroy(&tl)

    for _ in 0 ..< 45 {
        assert(r.advance(&tl, Input{}).error == .None)
    }

    f, _ := r.current(&tl)
    testing.expect(t, f.state.players[0].hp == 10 && f.state.mobs.values[0].tele.left == 1)
    view := display.mobs(f.state, 1)
    testing.expect(t, view.items[0].view.value.charged_attack && view.items[0].view.value.telegraph_radius == 140)
    assert(r.advance(&tl, Input{}).error == .None)
    f, _ = r.current(&tl)
    testing.expect(
        t,
        f.state.players[0].hp == 8 && f.state.mobs.values[0].tele.left == 0 && f.state.mobs.values[0].next_act == 196,
    )
    testing.expect(t, f.state.flashes.count == 1 && game.state_valid(f.state))
    assert(r.advance(&tl, Input{}).error == .None)
    f, _ = r.current(&tl)
    testing.expect_value(t, f.state.players[0].hp, u8(8))
}

@(test)
late_escape_correction_removes_predicted_damage_and_death_interrupts_charge :: proc(t: ^testing.T) {
    predicted, actual: [50]Input

    for &input, i in actual {
        if i >= 9 {
            input.move = {-1, 0}
        }
    }

    result := scenario.correction(r.Frame(game.World){state = yard()}, step, predicted[:], actual[:], 10)
    testing.expect(
        t,
        result.report.phase == .Complete &&
        result.before.state.players[0].hp == 8 &&
        result.after.state.players[0].hp == 10,
    )
    tl: r.Timeline(game.World, Input, game.Event)
    defer r.destroy(&tl)
    f: r.Frame(game.World)
    assert(r.init(&tl, r.Frame(game.World){state = yard()}, step) == .None)

    for tick in 1 ..= 50 {
        assert(r.advance(&tl, Input{kill = tick == 20}).error == .None)
    }

    f, _ = r.current(&tl)
    testing.expect_value(t, f.state.players[0].hp, u8(10))
    testing.expect(t, f.state.mobs.values[0].hp == 0 && f.state.mobs.values[0].tele == (p.Telegraph{}))
}

@(test)
checkpoint_takeover_preserves_remaining_charge_and_fires_once :: proc(t: ^testing.T) {
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    model := game.model()
    model.reset_player = nil
    drive: proc(_: ^net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS), _: u64) -> net.Error
    result := scenario.takeover(r.Frame(game.World){state = yard()}, model, cfg, 20, 48, drive)
    testing.expect(
        t,
        result.report.phase == .Complete &&
        result.before.state.mobs.values[0].tele.left == 26 &&
        result.after.state.players[0].hp == 8 &&
        result.after.state.mobs.values[0].tele.left == 0,
    )

}

@(test)
real_content49_checkpoint_converts_without_inventing_new_attack_configuration :: proc(t: ^testing.T) {
    bytes, error := os.read_entire_file("tests/replay_stormcaller/fixtures/content49.checkpoint", context.allocator)
    assert(error == nil)
    defer delete(bytes)
    old: net.Checkpoint(upgrade.World_49, game.Control, upgrade.Action_50, game.SEATS)
    defer net.checkpoint_destroy(&old)
    testing.expect_value(t, net.checkpoint_decode(&old, bytes, upgrade.model_49(), upgrade.CONTENT_49), net.Error.None)
    converted, err := upgrade.root_49(bytes)
    testing.expect_value(t, err, net.Error.None)
    defer delete(converted)

    if err != .None {
        return
    }

    cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_decode(&cp, converted, game.model(), game.CONTENT) == .None)
    expected, ok := upgrade.map_world_49(old.frame.state)
    testing.expect(t, ok && reflect.equal(cp.frame.state, expected))

    for row in cp.frame.state.catalog.mobs {
        testing.expect_value(t, row.pulse, content.Pulse_Def{})
    }

    testing.expect(t, cp.header.content == game.CONTENT && cp.frame.tick == 12)
}
