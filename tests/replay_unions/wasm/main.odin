package wasm_corpus
import "base:runtime"
import "core:mem"
import corpus "../shared"
backing:[8*1024*1024]u8
last:corpus.Result
@(export)
run :: proc "c" ()->u32 {
	context=runtime.default_context();arena:mem.Arena;mem.arena_init(&arena,backing[:]);context.allocator=mem.arena_allocator(&arena);context.temp_allocator=context.allocator
	last=corpus.run();return last.ok ? 1 : 0
}
@(export)
fingerprint :: proc "c" ()->u64 {return last.fingerprint}
@(export)
hash :: proc "c" ()->u64 {return last.hash}
@(export)
count :: proc "c" ()->u32 {return u32(last.count)}
@(export)
byte_at :: proc "c" (i:u32)->u32 {return i<u32(last.count) ? u32(last.bytes[i]) : 0}
