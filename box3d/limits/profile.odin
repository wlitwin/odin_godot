package box3d_limits

// Capacities selected when building the backend and SDK modules. Counts bound
// storage and admission; they do not promise a particular simulation frame time.
Profile :: struct {
    max_bodies, max_shapes, max_contacts, max_joints, max_assets: int,
    max_sensor_pairs, network_bytes, debug_lines:                 int,
    memory_bytes, recovery_bytes, dto_bytes, snapshot_bytes:      u64,
}

current :: proc() -> Profile {
    return {
        MAX_BODIES,
        MAX_SHAPES,
        MAX_CONTACTS,
        MAX_JOINTS,
        MAX_ASSETS,
        MAX_SENSOR_PAIRS,
        NETWORK_BYTES,
        DEBUG_LINES,
        MEMORY_BYTES,
        RECOVERY_BYTES,
        DTO_BYTES,
        SNAPSHOT_BYTES,
    }
}
