package wasm_corpus

import "base:runtime"
import "core:mem"
import corpus "../../../examples/replay_duel/shared/corpus"

backing: [4 * 1024 * 1024]u8
last: corpus.Result

@(export)
run_corpus :: proc "c" (seed: u32) -> u64 {
    context = runtime.default_context()
    arena: mem.Arena
    mem.arena_init(&arena, backing[:])
    context.allocator = mem.arena_allocator(&arena)
    context.temp_allocator = context.allocator
    last = corpus.run(u64(seed), 2400)
    return last.ok ? last.hash : 0
}

@(export)
shots :: proc "c" () -> u32 {
    return last.shots
}

@(export)
hits :: proc "c" () -> u32 {
    return last.hits
}

@(export)
kills :: proc "c" (seat: u32) -> u32 {
    return seat < 2 ? last.kills[seat] : 0
}
