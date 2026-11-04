package replay_authority_test

import "core:reflect"
import "core:testing"
import auth "godot:replay/authority"
import rec "godot:replay/recovery"
import sc "godot:replay/schema"

A :: auth.Identity{1, 101}
B :: auth.Identity{2, 102}
C :: auth.Identity{3, 103}

Ledger :: struct {
    record: auth.Record,
    fail:   bool,
    writes: int,
}

commit :: proc(user: rawptr, expected: u64, next: auth.Record) -> bool {
    ledger := cast(^Ledger)user

    if ledger.fail || ledger.record.revision != expected {
        return false
    }

    ledger.record = next
    ledger.writes += 1
    return true
}

Clock :: struct {
    now:            u64,
    bad:            bool,
    reads, jump_on: int,
    jump_to:        u64,
}

read_clock :: proc(user: rawptr) -> (u64, bool) {
    c := cast(^Clock)user
    c.reads += 1

    if c.jump_on != 0 && c.reads == c.jump_on {
        c.now = c.jump_to
    }

    return c.now, !c.bad
}

clock_source :: proc(c: ^Clock) -> auth.Clock_Source {
    return {c, read_clock}
}

setup :: proc(c: ^auth.Coordinator, ledger: ^Ledger, mode := auth.Mode.Cooperative, drift: u32 = 1000) {
    policy := auth.DEFAULT_POLICY
    policy.lease_ms, policy.mode, policy.drift_ppm = 1000, mode, drift
    ledger.record = auth.record_make(44, 55, A, policy)
    assert(auth.coordinator_init(c, ledger.record, commit, ledger, 0) == .None)
    ids := [3]auth.Identity{A, B, C}

    for id, i in ids {
        address, _ := auth.endpoint("127.0.0.1", u16(45000 + i))
        assert(
            auth.coordinator_member(
                c,
                {
                    identity = id,
                    endpoint = address,
                    enabled = true,
                    can_host = true,
                    trusted_authority = true,
                    infrastructure = i != 1,
                },
                0,
            ) ==
            .None,
        )
    }

    assert(auth.coordinator_start(c, A, 1, 0) == .None)
}

point :: proc(tick: u64 = 10) -> auth.Point {
    return {{44, 1, 9, 55}, {sequence = 1, tick = tick, bytes = 512, hash = {0 = 17}}}
}

prepare :: proc(c: ^auth.Coordinator, tick: u64 = 10) {
    assert(auth.coordinator_nominate(c, A, 1, B, 9, 0) == .None)
    assert(auth.coordinator_prepare(c, B, point(tick), 0) == .None)
}

grant_lease :: proc(l: ^auth.Lease, c: ^auth.Coordinator, clock: ^Clock, id: auth.Identity, require_owner := true) {
    assert(auth.lease_init(l, id, 44, 55, clock_source(clock), require_owner) == .None)
    sequence, err := auth.lease_request(l)
    assert(err == .None)
    view, result := auth.coordinator_view(c, c.now)
    assert(result == .None)
    assert(auth.lease_accept(l, sequence, view) == .None)
}

@(test)
partition_waits_for_expiry_and_only_the_prepared_nominee_can_claim :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    prepare(&c)
    clock: Clock
    old: auth.Lease
    grant_lease(&old, &c, &clock, A)
    testing.expect_value(t, auth.coordinator_claim(&c, B, 1, 1, point(), 900), auth.Error.Busy)
    clock.now = 1000
    testing.expect(t, !auth.lease_live(&old, 1))
    testing.expect_value(t, auth.coordinator_claim(&c, C, 1, 1, point(), 1000), auth.Error.Denied)
    testing.expect_value(t, auth.coordinator_claim(&c, B, 1, 1, point(), 1000), auth.Error.None)
    testing.expect_value(t, ledger.record.owner, B)
    testing.expect_value(t, ledger.record.epoch, u64(2))
    testing.expect_value(t, ledger.record.recovery, auth.Recovery_Kind.Abrupt)
    testing.expect_value(t, auth.coordinator_renew(&c, A, 1, 2, 11, 1001), auth.Error.Denied)
    testing.expect_value(t, auth.coordinator_claim(&c, B, 1, 2, point(), 1001), auth.Error.Stale)
}

@(test)
planned_release_requires_a_prepared_final_archive_and_irrevocable_local_retirement :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    prepare(&c)
    clock: Clock
    old: auth.Lease
    grant_lease(&old, &c, &clock, A)
    retired, err := auth.lease_retire(&old)
    testing.expect_value(t, err, auth.Error.None)
    testing.expect(t, !auth.lease_live(&old, 1))
    wrong := point()
    wrong.archive.hash[1] = 7
    testing.expect_value(t, auth.coordinator_release(&c, A, retired, wrong, 100), auth.Error.No_Checkpoint)
    testing.expect_value(t, auth.coordinator_release(&c, A, retired, point(), 100), auth.Error.None)
    testing.expect_value(t, auth.coordinator_release(&c, A, retired, point(), 100), auth.Error.None)
    testing.expect_value(t, auth.coordinator_claim(&c, B, 1, 1, point(), 100), auth.Error.None)
    testing.expect_value(t, c.record.recovery, auth.Recovery_Kind.Planned)
    sequence, _ := auth.lease_request(&old)
    view, _ := auth.coordinator_view(&c, 100)
    testing.expect_value(t, auth.lease_accept(&old, sequence, view), auth.Error.None)
    testing.expect(t, !auth.lease_live(&old, 2)) // old owner cannot use another identity's lease
}

@(test)
durable_cas_failure_and_restart_quarantine_fence_an_old_coordinator :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    prepare(&c)
    before := ledger.record
    ledger.fail = true
    testing.expect_value(t, auth.coordinator_renew(&c, A, 1, 2, 20, 100), auth.Error.Storage)
    testing.expect(t, reflect.equal(before, ledger.record))
    _, err := auth.coordinator_view(&c, 100)
    testing.expect_value(t, err, auth.Error.Storage)
    ledger.fail = false
    restarted: auth.Coordinator
    testing.expect_value(t, auth.coordinator_init(&restarted, ledger.record, commit, &ledger, 200), auth.Error.None)
    testing.expect(t, restarted.quarantine_until > 1200)
    testing.expect_value(t, auth.coordinator_claim(&restarted, B, 1, 1, point(), 1200), auth.Error.Busy)
    testing.expect_value(
        t,
        auth.coordinator_claim(&restarted, B, 1, 1, point(), restarted.quarantine_until),
        auth.Error.None,
    )
    testing.expect_value(t, ledger.record.epoch, u64(2))
    testing.expect_value(t, ledger.record.recovery, auth.Recovery_Kind.Coordinator_Restart)
    // An earlier still-running instance also loses its ability to persist grants.
    d: auth.Coordinator
    other: Ledger
    setup(&d, &other)
    replacement: auth.Coordinator
    auth.coordinator_init(&replacement, other.record, commit, &other, 100)
    testing.expect_value(t, auth.coordinator_renew(&d, A, 1, 2, 1, 100), auth.Error.Storage)
}

@(test)
late_replies_duplicate_renewals_and_bad_clocks_cannot_extend_a_lease :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    clock: Clock
    lease: auth.Lease
    auth.lease_init(&lease, A, 44, 55, clock_source(&clock), true)
    sequence, _ := auth.lease_request(&lease)
    view, _ := auth.coordinator_view(&c, 0)
    clock.now = 2000
    testing.expect_value(t, auth.lease_accept(&lease, sequence, view), auth.Error.None)
    testing.expect(t, !auth.lease_live(&lease, 1))
    testing.expect_value(t, auth.lease_accept(&lease, sequence, view), auth.Error.Stale)
    testing.expect_value(t, auth.coordinator_renew(&c, A, 1, 2, 10, 100), auth.Error.None)
    expires := c.expires
    testing.expect_value(t, auth.coordinator_renew(&c, A, 1, 2, 10, 500), auth.Error.Stale)
    testing.expect_value(t, c.expires, expires)
    clock.now -= 1
    testing.expect(t, !auth.lease_live(&lease, 1))
    testing.expect(t, lease.poisoned)
    _, err := auth.lease_request(&lease)
    testing.expect_value(t, err, auth.Error.Clock)
}

@(test)
conservative_deadlines_hold_at_opposite_clock_rate_bounds_without_clock_sync :: proc(t: ^testing.T) {
    skews := [2]i64{-10000, 10000}

    for coordinator_skew in skews {
        c: auth.Coordinator
        ledger: Ledger
        setup(&c, &ledger, drift = 10000)
        prepare(&c)
        clock := Clock {
            now = 50000,
        }
        lease: auth.Lease
        grant_lease(&lease, &c, &clock, A)
        claimed := false

        for real_ms in u64(0) ..< 1100 {
            service_now := u64(i64(real_ms) * (1000000 + coordinator_skew) / 1000000)
            clock.now = 50000 + u64(i64(real_ms) * (1000000 - coordinator_skew) / 1000000)

            if service_now >= c.expires && !claimed {
                testing.expect(t, !auth.lease_live(&lease, 1))
                testing.expect_value(t, auth.coordinator_claim(&c, B, 1, 1, point(), service_now), auth.Error.None)
                claimed = true
            }
        }

        testing.expect(t, claimed)
    }
}

@(test)
eligibility_incarnation_and_known_rollback_limit_are_enforced :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger, .Dedicated)
    testing.expect_value(t, auth.coordinator_nominate(&c, A, 1, B, 9, 0), auth.Error.Denied)
    testing.expect_value(t, auth.coordinator_nominate(&c, A, 1, C, 9, 0), auth.Error.None)
    testing.expect_value(t, auth.coordinator_prepare(&c, {C.member, C.incarnation + 1}, point(), 0), auth.Error.Denied)
    testing.expect_value(t, auth.coordinator_prepare(&c, C, point(), 0), auth.Error.None)
    auth.coordinator_renew(&c, A, 1, 2, 1000, 0)
    testing.expect_value(t, auth.coordinator_claim(&c, C, 1, 1, point(), 1000), auth.Error.Too_Old)
    member := c.record.members[2]
    member.enabled = false
    auth.coordinator_member(&c, member, 1000)
    testing.expect_value(t, auth.coordinator_claim(&c, C, 1, 1, point(), 1000), auth.Error.Denied)
}

@(test)
native_clock_is_available_and_monotonic_on_the_test_host :: proc(t: ^testing.T) {
    clock := auth.native_clock()
    a, ok := clock.read(clock.user)
    b, also := clock.read(clock.user)
    testing.expect(t, ok && also && b >= a)
}

@(test)
consecutive_migrations_and_old_host_return_require_a_fresh_nomination_and_epoch :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    prepare(&c)
    auth.coordinator_claim(&c, B, 1, 1, point(), 1000)
    testing.expect_value(t, auth.coordinator_nominate(&c, A, 1, C, 10, 1001), auth.Error.Denied)
    testing.expect_value(t, auth.coordinator_nominate(&c, B, 2, C, 10, 1001), auth.Error.None)
    next := point(20)
    next.scope.epoch, next.scope.binding = 2, 10
    testing.expect_value(t, auth.coordinator_prepare(&c, C, next, 1001), auth.Error.None)
    testing.expect_value(t, auth.coordinator_claim(&c, C, 2, 1, next, 2000), auth.Error.None)
    testing.expect_value(t, c.record.epoch, u64(3))
    testing.expect_value(t, auth.coordinator_renew(&c, B, 2, 2, 20, 2001), auth.Error.Denied)
    returned := c.record.members[0]
    returned.identity.incarnation += 1
    auth.coordinator_member(&c, returned, 2001)
    testing.expect_value(t, auth.coordinator_nominate(&c, C, 3, A, 11, 2001), auth.Error.Denied)
    testing.expect_value(t, auth.coordinator_nominate(&c, C, 3, returned.identity, 11, 2001), auth.Error.None)
    testing.expect_value(t, auth.coordinator_prepare(&c, returned.identity, point(), 2001), auth.Error.Invalid)
}

@(test)
decision_record_canonical_roundtrip_preserves_epoch_floor_and_permissions :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    prepare(&c)
    schema: sc.Schema
    defer sc.destroy(&schema)
    testing.expect_value(t, sc.init(&schema, auth.Record).error, sc.Error.None)
    bytes := make([]u8, schema.wire_size)
    defer delete(bytes)
    testing.expect_value(t, sc.encode(&schema, ledger.record, bytes).error, sc.Error.None)
    decoded: auth.Record
    testing.expect_value(t, sc.decode(&schema, &decoded, bytes).error, sc.Error.None)
    testing.expect(t, auth.record_valid(decoded) && reflect.equal(decoded, ledger.record))
    decoded.members[1].identity = decoded.members[0].identity
    testing.expect(t, !auth.record_valid(decoded))
}

@(test)
restart_after_a_committed_but_unconsumed_grant_can_use_its_exact_recovery_point :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    prepare(&c)
    testing.expect_value(t, auth.coordinator_claim(&c, B, 1, 1, point(), 1000), auth.Error.None)
    // No B runtime/lease is constructed: the service dies before B uses epoch 2.
    restarted: auth.Coordinator
    auth.coordinator_init(&restarted, ledger.record, commit, &ledger, 1001)
    wrong := point()
    wrong.archive.hash[0] ~= 1
    testing.expect_value(
        t,
        auth.coordinator_recover_owner(&restarted, B, 2, 2, wrong, restarted.quarantine_until),
        auth.Error.Invalid,
    )
    testing.expect_value(
        t,
        auth.coordinator_recover_owner(&restarted, B, 2, 2, point(), restarted.quarantine_until),
        auth.Error.None,
    )
    testing.expect_value(t, restarted.record.epoch, u64(3))
    testing.expect_value(t, restarted.record.recovered, point())
}

@(test)
surviving_owner_can_reacquire_only_after_expiry_and_under_a_new_epoch :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    prepare(&c)
    testing.expect_value(t, auth.coordinator_recover_owner(&c, A, 1, 2, point(), 999), auth.Error.Busy)
    testing.expect_value(t, auth.coordinator_recover_owner(&c, A, 1, 2, point(), 1000), auth.Error.None)
    testing.expect_value(t, c.record.epoch, u64(2))
    testing.expect_value(t, auth.coordinator_claim(&c, B, 1, 1, point(), 1001), auth.Error.Stale)
}

@(test)
released_owner_fallback_requires_the_exact_sealed_world_and_a_new_epoch :: proc(t: ^testing.T) {
    c: auth.Coordinator
    ledger: Ledger
    setup(&c, &ledger)
    prepare(&c)
    clock: Clock
    lease: auth.Lease
    grant_lease(&lease, &c, &clock, A)
    retired, _ := auth.lease_retire(&lease)
    testing.expect_value(t, auth.coordinator_release(&c, A, retired, point(), 100), auth.Error.None)
    wrong := point()
    wrong.archive.hash[0] ~= 1
    testing.expect_value(t, auth.coordinator_recover_owner(&c, A, 1, 2, wrong, 101), auth.Error.No_Checkpoint)
    testing.expect_value(t, auth.coordinator_recover_owner(&c, A, 1, 2, point(), 101), auth.Error.None)
    testing.expect_value(t, c.record.epoch, u64(2))
    testing.expect_value(t, auth.coordinator_claim(&c, B, 1, 1, point(), 102), auth.Error.Stale)
    testing.expect(t, !auth.lease_live(&lease, 1))
}
