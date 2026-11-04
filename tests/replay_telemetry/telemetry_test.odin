package replay_telemetry_test

import "core:testing"
import dg "godot:replay/telemetry"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

Fixture :: struct {
    memory:       tr.Memory,
    endpoints:    [3]tr.Memory_Endpoint,
    host, client: dg.Diagnostics,
    now:          u64,
}

HOST :: dg.Binding {
    peer       = 1,
    generation = 11,
    seat       = 1,
}
GUEST :: dg.Binding {
    peer       = 2,
    generation = 22,
    seat       = 2,
}
AUTHORITY :: dg.Binding {
    peer       = 1,
    generation = 22,
}
SCOPE :: dg.Scope{7, 1, 19}

open :: proc(f: ^Fixture) {
    assert(tr.memory_init(&f.memory, 33, {3, 256, 512, 16384}, {latency_ticks = 20, retry_ticks = 1}))

    for &ep, i in f.endpoints {
        assert(tr.memory_open(&f.memory, &ep, tr.Peer_Id(i + 1)))
    }

    assert(dg.init(&f.host))
    assert(dg.init(&f.client))
}

close :: proc(f: ^Fixture) {
    dg.destroy(&f.host)
    dg.destroy(&f.client)

    for &ep in f.endpoints {
        wire := tr.memory_transport(&ep)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

pump :: proc(f: ^Fixture, until: u64, scope := SCOPE, enabled := true, generation := u64(22)) {
    for f.now < until {
        f.now += 10
        assert(tr.memory_advance(&f.memory, f.now))
        guest, authority := GUEST, AUTHORITY
        guest.generation, authority.generation = generation, generation
        assert(
            dg.configure(
                &f.host,
                tr.memory_transport(&f.endpoints[0]),
                scope,
                true,
                HOST,
                []dg.Binding{guest},
                enabled,
                f.now,
            ),
        )
        assert(
            dg.configure(
                &f.client,
                tr.memory_transport(&f.endpoints[1]),
                scope,
                false,
                guest,
                []dg.Binding{authority},
                enabled,
                f.now,
            ),
        )
        dg.frame(&f.host)
        dg.frame(&f.client)
    }
}

inject :: proc(
    f: ^Fixture,
    from: int,
    to: tr.Peer_Id,
    packet: dg.Packet,
    epoch := u64(1),
    channel := tr.Channel.Unreliable,
) {
    bytes: [512]u8
    assert(
        sc.pack(&f.host.codec, packet, {kind = dg.PACKET_KIND, epoch = epoch, content = 19}, bytes[:]).error == .None,
    )
    wire := tr.memory_transport(&f.endpoints[from - 1])
    assert(tr.send(&wire, to, channel, bytes[:f.host.codec.wire_size + sc.HEADER_BYTES]) == .Sent)
}

@(test)
round_trip_is_measured_on_authority_clock_and_relayed_to_client :: proc(t: ^testing.T) {
    f: Fixture
    open(&f)
    defer close(&f)
    pump(&f, 1300)

    for d in ([]^dg.Diagnostics{&f.host, &f.client}) {
        local, remote := dg.read(d, 1), dg.read(d, 2)
        testing.expect(t, local.present && local.known && local.round_trip_ms == 0)
        testing.expect(t, remote.present && remote.known && remote.round_trip_ms == 40)
        testing.expect(t, !dg.read(d, 3).present)
    }

    testing.expect_value(t, f.host.rejected, u64(0))
    testing.expect_value(t, f.client.rejected, u64(0))
}

@(test)
loss_expires_samples_and_resume_refreshes_them :: proc(t: ^testing.T) {
    f: Fixture
    open(&f)
    defer close(&f)
    pump(&f, 1300)
    tr.memory_set_faults(&f.memory, {loss_permyriad = 10000, retry_ticks = 1})
    pump(&f, 8000)
    testing.expect(t, !dg.read(&f.host, 2).known && !dg.read(&f.client, 2).known)
    tr.memory_set_faults(&f.memory, {latency_ticks = 30, retry_ticks = 1})
    pump(&f, 14100) // outstanding lost probe expires, then the next report arrives
    testing.expect_value(t, dg.read(&f.host, 2).round_trip_ms, u32(60))
    testing.expect_value(t, dg.read(&f.client, 2).round_trip_ms, u32(60))
}

@(test)
migration_fencing_and_generation_rebind_clear_old_values :: proc(t: ^testing.T) {
    f: Fixture
    open(&f)
    defer close(&f)
    pump(&f, 1300)
    pump(&f, 1310, enabled = false)
    testing.expect(t, !dg.read(&f.host, 2).known && !dg.read(&f.client, 1).known)
    pump(&f, 1320, scope = {7, 2, 19}, generation = 23)
    testing.expect(t, !dg.read(&f.host, 2).known && !dg.read(&f.client, 2).known)
    inject(&f, 1, 2, {version = 1, room = 7, binding = 22, sequence = 999, kind = .Report})
    pump(&f, 1400, scope = {7, 2, 19}, generation = 23)
    testing.expect(t, f.client.rejected > 0)
    pump(&f, 2600, scope = {7, 2, 19}, generation = 23)
    testing.expect(t, dg.read(&f.host, 2).known && dg.read(&f.client, 2).known)
}

@(test)
forged_reports_wrong_peer_channel_duplicate_and_unsolicited_echo_are_rejected :: proc(t: ^testing.T) {
    f: Fixture
    open(&f)
    defer close(&f)
    pump(&f, 1300)
    packet := dg.Packet {
        version  = 1,
        room     = 7,
        binding  = 22,
        sequence = 999,
        kind     = .Report,
    }
    inject(&f, 3, 2, packet)
    inject(&f, 2, 1, packet)
    inject(&f, 1, 2, packet, channel = .Reliable)
    packet.kind = .Echo
    inject(&f, 2, 1, packet)
    packet.kind, packet.sequence = .Report, f.client.report_seen
    inject(&f, 1, 2, packet)
    pump(&f, 1400)
    testing.expect_value(t, f.host.rejected, u64(2))
    testing.expect_value(t, f.client.rejected, u64(3))
    testing.expect_value(t, dg.read(&f.client, 2).round_trip_ms, u32(40))
}

@(test)
invalid_config_is_transactional_and_disconnected_rows_disappear :: proc(t: ^testing.T) {
    f: Fixture
    open(&f)
    defer close(&f)
    pump(&f, 1300)
    wire := tr.memory_transport(&f.endpoints[0])
    bad := GUEST
    bad.seat = 1
    testing.expect(t, !dg.configure(&f.host, wire, SCOPE, true, HOST, []dg.Binding{bad}, true, f.now))
    testing.expect_value(t, dg.read(&f.host, 2).round_trip_ms, u32(40))
    testing.expect(t, !dg.configure(&f.host, wire, SCOPE, true, HOST, []dg.Binding{GUEST}, true, f.now - 1))
    testing.expect(t, dg.configure(&f.host, wire, SCOPE, true, HOST, nil, true, f.now))
    testing.expect(t, !dg.read(&f.host, 2).present)
}

@(test)
stall_discards_pending_probe_without_manufacturing_high_ping :: proc(t: ^testing.T) {
    f: Fixture
    open(&f)
    defer close(&f)
    pump(&f, 20)
    f.now = 9000
    pump(&f, 9010)
    testing.expect(t, !dg.read(&f.host, 2).known)
    pump(&f, 10300)
    testing.expect_value(t, dg.read(&f.host, 2).round_trip_ms, u32(40))
}

@(test)
report_values_validate_before_replacing_known_roster :: proc(t: ^testing.T) {
    f: Fixture
    open(&f)
    defer close(&f)
    pump(&f, 1300)
    packet := dg.Packet {
        version  = 1,
        room     = 7,
        binding  = 22,
        sequence = 999,
        kind     = .Report,
    }
    packet.rows[1] = {
        present       = true,
        known         = true,
        round_trip_ms = 5000,
    }
    inject(&f, 1, 2, packet)
    packet.rows[1] = {
        known = true,
    }
    inject(&f, 1, 2, packet)
    pump(&f, 1400)
    testing.expect_value(t, f.client.rejected, u64(2))
    testing.expect_value(t, dg.read(&f.client, 2).round_trip_ms, u32(40))
}

@(test)
slow_round_trip_is_not_overwritten_by_next_probe_interval :: proc(t: ^testing.T) {
    f: Fixture
    open(&f)
    defer close(&f)
    tr.memory_set_faults(&f.memory, {latency_ticks = 700, retry_ticks = 1})
    pump(&f, 4000)
    testing.expect_value(t, dg.read(&f.host, 2).round_trip_ms, u32(1400))
    testing.expect_value(t, dg.read(&f.client, 2).round_trip_ms, u32(1400))
}

@(test)
backpressure_does_not_start_a_round_trip_clock :: proc(t: ^testing.T) {
    d: dg.Diagnostics
    assert(dg.init(&d))
    defer dg.destroy(&d)

    blocked :: proc(_: rawptr, _: tr.Peer_Id, _: tr.Channel, _: []u8) -> tr.Send_Result {
        return .Backpressure
    }

    assert(dg.configure(&d, {send = blocked}, SCOPE, true, HOST, []dg.Binding{GUEST}, true, 1000))
    dg.frame(&d)
    testing.expect_value(t, d.peers[0].pending, u64(0))
    testing.expect(t, !dg.read(&d, 2).known)
    testing.expect_value(t, d.peers[0].next_send, u64(2000))
}

@(test)
authority_replacement_and_observers_do_not_reuse_player_rows :: proc(t: ^testing.T) {
    f: Fixture
    open(&f)
    defer close(&f)
    pump(&f, 1300)
    observer := GUEST
    observer.seat = 0
    assert(dg.configure(&f.host, {}, SCOPE, true, HOST, []dg.Binding{observer}, true, f.now))
    testing.expect(t, !dg.read(&f.host, 2).present)
    other := AUTHORITY
    other.peer = 3
    assert(dg.configure(&f.client, {}, SCOPE, false, GUEST, []dg.Binding{other}, true, f.now))
    testing.expect(t, !dg.read(&f.client, 1).present && !dg.read(&f.client, 2).known)
}
