package replay_net_test

import "core:testing"
import net "godot:replay/net"
import tr "godot:replay/transport"
import r "godot:replay"

mixed_schedule :: proc() -> net.Action_Schedule(Action) {
    return {id = 0x4d4958454431, timing = proc(a: Action) -> net.Action_Timing {
            return a.take ? .Receipt : .Scheduled
        }}
}

@(test)
mixed_actions_keep_receipt_delivery_and_scheduled_deadlines_in_one_queue :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_schedule = mixed_schedule())
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    tr.memory_set_faults(&f.network, {latency_ticks = 20, retry_ticks = 3})
    first, e1 := net.client_issue(&f.clients[0], Action{fail_after_mutation = true})
    second, e2 := net.client_issue(&f.clients[0], Action{take = true})
    testing.expect(t, e1 == .None && e2 == .None && second == first + 1)

    for _ in 0 ..< 160 {
        fixture_step(&f)
    }

    result: [8]net.Action_Outcome
    n := net.client_outcomes(&f.clients[0], result[:])
    testing.expect_value(t, n, 2)

    if n == 2 {
        testing.expect(
            t,
            result[0].sequence == first &&
            !result[0].applied &&
            result[0].reason == .Stale &&
            result[1].sequence == second &&
            result[1].applied &&
            result[0].tick < result[1].tick,
        )
    }

    testing.expect_value(t, net.client_outcomes(&f.clients[0], result[:]), 0)
    frame, _ := r.current(&f.server.timeline)
    testing.expect(t, frame.state.chest == 0 && frame.state.players[0].bag == 5 && frame.state.players[0].x == 0)
    testing.expect(t, f.server.stats.duplicate_actions > 0)
}

@(test)
mixed_resync_queue_only_accepts_receipt_payloads :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_schedule = mixed_schedule())
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    c := &f.clients[0]
    begin_test_resync(c)
    sent := c.stats.tx_packets
    _, scheduled := net.client_issue(c, Action{fail_after_mutation = true})
    testing.expect_value(t, scheduled, net.Error.Wrong_Phase)
    sequence, receipt := net.client_issue(c, Action{take = true})
    testing.expect_value(t, receipt, net.Error.None)
    testing.expect(
        t,
        c.action_count == 1 && c.stats.tx_packets == sent && !c.actions[0].predicted && !c.actions[0].sent,
    )

    for _ in 0 ..< 150 {
        fixture_step(&f)
    }

    result: [8]net.Action_Outcome
    n := net.client_outcomes(c, result[:])
    testing.expect_value(t, n, 1)

    if n == 1 {
        testing.expect(t, result[0].sequence == sequence && result[0].applied)
    }
}

@(test)
future_scheduled_action_keeps_fifo_order_ahead_of_a_receipt_action :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_schedule = mixed_schedule())
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    c := &f.clients[0]
    testing.expect(t, c.timeline.head > f.server.timeline.head + 4)
    first, e1 := net.client_issue(c, Action{fail_after_mutation = true})
    second, e2 := net.client_issue(c, Action{take = true})
    testing.expect(t, e1 == .None && e2 == .None)

    for _ in 0 ..< 4 {
        fixture_step(&f)
    }

    before, _ := r.current(&f.server.timeline)
    testing.expect_value(t, before.state.chest, u32(5))

    for _ in 0 ..< 80 {
        fixture_step(&f)
    }

    result: [8]net.Action_Outcome
    n := net.client_outcomes(c, result[:])
    testing.expect_value(t, n, 2)

    if n == 2 {
        testing.expect(
            t,
            result[0].sequence == first &&
            result[0].reason == .Predicate &&
            result[1].sequence == second &&
            result[1].applied &&
            result[1].tick == result[0].tick + 1,
        )
    }

    after, _ := r.current(&f.server.timeline)
    testing.expect(t, after.state.players[0].x == 0 && after.state.players[0].bag == 5)
}

@(test)
action_schedule_requires_versioned_callback_and_contract_match :: proc(t: ^testing.T) {
    m := model()
    m.action_schedule = mixed_schedule()
    m.action_schedule.id = 0
    c: Client
    testing.expect_value(t, net.client_init(&c, m, {}, net.Token{0 = 1}), net.Error.Invalid_Model)
    m.action_schedule = {
        id = 1,
    }
    s: Server
    testing.expect_value(t, net.server_init(&s, r.Frame(World){state = {chest = 5}}, m, {}), net.Error.Invalid_Model)
    f: Fixture
    fixture_init(&f, action_schedule = mixed_schedule())
    defer fixture_destroy(&f)
    net.client_destroy(&f.clients[0])
    m = model()
    m.action_schedule = mixed_schedule()
    m.action_schedule.id += 1
    testing.expect_value(
        t,
        net.client_init(&f.clients[0], m, tr.memory_transport(&f.endpoints[1]), net.Token{0 = 1}, cfg = f.server.cfg),
        net.Error.None,
    )

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    testing.expect(t, f.clients[0].phase == .Rejected && f.clients[0].rejection == .Contract)
}

@(test)
invalid_action_schedule_result_is_rejected_without_admission :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_schedule = mixed_schedule())
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    c := &f.clients[0]
    c.model.action_schedule.timing = proc(a: Action) -> net.Action_Timing {
        return net.Action_Timing(255)
    }
    _, error := net.client_issue(c, Action{take = true})
    testing.expect_value(t, error, net.Error.Invalid_Input)
    testing.expect_value(t, c.next_action, u64(0))
    c.model.action_schedule = mixed_schedule()
    // A valid sender cannot make the authority accept an invalid policy result.
    f.server.model.action_schedule.timing = proc(a: Action) -> net.Action_Timing {
        return net.Action_Timing(255)
    }
    f.server.model.action_admit = proc(_: rawptr, _: u16, _: Action) -> bool {
        panic("invalid policy must not reach admission")
    }
    _, issued := net.client_issue(c, Action{take = true})
    testing.expect_value(t, issued, net.Error.None)

    for _ in 0 ..< 80 {
        fixture_step(&f)
    }

    result: [8]net.Action_Outcome
    n := net.client_outcomes(c, result[:])
    testing.expect_value(t, n, 1)

    if n == 1 {
        testing.expect(t, !result[0].applied && result[0].reason == .Invalid)
    }
}

@(test)
mixed_schedule_checkpoint_keeps_admitted_ticks_without_reclassification :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_schedule = mixed_schedule())
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    _, error := net.client_issue(&f.clients[0], Action{take = true})
    testing.expect_value(t, error, net.Error.None)
    tr.memory_advance(&f.network, f.clock)
    testing.expect_value(t, net.server_pump(&f.server, f.clock * 1000 / 60), net.Error.None)
    cp, decoded: Checkpoint
    defer net.checkpoint_destroy(&cp)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
    testing.expect_value(t, len(cp.actions), 1)
    m := model()
    m.action_schedule = mixed_schedule()
    bytes, encoded := net.checkpoint_encode(&cp, m)
    defer delete(bytes)
    testing.expect_value(t, encoded, net.Error.None)
    testing.expect_value(
        t,
        net.checkpoint_decode(&decoded, bytes, model(), f.server.cfg.content),
        net.Error.Checkpoint_Contract,
    )
    // Recorded admission is authoritative; restore/replay must not invoke policy.
    m.action_schedule.timing = proc(_: Action) -> net.Action_Timing {
        panic("already admitted action was reclassified")
    }
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, m, f.server.cfg.content), net.Error.None)
    resumed: Server
    defer net.server_destroy(&resumed)
    testing.expect_value(
        t,
        net.server_restore(
            &resumed,
            &decoded,
            m,
            {},
            {epoch = 2, local_seat = 1, preserve_pending = true, retain_membership = true},
        ),
        net.Error.None,
    )
    testing.expect_value(t, net.server_step(&resumed), net.Error.None)
    frame, _ := r.current(&resumed.timeline)
    testing.expect(t, frame.state.players[0].bag == 5 && frame.state.chest == 0)
}

@(test)
explicit_checkpoint_conversions_stamp_target_schedule_and_preserve_pending_ticks :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_schedule = mixed_schedule())
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    _, issued := net.client_issue(&f.clients[0], Action{take = true})
    testing.expect_value(t, issued, net.Error.None)
    tr.memory_advance(&f.network, f.clock)
    testing.expect_value(t, net.server_pump(&f.server, f.clock * 1000 / 60), net.Error.None)
    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
    source := model()
    source.action_schedule = mixed_schedule()
    bytes, error := net.checkpoint_encode(&cp, source)
    defer delete(bytes)
    testing.expect_value(t, error, net.Error.None)
    target := source
    target.action_schedule.id += 1
    target.action_schedule.timing = proc(_: Action) -> net.Action_Timing {
        panic("conversion must preserve existing admission")
    }

    for kind in 0 ..< 3 {
        converted: []u8
        conversion: net.Error

        switch kind {
        case 0:
            converted, conversion = net.checkpoint_convert_actions(
                bytes,
                source,
                f.server.cfg.content,
                target,
                f.server.cfg.content + 1,
                proc(a: Action) -> (Action, bool) {
                    return a, true
                },
            )
        case 1:
            converted, conversion = net.checkpoint_convert_state(
                bytes,
                source,
                f.server.cfg.content,
                target,
                f.server.cfg.content + 1,
                proc(w: World) -> (World, bool) {
                    return w, true
                },
            )
        case 2:
            converted, conversion = net.checkpoint_convert(
                bytes,
                source,
                f.server.cfg.content,
                target,
                f.server.cfg.content + 1,
                proc(w: World) -> (World, bool) {
                    return w, true
                },
                proc(a: Action) -> (Action, bool) {
                    return a, true
                },
            )
        }

        defer delete(converted)
        testing.expect_value(t, conversion, net.Error.None)
        decoded: Checkpoint
        defer net.checkpoint_destroy(&decoded)
        testing.expect_value(
            t,
            net.checkpoint_decode(&decoded, converted, source, f.server.cfg.content + 1),
            net.Error.Checkpoint_Contract,
        )
        testing.expect_value(
            t,
            net.checkpoint_decode(&decoded, converted, target, f.server.cfg.content + 1),
            net.Error.None,
        )
        testing.expect(
            t,
            len(decoded.actions) == 1 &&
            decoded.actions[0].tick == cp.actions[0].tick &&
            decoded.actions[0].sequence == cp.actions[0].sequence,
        )
    }

    invalid := target
    invalid.action_schedule.timing = nil
    testing.expect(t, !net.checkpoint_valid(&cp, invalid))
}
