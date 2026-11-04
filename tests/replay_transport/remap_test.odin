package replay_transport_test

import "core:testing"
import tr "godot:replay/transport"

@(test)
logical_identity_survives_transport_ids_and_unknown_senders_remain_unadmitted :: proc(t: ^testing.T) {
    network: tr.Memory
    tr.memory_init(&network, cfg = {3, 16, 8, 128})
    defer tr.memory_destroy(&network)
    endpoints: [3]tr.Memory_Endpoint
    wires: [3]tr.Transport

    for &endpoint, i in endpoints {
        testing.expect(t, tr.memory_open(&network, &endpoint, tr.Peer_Id(1 + i)))
        wires[i] = tr.memory_transport(&endpoint)
    }

    defer for &wire in wires {
        tr.close(&wire)
    }

    mappings := [2]tr.Peer_Mapping{{10, 1}, {20, 2}}
    remaps: [2]tr.Remap

    for &remap, i in remaps {
        testing.expect(t, tr.remap_init(&remap, wires[i], mappings[:]))
    }

    a, b := tr.remap_transport(&remaps[0]), tr.remap_transport(&remaps[1])
    bytes := [2]u8{7, 9}
    out: [8]u8
    testing.expect_value(t, tr.send(&a, 20, .Reliable, bytes[:]), tr.Send_Result.Sent)
    testing.expect_value(t, tr.send(&a, 2, .Reliable, bytes[:]), tr.Send_Result.Invalid)
    tr.memory_advance(&network, 0)
    packet := tr.receive(&b, out[:])
    testing.expect_value(t, packet.state, tr.Receive_State.Received)
    testing.expect_value(t, packet.from, tr.Peer_Id(10))
    testing.expect_value(t, out[0], bytes[0])
    testing.expect(t, tr.peer_connected(&b, 10) && !tr.peer_connected(&b, 1))
    tr.send(&wires[2], 2, .Reliable, bytes[:])
    tr.memory_advance(&network, 1)
    packet = tr.receive(&b, out[:])
    testing.expect_value(t, packet.state, tr.Receive_State.Received)
    testing.expect_value(t, packet.from, tr.Peer_Id(0))
    testing.expect_value(t, tr.receive(&b, out[:]).state, tr.Receive_State.Empty)
    tr.close(&a)
    testing.expect(t, !tr.peer_connected(&b, 10))
}

@(test)
identity_bindings_reject_collisions_without_partial_installation :: proc(t: ^testing.T) {
    m: tr.Remap
    cases := [3][2]tr.Peer_Mapping{{{1, 10}, {1, 11}}, {{1, 10}, {2, 10}}, {{1, 10}, {0, 11}}}

    for invalid in cases {
        bindings := invalid
        testing.expect(t, !tr.remap_init(&m, {}, bindings[:]))
        testing.expect(t, !m.ready && m.count == 0)
    }
}
