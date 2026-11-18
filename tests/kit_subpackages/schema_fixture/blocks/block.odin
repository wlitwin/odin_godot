package schema_blocks

import values "../wireformats"

Block :: struct($T: typeid) {
    value: T `gd:"replicate,wire=values.SIGNED_V1,interp=blend_local"`,
}

@(private)
blend_local :: proc(dst, a, b: rawptr, alpha: f32) {
    (cast(^i32)dst)^ = i32(f32((cast(^i32)a)^) * (1-alpha) + f32((cast(^i32)b)^) * alpha)
}
