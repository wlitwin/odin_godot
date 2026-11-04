package replay_scrapyard_test

import "core:testing"
import co "godot:replay/comms"
import flow "../../examples/replay_scrapyard/shared/flow"

@(test)
pings_reject_another_floor_or_run_without_losing_u32_scope_bits :: proc(t: ^testing.T) {
    w := yard()

    for run in ([5]u32{0, 1, 2, max(u32) - 1, max(u32)}) {
        w.run, w.floor = run, 255
        payload := flow.ping_payload(&w, {1920, 1088})
        testing.expect(t, co.valid(payload) && flow.ping_valid(&w, payload))
        w.floor = 254
        testing.expect(t, !flow.ping_valid(&w, payload))
        w.floor = 255
        w.run ~= 1
        testing.expect(t, !flow.ping_valid(&w, payload))
    }

    w.run, w.floor = 0, 1
    testing.expect(t, !flow.ping_valid(&w, flow.ping_payload(&w, {-1, 0})))
    testing.expect(t, !flow.ping_valid(&w, flow.ping_payload(&w, {0, 1089})))
    w.stage = .Staging
    testing.expect(t, !flow.ping_valid(&w, flow.ping_payload(&w, {100, 100})))
}
