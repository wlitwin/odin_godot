// Detached value-only presentation. This package links no Native or Godot code.
package box3d_presentation

VERSION :: u32(1)
MAX_BODIES :: 35
MAX_CHANGES :: 2 * MAX_BODIES

Error :: enum {
    None,
    Invalid,
    Capacity,
    Duplicate,
    Missing_Body,
    Stale,
    Generation_Exhausted,
    Unsupported,
}

Body_Key :: distinct u64 // certified world-independent key from a public cache reader

Identity :: struct {
    entity, lifetime: u64,
} // game identity; neither field is a native handle

Pose :: struct {
    position: [3]f32,
    rotation: [4]f32,
}

Source :: enum u8 {
    Predicted,
    Confirmed,
    Observed,
}

Binding :: struct {
    id:    Identity,
    body:  Body_Key,
    asset: u32,
    seat:  u16,
    alive: bool,
}

Body_Sample :: struct {
    body:  Body_Key,
    pose:  Pose,
    awake: bool,
}

Row :: struct {
    id:    Identity,
    body:  Body_Key,
    asset: u32,
    seat:  u16,
    pose:  Pose,
    awake: bool,
}

// Full owned value. No borrowed slices/procs/allocator/native image survive capture.
Frame :: struct {
    epoch, tick, revision: u64,
    source:                Source,
    count:                 u32,
    rows:                  [MAX_BODIES]Row,
}

Token :: struct {
    slot, generation: u32,
} // presentation pool identity only, never game/wire identity

Change_Kind :: enum u8 {
    Spawn,
    Update,
    Rebind,
    Remove,
}

Change :: struct {
    kind:                  Change_Kind,
    token, previous_token: Token,
    row, previous:         Row,
    interpolated:          bool,
}

@(private)
Slot :: struct {
    active:     bool,
    generation: u32,
    row:        Row,
}

// Bounded proxy mapping only: no timeline, solver, transport, events or clock.
View :: struct {
    ready:                 bool,
    epoch, tick, revision: u64,
    slots:                 [MAX_BODIES]Slot,
    frames, cuts, rebinds: u64,
}

Status :: struct {
    epoch, head, confirmed:                                    u64,
    accepted_frontier, predicted_frontier:                     u64,
    accepted_frontier_available, predicted_frontier_available: bool,
    repair_depth:                                              u32,
    repair_depth_available:                                    bool,
    ready, hold, resync:                                       bool,
    error_code:                                                i32,
    profile:                                                   u64,
    profile_available:                                         bool,
    native_live_bytes, wrapper_live_bytes, host_live_bytes:    u64,
    reserved_bytes, tracked_peak_bytes:                        u64,
    resources_available:                                       bool,
    normal_ns, repair_ns, normal_peak_ns, repair_peak_ns:      u64,
    timing_available, latest_timing_available:                 bool,
    complete_solver_digest, motion_digest:                     u64,
    complete_available, motion_available:                      bool,
}

// Effect observations are routed by existing framework journals/postcommit gates.
// This value supplies diagnostics/visual identity only and never emits/deduplicates.
Effect_Id :: struct {
    epoch, tick, source, key: u64,
}

Effect_Change_Kind :: enum u8 {
    Begin,
    Update,
    Cancel,
    Confirm,
    Committed,
}

Effect_Observation :: struct {
    id:        Effect_Id,
    game:      Identity,
    kind:      Effect_Change_Kind,
    confirmed: bool,
}

// Requested existing-transport settings. Applying them belongs to the caller's
// current transport adapter; unsupported capabilities must be reported explicitly.
Impairment :: struct {
    latency_ms, jitter_ms:               u32,
    loss_permyriad, duplicate_permyriad: u32,
    reorder:                             bool,
}
