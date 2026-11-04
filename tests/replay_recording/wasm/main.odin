package recording_wasm

import "base:runtime"
import "core:mem"
import r "godot:replay"
import d "godot:replay/diagnostic"
import game "../../../examples/replay_hello/shared/hello"

input: [d.MAX_RECORDING_BYTES]u8
backing: [64 * 1024 * 1024]u8
last: d.Recording_Result
head, first, epoch, shots, events: u64
x: f64

@(export)
input_address :: proc "c" () -> u32 {
    return u32(uintptr(&input[0]))
}

@(export)
verify :: proc "c" (count: u32) -> u32 {
    context = runtime.default_context()
    arena: mem.Arena
    mem.arena_init(&arena, backing[:])
    context.allocator = mem.arena_allocator(&arena)
    context.temp_allocator = context.allocator
    last = {}
    head, first, epoch, shots, events = 0, 0, 0, 0, 0
    x = 0

    if count > u32(len(input)) {
        return u32(d.Recording_Error.Capacity)
    }

    recording: d.Recording(game.World, game.Input, game.Event)
    defer d.recording_destroy(&recording)

    if error := d.recording_decode(&recording, input[:count], game.RECORDING_CONTEXT); error != .None {
        return u32(error)
    }

    capture: r.Audit_Capture(game.World, game.Input, game.Event)
    defer r.audit_capture_destroy(&capture)
    last = d.recording_verify(&recording, game.RECORDING_CONTEXT, game.recording_model(), &capture)
    head, first, epoch, events =
        recording.header.head, recording.header.first, recording.epoch, u64(len(recording.events))
    frame := recording.base

    if len(recording.ticks) > 0 {
        frame = recording.ticks[len(recording.ticks) - 1].frame
    }

    shots = u64(frame.state.shots)
    actor, present := r.pool_get(&frame.state.actors, frame.state.players[0])

    if present {
        x = f64(actor.body.position[0])
    }

    return u32(last.error)
}

@(export)
field :: proc "c" (index: u32) -> u64 {
    switch index {
    case 0:
        return first
    case 1:
        return head
    case 2:
        return u64(last.replay.steps)
    case 3:
        return events
    case 4:
        return epoch
    case 5:
        return shots
    }

    return 0
}

@(export)
position :: proc "c" () -> f64 {
    return x
}
