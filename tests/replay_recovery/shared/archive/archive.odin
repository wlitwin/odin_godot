package recovery_archive_fixture

import r "godot:replay"
import net "godot:replay/net"
import cave "godot:examples/replay_cavecrawl/shared/cave"

// A real cave world plus >64 KiB of authority-only data exercises chunking beyond
// the transport's single-packet limit without putting secrets in public snapshots.
World :: struct {
    cave:         cave.World,
    private_data: [18000]u32 `replay:"authority"`,
}

SEATS :: cave.SEATS
CONTENT :: u64(0x52504c5941524331)
Control :: cave.Control
Action :: cave.Action
Event :: cave.Event
Server :: net.Server(World, Control, Action, Event, SEATS)
Checkpoint :: net.Checkpoint(World, Control, Action, SEATS)

model :: proc() -> net.Model(World, Control, Action, Event, SEATS) {
    return {
        step = step,
        action = action,
        reset_player = reset_player,
        control_valid = cave.control_valid,
        action_valid = cave.action_valid,
        hold = cave.hold,
        state_valid = valid,
    }
}

step :: proc(w: ^World, controls: [SEATS]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
    cave.step(&w.cave, controls, joins, leaves, ctx)
}

action :: proc(w: ^World, seat: u16, a: Action, ctx: ^r.Step(Event)) -> bool {
    return cave.act(&w.cave, seat, a, ctx)
}

reset_player :: proc(w: ^World, seat: u16, ctx: ^r.Step(Event)) {
    cave.reset_player(&w.cave, seat, ctx)
}

valid :: proc(w: World) -> bool {
    return cave.state_valid(w.cave) && w.private_data[0] == 19 && w.private_data[17999] == 17999 * 17 + 19
}

authority :: proc(s: ^Server, permit: net.Permit = {}) -> net.Error {
    w := World {
        cave = cave.initial(),
    }

    for &value, i in w.private_data {
        value = u32(i) * 17 + 19
    }

    cfg := net.DEFAULT_CONFIG
    cfg.content, cfg.hz, cfg.lead = CONTENT, cave.HZ, 4
    cfg.history, cfg.max_future, cfg.max_prediction, cfg.snapshot_history = 32, 16, 24, 2
    cfg.require_permit = permit.allow != nil

    if err := net.server_init(s, r.Frame(World){state = w}, model(), {}, cfg, local_seat = 1, permit = permit);
       err != .None {
        return err
    }

    net.server_set_local_token(s, net.Token{0 = 11})
    net.server_step(s)
    net.server_local(s, Control{move = {1, 0}})

    for _ in 0 ..< 36 {
        if err := net.server_step(s); err != .None {
            return err
        }
    }

    net.server_local(s, Control{move = {0, 1}})

    for _ in 0 ..< 10 {
        if err := net.server_step(s); err != .None {
            return err
        }
    }

    net.server_local(s, Control{})
    net.server_issue(s, Action{verb = .Take, index = 0})
    net.server_step(s)
    net.server_issue(s, Action{verb = .Throw, aim = {1, 0}})
    return net.server_step(s)
}
