package replay_net_test

import "core:testing"
import r "godot:replay"
import d "godot:replay/diagnostic"
import net "godot:replay/net"

Recording :: d.Recording(World, net.Batch(Control, Action, 2), net.Net_Event(Event))
Capture :: r.Audit_Capture(World, net.Batch(Control, Action, 2), net.Net_Event(Event))
RECORDING_ID :: d.Recording_Context{0x54455354, 1, 60}

recording_no_admission :: proc(user: rawptr, seat: u16, action: Action) -> bool {
    counter := cast(^int)user
    counter^ += 1
    return false
}

@(test)
network_recording_replays_control_actions_and_decisions_after_transport_destruction :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    net.client_issue(&f.clients[0], Action{take = true})
    net.client_issue(&f.clients[1], Action{take = true})

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    admissions := 0
    f.server.model.action_admit = recording_no_admission
    f.server.model.action_admission_user = &admissions
    net.client_issue(&f.clients[0], Action{fail_after_mutation = true})

    for _ in 0 ..< 20 {
        fixture_step(&f)
    }

    testing.expect_value(t, admissions, 1)
    authority, prediction: Recording
    defer d.recording_destroy(&authority)
    defer d.recording_destroy(&prediction)
    testing.expect_value(
        t,
        d.recording_capture(&authority, &f.server.timeline, RECORDING_ID).error,
        d.Recording_Error.None,
    )
    testing.expect_value(
        t,
        d.recording_capture(&prediction, &f.clients[0].timeline, RECORDING_ID).error,
        d.Recording_Error.None,
    )
    verdicts, rejected := 0, 0

    for event in authority.events {
        if event.value.kind == .Action_Result {
            verdicts += 1

            if event.value.reason == .Invalid {
                rejected += 1
            }
        }
    }

    testing.expect_value(t, verdicts, 3)
    testing.expect_value(t, rejected, 1)
    m := f.server.model
    fixture_destroy(&f)
    sources := [2]^Recording{&authority, &prediction}

    for source in sources {
        bytes, error := d.recording_encode(source)
        defer delete(bytes)
        testing.expect_value(t, error, d.Recording_Error.None)
        restored: Recording
        defer d.recording_destroy(&restored)
        testing.expect_value(t, d.recording_decode(&restored, bytes, RECORDING_ID), d.Recording_Error.None)
        capture: Capture
        defer r.audit_capture_destroy(&capture)
        result := d.recording_verify(&restored, RECORDING_ID, net.recording_model(&m), &capture)
        testing.expect_value(t, result.error, d.Recording_Error.None)
        testing.expect(t, !capture.ready)
    }

    // The live policy now denies requests, but previously accepted requests still
    // replay. Previously denied requests stay denied without calling the policy.
    testing.expect_value(t, admissions, 1)
}

recording_count_step :: proc(w: ^World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
    counter := cast(^int)ctx.user
    counter^ += 1
    model_step(w, controls, joins, leaves, ctx)
}

@(test)
network_recording_validates_every_executable_input_before_simulation :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 8 {
        fixture_step(&f)
    }

    recording: Recording
    defer d.recording_destroy(&recording)
    d.recording_capture(&recording, &f.server.timeline, RECORDING_ID)
    m := model()
    calls := 0
    m.step = recording_count_step
    m.user = &calls
    baseline := recording.ticks[1].input

    for kind in 0 ..< 5 {
        input := baseline

        switch kind {
        case 0:
            input.controls[0].move = 2
        case 1:
            input.joins = u64(1) << 2
        case 2:
            input.prediction_group = 1
            input.prediction_seat = 1
        case 3:
            input.has_action[0] = true
            input.sequences[0] = 0
        case 4:
            input.has_action[0] = true
            input.sequences[0] = 1
            input.actions[0] = {}
            input.rejections[0] = .None
        }

        recording.ticks[1].input = input
        capture: Capture
        defer r.audit_capture_destroy(&capture)
        result := d.recording_verify(&recording, RECORDING_ID, net.recording_model(&m), &capture)
        testing.expect_value(t, result.error, d.Recording_Error.Model)
        testing.expect_value(t, result.replay.tick, recording.ticks[1].frame.tick)
        testing.expect_value(t, calls, 0)
        testing.expect(t, !capture.ready)
    }

    recording.ticks[1].input = baseline
    // A recorded rejection may contain a semantically invalid payload. It must
    // produce its original result instead of ever executing that payload.
    rejected := baseline
    rejected.has_action[0] = true
    rejected.sequences[0] = 1
    rejected.rejections[0] = .Invalid
    runner := net.recording_model(&m)
    testing.expect(t, runner.input_check(rejected, 2, runner.user))
    before := recording.base
    events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(Event))
    ctx := r.Step(net.Net_Event(Event)) {
        tick   = before.tick + 1,
        epoch  = recording.epoch,
        events = events[:],
        user   = runner.user,
    }
    runner.step(&before.state, rejected, &ctx)
    testing.expect_value(t, ctx.error, r.Error.None)
    testing.expect_value(t, ctx.count, 1)
    testing.expect_value(t, events[0].value.reason, net.Action_Reason.Invalid)
    testing.expect(t, !events[0].value.applied)
}
