package replay_physics_native_net_test

import "core:testing"
import "core:mem"
import "core:fmt"
import b "godot:box3d"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import f "../fixture"

Native_Pair :: struct {
    catalog:   b.Recovery_Catalog,
    codec:     ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2),
    memory:    tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
    server:    net.Server(f.Game, f.Control, f.Action, f.Event, 2),
    client:    net.Client(f.Game, f.Control, f.Action, f.Event, 2),
}

pair_open :: proc(t: ^testing.T, p: ^Native_Pair, count: u32 = 4) {
    p.catalog = catalog_make(t)
    config := config_make(&p.catalog, count)
    world, game, status := f.world(count)
    testing.expect_value(t, status, b.Status.Ok)
    initial, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&initial)
    b.world_destroy(&world)
    testing.expect_value(t, ph.network_codec_init(&p.codec, &p.catalog, config, network_rules()), net.Error.None)
    testing.expect(t, tr.memory_init(&p.memory, cfg = {2, 64, tr.MAX_PACKET_BYTES, 4096}))

    for &endpoint, index in p.endpoints {
        testing.expect(t, tr.memory_open(&p.memory, &endpoint, tr.Peer_Id(index + 1)))
    }

    model := network_model(&p.codec)
    cfg := net.physics_config_default()
    testing.expect_value(
        t,
        net.server_init_complete(
            &p.server,
            &initial,
            model,
            tr.memory_transport(&p.endpoints[0]),
            cfg,
            local_seat = 1,
        ),
        net.Error.None,
    )
    testing.expect_value(t, net.server_set_local_token(&p.server, net.Token{0 = 1}), net.Error.None)
    testing.expect_value(
        t,
        net.client_init(&p.client, model, tr.memory_transport(&p.endpoints[1]), net.Token{0 = 2}, cfg = cfg),
        net.Error.None,
    )
    net.client_pump(&p.client, 0)
    tr.memory_advance(&p.memory, 0)
    net.server_pump(&p.server, 0)
    net.server_step(&p.server)
    tr.memory_advance(&p.memory, 0)
    net.client_pump(&p.client, 0)
    testing.expect_value(t, p.client.phase, net.Phase.Running)
}

pair_close :: proc(t: ^testing.T, p: ^Native_Pair) {
    net.client_destroy(&p.client)
    net.server_destroy(&p.server)
    tr.memory_destroy(&p.memory)
    testing.expect_value(t, ph.network_codec_destroy(&p.codec), net.Error.None)
    b.recovery_catalog_destroy(&p.catalog)
}

@(test)
resource_admission_preserves_published_pair_history_and_balances_owners :: proc(t: ^testing.T) {
    pair := new(Native_Pair)
    defer free(pair)
    pair_open(t, pair)
    defer pair_close(t, pair)
    testing.expect_value(t, ph.network_codec_destroy(&pair.codec), net.Error.Wrong_Phase)
    server_before, se := r.capture_complete(&pair.server.timeline, pair.server.timeline.head)
    client_before, ce := r.capture_complete(&pair.client.timeline, pair.client.timeline.head)
    testing.expect(t, se == .None && ce == .None)
    defer r.complete_checkpoint_destroy(&server_before)
    defer r.complete_checkpoint_destroy(&client_before)
    n, _ := ph.dump(&server_before, nil)
    baseline := make([]u8, int(n))
    defer delete(baseline)
    ph.dump(&server_before, baseline)
    observation, status := b.alpha_memory_check(ph.allocation_stats().live_bytes)
    testing.expect_value(t, status, b.Status.Ok)
    // Allocate/charge real external caller storage so the next two-MiB command
    // reservation crosses the cap by exactly one byte; no failed native alloc.
    padding_bytes := b.ALPHA_RESOURCE_BYTES - observation.live_bytes - ph.RESERVATION_BYTES + 1
    testing.expect_value(t, pair.codec.value.reserve(pair.codec.value.catalog, padding_bytes), net.Error.None)
    padding, allocation_error := mem.alloc_bytes(int(padding_bytes))
    testing.expect_value(t, allocation_error, mem.Allocator_Error.None)
    engine_before, _ := b.engine_allocation_stats()
    wrapper_before, _ := b.snapshot_allocation_stats()
    owned_before := ph.allocation_stats().live_bytes
    server_head, client_head := pair.server.timeline.head, pair.client.timeline.head
    testing.expect_value(t, net.server_step(&pair.server), net.Error.Capacity)
    testing.expect_value(t, pair.server.frame_error, r.Error.Resource_Limit)
    testing.expect_value(t, pair.server.timeline.head, server_head)
    testing.expect_value(t, pair.client.timeline.head, client_head)
    _, has_future := r.read_input(&pair.server.timeline, server_head + 1)
    testing.expect(t, !has_future)
    server_frame, _ := r.current_values(&pair.server.timeline)
    client_frame, _ := r.current_values(&pair.client.timeline)
    testing.expect_value(t, server_frame, server_before.frame)
    testing.expect_value(t, client_frame, client_before.frame)
    engine_after, _ := b.engine_allocation_stats()
    wrapper_after, _ := b.snapshot_allocation_stats()
    testing.expect_value(t, engine_after.live_bytes, engine_before.live_bytes)
    testing.expect_value(t, wrapper_after.live_bytes, wrapper_before.live_bytes)
    testing.expect_value(t, ph.allocation_stats().live_bytes, owned_before)
    delete(padding)
    pair.codec.value.release(pair.codec.value.catalog, padding_bytes)
    server_after, ae := r.capture_complete(&pair.server.timeline, server_head)
    testing.expect_value(t, ae, r.Error.None)
    defer r.complete_checkpoint_destroy(&server_after)
    after := make([]u8, int(n))
    defer delete(after)
    ph.dump(&server_after, after)
    testing.expect_value(t, mem.compare(baseline, after), 0)
    testing.expect_value(t, net.server_step(&pair.server), net.Error.None)
    fmt.printf(
        "PHYSICS_RESOURCE_BOUNDARY actual_live=%d reserve=%d proposed=%d cap=%d atomic=true balanced=true\n",
        observation.live_bytes + padding_bytes,
        ph.RESERVATION_BYTES,
        observation.live_bytes + padding_bytes + ph.RESERVATION_BYTES,
        b.ALPHA_RESOURCE_BYTES,
    )
}

@(test)
network_contract_binds_provider_parameters_and_prepublication_scalar_profile :: proc(t: ^testing.T) {
    pair := new(Native_Pair)
    defer free(pair)
    pair_open(t, pair)
    defer pair_close(t, pair)
    changed := pair.codec.config
    changed.assets[1].radius += 0.01
    other: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(t, ph.network_codec_init(&other, &pair.catalog, changed, network_rules()), net.Error.None)
    defer ph.network_codec_destroy(&other)
    testing.expect(t, other.value.identity.game_schema != pair.codec.value.identity.game_schema)
    before, error := r.capture_complete(&pair.server.timeline, pair.server.timeline.head)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&before)
    pair.server.model.step = proc(game: ^f.Game, controls: [2]f.Control, joins, leaves: u64, ctx: ^r.Step(f.Event)) {
        model_step(game, controls, joins, leaves, ctx)
        ph.body_velocity(ctx.execution, game.bodies[0], {1e13, 0, 0}, {})
    }
    testing.expect_value(t, net.server_step(&pair.server), net.Error.Simulation)
    testing.expect_value(t, pair.server.frame_error, r.Error.External_State)
    current, found := r.current_values(&pair.server.timeline)
    testing.expect(t, found)
    testing.expect_value(t, current, before.frame)
    _, future := r.read_input(&pair.server.timeline, before.frame.tick + 1)
    testing.expect(t, !future)
    pair.server.model.step = model_step
    testing.expect_value(t, net.server_step(&pair.server), net.Error.None)
}

@(test)
unbound_p2_checkpoint_rejects_unlisted_geometry_when_entering_network_mode :: proc(t: ^testing.T) {
    catalog := catalog_make(t)
    defer b.recovery_catalog_destroy(&catalog)
    config := config_make(&catalog, 4)
    world, game, status := f.world(4)
    testing.expect_value(t, status, b.Status.Ok)
    def := b.body_def_default()
    def.pose.position = {0, 30, 0}
    body, bs := b.body_create(world, def)
    testing.expect_value(t, bs, b.Status.Ok)
    _, ss := b.shape_box(body, b.shape_def_default(), {0.3, 0.3, 0.3})
    testing.expect_value(t, ss, b.Status.Ok)
    initial, error := ph.checkpoint_make(r.Frame(f.Game){state = game}, net.Net_Event(f.Event), world, config)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&initial)
    b.world_destroy(&world)
    codec: ph.Network_Codec(f.Game, f.Control, f.Action, f.Event, 2)
    testing.expect_value(t, ph.network_codec_init(&codec, &catalog, config, network_rules()), net.Error.None)
    defer ph.network_codec_destroy(&codec)
    server: net.Server(f.Game, f.Control, f.Action, f.Event, 2)
    defer net.server_destroy(&server)
    testing.expect_value(
        t,
        net.server_init_complete(&server, &initial, network_model(&codec), {}, net.physics_config_default()),
        net.Error.Checkpoint_Contract,
    )
    testing.expect(t, !server.initialized)
    // The rejected network bind did not consume or modify the P2 owner.
    model := network_model(&codec)
    standalone: r.Timeline(f.Game, net.Batch(f.Control, f.Action, 2), net.Net_Event(f.Event))
    testing.expect_value(
        t,
        r.init_complete(
            &standalone,
            &initial,
            net.model_callback(f.Game, f.Control, f.Action, f.Event, 2),
            {128, net.WIRE_EVENTS},
            user = &model,
        ),
        r.Error.None,
    )
    defer r.destroy(&standalone)
    testing.expect_value(t, r.advance(&standalone, net.Batch(f.Control, f.Action, 2){}).error, r.Error.None)
}

@(test)
network_bound_detached_image_owns_catalog_after_source_runtime_and_codec_die :: proc(t: ^testing.T) {
    pair := new(Native_Pair)
    defer free(pair)
    pair_open(t, pair)
    image, error := r.capture_complete(&pair.server.timeline, pair.server.timeline.head)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&image)
    model := network_model(&pair.codec)
    pair_close(t, pair)
    timeline: r.Timeline(f.Game, net.Batch(f.Control, f.Action, 2), net.Net_Event(f.Event))
    testing.expect_value(
        t,
        r.init_complete(
            &timeline,
            &image,
            net.model_callback(f.Game, f.Control, f.Action, f.Event, 2),
            {128, net.WIRE_EVENTS},
            user = &model,
        ),
        r.Error.None,
    )
    defer r.destroy(&timeline)

    for _ in 0 ..< 12 {
        testing.expect_value(t, r.advance(&timeline, net.Batch(f.Control, f.Action, 2){}).error, r.Error.None)
        testing.expect_value(t, r.confirm_through(&timeline, timeline.head), r.Error.None)
    }

    current, found := r.current_values(&timeline)
    testing.expect(t, found && current.tick == image.frame.tick + 12)
}

write_field :: proc(schema: ^sc.Schema, body: []u8, path: string, value: u64) -> bool {
    for field in schema.fields {
        if field.path == path {
            for i in 0 ..< field.width {
                body[field.wire_offset + i] = u8(value >> uint(i * 8))
            }

            return true
        }
    }

    return false
}

input_packet :: proc(t: ^testing.T, pair: ^Native_Pair, tick: u64, x: i16, view: net.View_Stamp = {}) -> []u8 {
    schema := &pair.server.codecs.inputs
    bytes := make([]u8, sc.HEADER_BYTES + schema.wire_size)
    body := bytes[sc.HEADER_BYTES:]
    fields := [?]struct {
        name:  string,
        value: u64,
    } {
        {"$.generation", pair.client.generation},
        {"$.serial", pair.client.serial},
        {"$.count", 1},
        {"$.samples[0].tick", tick},
        {"$.samples[0].value.x", u64(u16(x))},
        {"$.samples[0].view.from_id", view.from_id},
        {"$.samples[0].view.to_id", view.to_id},
        {"$.samples[0].view.from_tick", view.from_tick},
        {"$.samples[0].view.to_tick", view.to_tick},
        {"$.samples[0].view.fraction", u64(view.fraction)},
        {"$.samples[0].view.valid", u64(view.valid)},
    }

    for field in fields {
        testing.expect(t, write_field(schema, body, field.name, field.value))
    }

    testing.expect_value(
        t,
        sc.pack_bytes(schema.fingerprint, {kind = 4, epoch = pair.server.cfg.epoch, tick = tick, content = pair.server.cfg.content}, body, bytes).error,
        sc.Error.None,
    )
    return bytes
}

@(test)
actual_input_receiver_rejects_conflicts_and_physics_view_bounds_ignore_rtt :: proc(t: ^testing.T) {
    pair := new(Native_Pair)
    defer free(pair)
    pair_open(t, pair)
    defer pair_close(t, pair)
    remote := tr.memory_transport(&pair.endpoints[1])
    original := input_packet(t, pair, 4, 10)
    defer delete(original)
    conflict := input_packet(t, pair, 4, 11)
    defer delete(conflict)
    testing.expect_value(t, tr.send(&remote, 1, .Unreliable, original), tr.Send_Result.Sent)
    tr.memory_advance(&pair.memory, 0)
    net.server_pump(&pair.server, 0)
    before := pair.server.stats.rejected_inputs
    testing.expect_value(t, tr.send(&remote, 1, .Unreliable, conflict), tr.Send_Result.Sent)
    tr.memory_advance(&pair.memory, 0)
    net.server_pump(&pair.server, 0)
    testing.expect_value(t, pair.server.stats.rejected_inputs, before + 1)

    for pair.server.timeline.head < 8 {
        testing.expect_value(t, net.server_step(&pair.server), net.Error.None)
    }

    accepted, found := net.server_accepted_input(&pair.server, 4)
    testing.expect(t, found)
    testing.expect_value(t, accepted.batch.controls[1].x, i16(10))
    // Welcome tick1 is a real issued proof. A low RTT must not shorten the
    // physical eight-tick historical input bound or alter accepted gameplay.
    view := net.View_Stamp {
        from_tick = 1,
        to_tick   = 1,
        valid     = true,
    }
    pair.server.peers[1].rtt_floor_ms = 1
    low := input_packet(t, pair, 9, 0, view)
    defer delete(low)
    tr.send(&remote, 1, .Unreliable, low)
    tr.memory_advance(&pair.memory, 0)
    net.server_pump(&pair.server, 0)
    net.server_step(&pair.server)
    first, first_found := net.server_accepted_input(&pair.server, 9)
    testing.expect(t, first_found)
    testing.expect_value(t, first.batch.views[1].status, net.View_Status.Historical)
    pair.server.peers[1].rtt_floor_ms = 9999
    // Use the new tick8 fact proof, ID0 is scoped by the explicit tick.
    view.from_tick, view.to_tick = 8, 8
    high := input_packet(t, pair, 10, 0, view)
    defer delete(high)
    tr.send(&remote, 1, .Unreliable, high)
    tr.memory_advance(&pair.memory, 0)
    net.server_pump(&pair.server, 0)
    net.server_step(&pair.server)
    second, second_found := net.server_accepted_input(&pair.server, 10)
    testing.expect(t, second_found)
    testing.expect_value(t, second.batch.views[1].status, net.View_Status.Historical)
}

@(test)
actual_checked_prefix_then_later_predicted_failure_aborts_entire_client_suffix :: proc(t: ^testing.T) {
    pair := new(Native_Pair)
    defer free(pair)
    pair_open(t, pair)
    defer pair_close(t, pair)
    testing.expect_value(t, net.client_step(&pair.client, f.Control{}), net.Error.None)
    before, error := r.capture_complete(&pair.client.timeline, pair.client.timeline.head)
    testing.expect_value(t, error, r.Error.None)
    defer r.complete_checkpoint_destroy(&before)
    confirmed := pair.client.timeline.confirmed
    optimized := pair.client.physics.verified_compares
    // Calibrated Welcome lead may exceed the configured minimum. The plan must
    // cover the actual whole suffix, while only its first tick is checked.
    first := pair.server.timeline.head + 1
    head := pair.client.timeline.head
    testing.expect(t, head >= first + 2)

    if head < first + 2 {
        return
    }

    planned := head - first + 1
    pair.client.model.step = proc(game: ^f.Game, controls: [2]f.Control, joins, leaves: u64, ctx: ^r.Step(f.Event)) {
        model_step(game, controls, joins, leaves, ctx)

        if ctx.tick == 3 {
            r.abort(ctx)
        }
    }
    tr.memory_advance(&pair.memory, 0)
    net.server_pump(&pair.server, 0)
    // The host's own accepted control differs from the client's held guess at
    // the first unconfirmed tick, so the revision really executes the whole
    // suffix (an unchanged prefix would reuse its records without stepping).
    testing.expect_value(t, net.server_local(&pair.server, f.Control{x = 10}), net.Error.None)
    testing.expect_value(t, net.server_step(&pair.server), net.Error.None)
    tr.memory_advance(&pair.memory, 0)
    testing.expect_value(t, net.client_pump(&pair.client, 0), net.Error.Simulation)
    testing.expect_value(t, pair.client.physics.last_checked_prefix, u64(1))
    testing.expect_value(t, pair.client.physics.last_executed_steps, u64(1))
    testing.expect_value(t, pair.client.physics.last_planned_depth, planned)
    testing.expect_value(t, pair.client.physics.verified_compares, optimized)
    testing.expect_value(t, pair.client.timeline.confirmed, confirmed)
    current, found := r.current_values(&pair.client.timeline)
    testing.expect(t, found)
    testing.expect_value(t, current, before.frame)
    after, ae := r.capture_complete(&pair.client.timeline, pair.client.timeline.head)
    testing.expect_value(t, ae, r.Error.None)
    defer r.complete_checkpoint_destroy(&after)
    n, _ := ph.dump(&before, nil)
    a, z := make([]u8, int(n)), make([]u8, int(n))
    defer delete(a)
    defer delete(z)
    ph.dump(&before, a)
    ph.dump(&after, z)
    testing.expect_value(t, mem.compare(a, z), 0)
    testing.expect(t, !pair.client.physics.trace.ready)
    pair.client.model.step = model_step
    testing.expect_value(t, net.client_pump(&pair.client, 0), net.Error.None)
    testing.expect_value(t, pair.client.timeline.confirmed, u64(2))
}

action_packet :: proc(t: ^testing.T, pair: ^Native_Pair, sequence, tick: u64, kind: f.Action_Kind) -> []u8 {
    schema := &pair.server.codecs.action
    bytes := make([]u8, sc.HEADER_BYTES + schema.wire_size)
    body := bytes[sc.HEADER_BYTES:]

    for field in ([?]struct {
            name:  string,
            value: u64,
        } {
            {"$.generation", pair.client.generation},
            {"$.serial", pair.client.serial},
            {"$.sequence", sequence},
            {"$.tick", tick},
            {"$.value.kind", u64(kind)},
        }) {
        testing.expect(t, write_field(schema, body, field.name, field.value))
    }

    testing.expect_value(
        t,
        sc.pack_bytes(schema.fingerprint, {kind = 5, epoch = pair.server.cfg.epoch, tick = tick, content = pair.server.cfg.content}, body, bytes).error,
        sc.Error.None,
    )
    return bytes
}

@(test)
actual_action_receiver_deduplicates_exact_values_and_rejects_conflicting_sequence :: proc(t: ^testing.T) {
    pair := new(Native_Pair)
    defer free(pair)
    pair_open(t, pair)
    defer pair_close(t, pair)
    wire := tr.memory_transport(&pair.endpoints[1])
    original := action_packet(t, pair, 1, 4, .Spawn)
    defer delete(original)
    changed := action_packet(t, pair, 1, 4, .Motor)
    defer delete(changed)
    gap := action_packet(t, pair, 3, 4, .Spawn)
    defer delete(gap)

    for bytes, index in ([?][]u8{original, original, changed, gap}) {
        before_rejected, before_duplicates := pair.server.stats.rejected_packets, pair.server.stats.duplicate_actions
        testing.expect_value(t, tr.send(&wire, 1, .Reliable, bytes), tr.Send_Result.Sent)
        tr.memory_advance(&pair.memory, 0)
        net.server_pump(&pair.server, 0)

        if index == 1 {
            testing.expect_value(t, pair.server.stats.duplicate_actions, before_duplicates + 1)
        }

        if index >= 2 {
            testing.expect_value(t, pair.server.stats.rejected_packets, before_rejected + 1)
        }
    }

    testing.expect_value(t, pair.server.peers[1].action_received, u64(1))
    testing.expect_value(t, pair.server.peers[1].action_count, 1)
    archive: net.Checkpoint(f.Game, f.Control, f.Action, 2)
    testing.expect_value(t, net.checkpoint_capture(&pair.server, &archive), net.Error.None)
    defer net.checkpoint_destroy(&archive)
    testing.expect_value(t, len(archive.actions), 1)

    for pair.server.timeline.head < 4 {
        testing.expect_value(t, net.server_step(&pair.server), net.Error.None)
    }

    entry, found := net.server_accepted_input(&pair.server, 4)
    testing.expect(t, found && entry.batch.has_action[1] && entry.decisions.applied[1])
    testing.expect_value(t, entry.batch.actions[1].kind, f.Action_Kind.Spawn)
}

// Wire revision 2: a predicting driver confirms from signed accepted facts
// alone. With every accepted input equal to the prediction, confirmation
// re-executes nothing, no complete image reaches the driver, and the small
// status still feeds the input-lead controller.
@(test)
driver_confirms_from_facts_without_images_or_reexecution :: proc(t: ^testing.T) {
    pair := new(Native_Pair)
    defer free(pair)
    pair_open(t, pair)
    defer pair_close(t, pair)
    now := u64(0)

    exchange :: proc(pair: ^Native_Pair, now: u64) {
        tr.memory_advance(&pair.memory, now)
        net.server_pump(&pair.server, now)
        net.server_local(&pair.server, f.Control{})
        net.server_step(&pair.server)
        tr.memory_advance(&pair.memory, now)
        net.client_pump(&pair.client, now)

        if step := net.client_step(&pair.client, f.Control{}); step != .None && step != .Capacity {
            panic("client step")
        }
    }

    for _ in 0 ..< 20 {
        now += 16
        exchange(pair, now)
    }

    replayed := pair.client.stats.replayed_ticks
    reused := pair.client.stats.reused_correction_ticks
    corrections := pair.client.stats.corrections
    confirmed := pair.client.timeline.confirmed
    compares := pair.client.physics.verified_compares + pair.client.physics.full_compares

    for _ in 0 ..< 60 {
        now += 16
        exchange(pair, now)
    }

    testing.expect(t, pair.client.timeline.confirmed >= confirmed + 50)
    testing.expect_value(t, pair.client.stats.replayed_ticks, replayed)
    testing.expect_value(t, pair.client.stats.corrections, corrections)
    testing.expect(t, pair.client.stats.reused_correction_ticks > reused)
    testing.expect_value(t, pair.client.physics.verified_compares + pair.client.physics.full_compares, compares)
    testing.expect(t, pair.client.stats.timing_samples > 0)
    testing.expect_value(t, pair.client.stats.resyncs, u64(0))

    for tx in pair.server.physics.tx {
        testing.expect_value(t, len(tx.data.bytes), 0)
    }

    tick := pair.client.timeline.confirmed
    left, le := r.capture_complete(&pair.client.timeline, tick)
    right, re := r.capture_complete(&pair.server.timeline, tick)
    testing.expect(t, le == .None && re == .None)
    defer r.complete_checkpoint_destroy(&left)
    defer r.complete_checkpoint_destroy(&right)
    n, _ := ph.dump(&left, nil)
    m, _ := ph.dump(&right, nil)
    x, y := make([]u8, int(n)), make([]u8, int(m))
    defer delete(x)
    defer delete(y)
    ph.dump(&left, x)
    ph.dump(&right, y)
    testing.expect(t, n == m && mem.compare(x, y) == 0)
    testing.expect_value(t, left.frame, right.frame)
}
