package main

import "core:os"
import "core:fmt"
import "core:strconv"
import "core:encoding/json"
import r "godot:replay"
import net "godot:replay/net"
import scenario "godot:replay/testing"
import d "godot:replay/definitions"
import game "../../shared/game"
import content "../../shared/content"

Input :: struct {
    cast_requested: bool,
}

Result :: struct {
    ok: bool,
    kind: string,
    hash: u64,
    before_hp, after_hp: u8,
    before_casts, after_casts: u32,
    checkpoint_tick, final_tick: u64,
    message: string,
}

step :: proc(w: ^game.World, input: Input, ctx: ^r.Step(game.Event)) {
    if input.cast_requested && !game.cast_ability(w, 1, 0, w.players[0].position, true, ctx) {
        r.abort(ctx)
        return
    }

    game.step(w, [game.SEATS]game.Control{}, 0, 0, ctx)
}

drive :: proc(
    server: ^net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS),
    tick: u64,
) -> net.Error {
    if tick != 1 {
        return .None
    }

    _, error := net.server_issue(server, game.Action{kind = .Cast, slot = 0, aim = {600, 1040}, aim_is_point = true})
    return error
}

main :: proc() {
    if len(os.args) != 5 {
        fmt.eprintln("usage: authoring_scenario correction|takeover CATALOG ID RESULT.json")
        os.exit(2)
    }

    kind := os.args[1]
    id, parsed := strconv.parse_u64(os.args[3])

    if !parsed || id >= content.MAX_ABILITIES {
        os.exit(2)
    }

    bytes, read := os.read_entire_file(os.args[2], context.allocator)

    if read != nil {
        os.exit(2)
    }

    defer delete(bytes)
    store: d.Store(content.Catalog)
    defer d.destroy(&store)

    if d.init(&store, 1).error != .None {
        os.exit(2)
    }

    ref, report := d.artifact_import(&store, bytes, game.CONTENT)

    if report.error != .None {
        os.exit(2)
    }

    catalog, _ := d.get(&store, ref)

    if !content.valid(catalog) || !content.ability_present(&catalog, u8(id)) {
        os.exit(2)
    }

    world := game.initial(encounter_count = 0)
    world.catalog = catalog
    world.stage = .Yard
    world.players[0].connected, world.players[0].in_yard = true, true
    world.players[0].position = {600, 1040}
    world.players[0].hp = 4
    world.players[0].profile.abilities = {u8(id), 2}
    result := Result {
        kind = kind,
    }

    if kind == "correction" {
        predicted, actual: [70]Input
        predicted[0].cast_requested = true
        outcome := scenario.correction(r.Frame(game.World){state = world}, step, predicted[:], actual[:], 1)
        result.ok =
            outcome.report.phase == .Complete &&
            outcome.before.state.players[0].casts == 1 &&
            outcome.after.state.players[0].casts == 0
        result.hash = outcome.report.hash
        result.before_hp, result.after_hp = outcome.before.state.players[0].hp, outcome.after.state.players[0].hp
        result.before_casts, result.after_casts =
            outcome.before.state.players[0].casts, outcome.after.state.players[0].casts
        result.final_tick = outcome.after.tick
    } else if kind == "takeover" {
        cfg := net.DEFAULT_CONFIG
        cfg.content = game.CONTENT
        model := game.model()
        model.reset_player = nil
        outcome := scenario.takeover(r.Frame(game.World){state = world}, model, cfg, 20, 70, drive)
        result.ok = outcome.report.phase == .Complete && outcome.after.state.players[0].casts == 1

        if catalog.abilities[id].family == .Zone {
            result.ok = result.ok && outcome.before.state.zones.count > 0
        }

        result.hash = outcome.report.hash
        result.before_hp, result.after_hp = outcome.before.state.players[0].hp, outcome.after.state.players[0].hp
        result.before_casts, result.after_casts =
            outcome.before.state.players[0].casts, outcome.after.state.players[0].casts
        result.checkpoint_tick, result.final_tick = outcome.before.tick, outcome.after.tick
    } else {
        os.exit(2)
    }

    result.message = result.ok ? "Authored ability scenario passed." : "Authored ability scenario failed."
    output, encoded := json.marshal(result)
    defer delete(output)

    if encoded != nil || os.write_entire_file(os.args[4], output) != nil {
        os.exit(2)
    }

    if !result.ok {
        os.exit(1)
    }

    fmt.printf("REPLAY_AUTHORING_SCENARIO_OK kind=%s hash=%d\n", kind, result.hash)
}
