package kit_physics

// Canonical schema utility only: this imports no Replay runtime or net runner.
import "core:mem"
import b3 "godot:box3d"
import bd "godot:box3d/diagnostics"
import bg "godot:box3d/godot"
import bm "godot:box3d/godot/meter"
import knet "godot:kit/net"
import sim "godot:kit/sim"
import rs "godot:replay/schema"

Typed_Codec :: struct($T: typeid) {
    owner:       sim.World_Owner,
    users:       u32,
    schema:      rs.Schema,
    desc:        ^knet.Entity_Desc, // nil: whole typed value; nonnil: registered prediction subset
    desc_copy:   knet.Entity_Desc,
    desc_fields: []knet.Field_Desc,
    desc_names:  []u8,
    descriptor:  [dynamic]u8,
    owned:       u64,
    value:       sim.World_Value_Codec,
}

// The owned codec/context must remain at a stable address until network_detach.
// No schema-local offsets/typeid/padding are transmitted. Unregistered fields
// encode as zero and cannot be smuggled into the tracked state on decode.
codec_init :: proc(
    c: ^Typed_Codec($T),
    desc: ^knet.Entity_Desc = nil,
    allocator := context.allocator,
    ownership: SDK_User_Owner = {},
) -> sim.World_Error {
    if c == nil {
        return .Invalid
    }

    when #config(BOX3D_REQUIRE_DOMAIN, false) {
        memory, status := bm.context_for(allocator)

        if status != bg.OK ||
           !bm.owns(memory, c, u64(size_of(c^))) ||
           ownership.user != rawptr(c) ||
           sim.world_owner_is_empty(ownership.owner) {
            return .Unsupported
        }
    }

    if e := sim.world_owner_check(ownership.owner); e != .Ok {
        return e
    }

    if c.schema.initialized {
        return .Invalid
    }

    if !side_info_supported(type_info_of(T)) {
        return .Unsupported
    }

    if e := sim.world_owner_retain(ownership.owner); e != .Ok {
        return e
    }

    transferred := false

    defer {
        if !transferred {
            c.owner = {}
            _ = sim.world_owner_drop(ownership.owner)
        }
    }

    c.owner = ownership.owner
    options := rs.DEFAULT_OPTIONS
    options.max_wire_bytes = sim.WORLD_NETWORK_BYTES
    r := rs.init(&c.schema, T, options, allocator)

    if r.error != .None {
        rs.destroy(&c.schema)
        return .Unsupported
    }

    if desc != nil {
        if len(desc.fields) > knet.MAX_REPLICATED_FIELDS {
            rs.destroy(&c.schema)
            return .Capacity
        }

        names := len(desc.name)

        for field in desc.fields {
            if len(field.name) > sim.WORLD_NETWORK_BYTES - names {
                rs.destroy(&c.schema)
                return .Capacity
            }

            names += len(field.name)
        }

        var_error: mem.Allocator_Error
        c.desc_fields, var_error = make([]knet.Field_Desc, len(desc.fields), allocator)

        if var_error != nil {
            rs.destroy(&c.schema)
            return .Allocation_Failed
        }

        c.desc_names, var_error = make([]u8, names, allocator)

        if var_error != nil {
            delete(c.desc_fields, allocator)
            c.desc_fields = nil
            rs.destroy(&c.schema)
            return .Allocation_Failed
        }

        copy(c.desc_fields, desc.fields)
        at := 0
        copy(c.desc_names[:len(desc.name)], desc.name)
        c.desc_copy.name = transmute(string)c.desc_names[:len(desc.name)]
        at += len(desc.name)

        for &field in c.desc_fields {
            count := len(field.name)
            copy(c.desc_names[at:at + count], field.name)
            field.name = transmute(string)c.desc_names[at:at + count]
            at += count
        }

        c.desc_copy.fields = c.desc_fields
        c.desc = &c.desc_copy
    }

    allocation_error: mem.Allocator_Error
    c.descriptor, allocation_error = make(
        [dynamic]u8,
        0,
        len(c.schema.canonical) + 256 + len(c.desc_names) + len(c.desc_fields) * 16,
        allocator,
    )

    if allocation_error != nil {
        delete(c.desc_fields, allocator)
        delete(c.desc_names, allocator)
        c.desc_fields = nil
        c.desc_names = nil
        rs.destroy(&c.schema)
        return .Allocation_Failed
    }

    append(&c.descriptor, ..c.schema.canonical[:])

    if desc != nil {
        writer := knet.writer_make(64, allocator)
        defer knet.writer_destroy(&writer)

        for f, i in desc.fields {
            if .Predicted in f.flags {
                knet.write_u32(&writer, u32(i))
                knet.write_string(&writer, f.name)
            }
        }

        append(&c.descriptor, ..knet.writer_bytes(&writer))
    }

    c.value = {
        owner = c.owner,
        acquire = proc(user: rawptr) -> sim.World_Error {
            if user == nil {
                return .Invalid
            }

            if e := sim.world_owner_check((cast(^sim.World_Owner)user)^); e != .Ok {
                return e
            }

            c := cast(^Typed_Codec(T))user

            if c.users == max(u32) {
                return .Capacity
            }

            if e := sim.world_owner_retain(c.owner); e != .Ok {
                return e
            }

            c.users += 1
            return .Ok
        },
        release = proc(user: rawptr) -> sim.World_Error {
            if user == nil {
                return .Invalid
            }

            if e := sim.world_owner_check((cast(^sim.World_Owner)user)^); e != .Ok {
                return e
            }

            c := cast(^Typed_Codec(T))user

            if c.users == 0 {
                return .Invalid
            }

            if e := sim.world_owner_drop(c.owner); e != .Ok {
                return e
            }

            c.users -= 1
            return .Ok
        },
        user = c,
        local_bytes = desc == nil ? size_of(T) : knet.subset_view(desc, .Predicted).struct_bytes,
        wire_bytes = c.schema.wire_size,
        descriptor = c.descriptor[:],
        encode = proc(user: rawptr, local, wire: []u8) -> sim.World_Error {
            if user == nil {
                return .Invalid
            }

            if e := sim.world_owner_check((cast(^sim.World_Owner)user)^); e != .Ok {
                return e
            }

            c := cast(^Typed_Codec(T))user

            if len(local) != c.value.local_bytes || len(wire) != c.value.wire_bytes {
                return .Invalid
            }

            value: T

            if c.desc == nil {
                copy((cast([^]u8)&value)[:size_of(T)], local)
            } else {
                knet.subset_restore(knet.subset_view(c.desc, .Predicted), &value, local)
            }

            return rs.encode(&c.schema, value, wire).error == .None ? .Ok : .Invalid
        },
        decode = proc(user: rawptr, wire, local: []u8) -> sim.World_Error {
            if user == nil {
                return .Invalid
            }

            if e := sim.world_owner_check((cast(^sim.World_Owner)user)^); e != .Ok {
                return e
            }

            c := cast(^Typed_Codec(T))user

            if len(local) != c.value.local_bytes || len(wire) != c.value.wire_bytes {
                return .Invalid
            }

            value: T

            if rs.decode(&c.schema, &value, wire).error != .None {
                return .Invalid
            }

            if c.desc == nil {
                copy(local, (cast([^]u8)&value)[:size_of(T)])
            } else {
                knet.subset_capture(knet.subset_view(c.desc, .Predicted), &value, local)
                // Require zero canonical values in fields outside the fixed registry.
                canonical, err := make([]u8, c.value.wire_bytes, c.schema.allocator)

                if err != nil {
                    return .Allocation_Failed
                }

                defer delete(canonical, c.schema.allocator)

                if e := c.value.encode(user, local, canonical); e != .Ok {
                    return e
                }

                if mem.compare(canonical, wire) != 0 {
                    return .Invalid
                }
            }

            return .Ok
        },
    }
    c.owned = codec_charge(c)
    g_codec_bytes += c.owned
    g_total_external_requests += c.owned
    transferred = true
    return .Ok
}

codec_destroy :: proc(c: ^Typed_Codec($T)) -> sim.World_Error {
    if c == nil {
        return .Ok
    }

    if e := sim.world_owner_check(c.owner); e != .Ok {
        return e
    }

    if c.users != 0 {
        return .Busy
    }

    context.allocator = c.schema.allocator.procedure != nil ? c.schema.allocator : context.allocator
    owner := c.owner
    assert(g_codec_bytes >= c.owned)
    g_codec_bytes -= c.owned
    delete(c.descriptor)
    delete(c.desc_fields, c.schema.allocator)
    delete(c.desc_names, c.schema.allocator)
    rs.destroy(&c.schema)
    c^ = {}
    return sim.world_owner_drop(owner)
}

@(private)
g_codec_bytes, g_network_bytes: u64

@(private)
codec_charge :: proc(c: ^Typed_Codec($T)) -> u64 {
    s := &c.schema
    n := u64(
        size_of(c^) +
        len(c.desc_fields) * size_of(knet.Field_Desc) +
        len(c.desc_names) +
        cap(c.descriptor) +
        cap(s.canonical) +
        cap(s.fields) * size_of(rs.Field) +
        cap(s.checks) * size_of(int) +
        cap(s.validation) * size_of(s.validation[0]) +
        cap(s.validation_blocks) * size_of(s.validation_blocks[0]) +
        cap(s.spans) * size_of(s.spans[0]) +
        cap(s.arrays) * size_of(rs.Array_Span),
    )

    for f in s.fields {
        n += u64(len(f.path))
    }

    return n
}

// Zero-argument occurrences still have an explicit stable descriptor.
empty_codec :: proc() -> sim.World_Value_Codec {
    @(static) descriptor := "kit-physics-empty-value-v1"
    return {descriptor = transmute([]u8)descriptor, encode = proc(_: rawptr, a, b: []u8) -> sim.World_Error {
            return len(a) == 0 && len(b) == 0 ? .Ok : .Invalid
        }, decode = proc(_: rawptr, a, b: []u8) -> sim.World_Error {
            return len(a) == 0 && len(b) == 0 ? .Ok : .Invalid
        }}
}

Network_Identity :: bd.Identity

Network :: struct($Side: typeid) {
    owner:        sim.World_Owner,
    side_valid:   proc(value: Side) -> bool,
    instance:     ^Instance(Side),
    catalog:      b3.Recovery_Catalog,
    side:         Typed_Codec(Side),
    observations: Typed_Codec(Sensor_Observations),
    fields:       []sim.World_Wire_Field,
    inputs:       []sim.World_Wire_Input,
    identity:     bd.Identity,
    owned:        u64,
    allocator:    mem.Allocator,
}

// Catalog is cloned, typed codec contexts remain borrowed/immutable. The
// application verifies the trusted native build manifest before catalog_create.
// Identity binds the entire Side/field/occurrence/control/decision contract.
// side_valid is a pure incoming-value predicate; bind its semantics in game_rules.
network_attach :: proc(
    n: ^Network($Side),
    a: ^Instance(Side),
    catalog: ^b3.Recovery_Catalog,
    fields: []sim.World_Wire_Field,
    inputs: []sim.World_Wire_Input,
    drivers: []sim.World_Driver,
    effects: []sim.World_Effect_Def,
    game_rules: bd.Digest,
    epoch: u64 = 1,
    ownership: SDK_User_Owner = {},
) -> sim.World_Error {
    if n == nil || a == nil {
        return .Invalid
    }

    when #config(BOX3D_REQUIRE_DOMAIN, false) {
        memory, meter_status := bm.context_for(a.allocator)

        if meter_status != bg.OK ||
           !bm.owns(memory, n, u64(size_of(n^))) ||
           ownership.user != rawptr(n) ||
           sim.world_owner_is_empty(ownership.owner) {
            return .Unsupported
        }

        for effect in effects {
            if effect.user != nil &&
               (effect.user != a.config.effect_user || sim.world_owner_is_empty(a.config.effect_owner)) {
                return .Unsupported
            }
        }

        for field in fields {
            if field.codec.user != nil && sim.world_owner_is_empty(field.codec.owner) {
                return .Unsupported
            }
        }

        for input in inputs {
            if input.codec.user != nil && sim.world_owner_is_empty(input.codec.owner) {
                return .Unsupported
            }
        }
    }

    if e := sim.world_owner_check(ownership.owner); e != .Ok {
        return e
    }

    if len(fields) > 35 ||
       len(inputs) > sim.MAX_INPUT_CLASSES_PER_SEAT ||
       len(drivers) > sim.WORLD_NETWORK_DRIVERS ||
       len(effects) > sim.WORLD_EFFECTS_PER_TICK {
        return .Capacity
    }

    if n.instance != nil ||
       a.lane == nil ||
       a.lane.world == nil ||
       a.lane.world.network != nil ||
       a.lane.world.head != 0 ||
       catalog == nil ||
       game_rules == (bd.Digest{}) {
        return .Invalid
    }

    if sim.lane_world_busy(a.lane) {
        return .Busy
    }

    if e := sim.world_owner_retain(ownership.owner); e != .Ok {
        return e
    }

    n.owner = ownership.owner
    n.allocator = a.allocator
    context.allocator = n.allocator
    n.instance = a
    success := false

    defer {
        if !success {
            network_destroy(n)
        }
    }

    side_owner, observation_owner: SDK_User_Owner

    when #config(BOX3D_REQUIRE_DOMAIN, false) {
        var_error: sim.World_Error
        side_owner, var_error = sdk_user_owner_create(
            a.config.allocator_context,
            ownership.allocation_base,
            ownership.allocation_size,
            &n.side,
            u64(size_of(n.side)),
        )

        if var_error != .Ok {
            return var_error
        }

        defer sdk_user_owner_destroy(&side_owner)
        observation_owner, var_error = sdk_user_owner_create(
            a.config.allocator_context,
            ownership.allocation_base,
            ownership.allocation_size,
            &n.observations,
            u64(size_of(n.observations)),
        )

        if var_error != .Ok {
            return var_error
        }

        defer sdk_user_owner_destroy(&observation_owner)
    }

    if e := codec_init(&n.side, ownership = side_owner); e != .Ok {
        return e
    }

    if e := codec_init(&n.observations, ownership = observation_owner); e != .Ok {
        return e
    }

    status: b3.Status
    n.catalog, status = b3.recovery_catalog_clone(catalog)

    if status != .Ok {
        return map_status(status)
    }

    native, native_status := b3.recovery_catalog_identity(&n.catalog)

    if native_status != .Ok {
        return map_status(native_status)
    }

    allocation_error: mem.Allocator_Error
    n.fields, allocation_error = make([]sim.World_Wire_Field, len(fields), n.allocator)

    if allocation_error != nil || len(n.fields) != len(fields) {
        return .Allocation_Failed
    }

    copy(n.fields, fields)
    n.inputs, allocation_error = make([]sim.World_Wire_Input, len(inputs), n.allocator)

    if allocation_error != nil || len(n.inputs) != len(inputs) {
        return .Allocation_Failed
    }

    copy(n.inputs, inputs)
    n.owned = u64(
        size_of(n^) -
        size_of(n.side) -
        size_of(n.observations) +
        len(n.fields) * size_of(sim.World_Wire_Field) +
        len(n.inputs) * size_of(sim.World_Wire_Input),
    )
    g_network_bytes += n.owned
    g_total_external_requests += n.owned
    field_catalog := knet.writer_make(256, n.allocator)
    defer knet.writer_destroy(&field_catalog)

    for f in fields {
        knet.write_net_id(&field_catalog, f.id)
        knet.write_bytes(&field_catalog, f.codec.descriptor)
    }

    effect_catalog := knet.writer_make(64, n.allocator)
    defer knet.writer_destroy(&effect_catalog)

    for e in effects {
        knet.write_u16(&effect_catalog, e.kind)
        knet.write_bytes(&effect_catalog, e.codec.descriptor)
    }

    rules_copy := game_rules
    game_hash, ge := bd.hash_descriptors(
        "kit-physics-game-v1",
        []bd.Descriptor {
            {"fields", knet.writer_bytes(&field_catalog)},
            {"occurrences", knet.writer_bytes(&effect_catalog)},
            {"rules", rules_copy[:]},
            {"side", n.side.value.descriptor},
        },
    )

    if ge != .None {
        return .Incompatible
    }

    input_catalog := knet.writer_make(256, n.allocator)
    defer knet.writer_destroy(&input_catalog)
    // Ordered roster, accepted decision header, prediction semantics and each
    // actual typed schema are all part of the input contract.
    knet.write_u32(&input_catalog, sim.WORLD_NETWORK_REV)
    knet.write_u32(&input_catalog, u32(len(drivers)))

    for d in drivers {
        knet.write_player_id(&input_catalog, d.player)
        knet.write_u16(&input_catalog, d.class)
    }

    for c in inputs {
        knet.write_u16(&input_catalog, c.class)
        knet.write_u8(&input_catalog, u8(c.prediction))
        knet.write_bytes(&input_catalog, c.codec.descriptor)
    }

    input_hash, ie := bd.hash_descriptors(
        "kit-physics-input-v2",
        []bd.Descriptor{{"accepted-batch-control-action-decision", knet.writer_bytes(&input_catalog)}},
    )

    if ie != .None {
        return .Incompatible
    }

    obs_hash, oe := bd.hash_descriptors(
        "kit-physics-completed-observations-v1",
        []bd.Descriptor{{"ordered-sensors", n.observations.value.descriptor}},
    )

    if oe != .None {
        return .Incompatible
    }

    n.identity = {
        solver_format      = native.solver_format,
        recovery_format    = native.recovery_format,
        game_format        = 1,
        observation_format = 1,
        profile            = native.profile,
        build_target       = native.build_target,
        assets             = native.assets,
        solver_schema      = native.solver_schema,
        game_schema        = game_hash,
        observation_schema = obs_hash,
        input_schema       = input_hash,
    }
    // The initial local image predates network attachment. Enforce the same
    // trusted-resource source-image bound before adopting its wire identity.
    initial_image := cast(^Image(Side))a.lane.world.frames[0].image
    info, metrics_status := b3.snapshot_info(&initial_image.snapshot)

    if metrics_status != .Ok {
        return map_status(metrics_status)
    }

    if info.metrics.image_used > b3.RECOVERY_MAX_SOURCE_IMAGE_BYTES {
        return .Capacity
    }

    initial_image.info = info
    codec := sim.World_Wire_Codec {
        owner = n.owner,
        user = n,
        admit = proc(user, execution: rawptr) -> (int, sim.World_Error) {
            n := cast(^Network(Side))user
            exec := cast(^Execution(Side))execution
            external := sim.lane_world_owned_bytes(n.instance.lane) + owned_bytes()

            when #config(BOX3D_REQUIRE_DOMAIN, false) {
                service := bg.service_get()

                if status := service.legacy_extra(service.user, 0, 0, 0, &external); status != bg.OK {
                    return 0, host_status(status)
                }
            }

            count, status := b3.recovery_world_admit(&n.catalog, exec.stage.world, external)
            return int(count), map_status(status)
        },
        fields = n.fields,
        inputs = n.inputs,
        recovery_encode = proc(user, image_raw: rawptr, out: []u8) -> (int, sim.World_Error) {
            n := cast(^Network(Side))user
            image := cast(^Image(Side))image_raw
            mark, error := sdk_operation_begin(b3.RECOVERY_WRITE_RESERVE_BYTES)

            if error != .Ok {
                return 0, error
            }

            defer sdk_operation_end(&mark)

            if error := detached_admit(sim.lane_world_owned_bytes(n.instance.lane), b3.RECOVERY_WRITE_RESERVE_BYTES);
               error != .Ok {
                return 0, error
            }

            count, status := b3.recovery_write(&n.catalog, &image.snapshot, out)
            after := detached_admit(sim.lane_world_owned_bytes(n.instance.lane), 0)

            if status != .Ok {
                return int(count), map_status(status)
            }

            if error := sdk_operation_finish(mark); error != .Ok {
                return int(count), error
            }

            return int(count), after
        },
        encode = proc(user, image_raw: rawptr, part: bd.Part, out: []u8) -> (int, sim.World_Error) {
            n := cast(^Network(Side))user
            image := cast(^Image(Side))image_raw

            #partial switch part {
            case .Solver:
                if len(out) == 0 {
                    return int(image.info.storage.normalized_bytes), .Ok
                }

                count, status := b3.snapshot_dump(&image.snapshot, out)
                return int(count), map_status(status)
            case .Side:
                count := n.side.value.wire_bytes + 4

                if len(out) == 0 {
                    return count, .Ok
                }

                if len(out) < count {
                    return count, .Capacity
                }

                for i in 0 ..< 4 {
                    out[i] = u8(image.initial_dynamic_bodies >> uint(i * 8))
                }

                return count, n.side.value.encode(&n.side, (cast([^]u8)&image.side)[:size_of(Side)], out[4:count])
            case .Observations:
                count := n.observations.value.wire_bytes

                if len(out) == 0 {
                    return count, .Ok
                }

                if len(out) < count {
                    return count, .Capacity
                }

                return count, n.observations.value.encode(
                    &n.observations,
                    (cast([^]u8)&image.observations)[:size_of(Sensor_Observations)],
                    out[:count],
                )
            case:
                return 0, .Unsupported
            }
        },
        decode = proc(user: rawptr, solver, side, observations: []u8) -> (rawptr, sim.World_Error) {
            n := cast(^Network(Side))user

            if len(side) != n.side.value.wire_bytes + 4 || len(observations) != n.observations.value.wire_bytes {
                return nil, .Invalid
            }

            initial: u32

            for b, i in side[:4] {
                initial |= u32(b) << uint(i * 8)
            }

            if initial > b3.ALPHA_INITIAL_DYNAMIC_BODIES {
                return nil, .Budget
            }

            value: Side
            obs: Sensor_Observations

            if e := n.side.value.decode(&n.side, side[4:], (cast([^]u8)&value)[:size_of(Side)]); e != .Ok {
                return nil, e
            }

            if n.side_valid != nil {
                if e := sim.world_owner_check(n.owner, sim.WORLD_OWNER_EXECUTE); e != .Ok {
                    return nil, e
                }

                if !n.side_valid(value) {
                    return nil, .Invalid
                }
            }

            if e := n.observations.value.decode(
                &n.observations,
                observations,
                (cast([^]u8)&obs)[:size_of(Sensor_Observations)],
            ); e != .Ok {
                return nil, e
            }

            if obs.count > u32(len(obs.events)) {
                return nil, .Invalid
            }

            // Unused cache slots are canonical zero, rather than untracked payload.
            for event in obs.events[obs.count:] {
                if event != (Sensor_Observation{}) {
                    return nil, .Invalid
                }
            }

            for event in obs.events[:obs.count] {
                if event.began > 1 || event.sensor == 0 || event.visitor == 0 {
                    return nil, .Invalid
                }
            }

            mark, budget_error := sdk_operation_begin(b3.RECOVERY_WRITE_RESERVE_BYTES)

            if budget_error != .Ok {
                return nil, budget_error
            }

            defer sdk_operation_end(&mark)
            external := sim.lane_world_owned_bytes(n.instance.lane) + owned_bytes()

            when #config(BOX3D_REQUIRE_DOMAIN, false) {
                service := bg.service_get()

                // Read reserves DTO plus native staging internally. Exclude only
                // the known 4 MiB staging promise; lower catalog DTO limits remain
                // conservatively admitted by the unchanged native check.
                if status := service.legacy_extra(service.user, mark, 4 * 1024 * 1024, 0, &external); status != bg.OK {
                    return nil, host_status(status)
                }
            }

            snapshot, info, status := b3.recovery_read_info(&n.catalog, solver, external)

            if status != .Ok {
                return nil, map_status(status)
            }

            if info.metrics.image_used > b3.RECOVERY_MAX_SOURCE_IMAGE_BYTES {
                b3.snapshot_destroy(&snapshot)
                return nil, .Capacity
            }

            image, err := new(Image(Side), n.allocator)

            if err != nil || image == nil {
                b3.snapshot_destroy(&snapshot)
                return nil, .Allocation_Failed
            }

            image^ = {snapshot, value, n.instance.config.asset_id, n.allocator, initial, obs, n.identity, info}
            g_image_bytes += u64(size_of(image^))
            g_total_external_requests += u64(size_of(image^))

            if error := sdk_operation_finish(mark); error != .Ok {
                image_release(Side, image)
                return nil, error
            }

            return image, .Ok
        },
    }
    e := sim.lane_world_network_attach(
        a.lane,
        {identity = n.identity, codec = codec, drivers = drivers, effects = effects, epoch = epoch},
    )

    if e != .Ok {
        return e
    }

    a.network_identity = n.identity
    a.published.network_identity = n.identity
    (cast(^Image(Side))a.lane.world.frames[0].image).network_identity = n.identity
    success = true
    return .Ok
}

network_destroy :: proc(n: ^Network($Side)) -> sim.World_Error {
    if n == nil {
        return .Invalid
    }

    if e := sim.world_owner_check(n.owner); e != .Ok {
        return e
    }

    if status := b3.domain_access_check(); status != .Ok {
        return map_status(status)
    }

    context.allocator = n.allocator.procedure != nil ? n.allocator : context.allocator

    if n.instance != nil && n.instance.lane != nil {
        if error := sim.lane_world_network_detach(n.instance.lane); error != .Ok {
            return error
        }
    }

    assert(g_network_bytes >= n.owned)
    g_network_bytes -= n.owned

    if status := b3.recovery_catalog_destroy(&n.catalog); status != .Ok {
        return map_status(status)
    }

    if e := codec_destroy(&n.side); e != .Ok {
        return e
    }

    if e := codec_destroy(&n.observations); e != .Ok {
        return e
    }

    delete(n.fields, n.allocator)
    delete(n.inputs, n.allocator)
    owner := n.owner
    n^ = {}
    return sim.world_owner_drop(owner)
}
