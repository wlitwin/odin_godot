//gd:extends Node
//gd:class ReplayWindowProbe
package replay_window_probe

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import gd "godot:godot"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import net "godot:replay/net"
import ph "godot:replay/physics"
import tr "godot:replay/transport"
import view "godot:replay/view"

ReplayWindowProbe :: struct {
    owner: gd.Node,
}

Game :: struct {
    tick: u64,
    key:  b.Body_Key,
}

Model :: net.Model(Game, i16, u8, u8, 2)

State :: struct {
    memory:    tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
    server:    net.Server(Game, i16, u8, u8, 2),
    client:    net.Client(Game, i16, u8, u8, 2),
    codec:     ph.Network_Codec(Game, i16, u8, u8, 2),
    catalog:   b.Recovery_Catalog,
    owners:    [6]ph.Owner_Context,
}

PROFILE :: u64(0x57494e444f573031)

check :: proc(value: bool, label: string) {
    if !value {
        panic(label)
    }
}

none :: proc(error: net.Error, label: string) {
    check(error == .None, fmt.tprintf("%s: %v", label, error))
}

ledger :: proc() -> u32 {
    domain, status := b.domain_contract_get()
    check(status == .Ok, "domain")
    value, error := b.host_ledger_get(domain.cookie)
    check(error == .Ok, "ledger")
    return value.owner_count
}

step :: proc(game: ^Game, controls: [2]i16, _, _: u64, ctx: ^r.Step(u8)) {
    for control in controls {
        if ph.body_impulse(ctx.execution, game.key, {f32(control) * .001, 0, 0}) != .None {
            r.abort(ctx)
            return
        }
    }

    if ph.step(ctx.execution) != .None {
        r.abort(ctx)
        return
    }

    game.tick = ctx.tick
}

binding :: proc(scope: ^bm.Context, state: ^State, index: int, user: rawptr, bytes: u64) {
    lease, status := bm.block_lease(scope, state, size_of(State), user, bytes)
    check(status == bg.OK, "actual block lease")
    owner, error := ph.owner_context_create(lease, user_data = user, require_live_instance = false)
    check(error == .None, "actual retained owner")
    state.owners[index] = owner
}

pump :: proc(state: ^State, now: u64) {
    check(tr.memory_advance(&state.memory, now), "actual Memory service")
    none(net.client_pump(&state.client, now), "client pump")
    changes: [320]view.Change(net.Net_Event(u8))
    _ = view.drain(&state.client.journal, changes[:])
    check(tr.memory_advance(&state.memory, now), "same-time public service")
    none(net.server_pump(&state.server, now), "server pump")
}

@(gd_method = "owned_return")
replay_window_probe_exercise :: proc(self: ^ReplayWindowProbe) -> gd.String {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    baseline_owners := ledger()
    scope, status := bm.create(bg.service_get(), bg.CATEGORY_REPLAY_PROVIDER)
    check(status == bg.OK, "Meter")
    allocator := bm.allocator(scope)
    state := new(State, allocator)
    check(state != nil, "state storage")
    image_owner, image_error := ph.owner_context_create(
        bm.data_lease(scope),
        allocator_data = allocator.data,
        require_live_instance = false,
    )
    check(image_error == .None, "image allocator owner")
    state.owners[0] = image_owner
    binding(scope, state, 1, &state.codec, size_of(state.codec))
    binding(scope, state, 2, &state.server.model, size_of(Model))
    binding(scope, state, 3, &state.client.model, size_of(Model))
    binding(scope, state, 4, &state.endpoints[0], size_of(tr.Memory_Endpoint))
    binding(scope, state, 5, &state.endpoints[1], size_of(tr.Memory_Endpoint))
    config := b.recovery_config_default()
    config.profile = PROFILE
    assets := [1]b.Recovery_Asset{{id = 1, kind = .Box, a = {.25, .25, .25}}}
    catalog_status: b.Status
    state.catalog, catalog_status = b.recovery_catalog_create(config, assets[:])
    check(catalog_status == .Ok, "catalog")
    world_def := b.world_def_default()
    world_def.gravity = {0, 0, 0}
    world, world_status := b.world_create(world_def)
    check(world_status == .Ok, "source world")
    definition := b.body_def_default()
    definition.type = .Dynamic
    definition.pose.position = {0, 2, 0}
    body, body_status := b.body_create(world, definition)
    check(body_status == .Ok, "body")
    _, shape_status := b.shape_box(body, b.shape_def_default(), {.25, .25, .25})
    check(shape_status == .Ok, "shape")
    key, key_status := b.body_key(body)
    check(key_status == .Ok, "key")
    provider := ph.config_default(PROFILE, b.build_fingerprint())
    provider.initial_dynamic_bodies = 1
    provider.asset_count = 1
    provider.assets[0] = {
        id           = 1,
        kind         = .Box,
        shape        = b.shape_def_default(),
        half_extents = {.25, .25, .25},
    }
    initial, initial_error := ph.checkpoint_make(
        r.Frame(Game){state = {key = key}},
        net.Net_Event(u8),
        world,
        provider,
        allocator = allocator,
        ownership = image_owner,
        catalog = &state.catalog,
    )
    check(initial_error == .None, "complete initial checkpoint")
    check(b.world_destroy(&world) == .Ok, "destroy original Native world")
    none(
        ph.network_codec_init(
            &state.codec,
            &state.catalog,
            provider,
            bd.hash_bytes(transmute([]u8)string("browser-public-window.v1")),
            allocator = allocator,
            ownership = image_owner,
            context_ownership = state.owners[1],
        ),
        "codec",
    )
    check(tr.memory_init(&state.memory, cfg = {2, 64, 65536, 4096}, allocator = allocator), "bounded Memory transport")

    for &endpoint, i in state.endpoints {
        check(tr.memory_open(&state.memory, &endpoint, tr.Peer_Id(i + 1)), "real endpoint")
    }

    model := Model {
        complete_state = true,
        complete_codec = state.codec.value,
        step = step,
        control_valid = proc(value: i16) -> bool {
            return value >= -1 && value <= 1
        },
        hold = proc(value: i16) -> i16 {
            return value
        },
        action_valid = proc(value: u8) -> bool {
            return value == 0
        },
        state_valid = proc(value: Game) -> bool {
            return value.key != 0
        },
    }
    network := net.physics_config_default()
    network.snapshot_every = 1
    server_ownership := net.Runner_Ownership {
        allocator = {image_owner.owner, allocator.data},
        model     = {state.owners[2].owner, &state.server.model},
        wire      = {state.owners[4].owner, &state.endpoints[0]},
    }
    client_ownership := net.Runner_Ownership {
        allocator = {image_owner.owner, allocator.data},
        model     = {state.owners[3].owner, &state.client.model},
        wire      = {state.owners[5].owner, &state.endpoints[1]},
    }
    none(
        net.server_init_complete(
            &state.server,
            &initial,
            model,
            tr.memory_transport(&state.endpoints[0]),
            network,
            local_seat = 1,
            allocator = allocator,
            ownership = server_ownership,
        ),
        "server",
    )
    none(net.server_set_local_token(&state.server, net.Token{0 = 1}), "local token")
    none(
        net.client_init(
            &state.client,
            model,
            tr.memory_transport(&state.endpoints[1]),
            net.Token{0 = 2},
            cfg = network,
            allocator = allocator,
            ownership = client_ownership,
        ),
        "client",
    )
    check(r.complete_checkpoint_destroy(&initial) == .None, "initial release")
    check(b.recovery_catalog_destroy(&state.catalog) == .Ok, "source catalog release")
    none(net.client_pump(&state.client, 0), "Hello")
    check(tr.memory_advance(&state.memory, 0), "Hello service")
    none(net.server_pump(&state.server, 0), "receive Hello")
    none(net.server_step(&state.server), "membership")
    pump(state, 0)
    check(state.client.phase == .Running, "genuine first Welcome")
    generation, serial, baseline := state.client.generation, state.client.serial, state.client.baseline
    receiver := tr.memory_transport(&state.endpoints[1])
    scratch := make([]u8, 65536, allocator)
    discarded_packets, discarded_bytes: u64

    for state.server.timeline.head < 160 {
        now := (state.server.timeline.head + 1) * 17
        check(tr.memory_advance(&state.memory, now), "Memory authority service")
        none(net.server_pump(&state.server, now), "authority receive")
        none(net.server_local(&state.server, 1), "authority real control")
        none(net.server_step(&state.server), "actual authority step")
        check(tr.memory_advance(&state.memory, now), "deliver actual packets")

        if state.server.timeline.head <= 129 {
            drained := false

            for _ in 0 ..< 65 {
                packet := tr.receive(&receiver, scratch)

                if packet.state == .Empty {
                    drained = true
                    break
                }

                check(packet.state == .Received, "actual packet receiver discard")
                discarded_packets += 1
                discarded_bytes += u64(packet.count)
            }

            check(drained, "bounded complete discard")
        }
    }

    delete(scratch, allocator)
    gap := state.server.timeline.head - state.client.timeline.confirmed
    check(gap > 128 && discarded_packets > 0, "actual missing history")

    for index in 0 ..< 64 {
        pump(state, 3000 + u64(index) * 25)

        if state.client.phase == .Running && state.client.timeline.confirmed >= 160 {
            break
        }
    }

    check(
        state.client.phase == .Running && state.client.timeline.confirmed >= 160 && state.client.baseline > baseline,
        "real canonical Welcome recovery",
    )
    check(state.client.generation > generation || state.client.serial > serial, "actual committed replacement scope")
    check(state.client.stats.resyncs > 0 && state.client.resync_notice.serial != 0, "actual notice")
    left, left_error := r.capture_complete(&state.server.timeline, 160, allocator)
    right, right_error := r.capture_complete(&state.client.timeline, 160, allocator)
    check(left_error == .None && right_error == .None, "capture complete160")
    a, ae := net.complete_view(
        state.codec.value,
        &left,
        &state.server.physics.schemas.state,
        &state.server.physics.schemas.occurrence,
        allocator,
    )
    z, ze := net.complete_view(
        state.codec.value,
        &right,
        &state.client.physics.schemas.state,
        &state.client.physics.schemas.occurrence,
        allocator,
    )
    none(ae, "authority five parts")
    none(ze, "replica five parts")
    part_bytes: [5]u64

    for part in bd.Part {
        check(mem.compare(a.frame.parts[part], z.frame.parts[part]) == 0, "all five canonical parts equal")
        part_bytes[int(part)] = u64(len(a.frame.parts[part]))
    }

    net.complete_view_destroy(&a)
    net.complete_view_destroy(&z)
    check(
        r.complete_checkpoint_destroy(&left) == .None && r.complete_checkpoint_destroy(&right) == .None,
        "complete owners released",
    )
    result := struct {
        ok,
        source_free:                                                                                                                                                        bool,
        gap,
        discarded_packets,
        discarded_bytes,
        resyncs,
        notice,
        baseline_before,
        baseline_after,
        generation_before,
        generation_after,
        serial_before,
        serial_after,
        confirmed: u64,
        part_bytes:                                                                                                                                                             [5]u64,
        native,
        wrapper:                                                                                                                                                        u64,
        owners_before,
        owners_after:                                                                                                                                            u32,
    } {
        ok                = true,
        source_free       = true,
        gap               = gap,
        discarded_packets = discarded_packets,
        discarded_bytes   = discarded_bytes,
        resyncs           = state.client.stats.resyncs,
        notice            = state.client.resync_notice.serial,
        baseline_before   = baseline,
        baseline_after    = state.client.baseline,
        generation_before = generation,
        generation_after  = state.client.generation,
        serial_before     = serial,
        serial_after      = state.client.serial,
        confirmed         = state.client.timeline.confirmed,
        part_bytes        = part_bytes,
        owners_before     = baseline_owners,
    }
    none(net.server_step(&state.server), "resumed real work")
    none(net.client_destroy(&state.client), "client teardown")
    none(net.server_destroy(&state.server), "server teardown")
    tr.memory_destroy(&state.memory)
    none(ph.network_codec_destroy(&state.codec), "codec teardown")

    for &owner in state.owners {
        check(ph.owner_context_destroy(&owner) == .None, "retained owner teardown")
    }

    mem.free(state, allocator)
    check(bm.destroy(&scope) == bg.OK, "Meter teardown")
    native, ns := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    check(ns == .Ok && ws == .Ok && native.live_bytes == 0 && wrapper.live_bytes == 0, "real backend balance")
    result.native = native.live_bytes
    result.wrapper = wrapper.live_bytes
    result.owners_after = ledger()
    check(result.owners_after == result.owners_before, "actual owner baseline restored")
    encoded, encoding_error := json.marshal(result)
    check(encoding_error == nil, "report encoding")
    defer delete(encoded)
    return gd.new_string_odin(string(encoded))
}
