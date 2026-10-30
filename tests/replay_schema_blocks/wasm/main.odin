package wasm
import "base:runtime"
import "core:mem"
import c "../shared"
backing:[64*1024*1024]u8
@(export)
run :: proc "c" ()->u32 {
 context=runtime.default_context();arena:mem.Arena;mem.arena_init(&arena,backing[:]);context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator
 return c.verify()
}
