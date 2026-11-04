package replay_hello_idempotency_test

// One post-ACK duplicate-Hello regression. Real generic4 complete physics,
// public Server/Client/Link/Memory; static OFFddff/nilOwner, NOT ENet or live cause.
import "core:encoding/json"
import "core:mem"
import "core:os"
import "core:testing"
import b "godot:box3d"
import bd "godot:box3d/diagnostics"
import net "godot:replay/net"
import sc "godot:replay/schema"
import tr "godot:replay/transport"
import ca "godot:tests/box3d_soak/replay/action_scope_case_a"
import ar "godot:tests/box3d_soak/replay/action_retire"

Scope :: struct {
    observed:                                                                                           bool,
    epoch, client_generation, client_serial, baseline, head, confirmed, view_reset, client_incarnation: u64,
    peer_generation, peer_serial, peer_incarnation:                                                     u64,
    client_phase:                                                                                       net.Phase,
    peer_phase:                                                                                         i32,
    connection:                                                                                         tr.Peer_Id,
    seat:                                                                                               u16,
    token:                                                                                              net.Token,
    peer_token_hash:                                                                                    bd.Digest,
}

Observation :: struct {
    schema:                                                                                  u32,
    scope, stage:                                                                            string,
    setup_complete, initial_ack_complete, first_hello_observed, retry_sent, retry_delivered: bool,
    same_connection_token_incarnation, hello_bytes_unchanged, post_ack_complete:             bool,
    full5_before, full5_after, criterion_reached, idempotent, cleanup_observed:              bool,
    before, after:                                                                           Scope,
    hello_index, retry_index, hello_bytes, hello_matches_before, hello_matches_after:        int,
    hello_kind:                                                                              u16,
    hello_channel:                                                                           tr.Channel,
    hello_from:                                                                              tr.Peer_Id,
    hello_transport_generation:                                                              u64,
    hello_hash, retry_hash:                                                                  bd.Digest,
    actual_retry_send:                                                                       tr.Send_Result,
    post_retry_transfer_bytes:                                                               int,
    post_retry_transfer_serial, post_retry_transfer_id:                                      u64,
    post_retry_transfer_purpose:                                                             u32,
    post_retry_waiting_ack:                                                                  bool,
    native_build, native_target:                                                             bd.Digest,
    native_live, wrapper_live, provider_live, odin_live:                                     u64,
    trace_count, trace_dropped:                                                              int,
    trace_hash:                                                                              u64,
}

write_json :: proc(name: string, value: $T) {
    bytes, error := json.marshal(value)
    assert(error == nil)
    defer delete(bytes)
    assert(os.write_entire_file(name, bytes) == nil)
}

gate :: proc(t: ^testing.T, ok: bool, o: ^Observation, stage: string) -> bool {
    o.stage = stage
    testing.expect(t, ok, stage)
    return ok
}

scope_state :: proc(c: ^ca.Case, index: int) -> Scope {
    p := &c.pair
    client := &p.client
    peer := &p.server.peers[index]
    return {
        observed = true,
        epoch = client.cfg.epoch,
        client_generation = client.generation,
        client_serial = client.serial,
        baseline = client.baseline,
        head = client.timeline.head,
        confirmed = client.timeline.confirmed,
        view_reset = client.view_reset,
        client_incarnation = client.incarnation,
        peer_generation = peer.generation,
        peer_serial = peer.serial,
        peer_incarnation = peer.incarnation,
        client_phase = client.phase,
        peer_phase = i32(peer.phase),
        connection = peer.connection,
        seat = client.seat,
        token = client.token,
        peer_token_hash = peer.token_hash,
    }
}

@(test)
exact_hello_retry_after_real_welcome_ack_preserves_admitted_scope :: proc(t: ^testing.T) {
    backing := context.allocator
    tracking: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracking, backing, backing)
    context.allocator = mem.tracking_allocator(&tracking)
    c := new(ca.Case)
    cleanup: ca.Report
    o := Observation {
        schema      = 1,
        scope       = "ONE_post_ACK_generic4_static_OFFddff_nilOwner_public_Link_Memory_NOT_ENet_NOT_live_reconnect_cause",
        stage       = "open",
        hello_index = -1,
        retry_index = -1,
    }
    contract, status := b.domain_contract_get()

    if status == .Ok {
        o.native_build = contract.build
        o.native_target = contract.target
    }

    defer {
        o.trace_count = c.pair.memory.trace_count
        o.trace_dropped = c.pair.memory.trace_dropped
        o.trace_hash = c.pair.memory.trace_hash

        if o.trace_count > 0 {
            write_json("memory-trace.json", c.pair.memory.trace[:o.trace_count])
        }

        // Existing close preserves every captured packet+hash and performs real drops.
        ca.close(t, c, &cleanup)
        free(c)
        o.native_live = cleanup.native_live
        o.wrapper_live = cleanup.wrapper_live
        o.provider_live = cleanup.provider_live
        o.odin_live = u64(tracking.current_memory_allocated)
        o.cleanup_observed =
            cleanup.all_drops_ok &&
            o.native_live == 0 &&
            o.wrapper_live == 0 &&
            o.provider_live == 0 &&
            o.odin_live == 0
        testing.expect(t, o.cleanup_observed, "real Native/provider/Odin cleanup0; nilOwner, no actual-Core claim")
        context.allocator = backing
        mem.tracking_allocator_destroy(&tracking)
        write_json("observation.json", o)
    }

    if !ca.open(t, c) {
        return
    }

    p := &c.pair
    peer_index := -1

    for peer, index in p.server.peers {
        if !peer.local &&
           peer.phase == .Running &&
           peer.seat == p.client.seat &&
           peer.connection == p.endpoints[1].id {
            peer_index = index
            break
        }
    }

    if !gate(t, peer_index >= 0, &o, "real admitted peer on original Memory connection") {
        return
    }

    peer := &p.server.peers[peer_index]
    tx := &p.server.physics.tx[peer_index]
    o.initial_ack_complete = len(tx.data.bytes) == 0 && !tx.waiting_ack

    if !gate(
        t,
        o.initial_ack_complete &&
        p.client.phase == .Running &&
        peer.generation == p.client.generation &&
        peer.serial == p.client.serial,
        &o,
        "complete real Welcome ACK before replay; NOT active-transfer retransmission",
    ) {
        return
    }

    o.before = scope_state(c, peer_index)
    o.full5_before = ar.full_pair(t, p, o.before.confirmed)

    if !gate(t, o.full5_before, &o, "actual initial confirmed full5 and signatures") {
        return
    }

    // Only inspect the public envelope fingerprint of already captured bytes.
    // No private Hello type, copied schema, repacking or invented packet fields.
    for &saved, index in c.gates[0].saved[:c.gates[0].count] {
        meta, fingerprint, report := sc.inspect(saved.data.bytes)

        if report.error == .None && fingerprint == p.client.codecs.hello.fingerprint {
            o.hello_matches_before += 1

            if o.hello_index < 0 {
                o.hello_index = index
                o.hello_kind = meta.kind
            }
        }
    }

    if !gate(
        t,
        o.hello_index >= 0 && o.hello_matches_before == 1,
        &o,
        "FIRST actual serialized Hello captured by existing below-Link gate",
    ) {
        return
    }

    first := &c.gates[0].saved[o.hello_index]
    o.hello_bytes = len(first.data.bytes)
    o.hello_hash = first.hash
    o.hello_channel = first.packet.channel
    o.hello_from = first.packet.from
    o.hello_transport_generation = first.packet.generation
    o.first_hello_observed =
        first.packet.from == peer.connection &&
        first.packet.channel == .Reliable &&
        !first.held &&
        bd.hash_bytes(first.data.bytes) == first.hash

    if !gate(
        t,
        o.first_hello_observed && p.client.incarnation == peer.incarnation,
        &o,
        "real original same-connection Hello and admitted incarnation",
    ) {
        return
    }

    assert(os.write_entire_file("first-hello.bin", first.data.bytes) == nil)
    o.setup_complete = true
    count_before := c.gates[0].count
    // Re-send EXACT original bytes from the SAME live Memory endpoint below Link.
    // This controlled delivery is diagnostic, not a claim about ENet duplication.
    o.actual_retry_send = tr.send(&c.gates[1].base, p.endpoints[0].id, first.packet.channel, first.data.bytes)
    o.retry_sent = o.actual_retry_send == .Sent

    if !gate(t, o.retry_sent, &o, "one real unchanged-Hello Memory send") {
        return
    }

    if !ca.server_pump(t, c, 17) {
        return
    }

    o.post_retry_transfer_bytes = len(tx.data.bytes)
    o.post_retry_transfer_serial = tx.serial
    o.post_retry_transfer_id = tx.id
    o.post_retry_transfer_purpose = u32(tx.purpose)
    o.post_retry_waiting_ack = tx.waiting_ack

    for &saved, index in c.gates[0].saved[:c.gates[0].count] {
        _, fingerprint, report := sc.inspect(saved.data.bytes)

        if report.error == .None && fingerprint == p.client.codecs.hello.fingerprint {
            o.hello_matches_after += 1

            if index >= count_before && o.retry_index < 0 {
                o.retry_index = index
            }
        }
    }

    if !gate(
        t,
        o.retry_index >= 0 && o.hello_matches_after == o.hello_matches_before + 1,
        &o,
        "exactly one retry actually received on server below Link",
    ) {
        return
    }

    retry := &c.gates[0].saved[o.retry_index]
    o.retry_hash = retry.hash
    o.hello_bytes_unchanged = retry.hash == first.hash && mem.compare(first.data.bytes, retry.data.bytes) == 0
    o.retry_delivered =
        o.hello_bytes_unchanged &&
        retry.packet.from == first.packet.from &&
        retry.packet.channel == first.packet.channel &&
        retry.packet.generation == first.packet.generation

    if !gate(t, o.retry_delivered, &o, "received retry bytes/hash/channel/connection/transport generation identical") {
        return
    }

    assert(os.write_entire_file("retry-hello.bin", retry.data.bytes) == nil)

    if !ca.client_pump(t, c, 17) || !ca.server_pump(t, c, 17) {
        return
    }

    o.after = scope_state(c, peer_index)
    o.same_connection_token_incarnation =
        o.after.connection == o.before.connection &&
        o.after.token == o.before.token &&
        o.after.peer_token_hash == o.before.peer_token_hash &&
        o.after.client_incarnation == o.before.client_incarnation &&
        o.after.peer_incarnation == o.before.peer_incarnation &&
        o.after.seat == o.before.seat &&
        o.after.epoch == o.before.epoch
    o.post_ack_complete = len(tx.data.bytes) == 0 && !tx.waiting_ack

    if !gate(
        t,
        o.same_connection_token_incarnation &&
        o.post_ack_complete &&
        p.client.phase == .Running &&
        peer.phase == .Running &&
        peer.generation == p.client.generation &&
        peer.serial == p.client.serial,
        &o,
        "actual post-retry current scope and real ACK completion",
    ) {
        return
    }

    o.full5_after = ar.full_pair(t, p, o.after.confirmed)

    if !gate(t, o.full5_after, &o, "actual final confirmed full5 and signatures") {
        return
    }

    o.idempotent =
        o.after.peer_generation == o.before.peer_generation &&
        o.after.peer_serial == o.before.peer_serial &&
        o.after.client_generation == o.before.client_generation &&
        o.after.client_serial == o.before.client_serial &&
        o.after.baseline == o.before.baseline &&
        o.after.view_reset == o.before.view_reset
    o.criterion_reached = true
    o.stage = "ONE_PROSPECTIVE_POST_ACK_HELLO_IDEMPOTENCY_ASSERTION"
    testing.expect(
        t,
        o.idempotent,
        "EXPECTED baseline RED: an exact Hello retry after real Welcome ACK must not replace the already-admitted scope/create a new Welcome serial",
    )
}
