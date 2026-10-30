package route_wasm
import "base:runtime"
import "core:mem"
import corpus "../corpus"
backing:[1024*1024]u8
@(export)
verify :: proc "c"()->u32 {
    context=runtime.default_context();arena:mem.Arena;mem.arena_init(&arena,backing[:]);context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator
    return corpus.run()
}
