package main

import "core:fmt"
import "core:os"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import d "godot:replay/diagnostic"
import base "godot:examples/replay_cavecrawl/shared/cave"
import owner "godot:examples/replay_cavecrawl/shared/owner_cave"

// Capture new current-rule traces. These are not rewrites of historical events.
capture :: proc(data: []u8, model: net.Model($W, $C, $A, base.Event, base.SEATS), content: u64, name: string) {
    model := model
    cp: net.Checkpoint(W, C, A, base.SEATS)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_decode(&cp, data, model, content) == .None)
    assert(cp.frame.state.dwellers.values[0].hp == 70 && cp.frame.state.rocks.count == 1)
    assert(len(cp.actions) == 1 && cp.actions[0].value.verb == .Door)
    when A == owner.Action {assert(cp.actions[0].value.origin_kind == .Accepted_Pose)}
    server: net.Server(W, C, A, base.Event, base.SEATS)
    defer net.server_destroy(&server)
    assert(
        net.server_restore(
            &server,
            &cp,
            model,
            {},
            {epoch = cp.header.epoch + 1, local_seat = 1, preserve_pending = true, retain_membership = true},
        ) ==
        .None,
    )
    restored, _ := r.current(&server.timeline)
    assert(reflect.equal(restored, cp.frame))
    for tick in 0 ..< 3 {
        assert(net.server_step(&server) == .None)
        frame, _ := r.current(&server.timeline)
        assert(frame.state.dwellers.values[0].hp == 35 && frame.state.rocks.count == 0)
        assert(frame.state.players[0].damage == cp.frame.state.players[0].damage + 35)
    }
    record: d.Recording(W, net.Batch(C, A, base.SEATS), net.Net_Event(base.Event))
    defer d.recording_destroy(&record)
    identity := d.Recording_Context{content, 1, base.HZ}
    assert(d.recording_capture(&record, &server.timeline, identity, max_ticks = 3).error == .None)
    assert(record.base.tick == cp.frame.tick && record.epoch == cp.header.epoch + 1 && len(record.ticks) == 3)
    hits, verdicts := 0, 0
    for event in record.events {
        assert(
            event.id.epoch == record.epoch && event.id.tick > record.base.tick && event.id.tick <= record.header.head,
        )
        if event.value.kind == .Gameplay {
            assert(event.value.value.kind != .Door)
            if event.value.value.kind == .Hit && event.value.value.seat == 0 {
                hits += 1
                assert(event.value.value.amount == base.ROCK_DAMAGE)
                assert(event.id.key == u64(cp.frame.state.dwellers.generations[0]) << 32 | 1)
                assert(event.id.source == u64(1) << 60 | u64(cp.frame.state.rocks.generations[0]) << 16)
            }
        } else if event.value.sequence == cp.actions[0].sequence && event.value.seat == 1 {
            verdicts += 1
            assert(!event.value.applied && event.value.reason == .Predicate)
        }
    }
    assert(hits == 1 && verdicts == 1)
    encoded, error := d.recording_encode(&record)
    assert(error == .None)
    defer delete(encoded)
    decoded: d.Recording(W, net.Batch(C, A, base.SEATS), net.Net_Event(base.Event))
    defer d.recording_destroy(&decoded)
    assert(d.recording_decode(&decoded, encoded, identity) == .None)
    audit: r.Audit_Capture(W, net.Batch(C, A, base.SEATS), net.Net_Event(base.Event))
    defer r.audit_capture_destroy(&audit)
    assert(d.recording_verify(&decoded, identity, net.recording_model(&model), &audit).error == .None)
    assert(os.write_entire_file(fmt.tprintf("%s/%s.rplrec", os.args[1], name), encoded) == nil)
    fmt.printf(
        "CURRENT_CAVE_RECORDING_OK name=%s content=%x epoch=%d first=%d head=%d ticks=%d hits=%d verdicts=%d\n",
        name,
        content,
        record.epoch,
        record.header.first,
        record.header.head,
        len(record.ticks),
        hits,
        verdicts,
    )
}

main :: proc() {
    assert(len(os.args) == 2, "usage: capture OUTPUT_DIRECTORY")
    capture(#load("../fixtures/current/server.checkpoint", []u8), base.model(), base.CONTENT, "server")
    capture(#load("../fixtures/current/owner.checkpoint", []u8), owner.model(), owner.CONTENT, "owner")
}
