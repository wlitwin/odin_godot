package archive_wasm

import "base:runtime"
import "core:mem"
import rb "godot:replay/p2p"
import recording "../../../examples/replay_duel/shared/recording"

input: [rb.MAX_ARCHIVE_BYTES]u8
backing: [32 * 1024 * 1024]u8
last: recording.Report

@(export)
input_address :: proc "c" () -> u32 {
    return u32(uintptr(&input[0]))
}

@(export)
invalid_error :: proc "c" () -> u32 {
    return u32(rb.Error.Invalid_Archive)
}

@(export)
verify :: proc "c" (count: u32) -> u32 {
    context = runtime.default_context()
    arena: mem.Arena
    mem.arena_init(&arena, backing[:])
    context.allocator = mem.arena_allocator(&arena)
    context.temp_allocator = context.allocator

    if count > u32(len(input)) {
        last = {
            error = .Invalid_Archive,
        }
        return u32(last.error)
    }

    last = recording.verify(input[:count])
    return u32(last.error)
}

@(export)
field :: proc "c" (index: u32) -> u64 {
    switch index {
    case 0:
        return u64(last.phase)
    case 1:
        return last.base
    case 2:
        return last.head
    case 3:
        return last.confirmed
    case 4:
        return last.chain
    case 5:
        return last.replay.tick
    case 6:
        return last.replay.expected
    case 7:
        return last.replay.actual
    case 8:
        return last.disagreement.tick
    }

    return 0
}
