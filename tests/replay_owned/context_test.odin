package replay_owned_test
import "core:testing"
import "core:reflect"
import own "godot:replay/owned"

@(test)
action_context_survives_newer_samples_without_rewinding_the_owned_value :: proc(t: ^testing.T) {
    s := make_state()
    driver: own.Driver
    own.drive(&driver, s, 1, 1, 0, true)
    claim, error := own.capture_context(&driver, Value{40, 20, 5})
    testing.expect_value(t, error, own.Error.None)
    testing.expect(t, driver.sequence == 0 && driver.produced == 0)
    latest := own.Sample(Value){own.scope(s), 1, 8, {80, 20, 5}}
    testing.expect(t, own.accept(&s, 1, latest, 8, rules()).applied)
    before := s
    value, read := own.read_context(&s, 1, claim, 9, rules())
    testing.expect(t, read == .None && value.x == 40 && reflect.equal(s, before))
    // Context reading does not call the stream transition predicate or update its
    // sample sequence. An older/future claim has its own application trust policy.
    claim.value.x = 500
    value, read = own.read_context(&s, 1, claim, 9, rules())
    testing.expect(t, read == .None && value.x == 500 && reflect.equal(s, before))
    _, wrong_owner := own.read_context(&s, 2, claim, 9, rules())
    testing.expect_value(t, wrong_owner, own.Error.Invalid_Owner)
    claim.value.x = 1001
    _, invalid := own.read_context(&s, 1, claim, 9, rules())
    testing.expect_value(t, invalid, own.Error.Invalid_Value)
    testing.expect(t, reflect.equal(s, before))
}

@(test)
action_context_cannot_commit_an_offer_or_cross_lifetime_and_epoch_cuts :: proc(t: ^testing.T) {
    s := make_state()
    owner, prepared: own.Driver
    own.drive(&owner, s, 1, 1, 0, true)
    old, _ := own.capture_context(&owner, s.value)
    own.offer(&s, 2, 1, 10)
    own.drive(&prepared, s, 2, 1, 1, true)
    _, capture_error := own.capture_context(&prepared, s.pending.baseline)
    testing.expect_value(t, capture_error, own.Error.Invalid_Owner)
    pending := own.Action_Context(Value){own.offer_scope(s), s.pending.baseline}
    before := s
    _, error := own.read_context(&s, 2, pending, 1, rules())
    testing.expect_value(t, error, own.Error.Stale_Scope)
    testing.expect(t, reflect.equal(s, before))
    accepted := own.accept(&s, 2, own.Sample(Value){own.offer_scope(s), 1, 1, s.pending.baseline}, 2, rules())
    testing.expect(t, accepted.transferred)
    _, error = own.read_context(&s, 1, old, 2, rules())
    testing.expect_value(t, error, own.Error.Stale_Scope)
    own.drive(&prepared, s, 2, 1, 2, true)
    current, _ := own.capture_context(&prepared, s.value)
    own.cut(&s, 2, s.value, 3, rules())
    _, error = own.read_context(&s, 2, current, 3, rules())
    testing.expect_value(t, error, own.Error.Stale_Scope)
    own.drive(&prepared, s, 2, 1, 3, true)
    current, _ = own.capture_context(&prepared, s.value)
    own.bind_epoch(&s, 2, 4)
    _, error = own.read_context(&s, 2, current, 4, rules())
    testing.expect_value(t, error, own.Error.Stale_Scope)
}
