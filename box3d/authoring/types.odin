// Detached authoring definitions. No Godot/Owner/native handle is durable data.
package box3d_authoring

import "core:mem"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"

@(private)
Native_Vec3 :: b.Vec3

LEGACY_SCHEMA_VERSION :: 1
SCHEMA_VERSION :: 2
MAX_JOINTS :: 1
MAX_CHARACTERS :: MAX_BODIES
MAX_KEY_BYTES :: 128
MAX_BODIES :: b.ALPHA_TOTAL_BODIES
MAX_SHAPES :: b.ALPHA_SHAPES
MAX_ASSETS :: b.RECOVERY_MAX_ASSETS
MAX_VERTICES :: 4096
MAX_HULL_POINTS :: 256
MAX_INDICES :: 24576
MAX_GRID_SIDE :: 64
MAX_DEFINITION_BYTES :: 2 * 1024 * 1024

Pose_Input :: struct {
    position: [3]f32,
    rotation: [4]f32,
}

IDENTITY_POSE :: Pose_Input {
    rotation = {0, 0, 0, 1},
}

Scene_Input :: struct {
    schema_version:                                             u32,
    namespace:                                                  string,
    gravity:                                                    [3]f32,
    enable_sleep:                                               bool,
    // Optional solver tuning; each 0 keeps Box3D's (length-scaled) default.
    restitution_threshold, hit_event_threshold, contact_hertz:  f32,
    contact_damping_ratio, contact_speed, maximum_linear_speed: f32,
    isotropic_inertia_tolerance:                                f32,
    restitution_iterations:                                     u32,
    enable_restitution_propagation:                             bool,
    bodies:                                                     []Body_Input,
    joints:                                                     []Joint_Input,
    characters:                                                 []Character_Input,
}

Body_Input :: struct {
    stable_key, body_type:                                           string, // static / kinematic / dynamic
    pose:                                                            Pose_Input,
    linear_velocity, angular_velocity:                               [3]f32,
    linear_damping, angular_damping, gravity_scale, sleep_threshold: f32,
    enable_sleep, is_awake, is_bullet, is_enabled, sensor:           bool,
    allow_fast_rotation:                                             bool, // optional; wheels and balls
    motion_locks:                                                    u32, // optional Motion_Lock bits
    safety_factor:                                                   f32, // optional; 0 keeps Box3D's 0.5
    disable_contact_recycling:                                       bool,
    shapes:                                                          []Shape_Input,
}

Shape_Input :: struct {
    stable_key, kind:                                       string, // box / sphere / capsule / hull / mesh / heightfield
    local_pose:                                             Pose_Input,
    scale:                                                  [3]f32,
    half_extents:                                           [3]f32,
    radius:                                                 f32,
    center, centers_a, centers_b:                           [3]f32, // exact sphere center / capsule endpoints
    vertices:                                               [][3]f32,
    indices:                                                []u32,
    columns, rows:                                          u32,
    spacing:                                                [2]f32, // heightfield X/Z, origin at grid[0,0]
    heights:                                                []f32, // row-major Z then X
    density, friction, restitution:                         f32,
    category_bits, mask_bits:                               u64,
    group_index:                                            i32,
    is_sensor, enable_sensor_events, enable_contact_events: bool,
    rolling_resistance:                                     f32, // optional
    tangent_velocity:                                       [3]f32, // optional conveyor velocity
    skip_contact_creation, disable_speculative_contact:     bool,
}

Kind :: enum u32 {
    Box = 1,
    Sphere,
    Capsule,
    Hull,
    Mesh,
    Heightfield,
}

Native_Kind :: enum u32 {
    Box = 1,
    Sphere,
    Capsule,
    Hull,
    Mesh,
}

Baked_Asset :: struct {
    stable_key:  string,
    logical_id:  u64,
    catalog_id:  u32,
    source_kind: Kind,
    native_kind: Native_Kind,
    a, b:        Native_Vec3,
    radius:      f32,
    vertices:    []Native_Vec3,
    indices:     []u32,
}

Baked_Body :: struct {
    stable_key: string,
    logical_id: u64,
    definition: b.Body_Def,
}

Baked_Resource :: struct {
    stable_key: string,
    logical_id: u64,
    catalog_id: u32,
}

Baked_Shape :: struct {
    stable_key:          string,
    logical_id, body_id: u64,
    asset_id:            u32,
    definition:          b.Shape_Def,
}

Joint_Input :: struct {
    stable_key, kind, body_a, body_b:                                              string, // pin/hinge/slider/spherical/distance/motor/weld/wheel
    local_frame_a, local_frame_b:                                                  Pose_Input,
    force_threshold, torque_threshold, constraint_hertz, constraint_damping_ratio: f32,
    collide_connected:                                                             bool,
    axis:                                                                          b.Motion_Joint_Axis,
    distance:                                                                      b.Motion_Joint_Distance,
    spherical:                                                                     b.Motion_Joint_Spherical,
    motor:                                                                         b.Motion_Joint_Motor,
    weld:                                                                          b.Motion_Joint_Weld,
    wheel:                                                                         b.Motion_Joint_Wheel,
}

Character_Capsule_Input :: struct {
    center1, center2: [3]f32,
    radius:           f32,
}

Character_Config_Input :: struct {
    max_slides:               u32,
    capsule:                  Character_Capsule_Input,
    up:                       [3]f32,
    floor_cosine:             f32,
    category_bits, mask_bits: u64,
    include_sensors:          bool,
}

Character_Initial_Input :: struct {
    position, velocity: [3]f32,
}

Character_Input :: struct {
    stable_key, exclude_body: string,
    config:                   Character_Config_Input,
    initial:                  Character_Initial_Input,
}

Baked_Joint :: struct {
    stable_key:                       string,
    logical_id, body_a_id, body_b_id: u64,
    definition:                       b.Motion_Joint_Def,
}

Baked_Character :: struct {
    stable_key:                  string,
    logical_id, exclude_body_id: u64,
    config:                      b.Character_Config,
    initial:                     b.Character_State,
}

Scene_Data :: struct {
    schema_version: u32,
    namespace:      string,
    world:          b.World_Def,
    bodies:         []Baked_Body,
    shapes:         []Baked_Shape,
    assets:         []Baked_Asset,
    resources:      []Baked_Resource,
    joints:         []Baked_Joint,
    characters:     []Baked_Character,
}

// One owning value; assignment aliases ownership. Data is immutable until destroy.
Baked_Scene :: struct {
    data:              Scene_Data,
    content_hash:      bd.Digest,
    allocator:         mem.Allocator,
    _asset_storage:    []Baked_Asset,
    _resource_storage: []Baked_Resource,
}

Error :: enum {
    None,
    Schema,
    Key,
    Duplicate,
    Collision,
    Capacity,
    Nonfinite,
    Pose,
    Scale,
    Dimension,
    Geometry,
    Reference,
    Unsupported,
    Allocation,
    Native,
    Corrupt,
}

Diagnostic :: struct {
    error:                Error,
    body, shape, element: int,
    field:                string,
    native_status:        b.Status,
}

Body_Map :: struct {
    logical_id: u64,
    handle:     b.Body,
    key:        b.Body_Key,
}

Shape_Map :: struct {
    logical_id, body_id: u64,
    asset_id:            u32,
    handle:              b.Shape,
    key:                 b.Shape_Key,
}

Joint_Map :: struct {
    logical_id, body_a_id, body_b_id: u64,
    key:                              b.Joint_Key,
}

Character_Map :: struct {
    logical_id: u64,
    config:     b.Character_Config,
    initial:    b.Character_State,
}

// Local runtime owner, never canonical Game state. Destroy world before catalog.
Built_Scene :: struct {
    world:        b.World,
    catalog:      b.Recovery_Catalog,
    bodies:       []Body_Map,
    shapes:       []Shape_Map,
    joints:       []Joint_Map,
    characters:   []Character_Map,
    content_hash: bd.Digest,
    allocator:    mem.Allocator,
}

scene_input_default :: proc(namespace: string, schema_version: u32 = LEGACY_SCHEMA_VERSION) -> Scene_Input {
    return {schema_version = schema_version, namespace = namespace, gravity = {0, -9.81, 0}, enable_sleep = true}
}

body_input_default :: proc(key: string) -> Body_Input {
    return {
        stable_key = key,
        body_type = "static",
        pose = IDENTITY_POSE,
        gravity_scale = 1,
        sleep_threshold = 0.05,
        enable_sleep = true,
        is_awake = true,
        is_enabled = true,
    }
}

shape_input_default :: proc(key, kind: string) -> Shape_Input {
    return {
        stable_key = key,
        kind = kind,
        local_pose = IDENTITY_POSE,
        scale = {1, 1, 1},
        half_extents = {0.5, 0.5, 0.5},
        radius = 0.5,
        centers_a = {0, -0.5, 0},
        centers_b = {0, 0.5, 0},
        spacing = {1, 1},
        density = 1,
        friction = 0.5,
        category_bits = 1,
        mask_bits = 0xffffffff,
        enable_sensor_events = kind != "mesh" && kind != "heightfield",
    }
}

joint_input_default :: proc(key, kind, body_a, body_b: string) -> Joint_Input {
    result := Joint_Input {
        stable_key               = key,
        kind                     = kind,
        body_a                   = body_a,
        body_b                   = body_b,
        local_frame_a            = IDENTITY_POSE,
        local_frame_b            = IDENTITY_POSE,
        force_threshold          = max(f32),
        torque_threshold         = max(f32),
        constraint_hertz         = 60,
        constraint_damping_ratio = 1,
    }

    if kind == "distance" {
        result.distance.length = 1
    }

    if kind == "pin" || kind == "spherical" {
        result.spherical.target_rotation = b.IDENTITY_ROTATION
    }

    return result
}

character_input_default :: proc(key: string) -> Character_Input {
    return {
        stable_key = key,
        config = {
            max_slides = 4,
            capsule = {{0, 0.5, 0}, {0, 1.5, 0}, 0.5},
            up = {0, 1, 0},
            floor_cosine = 0.70710677,
            category_bits = 1,
            mask_bits = 0xffffffff,
        },
    }
}
