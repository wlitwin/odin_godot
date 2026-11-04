package turret_test
import "core:testing"
import "core:reflect"
import "core:os"
import r "godot:replay"
import net "godot:replay/net"
import game "../../../examples/replay_scrapyard/shared/game"
import upgrade "../../../examples/replay_scrapyard/shared/upgrade"
import scenario "godot:replay/testing"

TURRET :: u8(7)

Input :: struct {
    mount, release, deploy, fire: [game.SEATS]bool,
    move:                         [game.SEATS][2]f32,
    target:                       r.Handle(game.Turret),
}

step :: proc(w: ^game.World, input: Input, ctx: ^r.Step(game.Event)) {
    for i in 0 ..< game.SEATS {
        if input.deploy[i] {
            game.cast_ability(w, u16(i + 1), 0, [2]f32{630, 1040}, true, ctx)
        }

        if input.release[i] {
            game.action(w, u16(i + 1), game.Action{kind = .Turret_Dismount, turret = input.target}, ctx)
        }

        if input.mount[i] {
            game.action(w, u16(i + 1), game.Action{kind = .Turret_Mount, turret = input.target}, ctx)
        }
    }

    controls: [game.SEATS]game.Control

    for &c, i in controls {
        c = {
            move = input.move[i],
            aim  = {1, 0},
            fire = input.fire[i],
        }
    }

    game.step(w, controls, 0, 0, ctx)
}

yard :: proc(ammo: u16 = 3) -> game.World {
    w := game.initial(encounter_count = 0)
    w.stage = .Yard

    for &player, i in w.players[:2] {
        player.connected, player.in_yard = true, true
        player.position = {600, f32(1030 + i * 20)}
        player.profile.abilities = {TURRET, 2}
    }

    w.catalog.abilities[TURRET].turret.ammo = ammo
    w.catalog.abilities[TURRET].turret.cadence = 1
    return w
}

spawned :: proc(ammo: u16 = 3) -> game.World {
    timeline: r.Timeline(game.World, Input, game.Event)
    assert(r.init(&timeline, r.Frame(game.World){state = yard(ammo)}, step) == .None)
    defer r.destroy(&timeline)
    result := r.advance(&timeline, Input{deploy = {0 = true}})
    assert(result.error == .None)
    frame, _ := r.current(&timeline)
    assert(frame.state.turrets.count == 1)
    return frame.state
}

@(test)
shared_ammo_handoff_and_final_shot_dismount :: proc(t: ^testing.T) {
    w := spawned()
    target := r.Handle(game.Turret){0, w.turrets.generations[0]}
    timeline: r.Timeline(game.World, Input, game.Event)
    assert(r.init(&timeline, r.Frame(game.World){tick = w.clock, state = w}, step) == .None)
    defer r.destroy(&timeline)
    // Same tick claims have the normal deterministic seat ordering in this input.
    assert(
        r.advance(&timeline, Input{mount = {0 = true, 1 = true}, target = target, fire = {0 = true}}).error == .None,
    )
    frame, _ := r.current(&timeline)
    testing.expect(t, frame.state.turrets.values[0].operator.seat == 1 && frame.state.turrets.values[0].ammo == 2)
    p0 := frame.state.players[0].position
    assert(r.advance(&timeline, Input{move = {0 = {1, 0}}, target = target}).error == .None)
    frame, _ = r.current(&timeline)
    testing.expect_value(t, frame.state.players[0].position, p0)
    assert(
        r.advance(&timeline, Input{release = {0 = true}, mount = {1 = true}, fire = {1 = true}, target = target}).error ==
        .None,
    )
    frame, _ = r.current(&timeline)
    testing.expect(t, frame.state.turrets.values[0].operator.seat == 2 && frame.state.turrets.values[0].ammo == 1)
    assert(r.advance(&timeline, Input{fire = {1 = true}, target = target}).error == .None)
    frame, _ = r.current(&timeline)
    testing.expect(t, frame.state.turrets.count == 0 && !game.turret_operator(&frame.state, 2))
    testing.expect(
        t,
        frame.state.players[0].shots == 1 && frame.state.players[1].shots == 2,
        "last turret round must not also fire the handheld gun",
    )
    testing.expect(t, game.state_valid(frame.state))
}

@(test)
rejects_stale_remote_and_occupied_targets :: proc(t: ^testing.T) {
    w := spawned()
    target := r.Handle(game.Turret){0, w.turrets.generations[0]}
    testing.expect(t, game.turret_mount(&w, 1, target))
    testing.expect(t, !game.turret_mount(&w, 2, target) && !game.turret_dismount(&w, 2, target))
    w.players[0].connected = false
    game.turret_cleanup(&w)
    testing.expect(t, w.turrets.values[0].operator.seat == 0 && game.turret_mount(&w, 2, target))
    w.players[1].warp += 1
    game.turret_cleanup(&w)
    testing.expect(t, !game.turret_operator(&w, 2))
    assert(game.turret_mount(&w, 2, target))
    w.players[1].generation += 1
    game.turret_cleanup(&w)
    testing.expect(t, w.turrets.values[0].operator == (game.Credit{}))
    w.players[1].position = {100, 100}
    testing.expect(t, !game.turret_mount(&w, 2, target))
    saved := w.turrets.values[0]
    assert(r.pool_remove(&w.turrets, target))
    next, ok := r.pool_insert(&w.turrets, saved)
    assert(ok)
    testing.expect(t, next.generation != target.generation && !game.turret_mount(&w, 2, target))
}

@(test)
placement_occlusion_capacity_and_muzzle_clearance :: proc(t: ^testing.T) {
    w := yard()
    w.layout.covers = {}
    w.players[0].position = {500, 500}
    w.layout.covers[0] = {
        x = 520,
        y = 480,
        w = 20,
        h = 40,
    }
    events: [16]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = 1,
        epoch  = 1,
        events = events[:],
    }
    // Both intersecting cover and throwing through it reject without spending a cast.
    testing.expect(t, !game.cast_ability(&w, 1, 0, {530, 500}, true, &ctx))
    testing.expect(t, !game.cast_ability(&w, 1, 0, {560, 500}, true, &ctx))
    testing.expect(t, w.players[0].casts == 0 && w.players[0].ability_cd[0].remaining == 0 && w.turrets.count == 0)
    testing.expect(t, !game.turret_deploy(&w, {500, 500}, 255, {1, 1}, &ctx))
    testing.expect(t, !game.turret_deploy(&w, {0, 500}, TURRET, {1, 1}, &ctx))
    assert(game.cast_ability(&w, 1, 0, {500, 500}, true, &ctx))
    handle := r.Handle(game.Turret){0, w.turrets.generations[0]}
    w.players[1].position = {560, 500}
    testing.expect(t, !game.turret_mount(&w, 2, handle), "cannot operate through cover even within use radius")
    assert(game.turret_mount(&w, 1, handle))
    w.players[0].aim = {1, 0}
    game.turret_fire(&w, 1, &ctx)
    testing.expect_value(t, w.shots.values[0].position, [2]f32{512, 500})
    feedback: game.Notices
    game.shot_step(&w, &feedback, &ctx)
    testing.expect(t, w.shots.count == 0, "first turret bullet must hit nearby cover")
    assert(game.turret_dismount(&w, 1, handle))
    w.layout.covers = {}

    // Capacity refusal leaves the already established cooldown/cast counts intact.
    for i in 1 ..< game.MAX_TURRETS {
        assert(game.turret_deploy(&w, {500 + f32(i) * 40, 500}, TURRET, {1, 1}, &ctx))
    }

    w.players[0].position = {900, 500}
    w.players[0].ability_cd[0] = {}
    casts := w.players[0].casts
    testing.expect(t, !game.cast_ability(&w, 1, 0, {900, 500}, true, &ctx))
    testing.expect(
        t,
        w.turrets.count == game.MAX_TURRETS &&
        w.players[0].casts == casts &&
        w.players[0].ability_cd[0].remaining == 0,
    )
}

@(test)
late_claim_correction_removes_predicted_shots_and_ammo_spend :: proc(t: ^testing.T) {
    w := spawned()
    target := r.Handle(game.Turret){0, w.turrets.generations[0]}
    predicted, actual: [12]Input

    for &input in predicted {
        input.fire[0] = true
        input.target = target
    }

    predicted[0].mount[0] = true

    for &input in actual {
        input.target = target
    }

    actual[0].mount[1] = true
    result := scenario.correction(
        r.Frame(game.World){tick = w.clock, state = w},
        step,
        predicted[:],
        actual[:],
        w.clock + 1,
    )
    testing.expect(
        t,
        result.report.phase == .Complete &&
        result.before.state.players[0].shots > 0 &&
        result.after.state.players[0].shots == 0,
    )
    testing.expect(
        t,
        result.after.state.turrets.values[0].ammo == 3 && result.after.state.turrets.values[0].operator.seat == 2,
    )
}

@(test)
content50_checkpoint_upgrades_with_no_turret_or_occupation :: proc(t: ^testing.T) {
    bytes, error := os.read_entire_file("tests/replay_turret/fixtures/content50.checkpoint", context.allocator)
    assert(error == nil)
    defer delete(bytes)
    source: net.Checkpoint(upgrade.World_50, game.Control, upgrade.Action_50, game.SEATS)
    defer net.checkpoint_destroy(&source)
    assert(net.checkpoint_decode(&source, bytes, upgrade.model_50(), upgrade.CONTENT_50) == .None)
    converted, result := upgrade.root_50(bytes)
    testing.expect_value(t, result, net.Error.None)
    defer delete(converted)

    if result != .None {
        return
    }

    target: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&target)
    assert(net.checkpoint_decode(&target, converted, game.model(), game.CONTENT) == .None)
    expected, ok := upgrade.map_world_50(source.frame.state)
    testing.expect(t, ok && reflect.equal(target.frame.state, expected) && target.frame.state.turrets.count == 0)

    for ability in target.frame.state.catalog.abilities {
        testing.expect_value(t, ability.turret, game.World{}.catalog.abilities[0].turret)
    }
}

@(test)
occupied_checkpoint_takeover_preserves_ammo_operator_and_cadence :: proc(t: ^testing.T) {
    w := spawned(5)
    w.catalog.abilities[TURRET].turret.cadence = 10
    target := r.Handle(game.Turret){0, w.turrets.generations[0]}
    assert(game.turret_mount(&w, 1, target))
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    model := game.model()
    model.reset_player = nil

    drive := proc(
        s: ^net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS),
        tick: u64,
    ) -> net.Error {
        return net.server_local(s, game.Control{aim = {1, 0}, fire = tick <= 42})
    }

    result := scenario.takeover(r.Frame(game.World){tick = w.clock, state = w}, model, cfg, 5, 60, drive)
    testing.expect(t, result.report.phase == .Complete)
    testing.expect(
        t,
        result.before.state.turrets.values[0].operator.seat == 1 &&
        result.before.state.turrets.values[0].ammo == 4 &&
        result.before.state.turrets.values[0].next_shot == 12,
    )
    testing.expect(
        t,
        result.after.state.turrets.count == 0 &&
        result.after.state.players[0].shots == 5 &&
        !game.turret_operator(&result.after.state, 1),
    )
}

@(test)
mounted_actions_saturation_death_and_floor_cleanup :: proc(t: ^testing.T) {
    w := spawned()
    target := r.Handle(game.Turret){0, w.turrets.generations[0]}
    assert(game.turret_mount(&w, 1, target))
    timeline: r.Timeline(game.World, Input, game.Event)
    assert(r.init(&timeline, r.Frame(game.World){tick = w.clock, state = w}, step) == .None)
    defer r.destroy(&timeline)
    events: [16]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        tick   = w.clock + 1,
        epoch  = 1,
        events = events[:],
    }
    testing.expect(t, !game.dash_start(&w, 1, {1, 0}, &ctx) && !game.cast_ability(&w, 1, 1, {1, 0}, false, &ctx))
    ammo := w.turrets.values[0].ammo

    for w.shots.count < game.MAX_SHOTS {
        _, ok := r.pool_insert(
            &w.shots,
            game.Shot {
                kind = .Ballistic,
                seat = 1,
                generation = 1,
                serial = 1,
                position = {600, 1040},
                velocity = {1, 0},
                ttl = 40,
                damage = 1,
            },
        )
        assert(ok)
    }

    game.turret_fire(&w, 1, &ctx)
    testing.expect(
        t,
        w.turrets.values[0].ammo == ammo && w.players[0].shots == 0 && w.turrets.values[0].next_shot == 0,
    )
    notices: game.Notices
    game.hurt_player(&w, 0, 255, w.players[0].position, &notices, &ctx)
    testing.expect(t, !game.turret_operator(&w, 1) && game.turret_mount(&w, 2, target))
    game.turn_floor(&w, false, &ctx)
    testing.expect(t, w.turrets.count == 0 && !game.turret_operator(&w, 2))
}
