//gd:extends Node
//gd:class KitWebProbe
package kit_web_probe

import "base:runtime"
import "core:encoding/json"
import "core:fmt"
import "core:mem"
import gd "godot:godot"
import b "godot:box3d"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import bd "godot:box3d/diagnostics"
import p "godot:kit/physics"
import k "godot:kit/sim"
import s "godot:kit/session"

KitWebProbe :: struct {
    owner: gd.Node,
}

Side :: struct {
    tick:     u64,
    key:      b.Body_Key,
    controls: u64,
}

Control :: struct {
    axis: i16,
}

State :: struct {
    sdk:     p.SDK_Context,
    owners:  [4]p.SDK_User_Owner,
    lane:    k.Lane,
    session: s.Session,
    physics: p.Instance(Side),
    network: p.Network(Side),
    codec:   p.Typed_Codec(Control),
}

PROFILE :: u64(0x4b49545745423031)

check :: proc(value: bool, message: string) {
    if !value {
        panic(message)
    }
}

sample :: proc(_: rawptr, tick: u64, out: rawptr) {
    (cast(^Control)out)^ = {tick % 2 == 0 ? i16(1) : i16(-1)}
}

step :: proc(user: rawptr, tick: u64) {
    state := cast(^State)user
    side := p.state(&state.physics)
    world, error := p.world(&state.physics)
    check(error == .Ok, "Kit world")
    control, found := k.lane_input_of(&state.lane, 1, Control)
    check(found && abs(control.axis) == 1, "actual Kit sampled input")
    body, status := b.body_resolve(world, side.key)
    check(status == .Ok, "body key")
    check(p.require(&state.physics, b.body_apply_impulse(body, {f32(control.axis) * .01, 0, 0})), "Kit impulse")
    side.tick = tick
    side.controls += 1
}

ledger :: proc() -> u32 {
    domain, status := b.domain_contract_get()
    check(status == .Ok, "domain")
    value, error := b.host_ledger_get(domain.cookie)
    check(error == .Ok, "host ledger")
    return value.owner_count
}

@(gd_method = "owned_return")
kit_web_probe_exercise :: proc(self: ^KitWebProbe) -> gd.String {
    temp := runtime.default_temp_allocator_temp_begin()
    defer runtime.default_temp_allocator_temp_end(temp)
    baseline := ledger()
    sdk, error := p.sdk_context_create()
    check(error == .Ok, "SDK context")
    allocator := bm.allocator(sdk.memory)
    state := new(State, allocator)
    check(state != nil, "state allocation")
    state.sdk = sdk
    users := [4]rawptr{state, &state.physics, &state.network, &state.codec}
    sizes := [4]u64{size_of(State), size_of(state.physics), size_of(state.network), size_of(state.codec)}

    for user, i in users {
        state.owners[i], error = p.sdk_user_owner_create(sdk.memory, state, size_of(State), user, sizes[i])
        check(error == .Ok, "SDK actual block owners")
    }

    // This compatibility case has one local authority; emitted network bytes
    // go to an explicit sink, not a pretend second participant.
    state.session.send = proc(_: rawptr, _: s.Peer_Id, _: []u8, _: s.Channel) {}
    state.session.is_host = true
    state.session.me = 1
    k.lane_init(
        &state.lane,
        &state.session,
        size_of(Control),
        cfg = {slots = 128, snap_every = 3},
        allocator = allocator,
    )
    k.lane_set_sim(&state.lane, state, sample, step)
    k.lane_class_set_type(&state.lane, 0, Control)
    config := b.recovery_config_default()
    config.profile = PROFILE
    assets := [1]b.Recovery_Asset{{id = 1, kind = .Box, a = {.25, .25, .25}}}
    catalog, catalog_status := b.recovery_catalog_create(config, assets[:])
    check(catalog_status == .Ok, "catalog")
    definition := b.world_def_default()
    definition.gravity = {0, 0, 0}
    world, status := b.world_create(definition)
    check(status == .Ok, "world create")
    body_definition := b.body_def_default()
    body_definition.type = .Dynamic
    body_definition.pose.position = {0, 2, 0}
    body, body_status := b.body_create(world, body_definition)
    check(body_status == .Ok, "body create")
    _, shape_status := b.shape_box(body, b.shape_def_default(), {.25, .25, .25})
    check(shape_status == .Ok, "shape create")
    key, key_status := b.body_key(body)
    check(key_status == .Ok, "body key")
    provider := p.sdk_context_config(sdk, PROFILE, state.owners[1], state.owners[0])
    check(p.attach(&state.physics, &state.lane, &world, Side{key = key}, nil, provider) == .Ok, "Kit provider attach")
    check(p.codec_init(&state.codec, allocator = allocator, ownership = state.owners[3]) == .Ok, "input codec")
    inputs := [1]k.World_Wire_Input{{0, state.codec.value, .Neutral}}
    drivers := [1]k.World_Driver{{1, 0}}
    check(
        p.network_attach(
            &state.network,
            &state.physics,
            &catalog,
            nil,
            inputs[:],
            drivers[:],
            nil,
            bd.hash_bytes(transmute([]u8)string("kit-web-compatibility.v1")),
            ownership = state.owners[2],
        ) ==
        .Ok,
        "Kit World2 complete codec",
    )

    for _ in 0 ..< 16 {
        check(
            k.lane_frame(&state.lane, 1.0 / 60) == 1 && k.lane_world_status(&state.lane) == .Ok,
            "Kit actual fixed step",
        )
    }

    checkpoint, checkpoint_error := k.lane_world_checkpoint(&state.lane, 16)
    check(checkpoint_error == .Ok, "complete checkpoint")
    side, side_error := p.checkpoint_side(&checkpoint, Side)
    check(side_error == .Ok && side.tick == 16 && side.controls == 16, "Side checkpoint")
    frame: k.World_Diagnostic_Frame
    check(k.lane_world_diagnostic_frame(&state.lane, 16, &frame) == .Ok, "complete five parts")
    signature, signature_error := bd.sign(frame.view)
    check(signature_error == .None && bd.compare(signature, frame.signature) == .Match, "complete signature")
    part_bytes: [5]u64

    for part in bd.Part {
        part_bytes[int(part)] = u64(len(frame.view.parts[part]))
    }

    check(part_bytes[0] > 0 && part_bytes[2] > 0, "solver and Side canonical bytes")
    dump_bytes, dump_error := p.checkpoint_dump(&checkpoint, nil, Side)
    check(dump_error == .Ok && dump_bytes > 0, "owned solver dump capacity")
    before := make([]u8, int(dump_bytes), allocator)
    after := make([]u8, int(dump_bytes), allocator)
    _, dump_error = p.checkpoint_dump(&checkpoint, before, Side)
    check(dump_error == .Ok, "solver dump")
    check(k.world_diagnostic_frame_destroy(&frame) == .Ok, "diagnostic destruction")
    check(p.network_destroy(&state.network) == .Ok, "network destruction")
    check(p.detach(&state.physics) == .Ok, "provider destruction")
    k.lane_destroy(&state.lane)
    s.session_destroy(&state.session)
    check(b.recovery_catalog_destroy(&catalog) == .Ok, "source catalog destruction")
    _, dump_error = p.checkpoint_dump(&checkpoint, after, Side)
    check(
        dump_error == .Ok && mem.compare_ptrs(raw_data(before), raw_data(after), len(before)) == 0,
        "source-free complete solver image",
    )
    delete(before, allocator)
    delete(after, allocator)
    check(k.world_checkpoint_destroy(&checkpoint) == .Ok, "checkpoint destruction")
    check(p.codec_destroy(&state.codec) == .Ok, "codec destruction")

    for &owner in state.owners {
        check(p.sdk_user_owner_destroy(&owner) == .Ok, "owner destruction")
    }

    mem.free(state, allocator)
    check(p.sdk_context_destroy(&sdk) == .Ok, "SDK destruction")
    engine, engine_status := b.engine_allocation_stats()
    wrapper, wrapper_status := b.snapshot_allocation_stats()
    check(
        engine_status == .Ok && wrapper_status == .Ok && engine.live_bytes == 0 && wrapper.live_bytes == 0,
        "backend allocation balance",
    )
    check(ledger() == baseline, "actual owner baseline")
    result := struct {
        ok, source_free:             bool,
        steps:                       u32,
        part_bytes:                  [5]u64,
        native, wrapper:             u64,
        owners_before, owners_after: u32,
    }{true, true, 16, part_bytes, engine.live_bytes, wrapper.live_bytes, baseline, ledger()}
    encoded, encoding_error := json.marshal(result)
    check(encoding_error == nil, "result JSON")
    defer delete(encoded)
    return gd.new_string_odin(string(encoded))
}
