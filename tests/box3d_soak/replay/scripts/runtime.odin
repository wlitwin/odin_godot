// Explicit test-owned contexts around the EXISTING public wire/runner APIs.
package replay_gate_b_probe

import "core:mem"
import "core:fmt"
import gd "godot:godot"
import "godot:gdext"
import bg "godot:box3d/godot"
import meter "godot:box3d/godot/meter"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import r "godot:replay"
import ph "godot:replay/physics"
import net "godot:replay/net"
import rec "godot:replay/recovery"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import view "godot:replay/view"

MAX_PACKETS :: 1024

Saved :: struct {
    data: net.Complete_Data,
    tick: u64,
    kind: u16,
}

Capture :: struct($S, $C, $A, $E: typeid) {
    base:      tr.Transport,
    codec:     ^ph.Network_Codec(S, C, A, E, 2),
    allocator: mem.Allocator,
    packets:   [MAX_PACKETS]Saved,
    count:     int,
    bytes:     u64,
    forward:   bool,
}

Lane_Lease :: struct {
    next:   ^Lane_Lease,
    user:   rawptr,
    block:  bg.Data_Lease,
    parent: r.Owner,
}

@(private)
lanes: ^Lane_Lease

Actor :: struct($S, $C, $A, $E: typeid) {
    scope:                       ^meter.Context,
    allocator:                   mem.Allocator,
    allocator_owner, self_owner: ph.Owner_Context,
    // Preparatory Hello only; its real allocator scope is closed before replay.
    hello_scope:                 ^meter.Context,
    hello_allocator_owner:       ph.Owner_Context,
    creators:                    r.Owner_Retains,
    source:                      net.Server(S, C, A, E, 2),
    client:                      net.Client(S, C, A, E, 2),
    codec:                       ph.Network_Codec(S, C, A, E, 2),
    catalog:                     b.Recovery_Catalog,
    memory:                      tr.Memory,
    endpoints:                   [2]tr.Memory_Endpoint,
    link:                        rec.Link(S, C, A, E, 2),
    capture:                     Capture(S, C, A, E),
    lane_leases:                 [2]Lane_Lease,
    lane_count:                  int,
    changes:                     [2048]view.Change(net.Net_Event(E)),
    change_count:                int,
    counts, peak_counts:         b.World_Counters,
    golden:                      net.Complete_View,
    recorder:                    Phase_Recorder,
    diagnostic_stage:            int,
    diagnostic_status:           i32,
    diagnostic_user:             u64,
}

actor_alias :: proc(a: ^Actor($S, $C, $A, $E), user: rawptr, size: u64) -> (r.Owned_Context, net.Error) {
    lease, status := meter.block_lease(a.scope, a, size_of(a^), user, size)

    if status != bg.OK {
        return {}, .Invalid_Model
    }

    owner, error := ph.owner_context_create(lease, user_data = user, require_live_instance = false)

    if error != .None {
        return {}, .Invalid_Model
    }

    if a.creators.count == len(a.creators.owners) {
        ph.owner_context_destroy(&owner)
        return {}, .Capacity
    }

    a.creators.owners[a.creators.count] = owner.owner
    a.creators.count += 1
    return {owner.owner, user}, .None
}

actor_create :: proc($S, $C, $A, $E: typeid) -> ^Actor(S, C, A, E) {
    scope, status := meter.create(bg.service_get(), bg.CATEGORY_REPLAY_PROVIDER)

    if status != bg.OK {
        return nil
    }

    allocator := meter.allocator(scope)
    a, allocation_error := new(Actor(S, C, A, E), allocator)

    if allocation_error != .None {
        meter.destroy(&scope)
        return nil
    }

    a.scope = scope
    a.allocator = allocator
    a.recorder.requested = phase_requested()
    owner_error: r.Error
    a.allocator_owner, owner_error = ph.owner_context_create(
        meter.data_lease(scope),
        allocator_data = allocator.data,
        require_live_instance = false,
    )

    if owner_error != .None {
        mem.free(a, allocator)
        meter.destroy(&scope)
        return nil
    }

    lease, ls := meter.block_lease(scope, a, size_of(a^), a, size_of(a^))

    if ls != bg.OK {
        actor_destroy(&a)
        return nil
    }

    a.self_owner, owner_error = ph.owner_context_create(lease, user_data = a, require_live_instance = false)

    if owner_error != .None {
        actor_destroy(&a)
        return nil
    }

    return a
}

actor_memory :: proc(a: ^Actor($S, $C, $A, $E)) -> bool {
    if !tr.memory_init(&a.memory, cfg = {2, 64, tr.MAX_PACKET_BYTES, 4096}, allocator = a.allocator) {
        return false
    }

    for &endpoint, index in a.endpoints {
        if !tr.memory_open(&a.memory, &endpoint, tr.Peer_Id(index + 1)) {
            return false
        }
    }

    return true
}

capture_wire :: proc(c: ^Capture($S, $C, $A, $E)) -> tr.Transport {
    wire := c.base
    wire.user = c
    wire.send = proc(p: rawptr, to: tr.Peer_Id, ch: tr.Channel, bytes: []u8) -> tr.Send_Result {
        capture := cast(^Capture(S, C, A, E))p

        if capture.count == len(capture.packets) {
            return .Backpressure
        }

        if capture.codec.value.reserve(capture.codec.value.catalog, u64(len(bytes))) != .None {
            return .Backpressure
        }

        storage, error := mem.alloc_bytes(len(bytes), allocator = capture.allocator)

        if error != .None {
            capture.codec.value.release(capture.codec.value.catalog, u64(len(bytes)))
            return .Backpressure
        }

        copy(storage, bytes)
        owned, owner_error := net.complete_data_adopt(storage, capture.allocator, capture.codec.value)

        if owner_error != .None {
            delete(storage, capture.allocator)
            capture.codec.value.release(capture.codec.value.catalog, u64(len(bytes)))
            return .Backpressure
        }

        meta, _, report := sc.inspect(bytes)

        if report.error != .None {
            net.complete_data_destroy(&owned)
            return .Backpressure
        }

        // Normal-authority tee: all fallible copy/adopt work precedes real send.
        // A successful send is followed only by an infallible owner-table publish.
        if capture.forward {
            sent := tr.send(&capture.base, to, ch, bytes)

            if sent != .Sent {
                net.complete_data_destroy(&owned)
                return sent
            }
        }

        capture.packets[capture.count] = {owned, meta.tick, meta.kind}
        capture.count += 1
        capture.bytes += u64(len(bytes))
        return .Sent
    }
    wire.receive = proc(p: rawptr, dst: []u8) -> tr.Received {
        return tr.receive(&(cast(^Capture(S, C, A, E))p).base, dst)
    }
    wire.status = proc(p: rawptr) -> tr.Status {
        return tr.status(&(cast(^Capture(S, C, A, E))p).base)
    }
    wire.connected = proc(p: rawptr, peer: tr.Peer_Id) -> bool {
        return tr.peer_connected(&(cast(^Capture(S, C, A, E))p).base, peer)
    }
    wire.generation = proc(p: rawptr, peer: tr.Peer_Id) -> u64 {
        return tr.peer_generation(&(cast(^Capture(S, C, A, E))p).base, peer)
    }
    wire.poll = nil
    wire.close = nil
    return wire
}

lane_retain :: proc "c" (user: rawptr) -> bg.Status {
    context = gdext.godot_context()
    node := lanes

    for node != nil {
        if node.user == user {
            break
        }

        node = node.next
    }

    if node == nil {
        return bg.INVALID_HANDLE
    }

    if node.block.retain(user) != bg.OK {
        return bg.INVALID_HANDLE
    }

    if r.owner_retain(node.parent) != .None {
        node.block.drop(user)
        return bg.INCOMPATIBLE
    }

    return bg.OK
}

lane_drop :: proc "c" (user: rawptr) -> bg.Status {
    context = gdext.godot_context()
    node := lanes
    previous: ^Lane_Lease

    for node != nil {
        if node.user == user {
            break
        }

        previous = node
        node = node.next
    }

    if node == nil {
        return bg.INVALID_HANDLE
    }

    block, parent := node.block, node.parent

    if block.drop(user) != bg.OK {
        return bg.INVALID_HANDLE
    }

    if previous == nil {
        lanes = node.next
    } else {
        previous.next = node.next
    }

    if r.owner_drop(&parent) != .None {
        return bg.INCOMPATIBLE
    }

    return bg.OK
}

actor_lane_owner :: proc(
    a: ^Actor($S, $C, $A, $E),
    router: ^tr.Router,
    wire: tr.Transport,
) -> (
    r.Owned_Context,
    net.Error,
) {
    if a.lane_count == len(a.lane_leases) {
        return {}, .Capacity
    }

    a.diagnostic_stage = 310
    a.diagnostic_user = u64(uintptr(wire.user))
    lease, status := meter.block_lease(
        a.scope,
        raw_data(router.lanes),
        u64(len(router.lanes)) * size_of(router.lanes[0]),
        wire.user,
        size_of(router.lanes[0]),
    )
    a.diagnostic_status = i32(status)

    if status != bg.OK {
        return {}, .Invalid_Model
    }

    node := &a.lane_leases[a.lane_count]
    a.lane_count += 1
    node^ = {lanes, wire.user, lease, a.self_owner.owner}
    lanes = node
    owner, error := ph.owner_context_create(
        {wire.user, lane_retain, lane_drop},
        user_data = wire.user,
        require_live_instance = false,
    )

    if error != .None {
        a.diagnostic_stage = 311
        a.diagnostic_status = i32(error)
        lanes = node.next
        return {}, .Invalid_Model
    }

    return {owner.owner, wire.user}, .None
}

actor_link :: proc(a: ^Actor($S, $C, $A, $E), endpoint_index: int = 1) -> bool {
    if endpoint_index < 0 || endpoint_index >= len(a.endpoints) {
        return false
    }

    owned: rec.Link_Ownership
    owned.allocator = {a.allocator_owner.owner, a.allocator.data}
    owned.lane_user = {a.self_owner.owner, a}
    error: net.Error
    owned.container, error = actor_alias(a, &a.link, size_of(a.link))

    if error != .None {
        return false
    }

    owned.config, error = actor_alias(a, &a.link.cfg, size_of(a.link.cfg))

    if error != .None {
        return false
    }

    owned.wire, error = actor_alias(a, &a.endpoints[endpoint_index], size_of(a.endpoints[endpoint_index]))

    if error != .None {
        return false
    }

    owned.lane_owner = proc(p: rawptr, router: ^tr.Router, wire: tr.Transport) -> (r.Owned_Context, net.Error) {
        return actor_lane_owner(cast(^Actor(S, C, A, E))p, router, wire)
    }
    cfg := rec.DEFAULT_LINK_CONFIG
    cfg.transport.egress_per_second = 8 * 1024 * 1024
    cfg.transport.egress_per_pump = 1024 * 1024
    cfg.transport.burst_bytes = 1024 * 1024
    return rec.link_init(&a.link, tr.memory_transport(&a.endpoints[endpoint_index]), cfg, a.allocator, owned)
}

// The real source Server and temporary Hello Client need separate ordinary
// allocation-record tables. Both scopes keep Meter's default4096 entries and
// the same provider category/global quota; no allocation wrapper is involved.
actor_hello_allocator_create :: proc(a: ^Actor($S, $C, $A, $E)) -> bool {
    if a.hello_scope != nil || !r.owner_is_nil(a.hello_allocator_owner.owner) {
        return false
    }

    status: bg.Status
    a.hello_scope, status = meter.create(bg.service_get(), bg.CATEGORY_REPLAY_PROVIDER)

    if status != bg.OK {
        a.diagnostic_stage = 420
        a.diagnostic_status = i32(status)
        return false
    }

    allocator := meter.allocator(a.hello_scope)
    error: r.Error
    a.hello_allocator_owner, error = ph.owner_context_create(
        meter.data_lease(a.hello_scope),
        allocator_data = allocator.data,
        require_live_instance = false,
    )

    if error != .None {
        a.diagnostic_stage = 421
        a.diagnostic_status = i32(error)
        return false
    }

    return true
}

actor_hello_allocator_destroy :: proc(a: ^Actor($S, $C, $A, $E)) -> bool {
    // Call only after checked client_destroy. Mutate the actual retained handles;
    // on decline preserve the remaining state for outer checked cleanup/retry.
    if !r.owner_is_nil(a.hello_allocator_owner.owner) {
        if error := ph.owner_context_destroy(&a.hello_allocator_owner); error != .None {
            a.diagnostic_stage = 422
            a.diagnostic_status = i32(error)
            return false
        }
    }

    if a.hello_scope != nil {
        if status := meter.destroy(&a.hello_scope); status != bg.OK {
            a.diagnostic_stage = 423
            a.diagnostic_status = i32(status)
            return false
        }
    }

    return true
}

actor_client :: proc(
    a: ^Actor($S, $C, $A, $E),
    model: net.Model(S, C, A, E, 2),
    wire: tr.Transport,
    wire_owner: r.Owned_Context,
    preparatory_hello: bool = false,
) -> bool {
    allocator, allocator_owner := a.allocator, a.allocator_owner

    if preparatory_hello {
        if !actor_hello_allocator_create(a) {
            return false
        }

        allocator = meter.allocator(a.hello_scope)
        allocator_owner = a.hello_allocator_owner
    }

    model_owner, error := actor_alias(a, &a.client.model, size_of(a.client.model))

    if error != .None {
        return false
    }

    owned := net.Runner_Ownership {
        allocator = {allocator_owner.owner, allocator.data},
        model     = model_owner,
        wire      = wire_owner,
    }

    if a.recorder.requested {
        recorder_owner, recorder_error := actor_alias(a, &a.recorder, size_of(a.recorder))

        if recorder_error != .None {
            return false
        }

        owned.profile_clock = recorder_owner
        owned.profile_sample = recorder_owner
    }

    error = net.client_init(
        &a.client,
        model,
        wire,
        net.Token{0 = 2},
        cfg = net.physics_config_default(),
        allocator = allocator,
        ownership = owned,
    )

    if error != .None {
        a.diagnostic_stage = 410
        a.diagnostic_status = i32(error)
    }

    return error == .None
}

actor_phase_install :: proc(a: ^Actor($S, $C, $A, $E)) {
    if !a.recorder.requested {
        return
    }

    // The exact block alias was retained by Client initialization; its creator is
    // held separately until AFTER codec destruction, covering the codec clock too.
    a.recorder.active = gd.env_string("GATE_B_TIMING_MODE", "functional_only") == "profile"
    a.client.profile_clock = {&a.recorder, phase_clock}
    a.client.profile_user = &a.recorder
    a.client.profile_sample = phase_sample
    a.codec.profile_clock = a.client.profile_clock
}

actor_server :: proc(
    a: ^Actor($S, $C, $A, $E),
    cp: ^r.Complete_Checkpoint(S, net.Net_Event(E)),
    model: net.Model(S, C, A, E, 2),
    base_wire: tr.Transport = {},
    forward: bool = false,
) -> bool {
    model_owner, error := actor_alias(a, &a.source.model, size_of(a.source.model))

    if error != .None {
        return false
    }

    capture_owner, capture_error := actor_alias(a, &a.capture, size_of(a.capture))

    if capture_error != .None {
        return false
    }

    base := base_wire

    if base.send == nil {
        base = tr.memory_transport(&a.endpoints[0])
    }

    a.capture = {
        base      = base,
        codec     = &a.codec,
        allocator = a.allocator,
        forward   = forward,
    }
    owned := net.Runner_Ownership {
        allocator = {a.allocator_owner.owner, a.allocator.data},
        model     = model_owner,
        wire      = capture_owner,
    }
    cfg := net.physics_config_default()

    if net.server_init_complete(
           &a.source,
           cp,
           model,
           capture_wire(&a.capture),
           cfg,
           local_seat = 1,
           allocator = a.allocator,
           ownership = owned,
       ) !=
       .None {
        return false
    }

    return net.server_set_local_token(&a.source, net.Token{0 = 1}) == .None
}

actor_drain :: proc(a: ^Actor($S, $C, $A, $E)) {
    a.change_count = view.drain(&a.client.journal, a.changes[:])
}

actor_destroy :: proc(pointer: ^^Actor($S, $C, $A, $E)) -> bool {
    if pointer == nil || pointer^ == nil {
        return true
    }

    a := pointer^

    if net.complete_view_destroy(&a.golden) != .None {
        return false
    }

    for &saved in a.capture.packets[:a.capture.count] {
        if net.complete_data_destroy(&saved.data) != .None {
            return false
        }
    }

    a.capture.count = 0

    if net.client_destroy(&a.client) != .None {
        return false
    }

    if !actor_hello_allocator_destroy(a) {
        return false
    }

    if net.server_destroy(&a.source) != .None || rec.link_destroy(&a.link) != .None {
        return false
    }

    if len(a.memory.packets) != 0 {
        tr.memory_destroy(&a.memory)
    }

    if a.codec.ready || a.codec.catalog._handle != nil {
        if ph.network_codec_destroy(&a.codec) != .None {
            return false
        }
    }

    if b.recovery_catalog_destroy(&a.catalog) != .Ok {
        return false
    }

    if r.owner_retains_drop(&a.creators) != .None {
        return false
    }

    scope, allocator, own, self := a.scope, a.allocator, a.allocator_owner.owner, a.self_owner.owner
    mem.free(a, allocator)

    if r.owner_drop(&self) != .None {
        return false
    }

    if r.owner_drop(&own) != .None {
        return false
    }

    pointer^ = nil
    return meter.destroy(&scope) == bg.OK
}

actor_codec :: proc(
    a: ^Actor($S, $C, $A, $E),
    catalog: b.Recovery_Catalog,
    config: ph.Config,
    rules: bd.Digest,
) -> bool {
    a.catalog = catalog
    binding, error := actor_alias(a, &a.codec, size_of(a.codec))

    if error != .None {
        return false
    }

    return(
        ph.network_codec_init(
            &a.codec,
            &a.catalog,
            config,
            rules,
            a.allocator,
            a.allocator_owner,
            {owner = binding.owner, user_data = binding.data},
        ) ==
        .None \
    )
}

actor_source_prepare :: proc(
    a: ^Actor($S, $C, $A, $E),
    world: b.World,
    game: S,
    config: ph.Config,
    model: net.Model(S, C, A, E, 2),
    stimulus: proc(_: ^net.Server(S, C, A, E, 2), _: u64) -> bool,
) -> bool {
    initial, error := ph.checkpoint_make(
        r.Frame(S){state = game},
        net.Net_Event(E),
        world,
        config,
        allocator = a.allocator,
        ownership = a.allocator_owner,
    )
    created_world := world
    b.world_destroy(&created_world)

    if error != .None {
        return false
    }

    defer r.complete_checkpoint_destroy(&initial)

    if !actor_memory(a) || !actor_server(a, &initial, model) {
        return false
    }

    // Actual public Client emits its Hello before any solver Welcome is delivered.
    wire_owner, wire_error := actor_alias(a, &a.endpoints[1], size_of(a.endpoints[1]))

    if wire_error != .None {
        return false
    }

    if !actor_client(a, model, tr.memory_transport(&a.endpoints[1]), wire_owner, preparatory_hello = true) {
        return false
    }

    if net.client_pump(&a.client, 0) != .None {
        return false
    }

    if net.client_destroy(&a.client) != .None {
        return false
    }

    if !actor_hello_allocator_destroy(a) {
        return false
    }

    tr.memory_advance(&a.memory, 0)

    if net.server_pump(&a.source, 0) != .None {
        return false
    }

    for tick in u64(1) ..= 160 {
        if !stimulus(&a.source, tick) || net.server_step(&a.source) != .None {
            return false
        }
    }

    // Real correlated retained-image request obtains full160 canonical attachment.
    request, error_bytes := mem.alloc_bytes(
        sc.HEADER_BYTES + a.source.codecs.request.wire_size,
        allocator = a.allocator,
    )

    if error_bytes != .None {
        return false
    }

    defer delete(request, a.allocator)
    peer := a.source.peers[1]
    body := request[sc.HEADER_BYTES:]
    values := [4]u64{peer.generation, peer.serial, 1, 0}

    for value, index in values {
        for i in 0 ..< 8 {
            body[index * 8 + i] = u8(value >> uint(i * 8))
        }
    }

    if sc.pack_bytes(a.source.codecs.request.fingerprint, {kind = 31, epoch = a.source.cfg.epoch, tick = 160, content = a.source.cfg.content}, body, request).error !=
       .None {
        return false
    }

    wire := tr.memory_transport(&a.endpoints[1])

    if tr.send(&wire, 1, .Reliable, request) != .Sent {
        return false
    }

    tr.memory_advance(&a.memory, 0)

    if net.server_pump(&a.source, 0) != .None {
        return false
    }

    // Independent source oracle is retained as normalized bytes, not a solver
    // image/history. It remains charged to this source codec/allocator context.
    golden_cp, golden_error := r.capture_complete(&a.source.timeline, 160, a.allocator)

    if golden_error != .None {
        return false
    }

    golden_view_error: net.Error
    a.golden, golden_view_error = net.complete_view(
        a.codec.value,
        &golden_cp,
        &a.source.physics.schemas.state,
        &a.source.physics.schemas.occurrence,
        a.allocator,
    )
    r.complete_checkpoint_destroy(&golden_cp)

    if golden_view_error != .None {
        return false
    }

    if net.server_destroy(&a.source) != .None {
        return false
    }

    tr.memory_destroy(&a.memory)
    return true
}

actor_receiver_prepare :: proc(
    a: ^Actor($S, $C, $A, $E),
    source: ^Actor(S, C, A, E),
    model: net.Model(S, C, A, E, 2),
    target_head: u64 = 160,
) -> bool {
    a.diagnostic_stage = 401

    if !actor_memory(a) {
        return false
    }

    a.diagnostic_stage = 402

    if !actor_link(a) {
        return false
    }

    a.diagnostic_stage = 403

    if !actor_client(a, model, rec.link_game_transport(&a.link), rec.link_game_owner(&a.link)) {
        return false
    }

    a.diagnostic_stage = 404
    authority := tr.memory_transport(&a.endpoints[0])
    drain, error := mem.alloc_bytes(tr.MAX_PACKET_BYTES, allocator = a.allocator)

    if error != .None {
        return false
    }

    defer delete(drain, a.allocator)

    for tick in u64(1) ..= 152 {
        for saved in source.capture.packets[:source.capture.count] {
            if saved.tick == tick {
                if tr.send(&authority, 2, .Reliable, saved.data.bytes) != .Sent {
                    return false
                }
            }
        }

        tr.memory_advance(&a.memory, tick)

        if !rec.link_pump(&a.link, tick * 16) || net.client_pump(&a.client, tick * 16) != .None {
            return false
        }

        if tick > 1 && net.client_step(&a.client, C{}) != .None {
            return false
        }

        actor_drain(a)
        tr.memory_advance(&a.memory, tick)

        for tr.receive(&authority, drain).state == .Received {}
    }

    if a.client.phase != .Running || a.client.timeline.confirmed != 152 {
        return false
    }

    for a.client.timeline.head < target_head {
        if net.client_step(&a.client, C{}) != .None {
            return false
        }
    }

    actor_drain(a)
    return a.client.timeline.head == target_head
}

actor_queue_repair :: proc(a: ^Actor($S, $C, $A, $E), source: ^Actor(S, C, A, E)) -> bool {
    authority := tr.memory_transport(&a.endpoints[0])
    parts := 0

    for saved in source.capture.packets[:source.capture.count] {
        if saved.tick == 160 && saved.kind == 28 {
            if tr.send(&authority, 2, .Reliable, saved.data.bytes) != .Sent {
                return false
            }

            parts += 1
        }
    }

    if parts == 0 {
        return false
    }

    tr.memory_advance(&a.memory, 160)
    return true
}
