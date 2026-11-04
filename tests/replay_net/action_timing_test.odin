package replay_net_test
import "core:testing"
import net "godot:replay/net"
import tr "godot:replay/transport"
import r "godot:replay"

@(test)
receipt_actions_survive_late_delivery_and_preserve_order_dedup_and_atomicity :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_timing = .Receipt)
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    // Arrival occurs after both requested prediction ticks. Reliable retransmission
    // also resends still-pending requests; authority applies each sequence once.
    tr.memory_set_faults(&f.network, {latency_ticks = 20, retry_ticks = 3})
    first, e1 := net.client_issue(&f.clients[0], Action{take = true})
    second, e2 := net.client_issue(&f.clients[0], Action{fail_after_mutation = true})
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
            result[0].applied &&
            result[1].sequence == second &&
            !result[1].applied &&
            result[1].reason == .Predicate &&
            result[0].tick < result[1].tick,
        )
    }

    testing.expect_value(t, net.client_outcomes(&f.clients[0], result[:]), 0)
    frame, _ := r.current(&f.server.timeline)
    testing.expect(t, frame.state.chest == 0 && frame.state.players[0].bag == 5 && frame.state.players[0].x == 0)
    testing.expect(t, f.server.stats.duplicate_actions > 0)
}

@(test)
receipt_policy_still_requires_authority_admission :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_timing = .Receipt)
    defer fixture_destroy(&f)
    f.server.model.action_admit = proc(user: rawptr, seat: u16, action: Action) -> bool {
        return false
    }

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    tr.memory_set_faults(&f.network, {latency_ticks = 20, retry_ticks = 3})
    _, error := net.client_issue(&f.clients[0], Action{take = true})
    testing.expect_value(t, error, net.Error.None)

    for _ in 0 ..< 140 {
        fixture_step(&f)
    }

    result: [8]net.Action_Outcome
    n := net.client_outcomes(&f.clients[0], result[:])
    testing.expect_value(t, n, 1)

    if n == 1 {
        testing.expect(t, !result[0].applied && result[0].reason == .Invalid)
    }

    frame, _ := r.current(&f.server.timeline)
    testing.expect(t, frame.state.chest == 5 && frame.state.players[0].bag == 0)
}

@(test)
action_timing_policy_is_a_distinct_negotiated_contract :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_timing = .Receipt)
    defer fixture_destroy(&f)
    net.client_destroy(&f.clients[0])
    testing.expect_value(
        t,
        net.client_init(
            &f.clients[0],
            model(),
            tr.memory_transport(&f.endpoints[1]),
            net.Token{0 = 1},
            cfg = f.server.cfg,
        ),
        net.Error.None,
    )

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    testing.expect_value(t, f.clients[0].phase, net.Phase.Rejected)
    testing.expect_value(t, f.clients[0].rejection, net.Reject.Contract)
}

@(test)
scheduled_actions_keep_their_late_rejection_policy :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    tr.memory_set_faults(&f.network, {latency_ticks = 20, retry_ticks = 3})
    _, error := net.client_issue(&f.clients[0], Action{take = true})
    testing.expect_value(t, error, net.Error.None)

    for _ in 0 ..< 140 {
        fixture_step(&f)
    }

    result: [8]net.Action_Outcome
    n := net.client_outcomes(&f.clients[0], result[:])
    testing.expect_value(t, n, 1)

    if n == 1 {
        testing.expect(t, !result[0].applied && result[0].reason == .Stale)
    }

    frame, _ := r.current(&f.server.timeline)
    testing.expect(t, frame.state.chest == 5 && frame.state.players[0].bag == 0)
}

@(test)
receipt_checkpoint_requires_matching_policy_and_preserves_pending_action :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_timing = .Receipt)
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
    m.action_timing = .Receipt
    bytes, encoded := net.checkpoint_encode(&cp, m)
    defer delete(bytes)
    testing.expect_value(t, encoded, net.Error.None)
    testing.expect_value(
        t,
        net.checkpoint_decode(&decoded, bytes, model(), f.server.cfg.content),
        net.Error.Checkpoint_Contract,
    )
    testing.expect(t, !decoded.ready)
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
