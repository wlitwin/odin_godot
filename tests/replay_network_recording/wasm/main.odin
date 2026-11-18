package network_recording_wasm

import "base:runtime"
import "core:mem"
import tlsf "core:mem/tlsf"
import d "godot:replay/diagnostic"
import r "godot:replay"
import net "godot:replay/net"
import game "../../../examples/replay_scrapyard/shared/game"
import recording "../../../examples/replay_scrapyard/shared/recording"
World :: game.World
Action :: game.Action
IDENTITY :: recording.CONTEXT
source_model :: game.model

Archive :: d.Recording(World, net.Batch(game.Control, Action, game.SEATS), net.Net_Event(game.Event))

input: [d.MAX_RECORDING_BYTES]u8
backing: [128 * 1024 * 1024 / size_of(u64)]u64
report: [13]u64
failure: [8192]u8
failure_count: u32

@(export)
input_address :: proc "c" () -> u32 {
    return u32(uintptr(&input[0]))
}

@(export)
failure_address :: proc "c" () -> u32 {
    return u32(uintptr(&failure[0]))
}

@(export)
failure_size :: proc "c" () -> u32 {
    return failure_count
}

@(export)
field :: proc "c" (index: u32) -> u64 {
    return index < u32(len(report)) ? report[index] : 0
}

@(export)
verify :: proc "c" (count: u32) -> u32 {
    context = runtime.default_context()
    // Historical adapters create and destroy temporary schemas for each state.
    // Reclaim those allocations inside the same fixed backing, as native does;
    // a bump arena would retain every destroyed schema for the whole recording.
    heap: tlsf.Allocator

    if tlsf.init(&heap, mem.slice_to_bytes(backing[:])) != .None {
        return u32(d.Recording_Error.Capacity)
    }

    defer tlsf.destroy(&heap)
    context.allocator = tlsf.allocator(&heap)
    context.temp_allocator = context.allocator
    report = {}
    failure_count = 0

    if count > u32(len(input)) {
        return u32(d.Recording_Error.Capacity)
    }

    archive: Archive
    defer d.recording_destroy(&archive)

    if error := d.recording_decode(&archive, input[:count], IDENTITY); error != .None {
        return u32(error)
    }

    model := source_model()
    capture: r.Audit_Capture(World, net.Batch(game.Control, Action, game.SEATS), net.Net_Event(game.Event))
    defer r.audit_capture_destroy(&capture)
    result := d.recording_verify(&archive, IDENTITY, net.recording_model(&model), &capture)
    report[0], report[1], report[2], report[3], report[12] =
        archive.header.head, archive.base.tick, archive.epoch, u64(result.replay.steps), result.replay.tick

    if result.error != .None {
        text := d.audit_text(result.replay, &capture)
        defer delete(text)
        failure_count = u32(min(len(text), len(failure)))
        copy(failure[:failure_count], text)
        return u32(result.error)
    }

    for event in archive.events {
        if event.value.kind == .Gameplay {
            report[4] += 1
        } else {
            report[5] += 1

            if event.value.applied {
                report[6] += 1
            } else {
                report[7] += 1
            }
        }
    }

    for tick in archive.ticks {
        for view in tick.input.views {
            if view.status == .Historical {
                report[8] += 1
            }
        }
    }

    frame := archive.base

    if len(archive.ticks) > 0 {
        frame = archive.ticks[len(archive.ticks) - 1].frame
    }

    for player in frame.state.players {
        report[9] += u64(player.shots)
        report[10] += u64(player.casts)
    }

    report[11] = u64(frame.state.mobs.count)
    return 0
}
