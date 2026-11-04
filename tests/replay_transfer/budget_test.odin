package replay_transfer_test

import "core:testing"
import "core:mem"
import tf "godot:replay/transfer"
import tr "godot:replay/transport"

Accounting :: struct {
    live, peak, calls, limit: u64,
    owners:                   u32,
    fail_at:                  u64,
}

hooks :: proc(account: ^Accounting) -> tf.Budget {
    return {user = account, reserve = proc(pointer: rawptr, n: u64) -> bool {
            a := cast(^Accounting)pointer
            a.calls += 1

            if a.calls == a.fail_at || n > a.limit - min(a.limit, a.live) {
                return false
            }

            a.live += n
            a.peak = max(a.peak, a.live)
            return true
        }, release = proc(pointer: rawptr, n: u64) {
            a := cast(^Accounting)pointer
            assert(a.live >= n)
            a.live -= n
        }, acquire = proc(pointer: rawptr) -> bool {
            (cast(^Accounting)pointer).owners += 1
            return true
        }, drop = proc(pointer: rawptr) {
            a := cast(^Accounting)pointer
            assert(a.owners > 0)
            a.owners -= 1
        }}
}

@(test)
optional_budget_preflights_schemas_and_multiple_owners_balance :: proc(t: ^testing.T) {
    a := Accounting {
        limit = 4 * 1024 * 1024,
    }
    sender: tf.Sender
    receiver: tf.Blob_Receiver
    testing.expect_value(
        t,
        tf.sender_init(&sender, SCOPE, 2, {}, archive_kind = PAYLOAD_KIND, budget = hooks(&a)),
        tf.Error.None,
    )
    testing.expect_value(
        t,
        tf.blob_init(&receiver, SCOPE, 1, {}, PAYLOAD_KIND, proc(_: rawptr, _: tf.Archive, _: []u8) -> bool {
                return true
            }, nil, max_bytes = 4096, budget = hooks(&a)),
        tf.Error.None,
    )
    testing.expect_value(t, a.owners, u32(2))
    testing.expect_value(t, a.live, sender.budget.bytes + receiver.budget.bytes)
    testing.expect(
        t,
        len(sender.budget.schema_memory) == tf.SCHEMA_ARENA_BYTES &&
        len(receiver.budget.schema_memory) == tf.SCHEMA_ARENA_BYTES,
    )
    tf.sender_destroy(&sender)
    tf.blob_destroy(&receiver)
    testing.expect_value(t, a.live, u64(0))
    testing.expect_value(t, a.owners, u32(0))
    tracker: mem.Tracking_Allocator
    mem.tracking_allocator_init(&tracker, context.allocator)
    defer mem.tracking_allocator_destroy(&tracker)
    a.limit = 1
    testing.expect_value(
        t,
        tf.sender_init(
            &sender,
            SCOPE,
            2,
            {},
            allocator = mem.tracking_allocator(&tracker),
            archive_kind = PAYLOAD_KIND,
            budget = hooks(&a),
        ),
        tf.Error.Capacity,
    )
    testing.expect_value(t, tracker.total_allocation_count, i64(0))
    testing.expect_value(t, a.live, u64(0))
    testing.expect_value(t, a.owners, u32(0))
}

@(test)
compressed_sender_failure_preserves_old_payload_sequence_and_receipt :: proc(t: ^testing.T) {
    a := Accounting {
        limit = 4 * 1024 * 1024,
    }
    sender: tf.Sender
    testing.expect_value(
        t,
        tf.sender_init(&sender, SCOPE, 2, {}, archive_kind = PAYLOAD_KIND, budget = hooks(&a)),
        tf.Error.None,
    )

    defer {
        tf.sender_destroy(&sender)
        testing.expect_value(t, a.live, u64(0))
        testing.expect_value(t, a.owners, u32(0))
    }

    payload: [4096]u8
    bytes := packet(payload[:], 1)
    defer delete(bytes)
    testing.expect_value(t, tf.sender_begin(&sender, bytes, 0), tf.Error.None)
    sender.phase = .Complete // the replacement policy is independent of the ACK parser
    sender.acknowledged = {
        archive = sender.archive,
    }
    old := sender.archive
    old_pointer := raw_data(sender.bytes)
    old_clock := sender.clock
    baseline := a.live
    next := packet(payload[:], 2)
    defer delete(next)
    sender.compress = true
    // Permit the candidate copy, then reject compression workspace allocation.
    a.fail_at = a.calls + 2
    testing.expect_value(t, tf.sender_begin(&sender, next, 1), tf.Error.Capacity)
    testing.expect_value(t, sender.archive, old)
    testing.expect_value(t, raw_data(sender.bytes), old_pointer)
    testing.expect_value(t, sender.acknowledged.archive, old)
    testing.expect_value(t, sender.clock, old_clock)
    testing.expect_value(t, a.live, baseline)
    a.fail_at = 0
    testing.expect_value(t, tf.sender_begin(&sender, next, 1), tf.Error.None)
    testing.expect(t, len(sender.wire_bytes) > 0)
    testing.expect_value(t, a.live, sender.budget.bytes)
    tf.sender_cancel(&sender)
    testing.expect_value(t, len(sender.bytes) + len(sender.wire_bytes), 0)
}

@(test)
compressed_receiver_partial_allocation_failure_keeps_installed_archive :: proc(t: ^testing.T) {
    fixture: Fixture
    init(&fixture, cap = 65536)
    defer destroy(&fixture)
    a := Accounting {
        limit = 4 * 1024 * 1024,
    }
    testing.expect_value(t, tf.sender_budget_attach(&fixture.sender, hooks(&a)), tf.Error.None)
    testing.expect_value(t, tf.blob_budget_attach(&fixture.receiver, hooks(&a)), tf.Error.None)

    defer {     // fixture owns both transfer owners; destroy before checking callbacks
        tf.sender_destroy(&fixture.sender)
        tf.blob_destroy(&fixture.receiver)
        testing.expect_value(t, a.live, u64(0))
        testing.expect_value(t, a.owners, u32(0))
    }

    payload: [4096]u8
    bytes := packet(payload[:], 1)
    defer delete(bytes)
    testing.expect_value(t, tf.sender_begin(&fixture.sender, bytes, 0), tf.Error.None)

    for _ in 0 ..< 300 {
        pump(&fixture)

        if fixture.sender.phase == .Complete {
            break
        }
    }

    testing.expect_value(t, fixture.installed, u32(1))
    published := fixture.receiver.latest
    fixture.sender.compress = true
    next := packet(payload[:], 2)
    defer delete(next)
    testing.expect_value(t, tf.sender_begin(&fixture.sender, next, fixture.clock), tf.Error.None)
    baseline := a.live
    a.limit = baseline + 65536 // decoded fits, scratch must fail

    for _ in 0 ..< 300 {
        pump(&fixture)

        if fixture.sender.phase == .Failed {
            break
        }
    }

    testing.expect_value(t, fixture.receiver.last_error, tf.Error.Capacity)
    testing.expect_value(t, fixture.receiver.latest, published)
    testing.expect_value(t, fixture.installed, u32(1))
    testing.expect_value(t, len(fixture.receiver.decoded) + len(fixture.receiver.decode_scratch), 0)
    testing.expect_value(t, a.live, baseline)
}

@(test)
budget_reattach_requires_complete_lease_table_and_acquisition_failures_clean_up :: proc(t: ^testing.T) {
    a := Accounting {
        limit = 4 * 1024 * 1024,
    }
    sender: tf.Sender
    testing.expect_value(
        t,
        tf.sender_init(&sender, SCOPE, 2, {}, archive_kind = PAYLOAD_KIND, budget = hooks(&a)),
        tf.Error.None,
    )
    base_live, base_owners := a.live, a.owners
    changed := hooks(&a)
    changed.acquire = proc(_: rawptr) -> bool {
        return false
    }
    testing.expect_value(t, tf.sender_budget_attach(&sender, changed), tf.Error.Invalid_Config)
    testing.expect_value(t, a.live, base_live)
    testing.expect_value(t, a.owners, base_owners)
    changed = hooks(&a)
    changed.drop = proc(_: rawptr) {}
    testing.expect_value(t, tf.sender_budget_attach(&sender, changed), tf.Error.Invalid_Config)
    testing.expect_value(t, a.live, base_live)
    testing.expect_value(t, a.owners, base_owners)
    tf.sender_destroy(&sender)
    changed = hooks(&a)
    changed.acquire = proc(_: rawptr) -> bool {
        return false
    }
    testing.expect_value(
        t,
        tf.sender_init(&sender, SCOPE, 2, {}, archive_kind = PAYLOAD_KIND, budget = changed),
        tf.Error.Capacity,
    )
    testing.expect_value(t, a.live, u64(0))
    testing.expect_value(t, a.owners, u32(0))
    changed = hooks(&a)
    changed.drop = nil
    testing.expect_value(
        t,
        tf.sender_init(&sender, SCOPE, 2, {}, archive_kind = PAYLOAD_KIND, budget = changed),
        tf.Error.Invalid_Config,
    )
    testing.expect_value(t, a.live, u64(0))
    testing.expect_value(t, a.owners, u32(0))
    testing.expect_value(
        t,
        tf.sender_init(
            &sender,
            SCOPE,
            2,
            {},
            allocator = mem.nil_allocator(),
            archive_kind = PAYLOAD_KIND,
            budget = hooks(&a),
        ),
        tf.Error.Capacity,
    )
    testing.expect_value(t, a.live, u64(0))
    testing.expect_value(t, a.owners, u32(0))
}
