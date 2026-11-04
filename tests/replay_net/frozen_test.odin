package replay_net_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"

@(test)
fenced_drain_rejects_admission_without_changing_the_world :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 20 {
        fixture_step(&f)
    }

    allowed := true
    f.server.cfg.require_permit = true
    f.server.permit = {
        user = &allowed,
        allow = proc(user: rawptr, epoch: u64) -> bool {
            return (cast(^bool)user)^
        },
    }
    testing.expect_value(t, net.server_drain_fenced(&f.server), net.Error.Wrong_Phase)
    before, _ := r.current(&f.server.timeline)
    before_actions := f.server.peers[0].action_received
    net.client_issue(&f.clients[0], Action{take = true})
    tr.memory_advance(&f.network, f.clock)
    allowed = false
    testing.expect_value(t, net.server_drain_fenced(&f.server), net.Error.None)
    testing.expect(t, f.server.stats.fenced_packets > 0)
    after, _ := r.current(&f.server.timeline)
    testing.expect(t, reflect.equal(before, after))
    testing.expect_value(t, f.server.peers[0].action_received, before_actions)
    testing.expect_value(t, net.server_step(&f.server), net.Error.Fenced)
}
