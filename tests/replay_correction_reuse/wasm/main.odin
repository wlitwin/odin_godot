package wasm
import "base:runtime"
import "core:mem"
backing:[32*1024*1024]u8
import c "../shared"
@(export)
verify :: proc "c" ()->u64 {context=runtime.default_context();arena:mem.Arena;mem.arena_init(&arena,backing[:]);context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator;hash,reused,ok:=c.verify();return ok && reused>0 ? hash : 0}
