package replay_owned_test

import "core:testing"
import own "godot:replay/owned"

@(test)
prepared_driver_keeps_its_solver_and_sequence_when_its_offer_commits :: proc(t: ^testing.T) {
    s := make_state()
    own.offer(&s, 2, 1, 20)
    d: own.Driver
    choice := own.drive(&d, s, 2, 1, 1, true)
    testing.expect(t, choice.error == .None && choice.role == .Preparing && choice.reseed)
    sample, err := own.capture(&d, choice.baseline)
    testing.expect_value(t, err, own.Error.None)
    testing.expect(t, own.accept(&s, 2, sample, 3, rules()).transferred)
    choice = own.drive(&d, s, 2, 1, 3, true)
    testing.expect(t, choice.role == .Owner && !choice.reseed)
    next, _ := own.capture(&d, choice.baseline)
    testing.expect_value(t, next.sequence, sample.sequence + 1)
    testing.expect(t, own.accept(&s, 2, next, 4, rules()).applied)
}

@(test)
fresh_driver_rebases_producer_ticks_and_lost_permission_cannot_publish :: proc(t: ^testing.T) {
    s := make_state()
    previous := own.Sample(Value){own.scope(s), 40, 900, s.value}
    own.accept(&s, 1, previous, 2, rules())
    d: own.Driver
    choice := own.drive(&d, s, 1, 1, 2, true)
    testing.expect(t, choice.reseed && choice.role == .Owner)
    sample, _ := own.capture(&d, s.value)
    testing.expect_value(t, sample.sequence, u64(41))
    testing.expect_value(t, sample.produced, u64(901))
    choice = own.drive(&d, s, 1, 1, 2, false)
    testing.expect_value(t, choice.role, own.Role.Observer)
    _, err := own.capture(&d, s.value)
    testing.expect_value(t, err, own.Error.Invalid_Owner)
    choice = own.drive(&d, s, 1, 1, 2, true)
    testing.expect(t, choice.reseed)
    sample, _ = own.capture(&d, s.value)
    testing.expect_value(t, sample.sequence, u64(42))
    testing.expect_value(t, own.drive(&d, s, 1, 1, 1, true).error, own.Error.Invalid_Time)
    // A migration can recover an older world tick under a newer authority epoch.
    choice = own.drive(&d, make_state(), 1, 2, 0, true)
    testing.expect_value(t, choice.role, own.Role.Observer)
}

@(test)
pose_limits_use_finite_norms_and_quaternion_constraints :: proc(t: ^testing.T) {
    limits2 := own.Limits2{{-10, -10}, {10, 10}, 1e38, 20}
    p2 := own.Pose2 {
        linear = {1e38, 1e38},
    }
    testing.expect(t, !own.pose2_valid(p2, limits2))
    p2.linear = {10, 0}
    testing.expect(t, own.pose2_valid(p2, limits2))
    p2.rotation = transmute(f32)u32(0x7fc00000)
    testing.expect(t, !own.pose2_valid(p2, limits2))
    limits3 := own.Limits3{{-10, -10, -10}, {10, 10, 10}, 10, 20}
    p3 := own.Pose3 {
        rotation = {0, 0, 0, 1},
        linear   = {3, 4, 0},
        angular  = {0, 1, 0},
    }
    testing.expect(t, own.pose3_valid(p3, limits3))
    p3.rotation = {0, 0, 0, -1}
    testing.expect(t, own.pose3_valid(p3, limits3))
    p3.rotation = {}
    testing.expect(t, !own.pose3_valid(p3, limits3))
    p3.rotation = {0, 0, 0, 1}
    p3.angular[0] = 30
    testing.expect(t, !own.pose3_valid(p3, limits3))
}
