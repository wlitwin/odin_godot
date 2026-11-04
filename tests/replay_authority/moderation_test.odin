package replay_authority_test

import "core:testing"
import "core:reflect"
import auth "godot:replay/authority"
import tr "godot:replay/transport"
import sc "godot:replay/schema"

remove_call :: proc(f: ^Rpc_Fixture, actor: int, epoch: u64, target: auth.Identity) -> auth.Reply {
    assert(auth.rpc_remove(&f.clients[actor], epoch, target) == .None)

    for _ in 0 ..< 100 {
        rpc_step(f)

        if reply, done := auth.rpc_completed(&f.clients[actor]); done {
            return reply
        }
    }

    assert(false, "removal did not complete")
    return {}
}

@(test)
durable_removal_invalidates_prepared_successor_and_exact_retry_is_idempotent :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    testing.expect_value(t, rpc_call(&f, 0, {verb = .Start}).result, auth.Error.None)
    testing.expect_value(
        t,
        rpc_call(&f, 0, {verb = .Nominate, epoch = 1, successor = B, binding = 9}).result,
        auth.Error.None,
    )
    testing.expect_value(t, rpc_call(&f, 1, {verb = .Prepare, point = point()}).result, auth.Error.None)
    testing.expect(t, f.ledger.record.prepared)
    testing.expect_value(t, remove_call(&f, 0, 1, B).result, auth.Error.None)
    testing.expect(
        t,
        !f.ledger.record.members[1].enabled &&
        !f.ledger.record.prepared &&
        f.ledger.record.nominee == (auth.Identity{}),
    )
    revision, writes := f.ledger.record.revision, f.ledger.writes
    request := f.clients[0].txb
    count := f.clients[0].count
    testing.expect(t, auth.service_receive(&f.service, 2, request[:count]))
    testing.expect_value(t, f.ledger.record.revision, revision)
    testing.expect_value(t, f.ledger.writes, writes)
    f.clock.now += 2000
    testing.expect_value(
        t,
        auth.coordinator_claim(&f.service.coordinator, B, 1, 99, point(), f.clock.now),
        auth.Error.Denied,
    )
    // Restart from durable state cannot restore the target's right to claim.
    keys := [1]auth.Credential{f.service.credentials[0]}
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
    f.clock.now += 2000
    testing.expect_value(
        t,
        auth.coordinator_claim(&f.service.coordinator, B, 1, 100, point(), f.clock.now),
        auth.Error.Denied,
    )
}

@(test)
removal_requires_live_authority_and_exact_target_incarnation :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    rpc_call(&f, 0, {verb = .Start})
    testing.expect_value(t, remove_call(&f, 1, 1, A).result, auth.Error.Denied)
    testing.expect_value(t, remove_call(&f, 0, 1, A).result, auth.Error.Denied)
    testing.expect_value(t, remove_call(&f, 0, 2, B).result, auth.Error.Denied)
    testing.expect_value(t, remove_call(&f, 0, 1, {B.member, B.incarnation + 1}).result, auth.Error.Stale)
    testing.expect(t, f.ledger.record.members[0].enabled && f.ledger.record.members[1].enabled)
    f.clock.now = 5000
    // Direct coordinator call fixes the expiry boundary independently of pump time.
    testing.expect_value(t, auth.coordinator_remove(&f.service.coordinator, A, 1, B, f.clock.now), auth.Error.Denied)
}

@(test)
removal_cannot_commit_on_storage_failure_or_be_reinterpreted_as_query :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    rpc_call(&f, 0, {verb = .Start})
    before := f.ledger.record
    f.ledger.fail = true
    testing.expect_value(t, remove_call(&f, 0, 1, B).result, auth.Error.Storage)
    testing.expect(t, reflect.equal(before, f.ledger.record) && f.service.coordinator.poisoned)
}

@(test)
query_and_removal_have_distinct_authenticated_envelope_domains :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    rpc_call(&f, 0, {verb = .Start})
    // An ordinary Query may contain unused fields; its authenticated operation
    // remains Query. It must not become a removal merely because fields resemble it.
    testing.expect_value(t, rpc_call(&f, 0, {verb = .Query, epoch = 1, successor = B}).result, auth.Error.None)
    testing.expect(t, f.ledger.record.members[1].enabled)
    bytes := f.clients[0].txb
    count := f.clients[0].count
    before := f.ledger.writes
    meta, fingerprint, report := sc.inspect(bytes[:count - 32])
    assert(report.error == .None)
    meta.kind = auth.RPC_REMOVE_REQUEST
    // Recompute the unkeyed envelope checksum but retain the original Query MAC.
    // Domain separation must still refuse the rewritten operation before storage.
    assert(sc.pack_bytes(fingerprint, meta, bytes[sc.HEADER_BYTES:count - 32], bytes[:count - 32]).error == .None)
    testing.expect(t, !auth.service_receive(&f.service, 2, bytes[:count]))
    testing.expect_value(t, f.ledger.writes, before)
}

@(test)
disabled_members_receive_only_authenticated_denial_without_a_new_lease :: proc(t: ^testing.T) {
    f: Rpc_Fixture
    rpc_setup(&f)
    defer rpc_destroy(&f)
    rpc_call(&f, 0, {verb = .Start})
    testing.expect_value(t, remove_call(&f, 0, 1, B).result, auth.Error.None)
    writes := f.ledger.writes
    reply := rpc_call(&f, 1, {verb = .Query})
    testing.expect_value(t, reply.result, auth.Error.Denied)
    testing.expect(
        t,
        reply.view.remaining_ms == 0 &&
        reply.view.owner == (auth.Identity{}) &&
        reply.view.endpoint == (auth.Endpoint{}) &&
        reply.point == (auth.Point{}),
    )
    testing.expect(t, reply.members[0].identity == B && !reply.members[0].enabled)

    for member in reply.members[1:] {
        testing.expect_value(t, member, auth.Member{})
    }

    testing.expect_value(t, f.ledger.writes, writes)
    testing.expect(t, !auth.lease_live(&f.leases[1], 1))
    testing.expect_value(t, rpc_call(&f, 1, {verb = .Challenge}).result, auth.Error.Denied)
    testing.expect_value(t, f.ledger.writes, writes)
}
