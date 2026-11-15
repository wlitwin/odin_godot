package box3d

// Configuration is copied immutable caller data. Explicit state belongs to
// framework Game/Side; this wrapper neither steps nor mutates any body/clock.
Character_Config :: struct {
    version, max_slides: u32,
    capsule:             Motion_Capsule,
    up:                  Vec3,
    floor_cosine:        f32,
    filter:              Motion_Filter,
}

Character_State :: struct {
    position, velocity, ground_normal: Vec3,
    ground_shape:                      Shape_Key,
    grounded, reserved:                u32,
}

Character_Result :: struct {
    state:                   Character_State,
    displacement:            Vec3,
    iterations, plane_count: u32,
}

character_config_default :: proc() -> Character_Config {
    return {
        version = MOTION_VERSION,
        max_slides = 4,
        capsule = {{0, 0.5, 0}, {0, 1.5, 0}, 0.5},
        up = {0, 1, 0},
        floor_cosine = 0.70710677,
        filter = {category_bits = 1, mask_bits = max(u64)},
    }
}

character_step :: proc(
    world: World,
    config: Character_Config,
    state: Character_State,
    dt: f32,
) -> (
    result: Character_Result,
    status: Status,
) {
    if status = motion_abi_check(); status != .Ok {
        return
    }

    if status = domain_access_check(); status != .Ok {
        return
    }

    config_copy, state_copy := config, state
    status = raw_character_step(world, &config_copy, &state_copy, dt, &result)
    return
}
