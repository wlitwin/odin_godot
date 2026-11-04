package cave_impact_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import d "godot:replay/diagnostic"
import base "../../examples/replay_cavecrawl/shared/cave"
import owner "../../examples/replay_cavecrawl/shared/owner_cave"
import upgrade "../../examples/replay_cavecrawl/shared/upgrade"
import owned_upgrade "../../examples/replay_cavecrawl/shared/owner_upgrade"

check_checkpoint :: proc(
    t: ^testing.T,
    bytes: []u8,
    old: net.Model($W, $C, $A, base.Event, base.SEATS),
    current: net.Model(W, C, A, base.Event, base.SEATS),
    old_content, new_content: u64,
    convert: proc(_: []u8) -> ([]u8, net.Error),
) {
    before, after: net.Checkpoint(W, C, A, base.SEATS)
    defer net.checkpoint_destroy(&before)
    defer net.checkpoint_destroy(&after)
    testing.expect_value(t, net.checkpoint_decode(&before, bytes, old, old_content), net.Error.None)
    wrong: net.Checkpoint(W, C, A, base.SEATS)
    defer net.checkpoint_destroy(&wrong)
    testing.expect(t, net.checkpoint_decode(&wrong, bytes, current, new_content) != .None)
    mapped, error := convert(bytes)
    defer delete(mapped)
    testing.expect_value(t, error, net.Error.None)
    testing.expect_value(t, net.checkpoint_decode(&after, mapped, current, new_content), net.Error.None)
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
    expected_header := before.header
    expected_header.content, expected_header.contract = after.header.content, after.header.contract
    testing.expect(t, reflect.equal(expected_header, after.header))
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
    found := 0

    for event in events[:count] {
        if event.value.kind == .Gameplay && event.value.value.kind == .Hit && event.value.value.seat == 0 {
            found += 1
            testing.expect_value(t, event.id.key, u64(1) << 32 | 1)
        }
    }

    testing.expect_value(t, found, 1)
}

@(test)
c8_and_o2_checkpoints_preserve_exact_state_and_pending_actions_before_new_impacts :: proc(t: ^testing.T) {
    check_checkpoint(
        t,
        transmute([]u8)#load("fixtures/c8.checkpoint"),
        upgrade.model8(),
        base.model(),
        upgrade.CONTENT_8,
        base.CONTENT,
        upgrade.convert_archive,
    )
    check_checkpoint(
        t,
        transmute([]u8)#load("fixtures/o2.checkpoint"),
        owned_upgrade.model_2(),
        owner.model(),
        owned_upgrade.CONTENT_2,
        owner.CONTENT,
        owned_upgrade.convert_archive,
    )
}

check_recording :: proc(
    t: ^testing.T,
    bytes: []u8,
    old: net.Model($W, $C, $A, base.Event, base.SEATS),
    current: net.Model(W, C, A, base.Event, base.SEATS),
    content: u64,
) {
    record: d.Recording(W, net.Batch(C, A, base.SEATS), net.Net_Event(base.Event))
    defer d.recording_destroy(&record)
    identity := d.Recording_Context{content, 1, base.HZ}
    testing.expect_value(t, d.recording_decode(&record, bytes, identity), d.Recording_Error.None)
    historical, modern := old, current
    audit: r.Audit_Capture(W, net.Batch(C, A, base.SEATS), net.Net_Event(base.Event))
    defer r.audit_capture_destroy(&audit)
    testing.expect_value(
        t,
        d.recording_verify(&record, identity, net.recording_model(&historical), &audit).error,
        d.Recording_Error.None,
    )
    // Deliberately bypass the normal content check: even then, the event comparison
    // must detect that today's model cannot reproduce this historical recording.
    result := d.recording_verify(&record, identity, net.recording_model(&modern), &audit)
    testing.expect_value(t, result.error, d.Recording_Error.Replay)
    testing.expect_value(t, result.replay.error, r.Error.Diverged_Event)
}

@(test)
historical_c8_and_o2_recordings_require_their_explicit_event_rules :: proc(t: ^testing.T) {
    check_recording(t, transmute([]u8)#load("fixtures/c8.rplrec"), upgrade.model8(), base.model(), upgrade.CONTENT_8)
    check_recording(
        t,
        transmute([]u8)#load("fixtures/o2.rplrec"),
        owned_upgrade.model_2(),
        owner.model(),
        owned_upgrade.CONTENT_2,
    )
}
