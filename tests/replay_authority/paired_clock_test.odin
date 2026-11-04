package replay_authority_test

import "core:testing"
import auth "godot:replay/authority"

@(test)
paired_clock_accounts_for_suspend_and_does_not_freeze_after_wall_offset :: proc(t: ^testing.T) {
    c: auth.Paired_Clock
    now, ok := auth.paired_clock_sample(&c, 1000000, 50)
    testing.expect(t, ok && now == 0)
    now, ok = auth.paired_clock_sample(&c, 1000100, 150)
    testing.expect(t, ok && now == 100)
    now, ok = auth.paired_clock_sample(&c, 1005100, 150)
    testing.expect(t, ok && now == 5100)
    // A slowed wall source after a forward adjustment must not hide monotonic time.
    now, ok = auth.paired_clock_sample(&c, 1005101, 250)
    testing.expect(t, ok && now == 5200)
}

@(test)
paired_clock_poisoning_never_revives_an_existing_lease :: proc(t: ^testing.T) {
    for source in 0 ..< 2 {
        c: auth.Paired_Clock
        auth.paired_clock_sample(&c, 1000, 1000)
        _, ok := auth.paired_clock_sample(&c, source == 0 ? 999 : 1001, source == 1 ? 999 : 1001)
        testing.expect(t, !ok && c.poisoned)
        _, ok = auth.paired_clock_sample(&c, 2000, 2000)
        testing.expect(t, !ok)
    }
}

@(test)
paired_clock_overflow_fails_closed :: proc(t: ^testing.T) {
    c: auth.Paired_Clock
    auth.paired_clock_sample(&c, 0, 0)
    now, ok := auth.paired_clock_sample(&c, max(u64) - 1, 0)
    testing.expect(t, ok && now == max(u64) - 1)
    _, ok = auth.paired_clock_sample(&c, max(u64), 2)
    testing.expect(t, !ok && c.poisoned)
}

Paired_Source :: struct {
    clock:           auth.Paired_Clock,
    wall, monotonic: u64,
}

paired_read :: proc(user: rawptr) -> (u64, bool) {
    source := cast(^Paired_Source)user
    return auth.paired_clock_sample(&source.clock, source.wall, source.monotonic)
}

@(test)
paired_clock_suspension_expires_a_real_authority_lease :: proc(t: ^testing.T) {
    source := Paired_Source {
        wall      = 100000,
        monotonic = 1000,
    }
    lease: auth.Lease
    testing.expect_value(t, auth.lease_init(&lease, A, 44, 55, {&source, paired_read}, true), auth.Error.None)
    request, err := auth.lease_request(&lease)
    testing.expect_value(t, err, auth.Error.None)
    endpoint, ok := auth.endpoint("127.0.0.1", 45000)
    assert(ok)
    grant := auth.View {
        room                   = 44,
        content                = 55,
        revision               = 1,
        epoch                  = 1,
        coordinator_generation = 1,
        owner                  = A,
        endpoint               = endpoint,
        remaining_ms           = 2000,
        policy                 = auth.DEFAULT_POLICY,
    }
    testing.expect_value(t, auth.lease_accept(&lease, request, grant), auth.Error.None)
    testing.expect(t, auth.lease_live(&lease, 1))
    source.wall += 3000 // monotonic clock stops during simulated system sleep
    testing.expect(t, !auth.lease_live(&lease, 1) && !lease.poisoned)
    source.wall -= 1
    testing.expect(t, !auth.lease_live(&lease, 1) && lease.poisoned)
    source.wall += 10000
    source.monotonic += 10000
    testing.expect(t, !auth.lease_live(&lease, 1))
}
