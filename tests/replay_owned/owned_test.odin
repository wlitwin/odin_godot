package replay_owned_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import own "godot:replay/owned"
import sc "godot:replay/schema"

Value :: struct {
    x, velocity, spin: f32,
}

rules :: proc() -> own.Rules(Value) {
    return {valid = proc(user: rawptr, v: Value) -> bool {
            return(
                own.finite(v.x) &&
                own.finite(v.velocity) &&
                own.finite(v.spin) &&
                abs(v.x) <= 1000 &&
                abs(v.velocity) <= 100 &&
                abs(v.spin) <= 20 \
            )
        }, transition = proc(user: rawptr, before, after: Value, elapsed: u64) -> bool {
            return abs(after.x - before.x) <= f32(elapsed + 1) * 10
        }}
}

make_state :: proc() -> own.State(Value) {
    s: own.State(Value)
    assert(own.init(&s, {1, 0, 1}, 1, 0, 1, Value{0, 20, 5}, rules()) == .None)
    return s
}

@(test)
handoff_keeps_old_owner_until_prepared_sample_then_fences_its_revision :: proc(t: ^testing.T) {
    s := make_state()
    first := own.Sample(Value){own.scope(s), 1, 3, {1, 20, 5}}
    testing.expect(t, own.accept(&s, 1, first, 3, rules()).applied)
    testing.expect_value(t, own.offer(&s, 2, 4, 20), own.Error.None)
    testing.expect_value(t, s.owner, u16(1))
    testing.expect(t, reflect.equal(s.pending.baseline, first.value))
    first.sequence, first.produced, first.value.x = 2, 4, 2
    testing.expect(t, own.accept(&s, 1, first, 5, rules()).applied)
    prepared := own.Sample(Value){own.offer_scope(s), 1, 90, s.pending.baseline}
    result := own.accept(&s, 2, prepared, 6, rules())
    testing.expect(t, result.applied && result.transferred && result.error == .None)
    testing.expect_value(t, s.owner, u16(2))
    testing.expect_value(t, s.active_since, u64(6))
    testing.expect_value(t, s.value.velocity, f32(20))
    testing.expect_value(t, s.value.spin, f32(5))
    testing.expect_value(t, own.accept(&s, 1, first, 7, rules()).error, own.Error.Stale_Scope)
    testing.expect(t, own.valid(s, rules()))
}

@(test)
bad_samples_and_duplicate_conflicts_are_atomic :: proc(t: ^testing.T) {
    s := make_state()
    sample := own.Sample(Value){own.scope(s), 1, 4, {2, 30, 3}}
    testing.expect(t, own.accept(&s, 1, sample, 4, rules()).applied)
    before := s
    duplicate := own.accept(&s, 1, sample, 5, rules())
    testing.expect(t, duplicate.error == .None && !duplicate.applied && reflect.equal(before, s))
    sample.value.x = 3
    testing.expect_value(t, own.accept(&s, 1, sample, 5, rules()).error, own.Error.Conflict)
    sample.sequence = 2
    sample.produced = 3
    testing.expect_value(t, own.accept(&s, 1, sample, 5, rules()).error, own.Error.Invalid_Time)
    sample.produced = 5
    sample.value.x = 500
    testing.expect_value(t, own.accept(&s, 1, sample, 5, rules()).error, own.Error.Invalid_Transition)
    sample.value.x = 2
    sample.value.velocity = 101
    testing.expect_value(t, own.accept(&s, 1, sample, 5, rules()).error, own.Error.Invalid_Value)
    sample.value.velocity = 30
    testing.expect_value(t, own.accept(&s, 2, sample, 5, rules()).error, own.Error.Invalid_Owner)
    sample.scope.key.generation += 1
    testing.expect_value(t, own.accept(&s, 1, sample, 5, rules()).error, own.Error.Stale_Scope)
    testing.expect(t, reflect.equal(before, s))
}

@(test)
expired_and_canceled_offers_cannot_reuse_their_reserved_revision :: proc(t: ^testing.T) {
    s := make_state()
    own.offer(&s, 2, 1, 2)
    stale := own.Sample(Value){own.offer_scope(s), 1, 0, s.pending.baseline}
    testing.expect_value(t, own.accept(&s, 2, stale, 3, rules()).error, own.Error.Expired)
    testing.expect(t, own.expire(&s, 3))
    own.offer(&s, 2, 3, 20)
    testing.expect(t, s.pending.revision > stale.scope.revision)
    testing.expect_value(t, own.accept(&s, 2, stale, 4, rules()).error, own.Error.Stale_Scope)
    newest := s.pending.revision
    testing.expect_value(t, own.cancel(&s, 4), own.Error.None)
    own.offer(&s, 2, 5, 20)
    testing.expect(t, s.pending.revision > newest && s.owner == 1)
    testing.expect(t, own.valid(s, rules()))
}

@(test)
epoch_and_explicit_cuts_preserve_complete_values_and_reject_prior_scopes :: proc(t: ^testing.T) {
    s := make_state()
    own.offer(&s, 2, 2, 20)
    old := own.Sample(Value){own.scope(s), 1, 2, s.value}
    before := s.value
    testing.expect_value(t, own.bind_epoch(&s, 2, 3), own.Error.None)
    testing.expect(t, reflect.equal(before, s.value) && s.pending.revision == 0 && s.owner == 1)
    testing.expect_value(t, own.accept(&s, 1, old, 4, rules()).error, own.Error.Stale_Scope)
    testing.expect_value(t, own.bind_epoch(&s, 1, 4), own.Error.Invalid_Epoch)
    reset := Value{500, -30, -2}
    testing.expect_value(t, own.cut(&s, 0, reset, 4, rules()), own.Error.None)
    testing.expect(t, reflect.equal(reset, s.value) && s.owner == 0 && s.sequence == 0)
    testing.expect_value(
        t,
        own.accept(&s, 0, own.Sample(Value){own.scope(s), 1, 0, reset}, 5, rules()).error,
        own.Error.Invalid_Owner,
    )
    testing.expect(t, own.valid(s, rules()))
}

@(test)
canonical_owner_state_roundtrip_retains_pending_handoff_and_sample_frontiers :: proc(t: ^testing.T) {
    s := make_state()
    sample := own.Sample(Value){own.scope(s), 9, 22, {4, 25, 3}}
    own.accept(&s, 1, sample, 4, rules())
    own.offer(&s, 2, 5, 30)
    codec: sc.Schema
    defer sc.destroy(&codec)
    testing.expect_value(t, sc.init(&codec, own.State(Value)).error, sc.Error.None)
    bytes := make([]u8, codec.wire_size)
    defer delete(bytes)
    testing.expect_value(t, sc.encode(&codec, s, bytes).error, sc.Error.None)
    restored: own.State(Value)
    testing.expect_value(t, sc.decode(&codec, &restored, bytes).error, sc.Error.None)
    testing.expect(t, reflect.equal(s, restored) && own.valid(restored, rules()))
    next := own.Sample(Value){own.offer_scope(restored), 1, 900, restored.pending.baseline}
    testing.expect(t, own.accept(&restored, 2, next, 8, rules()).transferred)
    testing.expect(t, r.value_supported(own.State(Value)))
}

@(test)
exhausted_revisions_and_reference_values_fail_before_mutation :: proc(t: ^testing.T) {
    s := make_state()
    s.revision_counter = max(u64)
    before := s
    testing.expect_value(t, own.offer(&s, 2, 1, 5), own.Error.Exhausted)
    testing.expect_value(t, own.cut(&s, 1, s.value, 1, rules()), own.Error.Exhausted)
    testing.expect_value(t, own.bind_epoch(&s, 2, 1), own.Error.Exhausted)
    testing.expect(t, reflect.equal(before, s))
    invalid: own.State(^i32)
    rule := own.Rules(^i32) {
        valid = proc(user: rawptr, value: ^i32) -> bool {
            return true
        },
    }
    testing.expect_value(t, own.init(&invalid, {1, 0, 1}, 1, 0, 1, cast(^i32)nil, rule), own.Error.Invalid_Value)
}
