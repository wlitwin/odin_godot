package replay_authority_test

import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import auth "godot:replay/authority"
import tr "godot:replay/transport"
import view "godot:replay/view"

World :: struct {
    value: u32,
}

Control :: struct {
    axis: u8,
}

Action :: struct {
    add: u32,
}

Event :: struct {
    value: u32,
}

Server :: net.Server(World, Control, Action, Event, 2)

model :: proc() -> net.Model(World, Control, Action, Event, 2) {
    return {step = proc(w: ^World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
            w.value += u32(controls[0].axis)
        }, action = proc(w: ^World, seat: u16, a: Action, ctx: ^r.Step(Event)) -> bool {
            w.value += a.add
            r.emit(ctx, u64(seat), 1, Event{w.value})
            return true
        }, control_valid = proc(c: Control) -> bool {
            return c.axis <= 1
        }, action_valid = proc(a: Action) -> bool {
            return a.add > 0 && a.add <= 10
        }, state_valid = proc(w: World) -> bool {
            return w.value < 1000000
        }, hold = proc(c: Control) -> Control {
            return c
        }}
}

@(test)
expiry_during_a_step_rolls_back_before_confirmation_and_preserves_action_identity :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    clock: Clock
    lease: auth.Lease
    grant_lease(&lease, &c, &clock, A)
    s: Server
    defer net.server_destroy(&s)
    cfg := net.DEFAULT_CONFIG
    cfg.content = 55
    cfg.require_permit = true
    testing.expect_value(t, net.server_init(&s, r.Frame(World){}, model(), {}, cfg, local_seat = 1), net.Error.Fenced)
    testing.expect_value(
        t,
        net.server_init(&s, r.Frame(World){}, model(), {}, cfg, local_seat = 1, permit = auth.lease_permit(&lease)),
        net.Error.None,
    )
    net.server_set_local_token(&s, net.Token{0 = 12})
    net.server_local(&s, Control{1})
    sequence, _ := net.server_issue(&s, Action{3})
    clock.reads, clock.jump_on, clock.jump_to = 0, 2, 990
    testing.expect_value(t, net.server_step(&s), net.Error.Fenced)
    frame, _ := r.current(&s.timeline)
    testing.expect_value(t, frame.state.value, u32(0))
    testing.expect_value(t, frame.tick, u64(0))
    testing.expect_value(t, s.timeline.confirmed, u64(0))
    testing.expect_value(t, s.peers[0].action_received, sequence)
    testing.expect_value(t, s.peers[0].action_settled, u64(0))
    _, exists := r.read(&s.timeline, 1)
    testing.expect(t, !exists)
    // The conservative client deadline has passed, but the coordinator's old
    // lease has not. A timely correlated renewal can still resume the same epoch.
    clock.jump_on = 0
    request, _ := auth.lease_request(&lease)
    testing.expect_value(t, auth.coordinator_renew(&c, A, 1, request, 0, 995), auth.Error.None)
    view, _ := auth.coordinator_view(&c, 995)
    clock.now = 996
    testing.expect_value(t, auth.lease_accept(&lease, request, view), auth.Error.None)
    testing.expect_value(t, net.server_step(&s), net.Error.None)
    frame, _ = r.current(&s.timeline)
    testing.expect_value(t, frame.state.value, u32(4))
    testing.expect_value(t, s.peers[0].action_settled, sequence)

    for _ in 0 ..< cfg.history {
        testing.expect_value(t, net.server_step(&s), net.Error.None)
    }

    old_head := s.timeline.head
    oldest := old_head - u64(cfg.history - 1)
    clock.reads, clock.jump_on, clock.jump_to = 0, 2, 1990
    testing.expect_value(t, net.server_step(&s), net.Error.Fenced)
    _, retained := r.read(&s.timeline, oldest)
    testing.expect(t, retained) // rewinding AFTER commit would already have lost this slot
    testing.expect_value(t, s.timeline.head, old_head)
    clock.jump_on = 0
    cp: net.Checkpoint(World, Control, Action, 2)
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&s, &cp)
    resumed: Server
    defer net.server_destroy(&resumed)
    testing.expect(t, cp.settings.require_permit)
    testing.expect_value(
        t,
        net.server_restore(&resumed, &cp, model(), {}, {epoch = 2, local_seat = 1}),
        net.Error.Fenced,
    )
    clock.now = 3000
    testing.expect_value(t, net.server_pump(&s, 3000), net.Error.Fenced)
    testing.expect_value(t, net.server_step(&s), net.Error.Fenced)
    _, err := net.server_issue(&s, Action{3})
    testing.expect_value(t, err, net.Error.Fenced)
}

@(test)
client_prediction_and_action_flags_are_not_published_after_its_view_lease_expires :: proc(t: ^testing.T) {
    coordinator: auth.Coordinator
    ledger: Ledger
    setup(&coordinator, &ledger)
    clock: Clock
    lease: auth.Lease
    grant_lease(&lease, &coordinator, &clock, B, false)
    memory: tr.Memory
    tr.memory_init(&memory, cfg = {2, 256, 8192, 2048})
    defer tr.memory_destroy(&memory)
    a, b: tr.Memory_Endpoint
    tr.memory_open(&memory, &a, 1)
    tr.memory_open(&memory, &b, 2)
    wa, wb := tr.memory_transport(&a), tr.memory_transport(&b)
    defer tr.close(&wa)
    defer tr.close(&wb)
    s: Server
    defer net.server_destroy(&s)
    c: net.Client(World, Control, Action, Event, 2)
    defer net.client_destroy(&c)
    cfg := net.DEFAULT_CONFIG
    cfg.content, cfg.require_permit = 55, true
    net.server_init(
        &s,
        r.Frame(World){},
        model(),
        wa,
        cfg,
        local_seat = 1,
        permit = {allow = proc(user: rawptr, epoch: u64) -> bool {
                return epoch == 1
            }},
    )
    net.server_set_local_token(&s, net.Token{0 = 3})
    testing.expect_value(
        t,
        net.client_init(&c, model(), wb, net.Token{0 = 4}, cfg = cfg, permit = auth.lease_permit(&lease)),
        net.Error.None,
    )
    changes: [256]view.Change(net.Net_Event(Event))

    for tick in u64(0) ..< 30 {
        clock.now = tick * 1000 / 60
        tr.memory_advance(&memory, tick)
        net.server_pump(&s, clock.now)
        net.client_pump(&c, clock.now)
        net.server_step(&s)

        if c.phase == .Running {
            net.client_step(&c, Control{})
        }

        view.drain(&c.journal, changes[:])
    }

    testing.expect_value(t, c.phase, net.Phase.Running)
    net.client_issue(&c, Action{5})
    head := c.timeline.head
    clock.reads, clock.jump_on, clock.jump_to = 0, 2, 990
    testing.expect_value(t, net.client_step(&c, Control{}), net.Error.Fenced)
    testing.expect_value(t, c.timeline.head, head)
    testing.expect(t, !c.actions[0].predicted)
    testing.expect_value(t, view.drain(&c.journal, changes[:]), 0)
    testing.expect_value(t, net.client_pump(&c, 990), net.Error.Fenced)
}
