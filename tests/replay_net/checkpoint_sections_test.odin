package replay_net_test

import "core:reflect"
import "core:testing"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

@(test)
current_checkpoint_preserves_every_archive_section_and_source_bytes :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    net.client_issue(&f.clients[0], Action{take = true})

    for _ in 0 ..< 30 {
        fixture_step(&f)
    }

    net.server_set_locked(&f.server, true)
    net.client_issue(&f.clients[0], Action{take = true})
    tr.memory_advance(&f.network, f.clock)
    net.server_pump(&f.server, f.clock * 1000 / 60)
    net.server_ban(&f.server, net.Token{0 = 99})
    net.server_set_admission(&f.server, nil, proc(_: rawptr, _: [32]u8, _: bool) -> bool {
        return true
    })
    policy := [4]u8{4, 3, 2, 1}
    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_capture(&f.server, &cp, 123, policy[:]), net.Error.None)
    testing.expect(
        t,
        len(cp.actions) > 0 &&
        len(cp.inputs) > 0 &&
        len(cp.outcomes) > 0 &&
        len(cp.banned) > 0 &&
        len(cp.policy_data) > 0,
    )
    current, err := net.checkpoint_encode(&cp, model())
    defer delete(current)
    testing.expect_value(t, err, net.Error.None)
    before := sc.digest(current)
    restored: Checkpoint
    defer net.checkpoint_destroy(&restored)
    testing.expect_value(t, net.checkpoint_decode(&restored, current, model(), f.server.cfg.content), net.Error.None)
    testing.expect_value(t, sc.digest(current), before)
    testing.expect(t, reflect.equal(cp.header, restored.header) && reflect.equal(cp.settings, restored.settings))
    testing.expect(
        t,
        reflect.equal(cp.frame, restored.frame) && cp.held == restored.held && cp.held_views == restored.held_views,
    )
    testing.expect(t, reflect.equal(cp.peers[:], restored.peers[:], true))
    testing.expect(t, reflect.equal(cp.actions[:], restored.actions[:], true))
    testing.expect(t, reflect.equal(cp.inputs[:], restored.inputs[:], true))
    testing.expect(t, reflect.equal(cp.outcomes[:], restored.outcomes[:], true))
    testing.expect(t, reflect.equal(cp.banned[:], restored.banned[:], true))
    testing.expect(t, reflect.equal(cp.policy_data, restored.policy_data, true))
    // Unsupported protocol numbers are rejected even with a valid checksum.
    codec: sc.Schema
    defer sc.destroy(&codec)
    testing.expect_value(t, sc.init(&codec, net.Checkpoint_Header).error, sc.Error.None)
    meta, fingerprint, inspection := sc.inspect(current)
    testing.expect_value(t, inspection.error, sc.Error.None)
    for protocol in ([3]u64{0, 6, net.PROTOCOL_VERSION + 1}) {
        bytes := make([]u8, len(current), context.temp_allocator)
        copy(bytes, current)
        header := cp.header
        header.protocol = protocol
        testing.expect_value(
            t,
            sc.encode(&codec, header, bytes[sc.HEADER_BYTES:sc.HEADER_BYTES + codec.wire_size]).error,
            sc.Error.None,
        )
        testing.expect_value(t, sc.pack_bytes(fingerprint, meta, bytes[sc.HEADER_BYTES:], bytes).error, sc.Error.None)
        refused: Checkpoint
        testing.expect_value(
            t,
            net.checkpoint_decode(&refused, bytes, model(), f.server.cfg.content),
            net.Error.Invalid_Checkpoint,
        )
        testing.expect(t, !refused.ready && len(refused.peers) == 0 && len(refused.actions) == 0)
        net.checkpoint_destroy(&refused)
    }
}
