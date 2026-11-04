// Detached debug values only. No Native, Godot, allocator, live world or clock.
package box3d_debugdraw

import p "godot:box3d/presentation"

VERSION :: u32(1)
MAX_GEOMETRIES :: 8
MAX_BINDINGS :: 35
MAX_VERTICES :: 4096
MAX_TRIANGLES :: 4096
MAX_HULL_POINTS :: 256
MAX_LINES :: 8192 // preview budget only; never changes a simulation/profile cap
MAX_CHARACTERS :: 35
MAX_JOINTS :: 1

Vec3 :: [3]f32
Color :: [4]f32

Error :: enum {
    None,
    Invalid,
    Capacity,
    Duplicate,
    Missing_Body,
    Missing_Geometry,
    Stale,
    Unsupported,
}

Kind :: enum u8 {
    Box,
    Sphere,
    Capsule,
    Hull,
    Mesh,
}

Stamp :: struct {
    epoch, tick, revision: u64,
    source:                p.Source,
}

Line :: struct {
    a, b:  Vec3,
    color: Color,
}

// Borrowed immutable arrays for ONE generate call. Heightfield is already
// baked Mesh. Hull is its copied point cloud; this package derives only its
// wireframe topology, never an asset identity or canonical physics geometry.
// Box a=half extents; Sphere a=center/radius; Capsule a/b=endpoints/radius;
// Hull/Mesh vertices, Mesh triangle indices. Other geometry fields zero.
Geometry :: struct {
    id:       u32,
    kind:     Kind,
    a, b:     Vec3,
    radius:   f32,
    vertices: []Vec3,
    indices:  []u32,
}

Binding :: struct {
    id:       u64,
    body:     p.Body_Key,
    geometry: u32,
    local:    p.Pose,
    color:    Color,
}

Joint_Kind :: enum u8 {
    Pin,
    Hinge,
    Slider,
    Spherical,
    Distance,
    Motor,
    Weld,
    Wheel,
}

// Generic joint diagnostics show actual copied anchor frames and connection;
// they do not claim to visualize solver impulses or enforce joint limits.
Joint :: struct {
    id:               u64,
    kind:             Joint_Kind,
    body_a, body_b:   p.Body_Key,
    local_a, local_b: p.Pose,
    color:            Color,
}

// body=0: pose is world-space copied Game/Side. Otherwise pose is body-local.
// Ground/up are copied world-space direction values, not new solver queries.
Character :: struct {
    id:                u64,
    body:              p.Body_Key,
    pose:              p.Pose,
    a, b:              Vec3,
    radius:            f32,
    up, ground_normal: Vec3,
    grounded:          bool,
    color:             Color,
}

Scene :: struct {
    geometries: []Geometry,
    bindings:   []Binding,
    joints:     []Joint,
    characters: []Character,
}

Options :: struct {
    enabled:  bool, // default OFF, disabled emits nothing and reads no input geometry
    expected: Stamp, // enabled requires exact frame stamp, including source
    segments: u32, // even 8..64, zero selects16
}

Batch :: struct {
    stamp:           Stamp,
    required, count: u32,
}

// generate(frame,scene,options,out)->(Batch,Error) is contextless/allocation-free.
// Every input is immutable for the call; no reference is retained. Validate and
// count first; any failure leaves the ENTIRE caller output buffer untouched.
// Capacity reports required (MAX_LINES+1 is a lower bound if budget exceeded;
// zero means an input cap prevented counting), count0.
// Success lines own only values and survive frame/scene destruction. No hidden
// last-frame state: stale iff options.expected differs from the supplied frame.
