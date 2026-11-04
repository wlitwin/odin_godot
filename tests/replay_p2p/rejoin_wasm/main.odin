package wasm
import "base:runtime"
import "core:mem"
import c "../rejoin_corpus"
backing: [32 * 1024 * 1024]u8

@(export)
verify :: proc "c" (seed: u32) -> u64 {
    context = runtime.default_context()
    arena: mem.Arena
    mem.arena_init(&arena, backing[:])
    context.allocator = mem.arena_allocator(&arena)
    context.temp_allocator = context.allocator
    return c.verify_case(u64(seed))
}
