package wasm
import "base:runtime"
import "core:mem"
import corpus "../shared"
backing:[8*1024*1024]u8
value:u64
@(export)
run :: proc "c" ()->u32 {context=runtime.default_context();arena:mem.Arena;mem.arena_init(&arena,backing[:]);context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator;code,hash,_:=corpus.verify();value=hash;return code}
@(export)
hash :: proc "c" ()->u64 {return value}
