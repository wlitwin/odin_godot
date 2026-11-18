package cave_impact_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import d "godot:replay/diagnostic"
import base "../../examples/replay_cavecrawl/shared/cave"
import owner "../../examples/replay_cavecrawl/shared/owner_cave"

check_checkpoint :: proc(
    t: ^testing.T,
    bytes: []u8,
    current: net.Model($W, $C, $A, base.Event, base.SEATS),
    content: u64,
) {
    before, after: net.Checkpoint(W, C, A, base.SEATS)
    defer net.checkpoint_destroy(&before)
    defer net.checkpoint_destroy(&after)
    testing.expect_value(t, net.checkpoint_decode(&before, bytes, current, content), net.Error.None)
    encoded, error := net.checkpoint_encode(&before, current)
    defer delete(encoded)
    testing.expect_value(t, error, net.Error.None)
    testing.expect(t, reflect.equal(bytes, encoded, true))
    testing.expect_value(t, net.checkpoint_decode(&after, encoded, current, content), net.Error.None)
    testing.expect(
        t,
        reflect.equal(before.frame, after.frame) &&
        reflect.equal(before.held, after.held) &&
        reflect.equal(before.held_views, after.held_views),
    )
    testing.expect(
        t,
        reflect.equal(before.peers[:], after.peers[:], true) &&
        reflect.equal(before.actions[:], after.actions[:], true),
    )
    testing.expect(
        t,
        reflect.equal(before.settings, after.settings) && reflect.equal(before.inputs[:], after.inputs[:], true),
    )
    testing.expect(
        t,
        reflect.equal(before.outcomes[:], after.outcomes[:], true) &&
        reflect.equal(before.banned[:], after.banned[:], true) &&
        reflect.equal(before.policy_data, after.policy_data, true),
    )
    testing.expect(t, reflect.equal(before.header, after.header))
    testing.expect(t, len(after.actions) == 1 && after.frame.state.dwellers.values[0].hp == 70)
    server: net.Server(W, C, A, base.Event, base.SEATS)
    defer net.server_destroy(&server)
    testing.expect_value(
        t,
        net.server_restore(
            &server,
            &after,
            current,
            {},
            {epoch = 2, local_seat = 1, retain_membership = true, preserve_pending = true},
        ),
        net.Error.None,
    )
    restored, _ := r.current(&server.timeline)
    testing.expect(t, reflect.equal(restored, after.frame))
    testing.expect_value(t, net.server_step(&server), net.Error.None)
    advanced, _ := r.current(&server.timeline)
    testing.expect_value(t, advanced.state.dwellers.values[0].hp, i32(35))
    events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(base.Event))
    count, read := r.copy_events(&server.timeline, advanced.tick, events[:])
    testing.expect_value(t, read, r.Error.None)
    found, verdicts := 0, 0

    for event in events[:count] {
        if event.value.kind == .Gameplay && event.value.value.kind == .Hit && event.value.value.seat == 0 {
            found += 1
            testing.expect_value(t, event.id.key, u64(1) << 32 | 1)
        }
        if event.value.kind == .Action_Result &&
           event.value.sequence == after.actions[0].sequence &&
           event.value.seat == 1 {
            verdicts += 1
            testing.expect(t, !event.value.applied && event.value.reason == .Predicate)
        }
    }

    testing.expect_value(t, found, 1)
    testing.expect_value(t, verdicts, 1)
    testing.expect_value(t, server.peers[int(after.actions[0].peer)].action_settled, after.actions[0].sequence)
    testing.expect_value(t, net.server_step(&server), net.Error.None)
    later, _ := r.current(&server.timeline)
    count, read = r.copy_events(&server.timeline, later.tick, events[:])
    testing.expect_value(t, read, r.Error.None)
    for event in events[:count] {
        testing.expect(t, event.value.kind != .Action_Result || event.value.sequence != after.actions[0].sequence)
        testing.expect(
            t,
            event.value.kind != .Gameplay || event.value.value.kind != .Hit || event.value.value.seat != 0,
        )
    }
}

@(test)
current_checkpoints_preserve_complete_state_and_pending_impacts :: proc(t: ^testing.T) {
    check_checkpoint(t, #load("fixtures/current/server.checkpoint", []u8), base.model(), base.CONTENT)
    check_checkpoint(t, #load("fixtures/current/owner.checkpoint", []u8), owner.model(), owner.CONTENT)
}

check_recording :: proc(
    t: ^testing.T,
    bytes: []u8,
    current: net.Model($W, $C, $A, base.Event, base.SEATS),
    content: u64,
) {
    record: d.Recording(W, net.Batch(C, A, base.SEATS), net.Net_Event(base.Event))
    defer d.recording_destroy(&record)
    identity := d.Recording_Context{content, 1, base.HZ}
    testing.expect_value(t, d.recording_decode(&record, bytes, identity), d.Recording_Error.None)
    model := current
    audit: r.Audit_Capture(W, net.Batch(C, A, base.SEATS), net.Net_Event(base.Event))
    defer r.audit_capture_destroy(&audit)
    testing.expect(t, record.epoch == 2 && record.base.tick == 1 && record.header.head == 4 && len(record.ticks) == 3)
    testing.expect_value(
        t,
        d.recording_verify(&record, identity, net.recording_model(&model), &audit).error,
        d.Recording_Error.None,
    )
    hits, verdicts := 0, 0
    hit_index := -1
    for event, index in record.events {
        if event.value.kind == .Gameplay && event.value.value.kind == .Hit && event.value.value.seat == 0 {
            hits += 1
            hit_index = index
            testing.expect(t, event.value.value.amount == base.ROCK_DAMAGE && event.id.key == (u64(1) << 32 | 1))
        }
        if event.value.kind == .Action_Result && event.value.sequence == 1 && event.value.seat == 1 {
            verdicts += 1
            testing.expect(t, !event.value.applied && event.value.reason == .Predicate)
        }
    }
    testing.expect(t, hits == 1 && verdicts == 1 && hit_index >= 0)
    if hit_index < 0 {return}
    r.audit_capture_destroy(&audit)
    // A wrong expected event must fail despite identical Worlds and inputs.
    record.events[hit_index].value.value.amount += 1
    result := d.recording_verify(&record, identity, net.recording_model(&model), &audit)
    testing.expect_value(t, result.error, d.Recording_Error.Replay)
    testing.expect_value(t, result.replay.error, r.Error.Diverged_Event)
    testing.expect(t, result.replay.tick == 2 && reflect.equal(audit.expected.state, audit.actual.state))
}

@(test)
current_recordings_verify_and_detect_changed_event_payloads :: proc(t: ^testing.T) {
    check_recording(t, #load("fixtures/current/server.rplrec", []u8), base.model(), base.CONTENT)
    check_recording(t, #load("fixtures/current/owner.rplrec", []u8), owner.model(), owner.CONTENT)
}
