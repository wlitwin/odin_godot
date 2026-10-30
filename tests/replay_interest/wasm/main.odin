package wasm_interest
import "base:runtime"
import "core:mem"
import corpus "../corpus"
backing:[8*1024*1024]u8
last:corpus.Result
@(export)
run :: proc "c" ()->u32 {context=runtime.default_context();arena:mem.Arena;mem.arena_init(&arena,backing[:]);context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator;last=corpus.run();return last.ok ? 1 : 0}
@(export)
hash :: proc "c" ()->u64 {return last.hash}
@(export)
fingerprint :: proc "c" ()->u64 {return last.fingerprint}
@(export)
frames :: proc "c" ()->u32 {return last.frames}
