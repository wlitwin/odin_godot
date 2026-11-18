package large_values

import "base:runtime"
import r "godot:replay"

Unit :: struct {
    position, velocity: [3]f32,
    health: i32,
    tag: u64,
}

World :: struct {units: [4096]Unit}
Timeline :: r.Timeline(World, u8, u8)

// Export keeps an opaque caller and output alive in optimized Wasm codegen.
// The ordinary read API must remain practical for large value-only Worlds.
@(export)
large_values_read :: proc "c" (timeline: ^Timeline, tick: u64, out: ^r.Frame(World)) -> bool {
    context = runtime.default_context()
    frame, ok := r.read_values(timeline, tick)
    out^ = frame
    return ok
}
