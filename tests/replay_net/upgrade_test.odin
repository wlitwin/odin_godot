package replay_net_test

import "core:reflect"
import "core:testing"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

// Protocol-6 contract formula retained as an independent fixture writer. The
// production converter must validate this, not just rewrite a version number.
legacy_contract :: proc(s: ^net.Server($S, $C, $A, $E, $N), protocol: u64 = 6) -> u64 {
    c := &s.codecs
    cfg := s.cfg
    values := [?]u64 {
        protocol,
        u64(N),
        u64(cfg.hz),
        u64(cfg.require_permit),
        u64(cfg.max_rewind),
        u64(cfg.max_view_span),
        u64(cfg.view_slack),
        u64(cfg.watch_delay),
        c.controls.fingerprint,
        c.action_value.fingerprint,
        c.event_value.fingerprint,
        c.state.fingerprint,
        c.inputs.fingerprint,
        c.action.fingerprint,
        c.welcome.fingerprint,
        c.snapshot.fingerprint,
        c.facts.fingerprint,
        c.snapshot_ack.fingerprint,
        c.fact_header.fingerprint,
        c.occurrence.fingerprint,
    }
    h := u64(0xcbf29ce484222325)

    for value in values {
        h = (h ~ value) * 0x100000001b3
    }

    if s.model.control_timing != .Scheduled {
        h = (h ~ (0x4f42535600000000 | u64(s.model.control_timing))) * 0x100000001b3
        h = (h ~ c.observation.fingerprint) * 0x100000001b3
    }

    return h
}

legacy_bytes :: proc(s: ^net.Server($S, $C, $A, $E, $N), current: []u8, header: net.Checkpoint_Header) -> []u8 {
    bytes := make([]u8, len(current))
    copy(bytes, current)
    meta, fingerprint, report := sc.inspect(bytes)
    assert(report.error == .None)
    h := header
    h.protocol = 6
    h.contract = legacy_contract(s)
    codec: sc.Schema
    assert(sc.init(&codec, net.Checkpoint_Header).error == .None)
    defer sc.destroy(&codec)
    assert(sc.encode(&codec, h, bytes[sc.HEADER_BYTES:sc.HEADER_BYTES + codec.wire_size]).error == .None)
    assert(sc.pack_bytes(fingerprint, meta, bytes[sc.HEADER_BYTES:], bytes).error == .None)
    return bytes
}

@(test)
protocol6_conversion_preserves_every_archive_section_and_source_bytes :: proc(t: ^testing.T) {
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
    old := legacy_bytes(&f.server, current, cp.header)
    defer delete(old)
    before := sc.digest(old)
    decoded: Checkpoint
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(
        t,
        net.checkpoint_decode(&decoded, old, model(), f.server.cfg.content),
        net.Error.Invalid_Checkpoint,
    )
    converted, result := net.checkpoint_upgrade_v6(old, model(), f.server.cfg.content)
    defer delete(converted)
    testing.expect_value(t, result, net.Error.None)
    testing.expect(t, reflect.equal(converted, current, true))
    testing.expect_value(t, sc.digest(old), before)
    testing.expect_value(t, net.checkpoint_decode(&decoded, converted, model(), f.server.cfg.content), net.Error.None)
    testing.expect(t, reflect.equal(decoded.frame, cp.frame))
    testing.expect(t, reflect.equal(decoded.peers[:], cp.peers[:], true))
}

@(test)
protocol6_conversion_rejects_wrong_contract_context_and_corruption :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 35 {
        fixture_step(&f)
    }

    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&f.server, &cp)
    current, _ := net.checkpoint_encode(&cp, model())
    defer delete(current)
    old := legacy_bytes(&f.server, current, cp.header)
    defer delete(old)

    for mode in 0 ..< 4 {
        bytes := make([]u8, len(old))
        copy(bytes, old)
        content := f.server.cfg.content

        if mode == 0 {
            content += 1
        }

        if mode == 1 {
            bytes[len(bytes) - 1] ~= 1
        }

        if mode == 2 {
            codec: sc.Schema
            sc.init(&codec, net.Checkpoint_Header)
            defer sc.destroy(&codec)
            h := cp.header
            h.protocol = 6
            h.contract = legacy_contract(&f.server) ~ 1
            meta, fp, _ := sc.inspect(bytes)
            sc.encode(&codec, h, bytes[sc.HEADER_BYTES:sc.HEADER_BYTES + codec.wire_size])
            sc.pack_bytes(fp, meta, bytes[sc.HEADER_BYTES:], bytes)
        }

        if mode == 3 {
            copy(bytes, current)
        } // upgrading a current archive is not a no-op

        before := sc.digest(bytes)
        out, err := net.checkpoint_upgrade_v6(bytes, model(), content)
        testing.expect(t, err != .None && len(out) == 0)
        testing.expect_value(t, sc.digest(bytes), before)
        delete(out)
        delete(bytes)
    }
}

@(test)
protocol6_observation_archive_requires_the_original_timing_contract :: proc(t: ^testing.T) {
    f: Observation_Fixture
    observation_setup(&f, .Latest_Observation, .Latest_Observation)
    defer observation_cleanup(&f)
    packet := observation_packet(&f, {1, 42})
    defer delete(packet)
    observation_deliver(&f, packet)
    cp: net.Checkpoint(Observed_World, Observation, u8, 2)
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
    current, err := net.checkpoint_encode(&cp, observation_model(.Latest_Observation))
    defer delete(current)
    testing.expect_value(t, err, net.Error.None)
    old := legacy_bytes(&f.server, current, cp.header)
    defer delete(old)
    converted, result := net.checkpoint_upgrade_v6(old, observation_model(.Latest_Observation), f.server.cfg.content)
    defer delete(converted)
    testing.expect_value(t, result, net.Error.None)
    testing.expect(t, reflect.equal(converted, current, true))
    wrong, rejected := net.checkpoint_upgrade_v6(old, observation_model(.Scheduled), f.server.cfg.content)
    defer delete(wrong)
    testing.expect(t, rejected != .None && len(wrong) == 0)
}

@(test)
protocol6_conversion_retains_authority_fencing :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 35 {
        fixture_step(&f)
    }

    cp: Checkpoint
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&f.server, &cp)
    // Construct the same layout with a coordinated authority requirement. No
    // permit or live lease is invented by this fixture or by the converter.
    f.server.cfg.require_permit = true
    cp.settings.require_permit = true
    cp.header.contract = legacy_contract(&f.server, net.PROTOCOL_VERSION)
    current, err := net.checkpoint_encode(&cp, model())
    defer delete(current)
    testing.expect_value(t, err, net.Error.None)
    old := legacy_bytes(&f.server, current, cp.header)
    defer delete(old)
    converted, result := net.checkpoint_upgrade_v6(old, model(), f.server.cfg.content)
    defer delete(converted)
    testing.expect_value(t, result, net.Error.None)
    testing.expect(t, reflect.equal(converted, current, true))
    decoded: Checkpoint
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_decode(&decoded, converted, model(), f.server.cfg.content), net.Error.None)
    testing.expect(t, decoded.settings.require_permit)
    testing.expect_value(t, decoded.header.epoch, cp.header.epoch)
    server: Server
    defer net.server_destroy(&server)
    testing.expect_value(
        t,
        net.server_restore(&server, &decoded, model(), {}, {epoch = cp.header.epoch + 1}),
        net.Error.Fenced,
    )
    testing.expect(t, !server.initialized)
}
