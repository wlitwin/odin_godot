package claimball_trace_wasm
import "base:runtime"
import "core:mem"
import "core:reflect"
import sc "godot:replay/schema"
import tape "godot:replay/transport/trace"
import net "godot:replay/net"
import tr "godot:replay/transport"
import view "godot:replay/view"
import trace "godot:tests/replay_claimball_trace/shared"
import game "godot:examples/replay_claimball/shared/pitch"

input: [16 * 1024 * 1024]u8
backing: [96 * 1024 * 1024]u8
scratch_backing: [16 * 1024 * 1024]u8
report: [8]u64
Client :: net.Client(game.World, game.Controls, game.Action, game.Event, game.SEATS)

@(export)
input_address :: proc "c" () -> u32 {
    return u32(uintptr(&input[0]))
}

@(export)
field :: proc "c" (index: u32) -> u64 {
    return index < u32(len(report)) ? report[index] : 0
}

@(export)
verify :: proc "c" (count: u32) -> u32 {
    context = runtime.default_context()
    arena, scratch: mem.Arena
    mem.arena_init(&arena, backing[:])
    mem.arena_init(&scratch, scratch_backing[:])
    context.allocator = mem.arena_allocator(&arena)
    context.temp_allocator = mem.arena_allocator(&scratch)
    report = {}

    if count > u32(len(input)) {
        return 1
    }

    log: tape.Log

    if tape.decode(&log, input[:count], limits = {100_000, len(input)}) != .None {
        return 1
    }

    defer tape.destroy(&log)
    player: tape.Replay
    wire := tape.replay(&player, &log)
    first, ok := tape.read_mark(&player, 1)

    if !ok {
        return 2
    }

    hc, fc: sc.Schema
    defer sc.destroy(&hc)
    defer sc.destroy(&fc)

    if sc.init(&hc, trace.Header).error != .None || sc.init(&fc, trace.Frame).error != .None {
        return 2
    }

    header: trace.Header

    if sc.decode(&hc, &header, tape.payload(&log, first)).error != .None {
        return 2
    }

    if header.drain_capacity == 0 || header.drain_capacity > net.WIRE_EVENTS * 8 {
        return 2
    }

    client: Client
    defer net.client_destroy(&client)

    if net.client_init(
           &client,
           game.model(),
           wire,
           header.token,
           true,
           tr.Peer_Id(header.authority),
           trace.config(header),
           incarnation = header.incarnation,
       ) !=
       .None {
        return 3
    }

    if header.query && net.client_discover_epoch(&client, header.query_nonce) != .None {
        return 3
    }

    if header.mixed {
        net.client_remote_observed(&client)
    }

    client.snapshot_parts_enabled, client.lz4_snapshots_enabled, client.snapshot_erasure_enabled, client.snapshot_shuffle_enabled =
        header.parts, header.lz4, header.erasure, header.shuffle
    client.fact_repair_enabled, client.action_copies_enabled, client.reuse_equal_corrections =
        header.facts, header.actions, header.reuse
    changes := make([]view.Change(net.Net_Event(game.Event)), header.drain_capacity)
    defer delete(changes)
    report[1] = u64(len(log.entries))

    for !tape.finished(&player) {
        if player.error != .None || player.index >= len(log.entries) {
            return 4
        }

        entry := log.entries[player.index]

        if entry.operation == .Mark && entry.peer == 3 {
            _, consumed := tape.read_mark(&player, 3)

            if !consumed || client.phase != .Running {
                return 4
            }

            trace.request_refresh(&client)
            report[5] += 1
            continue
        }

        mark, found := tape.next_mark(&player, 2)

        if !found {
            return 4
        }

        if net.client_pump(&client, mark.generation) != .None || player.error != .None {
            return 4
        }

        net.client_recovery(&client)
        n := view.drain(&client.journal, changes[:])
        expected: trace.Frame

        if sc.decode(&fc, &expected, tape.payload(&log, mark)).error != .None {
            return 2
        }

        // Schema/hash scratch is independent of the persistent decoded trace/client.
        actual := observe(&client, changes[:n], mem.arena_allocator(&scratch))
        report[6], report[7] = u64(expected.changes), u64(actual.changes)

        if !reflect.equal(actual, expected) {
            return 5
        }

        for change in changes[:n] {
            if change.kind == .Begin &&
               change.occurrence.value.kind == .Gameplay &&
               change.occurrence.value.value.kind == .Kick {
                report[3] += 1
            }
        }

        _, consumed := tape.read_mark(&player, 2)

        if !consumed {
            return 4
        }

        report[0] += 1
        mem.arena_free_all(&scratch)
    }

    report[2], report[4] = client.authority_frame.tick, client.stats.resyncs
    return 0
}

observe :: proc(
    c: ^Client,
    changes: []view.Change(net.Net_Event(game.Event)),
    allocator: mem.Allocator,
) -> trace.Frame {
    previous := context
    defer context = previous
    context.allocator, context.temp_allocator = allocator, allocator
    return trace.observation(c, changes)
}
