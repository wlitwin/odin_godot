package godot


Audio_Frame :: struct {
    left: f32,
    right: f32,
}

Caret_Info :: struct {
    leading_caret: Rect2,
    trailing_caret: Rect2,
    leading_direction: Text_Server_Direction,
    trailing_direction: Text_Server_Direction,
}

Glyph :: struct {
    start: Int,
    end: Int,
    count: u8,
    repeat: u8,
    flags: u16,
    x_off: f32,
    y_off: f32,
    advance: f32,
    font_rid: Rid,
    font_size: Int,
    index: i32,
}

Object_Id :: struct {
    id: u64,
}

Physics_Server2d_Extension_Motion_Result :: struct {
    travel: Vector2,
    remainder: Vector2,
    collision_point: Vector2,
    collision_normal: Vector2,
    collider_velocity: Vector2,
    collision_depth: Real,
    collision_safe_fraction: Real,
    collision_unsafe_fraction: Real,
    collision_local_shape: Int,
    collider_id: Object_Id,
    collider: Rid,
    collider_shape: Int,
}

Physics_Server2d_Extension_Ray_Result :: struct {
    position: Vector2,
    normal: Vector2,
    rid: Rid,
    collider_id: Object_Id,
    collider: Object,
    shape: Int,
}

Physics_Server2d_Extension_Shape_Rest_Info :: struct {
    point: Vector2,
    normal: Vector2,
    rid: Rid,
    collider_id: Object_Id,
    shape: Int,
    linear_velocity: Vector2,
}

Physics_Server2d_Extension_Shape_Result :: struct {
    rid: Rid,
    collider_id: Object_Id,
    collider: Object,
    shape: Int,
}

Physics_Server3d_Extension_Motion_Collision :: struct {
    position: Vector3,
    normal: Vector3,
    collider_velocity: Vector3,
    collider_angular_velocity: Vector3,
    depth: Real,
    local_shape: Int,
    collider_id: Object_Id,
    collider: Rid,
    collider_shape: Int,
}

Physics_Server3d_Extension_Motion_Result :: struct {
    travel: Vector3,
    remainder: Vector3,
    collision_depth: Real,
    collision_safe_fraction: Real,
    collision_unsafe_fraction: Real,
    collisions: [32]Physics_Server3d_Extension_Motion_Collision,
    collision_count: Int,
}

Physics_Server3d_Extension_Ray_Result :: struct {
    position: Vector3,
    normal: Vector3,
    rid: Rid,
    collider_id: Object_Id,
    collider: Object,
    shape: Int,
    face_index: Int,
}

Physics_Server3d_Extension_Shape_Rest_Info :: struct {
    point: Vector3,
    normal: Vector3,
    rid: Rid,
    collider_id: Object_Id,
    shape: Int,
    linear_velocity: Vector3,
}

Physics_Server3d_Extension_Shape_Result :: struct {
    rid: Rid,
    collider_id: Object_Id,
    collider: Object,
    shape: Int,
}

Script_Language_Extension_Profiling_Info :: struct {
    signature: String_Name,
    call_count: u64,
    total_time: u64,
    self_time: u64,
}

