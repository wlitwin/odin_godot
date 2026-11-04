package replay_runner_host_test

import "core:testing"
import "base:runtime"
import "core:mem"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import bh "godot:box3d/godot/host"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import ph "godot:replay/physics"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import rec "godot:replay/recovery"
import tf "godot:replay/transfer"

Server :: net.Server(u64, i64, i64, i64, 1)
Client :: net.Client(u64, i64, i64, i64, 1)
Model :: net.Model(u64, i64, i64, i64, 1)
// Context-free test transport entry points still exercise the existing wire
// runner. The actual underlying transport storage is explicitly Meter-owned.
@(private)
test_transport: ^tr.Memory
@(private)
test_endpoints: [2]tr.Memory_Endpoint

server_send :: proc(_: rawptr, to: tr.Peer_Id, ch: tr.Channel, bytes: []u8) -> tr.Send_Result {
    wire := tr.memory_transport(&test_endpoints[0])
    return tr.send(&wire, to, ch, bytes)
}

client_send :: proc(_: rawptr, to: tr.Peer_Id, ch: tr.Channel, bytes: []u8) -> tr.Send_Result {
    wire := tr.memory_transport(&test_endpoints[1])
    return tr.send(&wire, to, ch, bytes)
}

server_receive :: proc(_: rawptr, bytes: []u8) -> tr.Received {
    wire := tr.memory_transport(&test_endpoints[0])
    return tr.receive(&wire, bytes)
}

client_receive :: proc(_: rawptr, bytes: []u8) -> tr.Received {
    wire := tr.memory_transport(&test_endpoints[1])
    return tr.receive(&wire, bytes)
}

connected :: proc(_: rawptr) -> tr.Status {
    return .Connected
}

network_model :: proc(codec: ^ph.Network_Codec(u64, i64, i64, i64, 1)) -> Model {
    return {
        complete_state = true,
        complete_codec = codec.value,
        step = proc(game: ^u64, controls: [1]i64, joins, leaves: u64, ctx: ^r.Step(i64)) {
            if ph.step(ctx.execution) != .None {
                r.abort(ctx)
                return
            }

            game^ += 1
        },
        control_valid = proc(_: i64) -> bool {
            return true
        },
        hold = proc(v: i64) -> i64 {
            return v
        },
        state_valid = proc(_: u64) -> bool {
            return true
        },
    }
}

runner_owner :: proc(
    t: ^testing.T,
    m: ^meter.Context,
    base: rawptr,
    bytes: u64,
    model: rawptr,
    model_bytes: u64,
    allocator_owner: ph.Owner_Context,
) -> net.Runner_Ownership {
    lease, status := meter.block_lease(m, base, bytes, model, model_bytes)
    testing.expect_value(t, status, bg.OK)
    binding, error := ph.owner_context_create(lease, user_data = model, require_live_instance = false)
    testing.expect_value(t, error, r.Error.None)
    return {allocator = {allocator_owner.owner, meter.allocator(m).data}, model = {binding.owner, model}}
}

release_binding :: proc(owner: ^net.Runner_Ownership) {
    r.owner_drop(&owner.model.owner)
}

@(test)
strict_sdk_existing_complete_runners_retain_exact_model_blocks_through_join_and_teardown :: proc(t: ^testing.T) {
    contract: bg.Domain_Contract
    testing.expect_value(t, contract_get(&contract), bg.OK)
    api := bg.Native_API{contract, engine_stats, wrapper_stats, owner_open, owner_set, owner_close, ledger_get}
    hooks := bg.Core_Hooks {
        enter       = enter,
        leave       = leave,
        protected   = protected,
        code_retain = code_retain,
        code_drop   = code_drop,
        procedure   = procedure,
    }
    testing.expect_value(t, bh.registry_init(api, hooks), bg.OK)
    service: bg.Service
    testing.expect_value(t, bh.producer_create(&gate.code, &service), bg.OK)
    testing.expect_value(t, bg.module_install(&service), bg.OK)
    testing.expect_value(t, enter(nil), bg.OK)
    scope, status := bh.origin_enter(service.user)
    testing.expect_value(t, status, bg.OK)
    m, ms := meter.create(service, bg.CATEGORY_REPLAY_PROVIDER)
    testing.expect_value(t, ms, bg.OK)
    alloc := meter.allocator(m)
    owner, oe := ph.owner_context_create(
        meter.data_lease(m),
        allocator_data = alloc.data,
        require_live_instance = false,
    )
    testing.expect_value(t, oe, r.Error.None)
    managed := new(Managed_Codec, alloc)
    managed.references = 1
    managed.allocator = alloc
    context_owner, co := ph.owner_context_create(
        bg.Data_Lease{&managed.codec, retain_data, drop_data},
        user_data = &managed.codec,
        require_live_instance = false,
    )
    testing.expect_value(t, co, r.Error.None)
    config := b.recovery_config_default()
    config.profile = 17
    catalog, cs := b.recovery_catalog_create(
        config,
        []b.Recovery_Asset{b.recovery_asset_box(1, {.25, .25, .25}), b.recovery_asset_sphere(2, {}, .25)},
    )
    testing.expect_value(t, cs, b.Status.Ok)
    provider := ph.config_default(9, b.build_fingerprint())
    provider.initial_dynamic_bodies = 1
    codec := &managed.codec
    testing.expect_value(
        t,
        ph.network_codec_init(
            codec,
            &catalog,
            provider,
            bd.hash_bytes([]u8{1, 2, 3}),
            allocator = alloc,
            ownership = owner,
            context_ownership = context_owner,
        ),
        net.Error.None,
    )
    testing.expect_value(t, ph.owner_context_destroy(&context_owner), r.Error.None)
    testing.expect_value(t, drop_data(codec), bg.OK)
    b.recovery_catalog_destroy(&catalog)
    world, ws := b.world_create(b.world_def_default())
    testing.expect_value(t, ws, b.Status.Ok)
    definition := b.body_def_default()
    definition.type = .Dynamic
    definition.pose.position = {0, 2, 0}
    body, bs := b.body_create(world, definition)
    testing.expect_value(t, bs, b.Status.Ok)
    _, ss := b.shape_box(body, b.shape_def_default(), {.25, .25, .25})
    testing.expect_value(t, ss, b.Status.Ok)
    initial, ie := ph.checkpoint_make(
        r.Frame(u64){},
        net.Net_Event(i64),
        world,
        provider,
        allocator = alloc,
        ownership = owner,
    )
    testing.expect_value(t, ie, r.Error.None)
    b.world_destroy(&world)
    server := new(Server, alloc)
    client := new(Client, alloc)
    server_ptr, client_ptr := rawptr(server), rawptr(client)
    server_owner := runner_owner(t, m, server, size_of(Server), &server.model, size_of(Model), owner)
    client_owner := runner_owner(t, m, client, size_of(Client), &client.model, size_of(Model), owner)
    cfg := net.physics_config_default()
    model := network_model(codec)
    // Missing inner Model lease and undeclared raw callback contexts fail before
    // callbacks or container allocations. The original declared owners survive.
    missing := server_owner
    missing.model = {}
    testing.expect_value(
        t,
        net.server_init_complete(server, &initial, model, {}, cfg, allocator = alloc, ownership = missing),
        net.Error.Invalid_Model,
    )
    invalid := model
    invalid.user = server
    testing.expect_value(
        t,
        net.server_init_complete(server, &initial, invalid, {}, cfg, allocator = alloc, ownership = server_owner),
        net.Error.Invalid_Model,
    )
    invalid = model
    invalid.action_admission_user = server
    testing.expect_value(
        t,
        net.server_init_complete(server, &initial, invalid, {}, cfg, allocator = alloc, ownership = server_owner),
        net.Error.Invalid_Model,
    )
    // A retained-model partial initialization failure releases every child owner.
    invalid = model
    invalid.step = nil
    before := bh.registry_stats().owners
    testing.expect_value(
        t,
        net.server_init_complete(server, &initial, invalid, {}, cfg, allocator = alloc, ownership = server_owner),
        net.Error.Invalid_Model,
    )
    testing.expect_value(t, bh.registry_stats().owners, before)
    testing.expect_value(
        t,
        net.client_init(client, invalid, {}, net.Token{0 = 2}, cfg = cfg, allocator = alloc, ownership = client_owner),
        net.Error.Invalid_Model,
    )
    testing.expect_value(t, bh.registry_stats().owners, before)
    test_transport = new(tr.Memory, alloc)
    testing.expect(t, tr.memory_init(test_transport, cfg = {2, 64, tr.MAX_PACKET_BYTES, 2048}, allocator = alloc))

    for &endpoint, index in test_endpoints {
        testing.expect(t, tr.memory_open(test_transport, &endpoint, tr.Peer_Id(index + 1)))
    }

    testing.expect_value(
        t,
        net.server_init_complete(
            server,
            &initial,
            model,
            {send = server_send, receive = server_receive, status = connected},
            cfg,
            allocator = alloc,
            ownership = server_owner,
        ),
        net.Error.None,
    )
    testing.expect_value(
        t,
        net.client_init(
            client,
            model,
            {send = client_send, receive = client_receive, status = connected},
            net.Token{0 = 2},
            cfg = cfg,
            allocator = alloc,
            ownership = client_owner,
        ),
        net.Error.None,
    )
    r.complete_checkpoint_destroy(&initial)
    release_binding(&server_owner)
    release_binding(&client_owner)
    // Direct owner free is real: Meter defers these two blocks solely because
    // the runners and their inner Timelines own explicit model-subfield leases.
    mem.free(server, alloc)
    mem.free(client, alloc)
    testing.expect(t, meter.owns(m, server_ptr, size_of(Server)) && meter.owns(m, client_ptr, size_of(Client)))

    for tick in 0 ..< 10 {
        now := u64(tick * 17)
        tr.memory_advance(test_transport, u64(tick))
        testing.expect_value(t, net.client_pump(client, now), net.Error.None)
        tr.memory_advance(test_transport, u64(tick))
        testing.expect_value(t, net.server_pump(server, now), net.Error.None)
        testing.expect_value(t, net.server_step(server), net.Error.None)
        testing.expect_value(t, net.server_pump(server, now), net.Error.None)
        tr.memory_advance(test_transport, u64(tick))
        testing.expect_value(t, net.client_pump(client, now), net.Error.None)
    }

    testing.expect_value(t, client.phase, net.Phase.Running)
    testing.expect(t, client.has_world && client.timeline.confirmed > 0 && server.timeline.head == 10)
    // The canonical welcome created a second real native world and the known
    // accepted suffix has identical complete solver bytes and typed Game state.
    confirmed := client.timeline.confirmed
    left, le := r.capture_complete(&server.timeline, confirmed, alloc)
    right, re := r.capture_complete(&client.timeline, confirmed, alloc)
    testing.expect_value(t, le, r.Error.None)
    testing.expect_value(t, re, r.Error.None)
    testing.expect_value(t, left.frame, right.frame)
    ln, lde := ph.dump(&left, nil)
    rn, rde := ph.dump(&right, nil)
    testing.expect_value(t, lde, r.Error.None)
    testing.expect_value(t, rde, r.Error.None)
    testing.expect_value(t, ln, rn)
    a, z := make([]u8, int(ln), alloc), make([]u8, int(rn), alloc)
    _, lde = ph.dump(&left, a)
    _, rde = ph.dump(&right, z)
    testing.expect_value(t, lde, r.Error.None)
    testing.expect_value(t, rde, r.Error.None)
    testing.expect_value(t, mem.compare(a, z), 0)
    delete(a, alloc)
    delete(z, alloc)
    r.complete_checkpoint_destroy(&left)
    r.complete_checkpoint_destroy(&right)
    // A changed callback context is rejected before any callback/publication.
    head := server.timeline.head
    server.model.user = server
    testing.expect_value(t, net.server_step(server), net.Error.Invalid_Model)
    testing.expect_value(t, server.timeline.head, head)
    server.model.user = nil
    // Destruction outside stable Core origin preserves the complete owner/ring.
    bh.origin_leave(scope)
    leave(nil)
    testing.expect_value(t, net.server_destroy(server), net.Error.Invalid_Model)
    testing.expect(t, meter.is_allocator(alloc))
    testing.expect_value(t, enter(nil), bg.OK)
    scope, status = bh.origin_enter(service.user)
    testing.expect_value(t, status, bg.OK)
    testing.expect_value(t, server.timeline.head, head)
    testing.expect(t, server.initialized && server.physics != nil)
    // Durable canonical archive and expected complete image own their contexts
    // independently of both source runners.
    archive: net.Checkpoint(u64, i64, i64, 1)
    testing.expect_value(t, net.checkpoint_capture(server, &archive, allocator = alloc), net.Error.None)
    expected_cp, expected_error := r.capture_complete(&server.timeline, server.timeline.head, alloc)
    testing.expect_value(t, expected_error, r.Error.None)
    encoded, encode_error := net.checkpoint_encode_owned(&archive, model, alloc)
    testing.expect_value(t, encode_error, net.Error.None)
    testing.expect_value(t, net.checkpoint_destroy(&archive), net.Error.None)
    testing.expect_value(t, net.client_destroy(client), net.Error.None)
    client = nil
    testing.expect(t, !meter.owns(m, client_ptr, size_of(Client)))
    testing.expect_value(t, net.server_destroy(server), net.Error.None)
    server = nil
    testing.expect(t, !meter.owns(m, server_ptr, size_of(Server)))
    // Source worlds and actual runner allocations are gone. Decode and restore
    // into the SAME existing Server implementation from independently owned bytes.
    decoded: net.Checkpoint(u64, i64, i64, 1)
    testing.expect_value(t, net.checkpoint_decode(&decoded, encoded.bytes, model, cfg.content, alloc), net.Error.None)
    testing.expect_value(t, net.complete_data_destroy(&encoded), net.Error.None)
    resumed := new(Server, alloc)
    resumed_ptr := rawptr(resumed)
    resumed_owner := runner_owner(t, m, resumed, size_of(Server), &resumed.model, size_of(Model), owner)
    testing.expect_value(
        t,
        net.server_restore(resumed, &decoded, model, {}, {epoch = 2}, alloc, ownership = resumed_owner),
        net.Error.None,
    )
    testing.expect_value(t, net.checkpoint_destroy(&decoded), net.Error.None)
    release_binding(&resumed_owner)
    mem.free(resumed, alloc)
    restored_cp, restored_error := r.capture_complete(&resumed.timeline, resumed.timeline.head, alloc)
    testing.expect_value(t, restored_error, r.Error.None)
    testing.expect_value(t, restored_cp.frame, expected_cp.frame)
    en, _ := ph.dump(&expected_cp, nil)
    rrn, _ := ph.dump(&restored_cp, nil)
    testing.expect_value(t, en, rrn)
    ebytes, rbytes := make([]u8, int(en), alloc), make([]u8, int(rrn), alloc)
    ph.dump(&expected_cp, ebytes)
    ph.dump(&restored_cp, rbytes)
    testing.expect_value(t, mem.compare(ebytes, rbytes), 0)
    delete(ebytes, alloc)
    delete(rbytes, alloc)
    r.complete_checkpoint_destroy(&expected_cp)
    r.complete_checkpoint_destroy(&restored_cp)
    testing.expect_value(t, net.server_step(resumed), net.Error.None)
    transfer_archive: net.Checkpoint(u64, i64, i64, 1)
    testing.expect_value(t, net.checkpoint_capture(resumed, &transfer_archive, allocator = alloc), net.Error.None)
    testing.expect_value(t, net.server_destroy(resumed), net.Error.None)
    resumed = nil
    testing.expect(t, !meter.owns(m, resumed_ptr, size_of(Server)))
    // Existing recovery/TF owners run after ALL source Server worlds are gone.
    tr.memory_destroy(test_transport)
    test_endpoints = {}
    testing.expect(t, tr.memory_init(test_transport, cfg = {2, 64, 1200, 2048}, allocator = alloc))

    for &endpoint, index in test_endpoints {
        testing.expect(t, tr.memory_open(test_transport, &endpoint, tr.Peer_Id(index + 1)))
    }

    transfer_source_free(t, m, owner, model, &transfer_archive, service)
    testing.expect_value(t, net.checkpoint_destroy(&transfer_archive), net.Error.None)
    tr.memory_destroy(test_transport)
    mem.free(test_transport, alloc)
    test_transport = nil
    test_endpoints = {}
    carrier_tombstone(t, m, owner)
    testing.expect_value(t, ph.network_codec_destroy(codec), net.Error.None)
    codec = nil
    testing.expect_value(t, ph.owner_context_destroy(&owner), r.Error.None)
    testing.expect_value(t, meter.destroy(&m), bg.OK)
    testing.expect_value(t, ph.allocation_stats().live_bytes, u64(0))
    testing.expect_value(t, bh.registry_stats().marks, u32(0))
    testing.expect_value(t, bh.registry_stats().owners, u32(0))
    bh.origin_leave(scope)
    leave(nil)
    testing.expect_value(t, bh.producer_destroy(service.user), bg.OK)
    testing.expect_value(t, bh.registry_shutdown(), bg.OK)
    native: bg.Allocation_Stats
    testing.expect_value(t, engine_stats(&native), bg.OK)
    testing.expect_value(t, native.live_bytes, u64(0))
    testing.expect_value(t, wrapper_stats(&native), bg.OK)
    testing.expect_value(t, native.live_bytes, u64(0))
    testing.expect_value(t, gate.code.refs, u32(0))
}

// Exact explicit subfield aliases keep the actual containing blocks alive.
block_context :: proc(
    t: ^testing.T,
    m: ^meter.Context,
    base: rawptr,
    bytes: u64,
    user: rawptr,
    user_bytes: u64,
) -> r.Owned_Context {
    lease, ls := meter.block_lease(m, base, bytes, user, user_bytes)
    testing.expect_value(t, ls, bg.OK)
    binding, error := ph.owner_context_create(lease, user_data = user, require_live_instance = false)
    testing.expect_value(t, error, r.Error.None)
    return {binding.owner, user}
}

transfer_source_free :: proc(
    t: ^testing.T,
    m: ^meter.Context,
    owner: ph.Owner_Context,
    model: Model,
    archive: ^net.Checkpoint(u64, i64, i64, 1),
    service: bg.Service,
) {
    alloc := meter.allocator(m)
    sender := new(tf.Sender, alloc)
    receiver := new(rec.Receiver(u64, i64, i64, i64, 1), alloc)
    sender_ptr, receiver_ptr := rawptr(sender), rawptr(receiver)
    sender_context := block_context(t, m, sender, size_of(sender^), sender, size_of(sender^))
    receiver_context := block_context(t, m, receiver, size_of(receiver^), receiver, size_of(receiver^))
    model_context := block_context(t, m, receiver, size_of(receiver^), &receiver.model, size_of(Model))
    codec_context := block_context(
        t,
        m,
        receiver,
        size_of(receiver^),
        &receiver.archive_codec,
        size_of(net.Checkpoint_Codec),
    )
    allocator_context := r.Owned_Context{owner.owner, alloc.data}
    codec_owner := model.complete_codec.ownership.data_context
    sender_ownership := tf.Ownership {
        allocator = allocator_context,
        container = sender_context,
        budget    = codec_owner,
    }
    receiver_ownership := rec.Receiver_Ownership {
        transfer = {
            allocator = allocator_context,
            container = receiver_context,
            accept = receiver_context,
            budget = codec_owner,
        },
        model = model_context,
        codec = {allocator = allocator_context, data_context = codec_context},
    }
    scope := rec.Scope {
        room    = 7,
        epoch   = 2,
        binding = 9,
        content = archive.header.content,
    }
    testing.expect_value(
        t,
        rec.sender_init(
            sender,
            scope,
            2,
            {send = server_send, receive = server_receive, status = connected},
            allocator = alloc,
            ownership = sender_ownership,
        ),
        rec.Error.None,
    )
    missing := receiver_ownership
    missing.transfer.accept = {}
    testing.expect_value(
        t,
        rec.receiver_init(
            receiver,
            scope,
            1,
            {send = client_send, receive = client_receive, status = connected},
            model,
            allocator = alloc,
            ownership = missing,
        ),
        rec.Error.Invalid_Config,
    )
    testing.expect_value(
        t,
        rec.receiver_init(
            receiver,
            scope,
            1,
            {send = client_send, receive = client_receive, status = connected},
            model,
            allocator = alloc,
            ownership = receiver_ownership,
        ),
        rec.Error.None,
    )

    for binding in ([?]r.Owned_Context{sender_context, receiver_context, model_context, codec_context}) {
        local := binding.owner
        testing.expect_value(t, r.owner_drop(&local), r.Error.None)
    }

    testing.expect_value(t, rec.sender_publish(sender, archive, model, 0), rec.Error.None)
    mem.free(sender, alloc)
    mem.free(receiver, alloc)
    testing.expect(t, meter.owns(m, sender_ptr, size_of(tf.Sender)) && meter.owns(m, receiver_ptr, size_of(receiver^)))
    buffer: [1200]u8

    for tick in 1 ..= 300 {
        now := u64(tick * 10)
        tr.memory_advance(test_transport, now)

        for &endpoint, index in test_endpoints {
            wire := tr.memory_transport(&endpoint)

            for _ in 0 ..< 128 {
                packet := tr.receive(&wire, buffer[:])

                if packet.state != .Received {
                    break
                }

                if index == 0 {
                    rec.sender_receive(sender, packet.from, buffer[:packet.count], now)
                } else {
                    rec.receiver_receive(receiver, packet.from, buffer[:packet.count], now, packet.channel)
                }
            }
        }

        rec.sender_update(sender, now)
        rec.receiver_update(receiver, now)

        if sender.phase == .Complete {
            break
        }
    }

    testing.expect_value(t, sender.phase, rec.Phase.Complete)
    // An already promised one-byte operation cannot admit a replacement payload.
    // Failure occurs before allocation/publication and leaves old Sender ownership.
    previous_bytes, previous_clock, previous_sequence, previous_archive :=
        raw_data(sender.bytes), sender.started, sender.next_sequence, sender.archive
    mark: u64
    testing.expect_value(t, service.budget_begin(service.user, 1, &mark), bg.OK)
    testing.expect_value(t, tf.sender_begin(sender, sender.bytes, 10000), tf.Error.Capacity)
    testing.expect_value(t, raw_data(sender.bytes), previous_bytes)
    testing.expect_value(t, sender.started, previous_clock)
    testing.expect_value(t, sender.next_sequence, previous_sequence)
    testing.expect_value(t, sender.archive, previous_archive)
    testing.expect_value(t, service.budget_end(service.user, mark), bg.OK)
    receipt, found := rec.receiver_latest(receiver)
    testing.expect(t, found)
    decoded, ready := rec.receiver_checkpoint(receiver, receipt.archive)
    testing.expect(t, ready)

    if ready {
        testing.expect_value(t, decoded.frame, archive.frame)
    }

    testing.expect_value(t, rec.receiver_destroy(receiver), rec.Error.None)
    receiver = nil
    testing.expect_value(t, rec.sender_destroy(sender), rec.Error.None)
    sender = nil
    testing.expect(
        t,
        !meter.owns(m, sender_ptr, size_of(tf.Sender)) &&
        !meter.owns(m, receiver_ptr, size_of(rec.Receiver(u64, i64, i64, i64, 1))),
    )
}

Fault_Context :: struct {
    refs:      u32,
    deny:      bool,
    allocator: mem.Allocator,
}

@(private)
fault_freed, fault_releases: u64

fault_retain :: proc "c" (pointer: rawptr) -> bg.Status {
    (cast(^Fault_Context)pointer).refs += 1
    return bg.OK
}

fault_drop :: proc "c" (pointer: rawptr) -> bg.Status {
    context = runtime.default_context()
    data := cast(^Fault_Context)pointer

    if data.refs == 1 && data.deny {
        return bg.INCOMPATIBLE
    }

    data.refs -= 1

    if data.refs == 0 {
        fault_freed += 1
        mem.free(data, data.allocator)
    }

    return bg.OK
}

carrier_tombstone :: proc(t: ^testing.T, m: ^meter.Context, allocator_owner: ph.Owner_Context) {
    alloc := meter.allocator(m)
    data := new(Fault_Context, alloc)
    data^ = {
        refs      = 1,
        deny      = true,
        allocator = alloc,
    }
    owner, error := ph.owner_context_create(
        {data, fault_retain, fault_drop},
        user_data = data,
        require_live_instance = false,
    )
    testing.expect_value(t, error, r.Error.None)
    codec := net.Complete_Codec(u64, i64) {
        catalog = data,
        ownership = {allocator = {allocator_owner.owner, alloc.data}, data_context = {owner.owner, data}},
        release = proc(_: rawptr, _: u64) {
            fault_releases += 1
        },
    }
    bytes := make([]u8, 17, alloc)
    owned, adopt_error := net.complete_data_adopt(bytes, alloc, codec)
    testing.expect_value(t, adopt_error, net.Error.None)
    testing.expect_value(t, ph.owner_context_destroy(&owner), r.Error.None)
    // Drop the real source reference; only retained Data_Lease owns the heap data.
    testing.expect_value(t, fault_drop(data), bg.OK)
    testing.expect_value(t, net.complete_data_destroy(&owned), net.Error.Invalid_Model)
    testing.expect_value(t, len(owned.bytes), 0)
    testing.expect_value(t, fault_releases, u64(1))
    testing.expect_value(t, fault_freed, u64(0))
    data.deny = false
    testing.expect_value(t, net.complete_data_destroy(&owned), net.Error.None)
    testing.expect_value(t, fault_releases, u64(1))
    testing.expect_value(t, fault_freed, u64(1))
}
