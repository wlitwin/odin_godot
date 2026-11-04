package sample

import r "godot:replay"
import net "godot:replay/net"
import own "godot:replay/owned"

CONTENT :: u64(0x4f574e4544503231)

World :: struct {
    body:      own.State(own.Pose2),
    transfers: u32,
}

Control :: own.Sample(own.Pose2)

rules :: proc() -> own.Rules(own.Pose2) {
    return {valid = proc(user: rawptr, pose: own.Pose2) -> bool {
            return own.pose2_valid(pose, {{-10000, -10000}, {10000, 10000}, 1000, 100})
        }}
}

initial :: proc() -> World {
    w: World
    assert(
        own.init(
            &w.body,
            {1, 0, 1},
            1,
            0,
            1,
            own.Pose2{position = {100, 100}, linear = {80, 30}, angular = 5},
            rules(),
        ) ==
        .None,
    )
    return w
}

model :: proc() -> net.Model(World, Control, u8, u8, 2) {
    return {
        control_timing = .Latest_Observation,
        step = proc(w: ^World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(u8)) {
            if own.bind_epoch(&w.body, ctx.epoch, ctx.tick) != .None {
                r.abort(ctx)
                return
            }

            for control, i in controls {
                if control.sequence != 0 {
                    if own.accept(&w.body, u16(i + 1), control, ctx.tick, rules()).transferred {
                        w.transfers += 1
                    }
                }
            }

            if ctx.tick == 90 {
                assert(own.offer(&w.body, 2, ctx.tick, 120) == .None)
            }
        },
        control_valid = proc(c: Control) -> bool {
            return own.sample_valid(c, rules())
        },
        state_valid = proc(w: World) -> bool {
            return own.valid(w.body, rules())
        },
        hold = proc(c: Control) -> Control {
            return c
        },
    }
}
