// Shared physics PODs. Importing these definitions never registers a native domain.
package box3d_types

MAX_RESTITUTION_ITERATIONS :: 63 // Box3D's B3_MAX_RESTITUTION_ITERATIONS

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

Body_Key :: distinct u64

Shape_Key :: distinct u64

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
    gravity:                        Vec3,
    enable_sleep:                   u32,
    enable_continuous:              u32,
    // Solver tuning (ABI 2). Each 0 keeps Box3D's default, which Box3D scales by
    // the length unit for the thresholds and speeds: restitution threshold 1 m/s,
    // hit event threshold 1 m/s, contact hertz 30, contact damping ratio 10,
    // contact (push-out) speed 3 m/s, maximum linear speed 400 m/s, isotropic
    // inertia tolerance 0.2, two restitution iterations, no propagation.
    restitution_threshold:          f32,
    hit_event_threshold:            f32,
    contact_hertz:                  f32,
    contact_damping_ratio:          f32,
    contact_speed:                  f32,
    maximum_linear_speed:           f32,
    isotropic_inertia_tolerance:    f32,
    restitution_iterations:         u32,
    enable_restitution_propagation: u32,
}

Body_Type :: enum i32 {
    Static    = 0,
    Kinematic = 1,
    Dynamic   = 2,
}

Body_Def :: struct {
    type:                      Body_Type,
    pose:                      Pose,
    linear_velocity:           Vec3,
    angular_velocity:          Vec3,
    linear_damping:            f32,
    angular_damping:           f32,
    gravity_scale:             f32,
    sleep_threshold:           f32,
    enable_sleep:              u32,
    is_awake:                  u32,
    is_bullet:                 u32,
    is_enabled:                u32,
    // Lift Box3D's angular speed cap (one eighth turn per step, 47 rad/s at
    // 60 Hz) for round bodies that roll fast, such as wheels and balls.
    allow_fast_rotation:       u32,
    motion_locks:              Motion_Locks, // 0 = free
    safety_factor:             f32, // continuous-collision margin; 0 keeps Box3D's 0.5
    disable_contact_recycling: u32,
}

Motion_Lock :: enum u32 {
    Linear_X,
    Linear_Y,
    Linear_Z,
    Angular_X,
    Angular_Y,
    Angular_Z,
}

Motion_Locks :: distinct bit_set[Motion_Lock;u32]

Shape_Def :: struct {
    category_bits:               u64,
    mask_bits:                   u64,
    group_index:                 i32,
    density:                     f32,
    friction:                    f32,
    restitution:                 f32,
    is_sensor:                   u32,
    enable_sensor_events:        u32,
    enable_contact_events:       u32,
    // ABI 2. All 0 keep Box3D's defaults: no rolling resistance (a torque
    // opposing rolling, scaled by the shape's radius), no tangent (conveyor)
    // velocity, contact creation on add, speculative contacts on.
    rolling_resistance:          f32,
    tangent_velocity:            Vec3,
    skip_contact_creation:       u32,
    disable_speculative_contact: u32,
}

MOTION_VERSION :: 1

Motion_Joint_Kind :: enum u32 {
    Pin = 1,
    Hinge,
    Slider,
    Spherical,
    Distance,
    Motor,
    Weld,
    Wheel,
}

Motion_Joint_Axis :: struct {
    flags:                                                              u32,
    hertz, damping_ratio, target, lower, upper, motor_speed, max_motor: f32,
}

Motion_Joint_Distance :: struct {
    axis:                                           Motion_Joint_Axis,
    length, lower_spring_force, upper_spring_force: f32,
}

Motion_Joint_Spherical :: struct {
    flags:                                                                        u32,
    hertz, damping_ratio, cone_angle, lower_twist, upper_twist, max_motor_torque: f32,
    target_rotation:                                                              Quat,
    motor_velocity:                                                               Vec3,
}

Motion_Joint_Motor :: struct {
    linear_velocity,
    angular_velocity:                                                                                                                      Vec3,
    max_velocity_force,
    max_velocity_torque,
    linear_hertz,
    linear_damping_ratio,
    angular_hertz,
    angular_damping_ratio,
    max_spring_force,
    max_spring_torque: f32,
}

Motion_Joint_Weld :: struct {
    linear_hertz, angular_hertz, linear_damping_ratio, angular_damping_ratio: f32,
}

Motion_Joint_Wheel :: struct {
    flags:                                                                                                                                                                                                                           u32,
    suspension_hertz,
    suspension_damping_ratio,
    lower_suspension,
    upper_suspension,
    max_spin_torque,
    spin_speed,
    steering_hertz,
    steering_damping_ratio,
    target_steering_angle,
    max_steering_torque,
    lower_steering,
    upper_steering: f32,
}

Motion_Joint_Def :: struct {
    version:                                                                       u32,
    kind:                                                                          Motion_Joint_Kind,
    body_a, body_b:                                                                Body_Key,
    local_frame_a, local_frame_b:                                                  Pose,
    force_threshold, torque_threshold, constraint_hertz, constraint_damping_ratio: f32,
    collide_connected, reserved:                                                   u32,
    axis:                                                                          Motion_Joint_Axis,
    distance:                                                                      Motion_Joint_Distance,
    spherical:                                                                     Motion_Joint_Spherical,
    motor:                                                                         Motion_Joint_Motor,
    weld:                                                                          Motion_Joint_Weld,
    wheel:                                                                         Motion_Joint_Wheel,
}

Motion_Filter :: struct {
    category_bits, mask_bits:  u64,
    exclude_body:              Body_Key,
    include_sensors, reserved: u32,
}

Motion_Capsule :: struct {
    center1, center2: Vec3,
    radius:           f32,
}

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
