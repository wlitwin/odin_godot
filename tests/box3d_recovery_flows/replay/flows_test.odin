package replay_recovery_flows_test

import "core:fmt"
import "core:testing"
import b "godot:box3d"
import r "godot:replay"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import game "godot:examples/box3d_common"
import bounds "godot:tests/box3d_bounds/replay"

@(test)
progressed_shared_game_late_join_adopts_complete5_and_future_controls :: proc(t: ^testing.T) {
    c := new(Flow)
    defer free(c)
    defer close(t, c)

    if !authority(t, c) || !progress_alone(t, c, 40) {
        return
    }

    before := c.p.server.timeline.head

    if !check(t, !c.p.client.initialized && before == 40, "real progression precedes enrollment") || !enroll(t, c) {
        return
    }

    if !check(
        t,
        c.p.client.baseline >= before && c.p.client.generation > 0 && c.p.client.serial > 0 && c.p.client.seat == 2,
        "actual late Welcome scope and seat",
    ) {
        return
    }

    future(t, c)
}

@(test)
late_observer_adopts_complete5_without_input_prediction_or_spurious_fx :: proc(t: ^testing.T) {
    c := new(Flow)
    defer free(c)
    defer close(t, c)

    if !authority(t, c) || !enroll(t, c) {
        return
    }

    for _ in 0 ..< 40 {
        if !pair_step(t, c) {
            return
        }
    }

    before := c.p.server.timeline.head

    if !enroll(t, c, true) ||
       !check(
               t,
               c.observer.baseline >= before && c.observer.spectator && c.observer.seat == 0,
               "real late observer Welcome",
           ) {
        return
    }

    head, cf, tx := c.observer.timeline.head, c.observer.timeline.confirmed, c.observer.stats.tx_packets

    if !check(t, net.client_step(&c.observer, game.Control{x = 10}) == .Wrong_Phase, "observer public step refused") {
        return
    }

    _, error := net.client_issue(&c.observer, game.Action{kind = .Motor})

    if !check(
        t,
        error == .Wrong_Phase &&
        c.observer.stats.tx_packets == tx &&
        c.observer.timeline.head == head &&
        c.observer.timeline.confirmed == cf,
        "observer cannot send input/action or predict",
    ) {
        return
    }

    if !future(t, c) {
        return
    }

    check(
        t,
        c.observer.physics.repairs == 0 && c.observer.stats.replayed_ticks == 0 && c.observer_fx.unconfirmed == 0,
        "observer confirms real authority without speculative FX/repair",
    )
}

@(test)
same_token_replacement_isolates_real_old_peer_scope_and_ack :: proc(t: ^testing.T) {
    c := new(Flow)
    defer free(c)
    defer close(t, c)

    if !authority(t, c) || !enroll(t, c) || !future(t, c) {
        return
    }

    old: Old
    defer drop_old(&old)

    if !record_old(t, c, &old) {
        return
    }

    token, seat, generation := c.p.client.token, c.p.client.seat, c.p.client.generation
    old_wire := c.p.client.wire
    tr.close(&old_wire)
    now := c.p.memory.now

    if !none(t, net.server_pump(&c.p.server, now), "observe actual old endpoint departure") {
        return
    }

    if !check(t, tr.memory_open(&c.p.memory, &c.replacement_endpoint, 4), "distinct actual replacement endpoint") {
        return
    }

    replacement := tr.memory_transport(&c.replacement_endpoint)

    if !none(t, net.client_reconnect(&c.p.client, replacement), "public same-token reconnect") {
        return
    }

    c.remote = 4

    if !pump_clients(t, c, now) ||
       !advance(t, c, now) ||
       !none(t, net.server_pump(&c.p.server, now), "real replacement Hello") ||
       !none(t, net.server_step(&c.p.server), "replacement membership") ||
       !settle(t, c) {
        return
    }

    now = max(c.p.memory.now, max(c.p.server.now, c.p.client.now))

    if !check(
        t,
        c.p.client.token == token && c.p.client.seat == seat && c.p.client.generation > generation,
        "same logical identity real fresh generation",
    ) {
        return
    }

    admitted := false

    for peer in c.p.server.peers {
        if !peer.local &&
           peer.phase == .Running &&
           peer.connection == 4 &&
           peer.seat == seat &&
           peer.generation == c.p.client.generation &&
           peer.serial == c.p.client.serial {
            admitted = true
        }
    }

    if !check(t, admitted, "actual authority replacement peer/scope") || !same_client(t, c, &c.p.client) {
        return
    }

    // Reopen the departed numeric peer as a DIFFERENT transport generation. It
    // has no replacement seat; its old bytes must not authenticate that seat.
    if !check(t, tr.memory_open(&c.p.memory, &c.p.endpoints[1], 2), "real old-id endpoint reopened") {
        return
    }

    stale_sender := tr.memory_transport(&c.p.endpoints[1])
    host := tr.memory_transport(&c.p.endpoints[0])

    if !check(
        t,
        tr.peer_generation(&host, 2) > 1 && tr.peer_generation(&host, 4) > 0,
        "actual connection generations supplied by Memory",
    ) {
        return
    }

    drain_fx(t, &c.p.client, &c.driver_fx)
    before := bounds.published(&c.p)
    checkpoint, ce := r.capture_complete(&c.p.client.timeline, before.head)

    if !check(t, ce == .None, "replacement before replay complete5") {
        return
    }

    defer r.complete_checkpoint_destroy(&checkpoint)
    server_before, se := r.capture_complete(&c.p.server.timeline, c.p.server.timeline.head)

    if !check(t, se == .None, "authority before replay complete5") {
        return
    }

    defer r.complete_checkpoint_destroy(&server_before)

    for sender in ([?]^tr.Transport{&stale_sender, &replacement}) {
        if !deliver(t, &old.input, sender, 1) || !deliver(t, &old.ack, sender, 1) {
            return
        }
    }

    if !advance(t, c, now) ||
       !none(t, net.server_pump(&c.p.server, now), "old input/appropriate ACK rejected on Host") {
        return
    }

    server_after, sa := r.capture_complete(&c.p.server.timeline, server_before.frame.tick)

    if !check(t, sa == .None, "authority after old replay capture") {
        return
    }

    defer r.complete_checkpoint_destroy(&server_after)

    if !check(
        t,
        c.p.server.timeline.head == server_before.frame.tick && bounds.same5(t, &c.p, &server_before, &server_after),
        "old peer/scope cannot mutate authority complete5",
    ) {
        return
    }

    for sender in ([?]^tr.Transport{&host, &stale_sender}) {
        if !deliver(t, &old.facts, sender, 4) || !deliver(t, &old.chunks, sender, 4) {
            return
        }
    }

    if !advance(t, c, now) ||
       !none(t, net.client_pump(&c.p.client, now), "old facts/signature/chunks public replacement receive") ||
       !unchanged(t, c, before, &checkpoint) {
        return
    }

    future(t, c)
}

parts_only :: proc(t: ^testing.T, c: ^Flow, source: ^Packets, out: ^Packets, purpose: net.Complete_Purpose) -> bool {
    for packet in source.rows[:source.count] {
        _, fingerprint, report := sc.inspect(packet.bytes)

        if !check(t, report.error == .None, "actual transfer envelope") {
            return false
        }

        if fingerprint != c.p.client.physics.schemas.chunk.fingerprint {
            continue
        }

        _, body, unpacked := sc.unpack_bytes(fingerprint, packet.bytes, packet.meta)
        size := c.p.client.physics.schemas.chunk.wire_size

        if !check(t, unpacked.error == .None && len(body) >= size, "public chunk envelope bounds") {
            return false
        }

        header: net.Physics_Chunk_Header

        if !check(
            t,
            sc.decode(&c.p.client.physics.schemas.chunk, &header, body[:size]).error == .None,
            "public chunk schema decode",
        ) {
            return false
        }

        if header.purpose == u32(purpose) {
            if !append_packet(t, out, packet.bytes, packet.from, packet.channel) {
                return false
            }
        }
    }

    return check(t, out.count > 1, "genuine32-body recovery has an interrupted multi-part transfer")
}

send_one :: proc(t: ^testing.T, c: ^Flow, packet: Raw) -> bool {
    host := tr.memory_transport(&c.p.endpoints[0])
    return check(t, tr.send(&host, c.remote, packet.channel, packet.bytes) == .Sent, "real authority chunk delivery")
}

corrupt_payload :: proc(t: ^testing.T, c: ^Flow, original: Raw, out: ^Packets) -> bool {
    _, fingerprint, report := sc.inspect(original.bytes)

    if !check(t, report.error == .None, "genuine corrupt-control source") {
        return false
    }

    _, borrowed, unpacked := sc.unpack_bytes(fingerprint, original.bytes, original.meta)

    if !check(
        t,
        unpacked.error == .None && len(borrowed) > c.p.client.physics.schemas.chunk.wire_size,
        "actual chunk payload byte exists",
    ) {
        return false
    }

    body := make([]u8, len(borrowed))
    defer delete(body)
    copy(body, borrowed)
    body[len(body) - 1] ~= 1
    bytes := make([]u8, len(original.bytes))
    defer delete(bytes)

    if !check(
        t,
        sc.pack_bytes(fingerprint, original.meta, body, bytes).error == .None,
        "public outer checksum re-encode",
    ) {
        return false
    }

    return append_packet(t, out, bytes, original.from, original.channel)
}

@(test)
beyond_h128_real_resync_preserves_last_complete5_until_valid_replacement :: proc(t: ^testing.T) {
    c := new(Flow)
    defer free(c)
    defer close(t, c)

    if !authority(t, c, 32) || !enroll(t, c) || !future(t, c) {
        return
    }

    old: Old
    defer drop_old(&old)

    if !record_old(t, c, &old) {
        return
    }

    confirmed, generation, serial := c.p.client.timeline.confirmed, c.p.client.generation, c.p.client.serial
    target := c.p.server.timeline.head + 160
    discarded_packets, discarded_bytes: u64
    receiver := c.p.client.wire
    scratch: [tr.MAX_PACKET_BYTES]u8

    for c.p.server.timeline.head < target {
        now := max(c.p.memory.now, c.p.server.now) + 17

        if !advance(t, c, now) ||
           !none(t, net.server_pump(&c.p.server, now), "gap authority pump") ||
           !none(t, net.server_local(&c.p.server, game.Control{x = 25}), "gap actual local input") ||
           !none(t, net.server_step(&c.p.server), "real authority progression during receiver gap") ||
           !advance(t, c, now) {
            return
        }

        if c.p.server.timeline.head <= confirmed + 128 {
            drained := false

            for _ in 0 ..< 65 {
                packet := tr.receive(&receiver, scratch[:])

                if packet.state == .Empty {
                    drained = true
                    break
                }

                if !check(t, packet.state == .Received, "public receiver discard") {
                    return
                }

                discarded_packets += 1
                discarded_bytes += u64(packet.count)
            }

            if !check(t, drained, "bounded actual discard") {
                return
            }
        }
    }

    if !check(
        t,
        c.p.server.timeline.head - confirmed > 128 && discarded_packets > 0 && discarded_bytes > 0,
        "real beyond-H128 received-history loss",
    ) {
        return
    }

    now := c.p.memory.now

    if !none(t, net.client_pump(&c.p.client, now), "actual retained far facts trigger recovery") {
        return
    }

    if !check(
        t,
        c.p.client.phase == .Resyncing && c.p.client.stats.resyncs > 0 && c.p.client.resync_notice.serial != 0,
        "actual automatic hard-resync notice, no setter/private call",
    ) {
        return
    }

    drain_fx(t, &c.p.client, &c.driver_fx)
    before := bounds.published(&c.p)
    original, oe := r.capture_complete(&c.p.client.timeline, before.head)

    if !check(t, oe == .None, "last source-free owning complete5 before replacement") {
        return
    }

    defer r.complete_checkpoint_destroy(&original)

    // Next public pump emits the real correlated Resync request.
    if !none(t, net.client_pump(&c.p.client, now), "actual Resync request") ||
       !advance(t, c, now) ||
       !none(t, net.server_pump(&c.p.server, now), "authority prepares actual canonical replacement") {
        return
    }

    all, parts, bad: Packets
    defer drop(&all)
    defer drop(&parts)
    defer drop(&bad)

    if !advance(t, c, now) || !capture(t, &receiver, &all) || !parts_only(t, c, &all, &parts, .Welcome) {
        return
    }

    if !send_one(t, c, parts.rows[0]) ||
       !advance(t, c, now) ||
       !none(t, net.client_pump(&c.p.client, now), "genuine partial replacement") ||
       !unchanged(t, c, before, &original) {
        return
    }

    first_memory := bounded_memory(t)

    if !send_one(t, c, parts.rows[0]) ||
       !advance(t, c, now) ||
       !none(t, net.client_pump(&c.p.client, now), "identical duplicate part") ||
       !unchanged(t, c, before, &original) {
        return
    }

    duplicate_memory := bounded_memory(t)

    if !check(
        t,
        duplicate_memory.admitted_bytes == first_memory.admitted_bytes &&
        duplicate_memory.owner_count == first_memory.owner_count,
        "duplicate part creates no additional owned transfer",
    ) {
        return
    }

    if !corrupt_payload(t, c, parts.rows[0], &bad) ||
       !send_one(t, c, bad.rows[0]) ||
       !advance(t, c, now) ||
       !none(t, net.client_pump(&c.p.client, now), "same-index conflicting part") ||
       !unchanged(t, c, before, &original) {
        return
    }

    bounded_memory(t)

    if !send_one(t, c, bad.rows[0]) {
        return
    }

    for packet in parts.rows[1:parts.count] {
        if !send_one(t, c, packet) {
            return
        }
    }

    if !advance(t, c, now) ||
       !none(t, net.client_pump(&c.p.client, now), "complete corrupt digest candidate") ||
       !unchanged(t, c, before, &original) {
        return
    }

    host := tr.memory_transport(&c.p.endpoints[0])

    if !deliver(t, &old.facts, &host, c.remote) ||
       !deliver(t, &old.chunks, &host, c.remote) ||
       !advance(t, c, now) ||
       !none(t, net.client_pump(&c.p.client, now), "stale previous-context transfer during resync") ||
       !unchanged(t, c, before, &original) {
        return
    }

    if !deliver(t, &parts, &host, c.remote) || !settle(t, c) {
        return
    }

    if !check(
        t,
        c.p.client.phase == .Running &&
        c.p.client.timeline.confirmed >= target &&
        c.p.client.baseline > confirmed &&
        (c.p.client.generation > generation || c.p.client.serial > serial),
        "genuine complete replacement commits new scope",
    ) {
        return
    }

    if !same_client(t, c, &c.p.client) {
        return
    }

    // Only new eligible effects are asserted after the canonical baseline; lost
    // out-of-window effects are not fabricated or reclassified as observed.
    if !future(t, c) {
        return
    }

    fmt.printf(
        "REPLAY_FLOW_RESYNC actual_notice=%v discarded_packets=%d discarded_bytes=%d final_head=%d final_cf=%d generation=%d serial=%d\n",
        c.p.client.resync_notice,
        discarded_packets,
        discarded_bytes,
        c.p.client.timeline.head,
        c.p.client.timeline.confirmed,
        c.p.client.generation,
        c.p.client.serial,
    )
}
