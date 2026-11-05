package box3d

import bg "godot:box3d/godot"
import intrinsics "base:intrinsics"

// Mirrors native/api.h, owned_snapshot.h and state_dump.h. No Box3D/C++ layout
// crosses this boundary. Native IDs are packed/unpacked exclusively by C.
@(private)
BOX3D_LIBRARY :: #config(BOX3D_LIBRARY, "native/libogb3.a")

// Odin treats an ordinary foreign import as package-relative even when it starts
// with '/'. The system prefix preserves an explicitly supplied absolute archive.
@(private)
BOX3D_LINK_LIBRARY ::
    "system:" + BOX3D_LIBRARY when len(BOX3D_LIBRARY) > 0 && BOX3D_LIBRARY[0] == '/' else BOX3D_LIBRARY

// The object is linked by emcc, not loaded as a named browser module. Odin's
// wasm foreign environment marker emits linkable env symbols; a desktop-style
// archive pathname would survive as a spurious WebAssembly import namespace.
when ODIN_ARCH == .wasm32 || ODIN_ARCH == .wasm64p32 {
    foreign import native "env.o"
} else {
    foreign import native {BOX3D_LINK_LIBRARY}
}

when ODIN_OS == .Linux {
    foreign import native_math "system:m"
}

ABI_VERSION :: 1

Status :: enum i32 {
    Ok               = 0,
    Invalid_Argument = 1,
    Invalid_Handle   = 2,
    Out_Of_Memory    = 3,
    Capacity         = 4,
    Unsupported      = 5,
    Incompatible     = 6,
    Corrupt          = 7,
}

World :: distinct u32
Body :: distinct u64
Shape :: distinct u64
Joint :: distinct u64
Body_Key :: distinct u64
Shape_Key :: distinct u64
Joint_Key :: distinct u64

Vec3 :: struct {
    x, y, z: f32,
}

Quat :: struct {
    x, y, z, w: f32,
}

Pose :: struct {
    position: Vec3,
    rotation: Quat,
}

IDENTITY_ROTATION :: Quat {
    w = 1,
}
IDENTITY_POSE :: Pose {
    rotation = IDENTITY_ROTATION,
}

World_Def :: struct {
    gravity:           Vec3,
    enable_sleep:      u32,
    enable_continuous: u32,
}

Body_Type :: enum i32 {
    Static    = 0,
    Kinematic = 1,
    Dynamic   = 2,
}

Body_Def :: struct {
    type:             Body_Type,
    pose:             Pose,
    linear_velocity:  Vec3,
    angular_velocity: Vec3,
    linear_damping:   f32,
    angular_damping:  f32,
    gravity_scale:    f32,
    sleep_threshold:  f32,
    enable_sleep:     u32,
    is_awake:         u32,
    is_bullet:        u32,
    is_enabled:       u32,
}

Shape_Def :: struct {
    category_bits:         u64,
    mask_bits:             u64,
    group_index:           i32,
    density:               f32,
    friction:              f32,
    restitution:           f32,
    is_sensor:             u32,
    enable_sensor_events:  u32,
    enable_contact_events: u32,
}

Hinge_Def :: struct {
    body_a:            Body,
    body_b:            Body,
    local_frame_a:     Pose,
    local_frame_b:     Pose,
    lower_angle:       f32,
    upper_angle:       f32,
    motor_speed:       f32,
    max_motor_torque:  f32,
    enable_limit:      u32,
    enable_motor:      u32,
    collide_connected: u32,
}

Query_Filter :: struct {
    category_bits, mask_bits: u64,
}

Ray_Hit :: struct {
    shape:    Shape,
    point:    Vec3,
    normal:   Vec3,
    fraction: f32,
    reserved: u32,
}

Sensor_Event :: struct {
    sensor:   Shape,
    visitor:  Shape,
    began:    u32,
    reserved: u32,
}

World_Counters :: struct {
    body_count, shape_count, contact_count, joint_count, island_count, tree_height: u32,
}

Body_State :: struct {
    key:                               Body_Key,
    pose:                              Pose,
    linear_velocity, angular_velocity: Vec3,
    mass:                              f32,
    type:                              Body_Type,
    is_awake, is_enabled:              u32,
}

Allocation_Stats :: struct {
    total_calls:      u64,
    total_bytes:      u64,
    live_bytes:       u64,
    high_water_bytes: u64,
}

#assert(size_of(World) == 4 && size_of(Body) == 8 && size_of(Shape) == 8 && size_of(Joint) == 8)
#assert(size_of(Status) == 4 && size_of(Body_Type) == 4)
#assert(size_of(Vec3) == 12 && size_of(Quat) == 16 && size_of(Pose) == 28)
#assert(size_of(World_Def) == 20 && size_of(Body_Def) == 88)
#assert(size_of(Shape_Def) == 48 && size_of(Hinge_Def) == 104)
#assert(size_of(Query_Filter) == 16 && size_of(Ray_Hit) == 40 && size_of(Sensor_Event) == 24)
#assert(size_of(Allocation_Stats) == 32)
#assert(size_of(World_Counters) == 24 && size_of(Body_State) == 80)
#assert(size_of(Body_Key) == 8 && size_of(Shape_Key) == 8 && size_of(Joint_Key) == 8)

// Check all field offsets, sizes and alignments against C before passing any POD
// to native code. A status failure leaves world creation unattempted.
abi_check :: proc() -> Status {
    if version_status := native_version_check(); version_status != .Ok {
        return version_status
    }

    checks := [?]struct {
        id, size, alignment: u32,
        offsets:             []uintptr,
    } {
        {1, size_of(Vec3), align_of(Vec3), []uintptr{offset_of(Vec3, x), offset_of(Vec3, y), offset_of(Vec3, z)}},
        {
            2,
            size_of(Quat),
            align_of(Quat),
            []uintptr{offset_of(Quat, x), offset_of(Quat, y), offset_of(Quat, z), offset_of(Quat, w)},
        },
        {3, size_of(Pose), align_of(Pose), []uintptr{offset_of(Pose, position), offset_of(Pose, rotation)}},
        {
            4,
            size_of(World_Def),
            align_of(World_Def),
            []uintptr {
                offset_of(World_Def, gravity),
                offset_of(World_Def, enable_sleep),
                offset_of(World_Def, enable_continuous),
            },
        },
        {
            5,
            size_of(Body_Def),
            align_of(Body_Def),
            []uintptr {
                offset_of(Body_Def, type),
                offset_of(Body_Def, pose),
                offset_of(Body_Def, linear_velocity),
                offset_of(Body_Def, angular_velocity),
                offset_of(Body_Def, linear_damping),
                offset_of(Body_Def, angular_damping),
                offset_of(Body_Def, gravity_scale),
                offset_of(Body_Def, sleep_threshold),
                offset_of(Body_Def, enable_sleep),
                offset_of(Body_Def, is_awake),
                offset_of(Body_Def, is_bullet),
                offset_of(Body_Def, is_enabled),
            },
        },
        {
            6,
            size_of(Shape_Def),
            align_of(Shape_Def),
            []uintptr {
                offset_of(Shape_Def, category_bits),
                offset_of(Shape_Def, mask_bits),
                offset_of(Shape_Def, group_index),
                offset_of(Shape_Def, density),
                offset_of(Shape_Def, friction),
                offset_of(Shape_Def, restitution),
                offset_of(Shape_Def, is_sensor),
                offset_of(Shape_Def, enable_sensor_events),
                offset_of(Shape_Def, enable_contact_events),
            },
        },
        {
            7,
            size_of(Hinge_Def),
            align_of(Hinge_Def),
            []uintptr {
                offset_of(Hinge_Def, body_a),
                offset_of(Hinge_Def, body_b),
                offset_of(Hinge_Def, local_frame_a),
                offset_of(Hinge_Def, local_frame_b),
                offset_of(Hinge_Def, lower_angle),
                offset_of(Hinge_Def, upper_angle),
                offset_of(Hinge_Def, motor_speed),
                offset_of(Hinge_Def, max_motor_torque),
                offset_of(Hinge_Def, enable_limit),
                offset_of(Hinge_Def, enable_motor),
                offset_of(Hinge_Def, collide_connected),
            },
        },
        {
            8,
            size_of(Query_Filter),
            align_of(Query_Filter),
            []uintptr{offset_of(Query_Filter, category_bits), offset_of(Query_Filter, mask_bits)},
        },
        {
            9,
            size_of(Ray_Hit),
            align_of(Ray_Hit),
            []uintptr {
                offset_of(Ray_Hit, shape),
                offset_of(Ray_Hit, point),
                offset_of(Ray_Hit, normal),
                offset_of(Ray_Hit, fraction),
                offset_of(Ray_Hit, reserved),
            },
        },
        {
            10,
            size_of(Sensor_Event),
            align_of(Sensor_Event),
            []uintptr {
                offset_of(Sensor_Event, sensor),
                offset_of(Sensor_Event, visitor),
                offset_of(Sensor_Event, began),
                offset_of(Sensor_Event, reserved),
            },
        },
        {
            11,
            size_of(Allocation_Stats),
            align_of(Allocation_Stats),
            []uintptr {
                offset_of(Allocation_Stats, total_calls),
                offset_of(Allocation_Stats, total_bytes),
                offset_of(Allocation_Stats, live_bytes),
                offset_of(Allocation_Stats, high_water_bytes),
            },
        },
        {
            12,
            size_of(World_Counters),
            align_of(World_Counters),
            []uintptr {
                offset_of(World_Counters, body_count),
                offset_of(World_Counters, shape_count),
                offset_of(World_Counters, contact_count),
                offset_of(World_Counters, joint_count),
                offset_of(World_Counters, island_count),
                offset_of(World_Counters, tree_height),
            },
        },
        {
            13,
            size_of(Body_State),
            align_of(Body_State),
            []uintptr {
                offset_of(Body_State, key),
                offset_of(Body_State, pose),
                offset_of(Body_State, linear_velocity),
                offset_of(Body_State, angular_velocity),
                offset_of(Body_State, mass),
                offset_of(Body_State, type),
                offset_of(Body_State, is_awake),
                offset_of(Body_State, is_enabled),
            },
        },
        {
            14,
            size_of(Domain_Contract),
            align_of(Domain_Contract),
            []uintptr {
                offset_of(Domain_Contract, cookie),
                offset_of(Domain_Contract, size),
                offset_of(Domain_Contract, version),
                offset_of(Domain_Contract, abi_version),
                offset_of(Domain_Contract, logical_version),
                offset_of(Domain_Contract, resource_version),
                offset_of(Domain_Contract, recovery_version),
                offset_of(Domain_Contract, pointer_bits),
                offset_of(Domain_Contract, endian),
                offset_of(Domain_Contract, build),
                offset_of(Domain_Contract, target),
            },
        },
        {
            15,
            size_of(Host_Owner_Info),
            align_of(Host_Owner_Info),
            []uintptr {
                offset_of(Host_Owner_Info, producer),
                offset_of(Host_Owner_Info, component),
                offset_of(Host_Owner_Info, live_bytes),
                offset_of(Host_Owner_Info, reserved_bytes),
            },
        },
        {
            16,
            size_of(Host_Ledger_Stats),
            align_of(Host_Ledger_Stats),
            []uintptr {
                offset_of(Host_Ledger_Stats, engine_live_bytes),
                offset_of(Host_Ledger_Stats, snapshot_live_bytes),
                offset_of(Host_Ledger_Stats, host_live_bytes),
                offset_of(Host_Ledger_Stats, host_reserved_bytes),
                offset_of(Host_Ledger_Stats, live_bytes),
                offset_of(Host_Ledger_Stats, admitted_bytes),
                offset_of(Host_Ledger_Stats, limit_bytes),
                offset_of(Host_Ledger_Stats, committed_peak_bytes),
                offset_of(Host_Ledger_Stats, successful_updates),
                offset_of(Host_Ledger_Stats, ledger_storage_bytes),
                offset_of(Host_Ledger_Stats, owner_count),
                offset_of(Host_Ledger_Stats, owner_capacity),
            },
        },
    }

    for check in checks {
        for expected, index in check.offsets {
            size, alignment, offset: u32
            status := c_abi_layout(check.id, u32(index), &size, &alignment, &offset)

            if status != .Ok || size != check.size || alignment != check.alignment || uintptr(offset) != expected {
                return .Incompatible
            }
        }
    }

    return .Ok
}

// Callable before initialization; rejects an ABI-compatible archive whose
// logical snapshot/dump contract differs. Cleanup calls remain available.
@(private)
native_version_check :: proc() -> Status {
    if c_abi_version() != ABI_VERSION || c_state_version() != STATE_DUMP_VERSION {
        return .Incompatible
    }

    return .Ok
}

build_fingerprint :: proc() -> u64 {
    return c_build_fingerprint()
}

// Process-wide length scale (Box3D's lengthUnitsPerMeter, default 1). Contact slop
// (0.005 m x units), speculative distance and AABB margins scale with it, so a scene
// far smaller than a metre, such as a 3 cm golf ball, can use e.g. 0.1. Call it before
// the first world, geometry or build_fingerprint in the process; afterwards only the
// current value is accepted (.Unsupported). The fingerprint is computed with it, so
// processes using different values never match. Kit and Replay are validated with 1.
set_length_units_per_meter :: proc(units: f32) -> Status {
    return c_set_length_units_per_meter(units)
}

get_length_units_per_meter :: proc() -> f32 {
    return c_get_length_units_per_meter()
}

// Allocation-free identity of the actual loaded native image. Cookie is a
// process-local lifetime token, never a game/wire identity or authentication.
DOMAIN_CONTRACT_VERSION :: u32(1)
HOST_OWNER_CAPACITY :: u32(256)
HOST_LIMIT_BYTES :: u64(67108864)

Domain_Contract :: struct {
    cookie:                                                                                                u64,
    size, version, abi_version, logical_version, resource_version, recovery_version, pointer_bits, endian: u32,
    build, target:                                                                                         [32]u8,
}

Host_Owner :: distinct u64

Host_Owner_Info :: struct {
    producer, component, live_bytes, reserved_bytes: u64,
}

Host_Ledger_Stats :: struct {
    engine_live_bytes,
    snapshot_live_bytes,
    host_live_bytes,
    host_reserved_bytes,
    live_bytes,
    admitted_bytes,
    limit_bytes,
    committed_peak_bytes,
    successful_updates,
    ledger_storage_bytes: u64,
    owner_count,
    owner_capacity:                                                                                                                                                           u32,
}

domain_contract_get :: proc() -> (contract: Domain_Contract, status: Status) {
    status = c_domain_contract_get(&contract)
    return
}

domain_contract_check :: proc(expected: Domain_Contract) -> Status {
    expected := expected
    return c_domain_contract_check(&expected)
}

host_owner_open :: proc(cookie, producer, component: u64) -> (owner: Host_Owner, status: Status) {
    status = c_host_owner_open(cookie, producer, component, &owner)
    return
}

host_owner_set :: proc(cookie: u64, owner: Host_Owner, live, reserved: u64) -> Status {
    return c_host_owner_set(cookie, owner, live, reserved)
}

host_owner_get :: proc(cookie: u64, owner: Host_Owner) -> (info: Host_Owner_Info, status: Status) {
    status = c_host_owner_get(cookie, owner, &info)
    return
}

host_owner_close :: proc(cookie: u64, owner: ^Host_Owner) -> Status {
    if owner == nil {
        return .Invalid_Argument
    }

    status := c_host_owner_close(cookie, owner^)

    if status == .Ok {
        owner^ = 0
    }

    return status
}

host_memory_check :: proc(
    cookie: u64,
    owner: Host_Owner = 0,
    proposed_live: u64 = 0,
    proposed_reserved: u64 = 0,
    additional_live: u64 = 0,
    additional_reserved: u64 = 0,
) -> (
    required: u64,
    status: Status,
) {
    status = c_host_memory_check(
        cookie,
        owner,
        proposed_live,
        proposed_reserved,
        additional_live,
        additional_reserved,
        &required,
    )
    return
}

host_ledger_get :: proc(cookie: u64) -> (stats: Host_Ledger_Stats, status: Status) {
    status = c_host_ledger_get(cookie, &stats)
    return
}

// Foreign declarations are package-private. Arrays are multi-pointers with
// fixed-width counts; no Odin slice descriptor is passed across C.
@(private, default_calling_convention = "c")
foreign native {
    @(link_name = "ogb3_motion_layout")
    raw_motion_layout :: proc(_: u32, _: u32, _: ^u32, _: ^u32, _: ^u32) -> Status ---
    @(link_name = "ogb3_motion_joint_default")
    raw_motion_joint_default :: proc(_: u32, _: ^Motion_Joint_Def) -> Status ---
    @(link_name = "ogb3_motion_joint_create")
    raw_motion_joint_create :: proc(_: World, _: ^Motion_Joint_Def, _: ^Joint_Key) -> Status ---
    @(link_name = "ogb3_query_aabb")
    raw_query_aabb :: proc(_: World, _: ^Vec3, _: ^Vec3, _: ^Motion_Filter, _: [^]Motion_Hit, _: u32, _: ^u32) -> Status ---
    @(link_name = "ogb3_query_ray")
    raw_query_ray_sorted :: proc(_: World, _: ^Vec3, _: ^Vec3, _: ^Motion_Filter, _: [^]Motion_Hit, _: u32, _: ^u32) -> Status ---
    @(link_name = "ogb3_query_capsule")
    raw_query_capsule :: proc(_: World, _: ^Vec3, _: ^Motion_Capsule, _: ^Motion_Filter, _: [^]Motion_Hit, _: u32, _: ^u32) -> Status ---
    @(link_name = "ogb3_query_capsule_cast")
    raw_query_capsule_cast :: proc(_: World, _: ^Vec3, _: ^Motion_Capsule, _: ^Vec3, _: ^Motion_Filter, _: [^]Motion_Hit, _: u32, _: ^u32) -> Status ---
    @(link_name = "ogb3_character_step")
    raw_character_step :: proc(_: World, _: ^Character_Config, _: ^Character_State, _: f32, _: ^Character_Result) -> Status ---
    @(link_name = "ogb3_domain_contract_get")
    raw_domain_contract_get :: proc(_: ^Domain_Contract) -> Status ---
    @(link_name = "ogb3_domain_contract_check")
    raw_domain_contract_check :: proc(_: ^Domain_Contract) -> Status ---
    @(link_name = "ogb3_host_owner_open")
    raw_host_owner_open :: proc(_: u64, _: u64, _: u64, _: ^Host_Owner) -> Status ---
    @(link_name = "ogb3_host_owner_set")
    raw_host_owner_set :: proc(_: u64, _: Host_Owner, _: u64, _: u64) -> Status ---
    @(link_name = "ogb3_host_owner_get")
    raw_host_owner_get :: proc(_: u64, _: Host_Owner, _: ^Host_Owner_Info) -> Status ---
    @(link_name = "ogb3_host_owner_close")
    raw_host_owner_close :: proc(_: u64, _: Host_Owner) -> Status ---
    @(link_name = "ogb3_host_memory_check")
    raw_host_memory_check :: proc(_: u64, _: Host_Owner, _: u64, _: u64, _: u64, _: u64, _: ^u64) -> Status ---
    @(link_name = "ogb3_host_ledger_get")
    raw_host_ledger_get :: proc(_: u64, _: ^Host_Ledger_Stats) -> Status ---
    @(link_name = "ogb3_recovery_format")
    raw_recovery_format :: proc() -> u32 ---
    @(link_name = "ogb3_recovery_layout")
    raw_recovery_layout :: proc(_: u32, _: u32, _: ^u32, _: ^u32, _: ^u32) -> Status ---
    @(link_name = "ogb3_recovery_config_default")
    raw_recovery_config_default :: proc(_: ^Recovery_Config) -> Status ---
    @(link_name = "ogb3_recovery_catalog_create")
    raw_recovery_catalog_create :: proc(_: ^Recovery_Config, _: [^]Recovery_Asset, _: u32, _: ^rawptr) -> Status ---
    @(link_name = "ogb3_authoring_asset_layout")
    raw_authoring_asset_layout :: proc(_: u32, _: ^u32, _: ^u32, _: ^u32) -> Status ---
    @(link_name = "ogb3_recovery_catalog_create_v2")
    raw_recovery_catalog_create_v2 :: proc(_: ^Recovery_Config, _: [^]Recovery_Asset_V2, _: u32, _: ^rawptr) -> Status ---
    @(link_name = "ogb3_recovery_catalog_create_v3")
    raw_recovery_catalog_create_v3 :: proc(_: ^Recovery_Config, _: [^]Recovery_Asset_V2, _: u32, _: ^rawptr) -> Status ---
    @(link_name = "ogb3_recovery_catalog_shape")
    raw_recovery_catalog_shape :: proc(_: rawptr, _: u32, _: Body, _: ^Shape_Def, _: ^Shape) -> Status ---
    @(link_name = "ogb3_recovery_catalog_clone")
    raw_recovery_catalog_clone :: proc(_: rawptr, _: ^rawptr) -> Status ---
    @(link_name = "ogb3_recovery_catalog_release")
    raw_recovery_catalog_release :: proc(_: rawptr) ---
    @(link_name = "ogb3_recovery_identity_get")
    raw_recovery_identity_get :: proc(_: rawptr, _: ^Recovery_Identity) -> Status ---
    @(link_name = "ogb3_recovery_world_admit")
    raw_recovery_world_admit :: proc(_: rawptr, _: World, _: u64, _: ^u64, _: ^Recovery_Diagnostic) -> Status ---
    @(link_name = "ogb3_recovery_write")
    raw_recovery_write :: proc(_: rawptr, _: rawptr, _: [^]u8, _: u64, _: ^u64, _: ^Recovery_Diagnostic) -> Status ---
    @(link_name = "ogb3_recovery_read_info")
    raw_recovery_read_info :: proc(_: rawptr, _: [^]u8, _: u64, _: u64, _: ^rawptr, _: ^u64, _: ^u64, _: ^u64, _: ^u32, _: ^u64, _: ^u64, _: ^u64, _: ^Recovery_Diagnostic) -> Status ---
    @(link_name = "ogb3_recovery_read")
    raw_recovery_read :: proc(_: rawptr, _: [^]u8, _: u64, _: u64, _: ^rawptr, _: ^Recovery_Diagnostic) -> Status ---

    @(link_name = "ogb3_shape_key_from_handle")
    raw_shape_key_from_handle :: proc(_: Shape, _: ^Shape_Key) -> Status ---
    @(link_name = "ogb3_world_get_counters")
    raw_world_get_counters :: proc(_: World, _: ^World_Counters) -> Status ---
    @(link_name = "ogb3_body_get_key")
    raw_body_get_key :: proc(_: Body, _: ^Body_Key) -> Status ---
    @(link_name = "ogb3_shape_get_key")
    raw_shape_get_key :: proc(_: Shape, _: ^Shape_Key) -> Status ---
    @(link_name = "ogb3_joint_get_key")
    raw_joint_get_key :: proc(_: Joint, _: ^Joint_Key) -> Status ---
    @(link_name = "ogb3_body_resolve")
    raw_body_resolve :: proc(_: World, _: Body_Key, _: ^Body) -> Status ---
    @(link_name = "ogb3_shape_resolve")
    raw_shape_resolve :: proc(_: World, _: Shape_Key, _: ^Shape) -> Status ---
    @(link_name = "ogb3_joint_resolve")
    raw_joint_resolve :: proc(_: World, _: Joint_Key, _: ^Joint) -> Status ---
    @(link_name = "ogb3_snapshot_body_state")
    raw_snapshot_body_state :: proc(_: rawptr, _: Body_Key, _: ^Body_State) -> Status ---
    @(link_name = "ogb3_snapshot_body_states")
    raw_snapshot_body_states :: proc(_: rawptr, _: [^]Body_State, _: u32, _: ^u32) -> Status ---

    @(link_name = "ogb3_abi_version")
    raw_abi_version :: proc() -> u32 ---
    @(link_name = "ogb3_abi_layout")
    raw_abi_layout :: proc(type_id, field: u32, size, alignment, offset: ^u32) -> Status ---
    @(link_name = "ogb3_build_fingerprint")
    raw_build_fingerprint :: proc() -> u64 ---
    @(link_name = "ogb3_set_length_units_per_meter")
    raw_set_length_units_per_meter :: proc(units: f32) -> Status ---
    @(link_name = "ogb3_get_length_units_per_meter")
    raw_get_length_units_per_meter :: proc() -> f32 ---
    @(link_name = "ogb3_world_def_default")
    raw_world_def_default :: proc(def: ^World_Def) -> Status ---
    @(link_name = "ogb3_body_def_default")
    raw_body_def_default :: proc(def: ^Body_Def) -> Status ---
    @(link_name = "ogb3_shape_def_default")
    raw_shape_def_default :: proc(def: ^Shape_Def) -> Status ---
    @(link_name = "ogb3_hinge_def_default")
    raw_hinge_def_default :: proc(def: ^Hinge_Def) -> Status ---
    @(link_name = "ogb3_world_create")
    raw_world_create :: proc(def: ^World_Def, world: ^World) -> Status ---
    @(link_name = "ogb3_world_destroy")
    raw_world_destroy :: proc(world: World) -> Status ---
    @(link_name = "ogb3_world_valid")
    raw_world_valid :: proc(world: World, valid: ^u32) -> Status ---
    @(link_name = "ogb3_world_step")
    raw_world_step :: proc(world: World, seconds: f32, substeps: u32) -> Status ---
    @(link_name = "ogb3_world_step_fixed")
    raw_world_step_fixed :: proc(world: World) -> Status ---
    @(link_name = "ogb3_world_get_gravity")
    raw_world_get_gravity :: proc(world: World, gravity: ^Vec3) -> Status ---
    @(link_name = "ogb3_world_set_gravity")
    raw_world_set_gravity :: proc(world: World, gravity: ^Vec3) -> Status ---
    @(link_name = "ogb3_body_create")
    raw_body_create :: proc(world: World, def: ^Body_Def, body: ^Body) -> Status ---
    @(link_name = "ogb3_body_destroy")
    raw_body_destroy :: proc(body: Body) -> Status ---
    @(link_name = "ogb3_body_valid")
    raw_body_valid :: proc(body: Body, valid: ^u32) -> Status ---
    @(link_name = "ogb3_body_identity")
    raw_body_identity :: proc(body: Body, index, generation: ^u32) -> Status ---
    @(link_name = "ogb3_body_retarget")
    raw_body_retarget :: proc(world: World, source: Body, destination: ^Body) -> Status ---
    @(link_name = "ogb3_shape_retarget")
    raw_shape_retarget :: proc(world: World, source: Shape, destination: ^Shape) -> Status ---
    @(link_name = "ogb3_joint_retarget")
    raw_joint_retarget :: proc(world: World, source: Joint, destination: ^Joint) -> Status ---
    @(link_name = "ogb3_engine_allocation_stats")
    raw_engine_allocation_stats :: proc(stats: ^Allocation_Stats) -> Status ---
    @(link_name = "ogb3_body_get_pose")
    raw_body_get_pose :: proc(body: Body, pose: ^Pose) -> Status ---
    @(link_name = "ogb3_body_set_pose")
    raw_body_set_pose :: proc(body: Body, pose: ^Pose) -> Status ---
    @(link_name = "ogb3_body_set_type")
    raw_body_set_type :: proc(body: Body, kind: Body_Type) -> Status ---
    @(link_name = "ogb3_body_get_velocity")
    raw_body_get_velocity :: proc(body: Body, linear, angular: ^Vec3) -> Status ---
    @(link_name = "ogb3_body_set_velocity")
    raw_body_set_velocity :: proc(body: Body, linear, angular: ^Vec3) -> Status ---
    @(link_name = "ogb3_body_apply_impulse")
    raw_body_apply_impulse :: proc(body: Body, impulse, point: ^Vec3, wake: u32) -> Status ---
    @(link_name = "ogb3_body_apply_angular_impulse")
    raw_body_apply_angular_impulse :: proc(body: Body, impulse: ^Vec3, wake: u32) -> Status ---
    @(link_name = "ogb3_body_set_awake")
    raw_body_set_awake :: proc(body: Body, awake: u32) -> Status ---
    @(link_name = "ogb3_body_get_awake")
    raw_body_get_awake :: proc(body: Body, awake: ^u32) -> Status ---
    @(link_name = "ogb3_body_get_mass")
    raw_body_get_mass :: proc(body: Body, mass: ^f32) -> Status ---
    @(link_name = "ogb3_geometry_hull")
    raw_geometry_hull :: proc(points: [^]Vec3, count: u32, geometry: ^rawptr) -> Status ---
    @(link_name = "ogb3_geometry_mesh")
    raw_geometry_mesh :: proc(vertices: [^]Vec3, vertex_count: u32, indices: [^]u32, triangle_count: u32, geometry: ^rawptr) -> Status ---
    @(link_name = "ogb3_geometry_release")
    raw_geometry_release :: proc(geometry: rawptr) ---
    @(link_name = "ogb3_shape_box")
    raw_shape_box :: proc(body: Body, def: ^Shape_Def, half_extents: ^Vec3, shape: ^Shape) -> Status ---
    @(link_name = "ogb3_shape_sphere")
    raw_shape_sphere :: proc(body: Body, def: ^Shape_Def, center: ^Vec3, radius: f32, shape: ^Shape) -> Status ---
    @(link_name = "ogb3_shape_capsule")
    raw_shape_capsule :: proc(body: Body, def: ^Shape_Def, center_a, center_b: ^Vec3, radius: f32, shape: ^Shape) -> Status ---
    @(link_name = "ogb3_shape_geometry")
    raw_shape_geometry :: proc(body: Body, def: ^Shape_Def, geometry: rawptr, shape: ^Shape) -> Status ---
    @(link_name = "ogb3_shape_destroy")
    raw_shape_destroy :: proc(shape: Shape) -> Status ---
    @(link_name = "ogb3_shape_valid")
    raw_shape_valid :: proc(shape: Shape, valid: ^u32) -> Status ---
    @(link_name = "ogb3_shape_get_body")
    raw_shape_get_body :: proc(shape: Shape, body: ^Body) -> Status ---
    @(link_name = "ogb3_shape_get_aabb")
    raw_shape_get_aabb :: proc(shape: Shape, lower, upper: ^Vec3) -> Status ---
    @(link_name = "ogb3_world_overlap_aabb")
    raw_world_overlap_aabb :: proc(world: World, lower, upper: ^Vec3, filter: ^Query_Filter, shapes: [^]Shape, capacity: u32, count: ^u32) -> Status ---
    @(link_name = "ogb3_world_cast_ray")
    raw_world_cast_ray :: proc(world: World, origin, translation: ^Vec3, filter: ^Query_Filter, hits: [^]Ray_Hit, capacity: u32, count: ^u32) -> Status ---
    @(link_name = "ogb3_world_sensor_events")
    raw_world_sensor_events :: proc(world: World, events: [^]Sensor_Event, capacity: u32, count: ^u32) -> Status ---
    @(link_name = "ogb3_joint_hinge_create")
    raw_joint_hinge_create :: proc(world: World, def: ^Hinge_Def, joint: ^Joint) -> Status ---
    @(link_name = "ogb3_joint_destroy")
    raw_joint_destroy :: proc(joint: Joint) -> Status ---
    @(link_name = "ogb3_joint_valid")
    raw_joint_valid :: proc(joint: Joint, valid: ^u32) -> Status ---
    @(link_name = "ogb3_joint_hinge_set_motor")
    raw_joint_hinge_set_motor :: proc(joint: Joint, enabled: u32, speed, max_torque: f32) -> Status ---
    @(link_name = "ogb3_joint_hinge_get_angle")
    raw_joint_hinge_get_angle :: proc(joint: Joint, angle: ^f32) -> Status ---
    @(link_name = "ogb3_snapshot_capture")
    raw_snapshot_capture :: proc(world: World, snapshot: ^rawptr) -> Status ---
    @(link_name = "ogb3_snapshot_clone")
    raw_snapshot_clone :: proc(snapshot: rawptr, clone: ^rawptr) -> Status ---
    @(link_name = "ogb3_snapshot_release")
    raw_snapshot_release :: proc(snapshot: rawptr) ---
    @(link_name = "ogb3_snapshot_restore")
    raw_snapshot_restore :: proc(world: World, snapshot: rawptr) -> Status ---
    @(link_name = "ogb3_snapshot_capture_info")
    raw_snapshot_capture_info :: proc(_: World, _: ^rawptr, _: ^u64, _: ^u64, _: ^u64, _: ^u32, _: ^u64, _: ^u64, _: ^u64) -> Status ---
    @(link_name = "ogb3_snapshot_clone_info")
    raw_snapshot_clone_info :: proc(_: rawptr, _: ^rawptr, _: ^u64, _: ^u64, _: ^u64, _: ^u32, _: ^u64, _: ^u64, _: ^u64) -> Status ---
    @(link_name = "ogb3_snapshot_info")
    raw_snapshot_info :: proc(_: rawptr, _: ^u64, _: ^u64, _: ^u64, _: ^u32, _: ^u64, _: ^u64, _: ^u64) -> Status ---
    @(link_name = "ogb3_snapshot_metrics")
    raw_snapshot_metrics :: proc(snapshot: rawptr, used, capacity, geometry_bytes: ^u64, geometry_count: ^u32) -> Status ---
    @(link_name = "ogb3_snapshot_storage")
    raw_snapshot_storage :: proc(snapshot: rawptr, normalized, wrapper_malloc, native_requested: ^u64) -> Status ---
    @(link_name = "ogb3_snapshot_allocation_stats")
    raw_snapshot_allocation_stats :: proc(stats: ^Allocation_Stats) -> Status ---
    @(link_name = "ogb3_snapshot_dump")
    raw_snapshot_dump :: proc(snapshot: rawptr, bytes: [^]u8, capacity: u64, required: ^u64) -> Status ---
    @(link_name = "ogb3_snapshot_digest")
    raw_snapshot_digest :: proc(snapshot: rawptr, complete, motion: ^u64) -> Status ---
    @(link_name = "ogb3_state_coverage")
    raw_state_coverage :: proc() -> cstring ---
    @(link_name = "ogb3_state_version")
    raw_state_version :: proc() -> u32 ---
    @(link_name = "ogb3_state_dump")
    raw_state_dump :: proc(world: World, bytes: [^]u8, capacity: u64, required: ^u64) -> Status ---
    @(link_name = "ogb3_state_digest")
    raw_state_digest :: proc(world: World, complete, motion: ^u64) -> Status ---
}


// SDK builds fail closed until the stable host installs the exact loaded native
// domain. Default standalone callers retain the previous local behavior.
BOX3D_REQUIRE_DOMAIN :: #config(BOX3D_REQUIRE_DOMAIN, false)
BOX3D_EXPECTED_BUILD :: #config(BOX3D_EXPECTED_BUILD, "")
BOX3D_EXPECTED_TARGET :: #config(BOX3D_EXPECTED_TARGET, "")
Domain_Check :: #type proc "c" (user: rawptr, cookie: u64) -> bg.Status

@(private)
Domain_Guard :: struct {
    installed: bool,
    expected:  Domain_Contract,
    user:      rawptr,
    check:     Domain_Check,
}

@(private)
domain_guard: Domain_Guard

// Installation performs only allocation-free native metadata comparison. The
// callback belongs to stable Core and owns/validates its actual user context.
domain_install :: proc "contextless" (expected: Domain_Contract, user: rawptr, check: Domain_Check) -> Status {
    if check == nil {
        return .Invalid_Argument
    }

    if !domain_compile_expected(expected) {
        return .Incompatible
    }

    expected := expected

    if status := raw_domain_contract_check(&expected); status != .Ok {
        return status
    }

    if domain_guard.installed {
        if domain_guard.expected != expected || domain_guard.user != user || domain_guard.check != check {
            return .Incompatible
        }

        return .Ok
    }

    domain_guard = {true, expected, user, check}
    return .Ok
}

domain_access_check :: proc "contextless" () -> Status {
    if !domain_guard.installed {
        when BOX3D_REQUIRE_DOMAIN {
            return .Incompatible
        }

        return .Ok
    }

    if status := raw_domain_contract_check(&domain_guard.expected); status != .Ok {
        return status
    }

    code := domain_guard.check(domain_guard.user, domain_guard.expected.cookie)

    if i32(code) < 0 || i32(code) > i32(Status.Corrupt) {
        return .Incompatible
    }

    return Status(i32(code))
}

// Every native entry which may use a handle/owner or initialize native state
// passes the same guard. The raw imports remain package-private. Void native
// release functions become checked private calls so outer owners can survive
// rejected access instead of being silently cleared.

@(private)
c_domain_contract_get :: proc(a0: ^Domain_Contract) -> Status {
    return raw_domain_contract_get(a0)
}

@(private)
c_domain_contract_check :: proc(a0: ^Domain_Contract) -> Status {
    return raw_domain_contract_check(a0)
}

@(private)
c_host_owner_open :: proc(a0: u64, a1: u64, a2: u64, a3: ^Host_Owner) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_host_owner_open(a0, a1, a2, a3)
}

@(private)
c_host_owner_set :: proc(a0: u64, a1: Host_Owner, a2: u64, a3: u64) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_host_owner_set(a0, a1, a2, a3)
}

@(private)
c_host_owner_get :: proc(a0: u64, a1: Host_Owner, a2: ^Host_Owner_Info) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_host_owner_get(a0, a1, a2)
}

@(private)
c_host_owner_close :: proc(a0: u64, a1: Host_Owner) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_host_owner_close(a0, a1)
}

@(private)
c_host_memory_check :: proc(a0: u64, a1: Host_Owner, a2: u64, a3: u64, a4: u64, a5: u64, a6: ^u64) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_host_memory_check(a0, a1, a2, a3, a4, a5, a6)
}

@(private)
c_host_ledger_get :: proc(a0: u64, a1: ^Host_Ledger_Stats) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_host_ledger_get(a0, a1)
}

@(private)
c_recovery_format :: proc() -> u32 {
    return raw_recovery_format()
}

@(private)
c_recovery_layout :: proc(a0: u32, a1: u32, a2: ^u32, a3: ^u32, a4: ^u32) -> Status {
    return raw_recovery_layout(a0, a1, a2, a3, a4)
}

@(private)
c_recovery_config_default :: proc(a0: ^Recovery_Config) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_config_default(a0)
}

@(private)
c_recovery_catalog_create :: proc(a0: ^Recovery_Config, a1: [^]Recovery_Asset, a2: u32, a3: ^rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_catalog_create(a0, a1, a2, a3)
}

@(private)
c_authoring_asset_layout :: proc(field: u32, size, alignment, offset: ^u32) -> Status {
    return raw_authoring_asset_layout(field, size, alignment, offset)
}

@(private)
c_recovery_catalog_create_v2 :: proc(
    config: ^Recovery_Config,
    assets: [^]Recovery_Asset_V2,
    count: u32,
    out: ^rawptr,
) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_catalog_create_v2(config, assets, count, out)
}

@(private)
c_recovery_catalog_create_v3 :: proc(
    config: ^Recovery_Config,
    assets: [^]Recovery_Asset_V2,
    count: u32,
    out: ^rawptr,
) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_catalog_create_v3(config, assets, count, out)
}

@(private)
c_recovery_catalog_shape :: proc(catalog: rawptr, id: u32, body: Body, definition: ^Shape_Def, out: ^Shape) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_catalog_shape(catalog, id, body, definition, out)
}

@(private)
c_recovery_catalog_clone :: proc(a0: rawptr, a1: ^rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_catalog_clone(a0, a1)
}

@(private)
c_recovery_catalog_release :: proc(a0: rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    raw_recovery_catalog_release(a0)
    return .Ok
}

@(private)
c_recovery_identity_get :: proc(a0: rawptr, a1: ^Recovery_Identity) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_identity_get(a0, a1)
}

@(private)
c_recovery_world_admit :: proc(a0: rawptr, a1: World, a2: u64, a3: ^u64, a4: ^Recovery_Diagnostic) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_world_admit(a0, a1, a2, a3, a4)
}

@(private)
c_recovery_write :: proc(a0: rawptr, a1: rawptr, a2: [^]u8, a3: u64, a4: ^u64, a5: ^Recovery_Diagnostic) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_write(a0, a1, a2, a3, a4, a5)
}

@(private)
c_recovery_read_info :: proc(
    a0: rawptr,
    a1: [^]u8,
    a2: u64,
    a3: u64,
    a4: ^rawptr,
    a5: ^u64,
    a6: ^u64,
    a7: ^u64,
    a8: ^u32,
    a9: ^u64,
    a10: ^u64,
    a11: ^u64,
    a12: ^Recovery_Diagnostic,
) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_read_info(a0, a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12)
}

@(private)
c_recovery_read :: proc(a0: rawptr, a1: [^]u8, a2: u64, a3: u64, a4: ^rawptr, a5: ^Recovery_Diagnostic) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_recovery_read(a0, a1, a2, a3, a4, a5)
}

@(private)
c_shape_key_from_handle :: proc(a0: Shape, a1: ^Shape_Key) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_key_from_handle(a0, a1)
}

@(private)
c_world_get_counters :: proc(a0: World, a1: ^World_Counters) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_get_counters(a0, a1)
}

@(private)
c_body_get_key :: proc(a0: Body, a1: ^Body_Key) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_get_key(a0, a1)
}

@(private)
c_shape_get_key :: proc(a0: Shape, a1: ^Shape_Key) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_get_key(a0, a1)
}

@(private)
c_joint_get_key :: proc(a0: Joint, a1: ^Joint_Key) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_joint_get_key(a0, a1)
}

@(private)
c_body_resolve :: proc(a0: World, a1: Body_Key, a2: ^Body) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_resolve(a0, a1, a2)
}

@(private)
c_shape_resolve :: proc(a0: World, a1: Shape_Key, a2: ^Shape) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_resolve(a0, a1, a2)
}

@(private)
c_joint_resolve :: proc(a0: World, a1: Joint_Key, a2: ^Joint) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_joint_resolve(a0, a1, a2)
}

@(private)
c_snapshot_body_state :: proc(a0: rawptr, a1: Body_Key, a2: ^Body_State) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_body_state(a0, a1, a2)
}

@(private)
c_snapshot_body_states :: proc(a0: rawptr, a1: [^]Body_State, a2: u32, a3: ^u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_body_states(a0, a1, a2, a3)
}

@(private)
c_abi_version :: proc() -> u32 {
    return raw_abi_version()
}

@(private)
c_abi_layout :: proc(a0: u32, a1: u32, a2: ^u32, a3: ^u32, a4: ^u32) -> Status {
    return raw_abi_layout(a0, a1, a2, a3, a4)
}

@(private)
c_build_fingerprint :: proc() -> u64 {
    if status := domain_access_check(); status != .Ok {
        return 0
    }

    return raw_build_fingerprint()
}

@(private)
c_set_length_units_per_meter :: proc(a0: f32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_set_length_units_per_meter(a0)
}

@(private)
c_get_length_units_per_meter :: proc() -> f32 {
    if status := domain_access_check(); status != .Ok {
        return 0
    }

    return raw_get_length_units_per_meter()
}

@(private)
c_world_def_default :: proc(a0: ^World_Def) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_def_default(a0)
}

@(private)
c_body_def_default :: proc(a0: ^Body_Def) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_def_default(a0)
}

@(private)
c_shape_def_default :: proc(a0: ^Shape_Def) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_def_default(a0)
}

@(private)
c_hinge_def_default :: proc(a0: ^Hinge_Def) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_hinge_def_default(a0)
}

@(private)
c_world_create :: proc(a0: ^World_Def, a1: ^World) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_create(a0, a1)
}

@(private)
c_world_destroy :: proc(a0: World) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_destroy(a0)
}

@(private)
c_world_valid :: proc(a0: World, a1: ^u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_valid(a0, a1)
}

@(private)
c_world_step :: proc(a0: World, a1: f32, a2: u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_step(a0, a1, a2)
}

@(private)
c_world_step_fixed :: proc(a0: World) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_step_fixed(a0)
}

@(private)
c_world_get_gravity :: proc(a0: World, a1: ^Vec3) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_get_gravity(a0, a1)
}

@(private)
c_world_set_gravity :: proc(a0: World, a1: ^Vec3) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_set_gravity(a0, a1)
}

@(private)
c_body_create :: proc(a0: World, a1: ^Body_Def, a2: ^Body) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_create(a0, a1, a2)
}

@(private)
c_body_destroy :: proc(a0: Body) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_destroy(a0)
}

@(private)
c_body_valid :: proc(a0: Body, a1: ^u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_valid(a0, a1)
}

@(private)
c_body_identity :: proc(a0: Body, a1: ^u32, a2: ^u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_identity(a0, a1, a2)
}

@(private)
c_body_retarget :: proc(a0: World, a1: Body, a2: ^Body) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_retarget(a0, a1, a2)
}

@(private)
c_shape_retarget :: proc(a0: World, a1: Shape, a2: ^Shape) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_retarget(a0, a1, a2)
}

@(private)
c_joint_retarget :: proc(a0: World, a1: Joint, a2: ^Joint) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_joint_retarget(a0, a1, a2)
}

@(private)
c_engine_allocation_stats :: proc(a0: ^Allocation_Stats) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_engine_allocation_stats(a0)
}

@(private)
c_body_get_pose :: proc(a0: Body, a1: ^Pose) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_get_pose(a0, a1)
}

@(private)
c_body_set_pose :: proc(a0: Body, a1: ^Pose) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_set_pose(a0, a1)
}

@(private)
c_body_set_type :: proc(body: Body, kind: Body_Type) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_set_type(body, kind)
}

@(private)
c_body_get_velocity :: proc(a0: Body, a1: ^Vec3, a2: ^Vec3) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_get_velocity(a0, a1, a2)
}

@(private)
c_body_set_velocity :: proc(a0: Body, a1: ^Vec3, a2: ^Vec3) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_set_velocity(a0, a1, a2)
}

@(private)
c_body_apply_impulse :: proc(a0: Body, a1: ^Vec3, a2: ^Vec3, a3: u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_apply_impulse(a0, a1, a2, a3)
}

@(private)
c_body_apply_angular_impulse :: proc(a0: Body, a1: ^Vec3, a2: u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_apply_angular_impulse(a0, a1, a2)
}

@(private)
c_body_set_awake :: proc(a0: Body, a1: u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_set_awake(a0, a1)
}

@(private)
c_body_get_awake :: proc(a0: Body, a1: ^u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_get_awake(a0, a1)
}

@(private)
c_body_get_mass :: proc(a0: Body, a1: ^f32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_body_get_mass(a0, a1)
}

@(private)
c_geometry_hull :: proc(a0: [^]Vec3, a1: u32, a2: ^rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_geometry_hull(a0, a1, a2)
}

@(private)
c_geometry_mesh :: proc(a0: [^]Vec3, a1: u32, a2: [^]u32, a3: u32, a4: ^rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_geometry_mesh(a0, a1, a2, a3, a4)
}

@(private)
c_geometry_release :: proc(a0: rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    raw_geometry_release(a0)
    return .Ok
}

@(private)
c_shape_box :: proc(a0: Body, a1: ^Shape_Def, a2: ^Vec3, a3: ^Shape) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_box(a0, a1, a2, a3)
}

@(private)
c_shape_sphere :: proc(a0: Body, a1: ^Shape_Def, a2: ^Vec3, a3: f32, a4: ^Shape) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_sphere(a0, a1, a2, a3, a4)
}

@(private)
c_shape_capsule :: proc(a0: Body, a1: ^Shape_Def, a2: ^Vec3, a3: ^Vec3, a4: f32, a5: ^Shape) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_capsule(a0, a1, a2, a3, a4, a5)
}

@(private)
c_shape_geometry :: proc(a0: Body, a1: ^Shape_Def, a2: rawptr, a3: ^Shape) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_geometry(a0, a1, a2, a3)
}

@(private)
c_shape_destroy :: proc(a0: Shape) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_destroy(a0)
}

@(private)
c_shape_valid :: proc(a0: Shape, a1: ^u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_valid(a0, a1)
}

@(private)
c_shape_get_body :: proc(a0: Shape, a1: ^Body) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_get_body(a0, a1)
}

@(private)
c_shape_get_aabb :: proc(a0: Shape, a1: ^Vec3, a2: ^Vec3) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_shape_get_aabb(a0, a1, a2)
}

@(private)
c_world_overlap_aabb :: proc(
    a0: World,
    a1: ^Vec3,
    a2: ^Vec3,
    a3: ^Query_Filter,
    a4: [^]Shape,
    a5: u32,
    a6: ^u32,
) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_overlap_aabb(a0, a1, a2, a3, a4, a5, a6)
}

@(private)
c_world_cast_ray :: proc(
    a0: World,
    a1: ^Vec3,
    a2: ^Vec3,
    a3: ^Query_Filter,
    a4: [^]Ray_Hit,
    a5: u32,
    a6: ^u32,
) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_cast_ray(a0, a1, a2, a3, a4, a5, a6)
}

@(private)
c_world_sensor_events :: proc(a0: World, a1: [^]Sensor_Event, a2: u32, a3: ^u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_world_sensor_events(a0, a1, a2, a3)
}

@(private)
c_joint_hinge_create :: proc(a0: World, a1: ^Hinge_Def, a2: ^Joint) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_joint_hinge_create(a0, a1, a2)
}

@(private)
c_joint_destroy :: proc(a0: Joint) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_joint_destroy(a0)
}

@(private)
c_joint_valid :: proc(a0: Joint, a1: ^u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_joint_valid(a0, a1)
}

@(private)
c_joint_hinge_set_motor :: proc(a0: Joint, a1: u32, a2: f32, a3: f32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_joint_hinge_set_motor(a0, a1, a2, a3)
}

@(private)
c_joint_hinge_get_angle :: proc(a0: Joint, a1: ^f32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_joint_hinge_get_angle(a0, a1)
}

@(private)
c_snapshot_capture :: proc(a0: World, a1: ^rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_capture(a0, a1)
}

@(private)
c_snapshot_clone :: proc(a0: rawptr, a1: ^rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_clone(a0, a1)
}

@(private)
c_snapshot_release :: proc(a0: rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    raw_snapshot_release(a0)
    return .Ok
}

@(private)
c_snapshot_restore :: proc(a0: World, a1: rawptr) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_restore(a0, a1)
}

@(private)
c_snapshot_capture_info :: proc(
    a0: World,
    a1: ^rawptr,
    a2: ^u64,
    a3: ^u64,
    a4: ^u64,
    a5: ^u32,
    a6: ^u64,
    a7: ^u64,
    a8: ^u64,
) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_capture_info(a0, a1, a2, a3, a4, a5, a6, a7, a8)
}

@(private)
c_snapshot_clone_info :: proc(
    a0: rawptr,
    a1: ^rawptr,
    a2: ^u64,
    a3: ^u64,
    a4: ^u64,
    a5: ^u32,
    a6: ^u64,
    a7: ^u64,
    a8: ^u64,
) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_clone_info(a0, a1, a2, a3, a4, a5, a6, a7, a8)
}

@(private)
c_snapshot_info :: proc(a0: rawptr, a1: ^u64, a2: ^u64, a3: ^u64, a4: ^u32, a5: ^u64, a6: ^u64, a7: ^u64) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_info(a0, a1, a2, a3, a4, a5, a6, a7)
}

@(private)
c_snapshot_metrics :: proc(a0: rawptr, a1: ^u64, a2: ^u64, a3: ^u64, a4: ^u32) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_metrics(a0, a1, a2, a3, a4)
}

@(private)
c_snapshot_storage :: proc(a0: rawptr, a1: ^u64, a2: ^u64, a3: ^u64) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_storage(a0, a1, a2, a3)
}

@(private)
c_snapshot_allocation_stats :: proc(a0: ^Allocation_Stats) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_allocation_stats(a0)
}

@(private)
c_snapshot_dump :: proc(a0: rawptr, a1: [^]u8, a2: u64, a3: ^u64) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_dump(a0, a1, a2, a3)
}

@(private)
c_snapshot_digest :: proc(a0: rawptr, a1: ^u64, a2: ^u64) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_snapshot_digest(a0, a1, a2)
}

@(private)
c_state_coverage :: proc() -> cstring {
    return raw_state_coverage()
}

@(private)
c_state_version :: proc() -> u32 {
    return raw_state_version()
}

@(private)
c_state_dump :: proc(a0: World, a1: [^]u8, a2: u64, a3: ^u64) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_state_dump(a0, a1, a2, a3)
}

@(private)
c_state_digest :: proc(a0: World, a1: ^u64, a2: ^u64) -> Status {
    if status := domain_access_check(); status != .Ok {
        return status
    }

    return raw_state_digest(a0, a1, a2)
}

@(private)
domain_hex_matches :: proc "contextless" (text: string, expected: [32]u8) -> bool {
    text := text

    if len(text) >= 7 && text[:7] == "sha256:" {
        text = text[7:]
    }

    if len(text) != 64 {
        return false
    }

    for byte, index in expected {
        value: u8

        for character in text[index * 2:index * 2 + 2] {
            value <<= 4

            if character >= '0' && character <= '9' {
                value |= u8(character - '0')
            } else if character >= 'a' && character <= 'f' {
                value |= u8(character - 'a' + 10)
            } else if character >= 'A' && character <= 'F' {
                value |= u8(character - 'A' + 10)
            } else {
                return false
            }
        }

        if value != byte {
            return false
        }
    }

    return true
}

@(private)
domain_compile_expected :: proc "contextless" (contract: Domain_Contract) -> bool {
    when BOX3D_REQUIRE_DOMAIN {
        return(
            domain_hex_matches(BOX3D_EXPECTED_BUILD, contract.build) &&
            domain_hex_matches(BOX3D_EXPECTED_TARGET, contract.target) \
        )
    } else {
        return(
            (len(BOX3D_EXPECTED_BUILD) == 0 || domain_hex_matches(BOX3D_EXPECTED_BUILD, contract.build)) &&
            (len(BOX3D_EXPECTED_TARGET) == 0 || domain_hex_matches(BOX3D_EXPECTED_TARGET, contract.target)) \
        )
    }
}

when BOX3D_REQUIRE_DOMAIN {
    @(init)
    domain_module_register :: proc "contextless" () {
        status := bg.module_register(domain_module_discover, domain_module_install)

        if status != bg.OK {
            intrinsics.trap()
        }
    }

    @(private)
    domain_module_discover :: proc "c" (out: ^bg.Domain_Contract) -> bg.Status {
        if out == nil {
            return bg.INVALID_ARGUMENT
        }

        native: Domain_Contract

        if status := raw_domain_contract_get(&native); status != .Ok {
            return bg.Status(status)
        }

        if !domain_compile_expected(native) {
            return bg.INCOMPATIBLE
        }

        out^ = {
            cookie           = native.cookie,
            size             = native.size,
            version          = native.version,
            abi_version      = native.abi_version,
            logical_version  = native.logical_version,
            resource_version = native.resource_version,
            recovery_version = native.recovery_version,
            pointer_bits     = native.pointer_bits,
            endian           = native.endian,
            build            = native.build,
            target           = native.target,
        }
        return bg.OK
    }

    @(private)
    domain_module_install :: proc "c" (service: ^bg.Service) -> bg.Status {
        if service == nil {
            return bg.INVALID_ARGUMENT
        }

        expected := Domain_Contract {
            cookie           = service.domain.cookie,
            size             = service.domain.size,
            version          = service.domain.version,
            abi_version      = service.domain.abi_version,
            logical_version  = service.domain.logical_version,
            resource_version = service.domain.resource_version,
            recovery_version = service.domain.recovery_version,
            pointer_bits     = service.domain.pointer_bits,
            endian           = service.domain.endian,
            build            = service.domain.build,
            target           = service.domain.target,
        }
        return bg.Status(domain_install(expected, service.user, service.domain_check))
    }
}
