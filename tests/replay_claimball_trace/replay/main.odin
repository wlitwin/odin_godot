package main
import "core:fmt"
import "core:os"
import "core:reflect"
import sc "godot:replay/schema"
import tape "godot:replay/transport/trace"
import net "godot:replay/net"
import tr "godot:replay/transport"
import view "godot:replay/view"
import trace "godot:tests/replay_claimball_trace/shared"
import game "godot:examples/replay_claimball/shared/pitch"

main :: proc() {
    assert(len(os.args) == 2)
    data, error := os.read_entire_file(os.args[1], context.allocator)
    assert(error == nil)
    defer delete(data)
    log: tape.Log
    assert(tape.decode(&log, data) == .None)
    defer tape.destroy(&log)
    player: tape.Replay
    wire := tape.replay(&player, &log)
    first, ok := tape.read_mark(&player, 1)
    assert(ok)
    hc, fc: sc.Schema
    assert(sc.init(&hc, trace.Header).error == .None && sc.init(&fc, trace.Frame).error == .None)
    defer sc.destroy(&hc)
    defer sc.destroy(&fc)
    header: trace.Header
    assert(sc.decode(&hc, &header, tape.payload(&log, first)).error == .None)
    assert(header.drain_capacity > 0 && header.drain_capacity <= net.WIRE_EVENTS * 8)
    client: net.Client(game.World, game.Controls, game.Action, game.Event, game.SEATS)
    assert(
        net.client_init(
            &client,
            game.model(),
            wire,
            header.token,
            true,
            tr.Peer_Id(header.authority),
            trace.config(header),
            incarnation = header.incarnation,
        ) ==
        .None,
    )
    defer net.client_destroy(&client)

    if header.query {
        assert(net.client_discover_epoch(&client, header.query_nonce) == .None)
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
    frames, kicks := u64(0), u64(0)

    for !tape.finished(&player) {
        entry := log.entries[player.index]

        if entry.operation == .Mark && entry.peer == 3 {
            _, consumed := tape.read_mark(&player, 3)
            assert(consumed)
            trace.request_refresh(&client)
            continue
        }

        mark, found := tape.next_mark(&player, 2)
        assert(found)
        error := net.client_pump(&client, mark.generation)

        if player.error != .None {
            fmt.printf("TRACE_DIVERGED frame=%d operation=%d error=%v\n", frames, player.index, player.error)
            os.exit(1)
        }

        assert(error == .None)
        net.client_recovery(&client)
        count := view.drain(&client.journal, changes[:])
        expected: trace.Frame
        assert(sc.decode(&fc, &expected, tape.payload(&log, mark)).error == .None)
        actual := trace.observation(&client, changes[:count])

        if !reflect.equal(actual, expected) {
            fmt.printf("TRACE_STATE_MISMATCH frame=%d expected=%v actual=%v\n", frames, expected, actual)
            os.exit(1)
        }

        for change in changes[:count] {
            if change.kind == .Begin &&
               change.occurrence.value.kind == .Gameplay &&
               change.occurrence.value.value.kind == .Kick {
                kicks += 1
            }
        }

        _, consumed := tape.read_mark(&player, 2)
        assert(consumed)
        frames += 1
    }

    fmt.printf(
        "CLAIMBALL_TRACE_REPLAY_OK frames=%d operations=%d world_tick=%d kicks=%d resyncs=%d\n",
        frames,
        len(log.entries),
        client.authority_frame.tick,
        kicks,
        client.stats.resyncs,
    )
}
