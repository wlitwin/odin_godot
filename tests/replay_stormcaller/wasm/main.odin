package storm_wasm
import "base:runtime"
import "core:mem"
import c "../corpus"
backing: [256 * 1024 * 1024]u8

@(export)
verify :: proc "c" () -> u64 {
    context = runtime.default_context()
    arena: mem.Arena
    mem.arena_init(&arena, backing[:])
    context.allocator = mem.arena_allocator(&arena)
    context.temp_allocator = context.allocator
    hash, ok := c.verify()
    return ok ? hash : 0
}
