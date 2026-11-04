package replay_authority_test

import "core:testing"
import auth "godot:replay/authority"
import tr "godot:replay/transport"

Rpc_Fixture :: struct {
    ledger:    Ledger,
    clock:     Clock,
    memory:    tr.Memory,
    endpoints: [4]tr.Memory_Endpoint,
    service:   auth.Service,
    leases:    [2]auth.Lease,
    clients:   [2]auth.Rpc_Client,
    tick:      u64,
}

rpc_setup :: proc(f: ^Rpc_Fixture) {
    policy := auth.DEFAULT_POLICY
    policy.lease_ms = 1000
    f.ledger.record = auth.record_make(44, 55, A, policy)
    ids := [2]auth.Identity{A, B}
    keys: [2]auth.Credential

    for id, i in ids {
        address, _ := auth.endpoint("127.0.0.1", u16(45000 + i))
        f.ledger.record.members[i] = {
            identity          = id,
            endpoint          = address,
            enabled           = true,
            can_host          = true,
            trusted_authority = true,
        }
        keys[i] = {
            identity = id,
            key = {0 = u8(i + 21)},
        }
    }

    tr.memory_init(&f.memory, cfg = {4, 128, tr.MAX_PACKET_BYTES, 8192}, faults = {latency_ticks = 1, retry_ticks = 3})

    for &endpoint, i in f.endpoints {
        tr.memory_open(&f.memory, &endpoint, tr.Peer_Id(i + 1))
    }

    assert(
        auth.service_init(
            &f.service,
            f.ledger.record,
            commit,
            &f.ledger,
            clock_source(&f.clock),
            tr.memory_transport(&f.endpoints[0]),
            keys[:],
        ) ==
        .None,
    )

    for &client, i in f.clients {
        auth.lease_init(&f.leases[i], ids[i], 44, 55, clock_source(&f.clock), i == 0)
        assert(
            auth.rpc_client_init(
                &client,
                &f.leases[i],
                keys[i].key,
                auth.Nonce{0 = u8(i + 11)},
                tr.memory_transport(&f.endpoints[i + 1]),
            ),
        )
    }
}

rpc_destroy :: proc(f: ^Rpc_Fixture) {
    for &client in f.clients {
        auth.rpc_client_destroy(&client)
    }

    auth.service_destroy(&f.service)

    for &endpoint in f.endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

rpc_step :: proc(f: ^Rpc_Fixture) {
    f.tick += 1
    f.clock.now = f.tick * 10
    tr.memory_advance(&f.memory, f.tick)
    auth.service_pump(&f.service)

    for &client in f.clients {
        auth.rpc_client_pump(&client)
    }
}

rpc_call :: proc(f: ^Rpc_Fixture, index: int, command: auth.Command) -> auth.Reply {
    assert(auth.rpc_begin(&f.clients[index], command) == .None)

    for _ in 0 ..< 100 {
        rpc_step(f)

        if reply, done := auth.rpc_completed(&f.clients[index]); done {
            return reply
        }
    }

    assert(false, "RPC did not complete")
    return {}
}

@(test)
authenticated_rpc_drives_nomination_preparation_and_planned_claim :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    reply := rpc_call(&f, 0, {verb = .Start})
    testing.expect_value(t, reply.result, auth.Error.None)
    testing.expect(t, auth.lease_live(&f.leases[0], 1))
    testing.expect_value(
        t,
        rpc_call(&f, 1, {verb = .Nominate, epoch = 1, successor = A, binding = 9}).result,
        auth.Error.Denied,
    )
    testing.expect_value(
        t,
        rpc_call(&f, 0, {verb = .Nominate, epoch = 1, successor = B, binding = 9}).result,
        auth.Error.None,
    )
    testing.expect_value(t, rpc_call(&f, 1, {verb = .Prepare, point = point()}).result, auth.Error.None)
    retired, _ := auth.lease_retire(&f.leases[0])
    testing.expect_value(
        t,
        rpc_call(&f, 0, {verb = .Release, retired = retired, point = point()}).result,
        auth.Error.None,
    )
    reply = rpc_call(&f, 1, {verb = .Claim, epoch = 1, point = point()})
    testing.expect_value(t, reply.result, auth.Error.None)
    testing.expect_value(t, reply.view.epoch, u64(2))
    testing.expect_value(t, reply.view.owner, B)
    testing.expect_value(t, reply.view.recovery, auth.Recovery_Kind.Planned)
    testing.expect(t, !auth.lease_live(&f.leases[0], 1))
    testing.expect_value(t, f.ledger.record.requests[1].sequence, f.clients[1].request.sequence)
}

@(test)
forged_mac_and_cross_identity_requests_never_reach_the_store :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    auth.rpc_begin(&f.clients[0], {verb = .Start})
    bytes := f.clients[0].txb
    count := f.clients[0].count
    before := f.ledger.writes
    bytes[count - 1] ~= 1
    testing.expect(t, !auth.service_receive(&f.service, 2, bytes[:count]))
    testing.expect_value(t, f.ledger.writes, before)
    // A correctly formed B request with A's key cannot act as B.
    f.clients[1].key = f.clients[0].key
    auth.rpc_begin(&f.clients[1], {verb = .Query})
    testing.expect(t, !auth.service_receive(&f.service, 3, f.clients[1].txb[:f.clients[1].count]))
    testing.expect_value(t, f.ledger.writes, before)
}

@(test)
oversized_unauthenticated_packet_cannot_block_later_valid_control_requests :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    attacker := tr.memory_transport(&f.endpoints[3])
    oversized := make([]u8, auth.RPC_BYTES + 1)
    defer delete(oversized)
    testing.expect_value(t, tr.send(&attacker, 1, .Reliable, oversized), tr.Send_Result.Sent)
    testing.expect_value(t, rpc_call(&f, 0, {verb = .Start}).result, auth.Error.None)
    testing.expect(t, f.service.stats.rejected > 0)
}

@(test)
durable_replay_frontier_prevents_old_mutations_after_newer_queries_and_restart :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    rpc_call(&f, 0, {verb = .Start})
    rpc_call(&f, 0, {verb = .Nominate, epoch = 1, successor = B, binding = 9})
    old_bytes, old_count := f.clients[0].txb, f.clients[0].count
    rpc_call(&f, 0, {verb = .Nominate, epoch = 1, successor = B, binding = 10})
    rpc_call(&f, 0, {verb = .Query})
    before := f.ledger.writes
    auth.service_receive(&f.service, 2, old_bytes[:old_count])
    testing.expect_value(t, f.ledger.record.source_binding, u64(10))
    testing.expect_value(t, f.ledger.writes, before)
    keys := [2]auth.Credential{f.service.credentials[0], f.service.credentials[1]}
    auth.service_destroy(&f.service)
    testing.expect_value(
        t,
        auth.service_init(
            &f.service,
            f.ledger.record,
            commit,
            &f.ledger,
            clock_source(&f.clock),
            tr.memory_transport(&f.endpoints[0]),
            keys[:],
        ),
        auth.Error.None,
    )
    before = f.ledger.writes
    auth.service_receive(&f.service, 2, old_bytes[:old_count])
    testing.expect_value(t, f.ledger.record.source_binding, u64(10))
    testing.expect_value(t, f.ledger.writes, before)
}

@(test)
lost_reply_retry_does_not_extend_lease_or_repeat_a_durable_decision :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    auth.rpc_begin(&f.clients[0], {verb = .Start})
    auth.service_receive(&f.service, 2, f.clients[0].txb[:f.clients[0].count])
    expires, revision := f.service.coordinator.expires, f.ledger.record.revision
    f.clock.now = 500
    testing.expect(t, auth.service_receive(&f.service, 2, f.clients[0].txb[:f.clients[0].count]))
    testing.expect_value(t, f.service.coordinator.expires, expires)
    testing.expect_value(t, f.ledger.record.revision, revision)
    testing.expect_value(t, f.service.stats.duplicates, u64(1))
}

@(test)
store_failure_publishes_no_grant_and_reply_is_bound_to_the_client_nonce :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    f.ledger.fail = true
    reply := rpc_call(&f, 0, {verb = .Start})
    testing.expect_value(t, reply.result, auth.Error.Storage)
    testing.expect_value(t, f.ledger.record.epoch, u64(0))
    testing.expect(t, !auth.lease_live(&f.leases[0], 1))
    f.ledger.fail = false
    // New independently initialized coordinator for a clean signed reply.
    keys := [2]auth.Credential{f.service.credentials[0], f.service.credentials[1]}
    auth.service_destroy(&f.service)
    auth.service_init(
        &f.service,
        f.ledger.record,
        commit,
        &f.ledger,
        clock_source(&f.clock),
        tr.memory_transport(&f.endpoints[0]),
        keys[:],
    )
    rpc_call(&f, 0, {verb = .Start})
    old_reply := f.service.txb
    count := f.service.codecs.reply.wire_size + 52 + 32
    old_sequence := f.clients[0].request.sequence
    auth.rpc_client_destroy(&f.clients[0])
    f.leases[0] = {}
    auth.lease_init(&f.leases[0], A, 44, 55, clock_source(&f.clock), true)
    f.leases[0].sequence = old_sequence - 1
    auth.rpc_client_init(
        &f.clients[0],
        &f.leases[0],
        keys[0].key,
        auth.Nonce{0 = 99},
        tr.memory_transport(&f.endpoints[1]),
    )
    auth.rpc_begin(&f.clients[0], {verb = .Start})
    testing.expect_value(t, f.clients[0].request.sequence, old_sequence)
    testing.expect(t, !auth.rpc_client_receive(&f.clients[0], 1, old_reply[:count]))
    testing.expect(t, !auth.lease_live(&f.leases[0], 1))
}
