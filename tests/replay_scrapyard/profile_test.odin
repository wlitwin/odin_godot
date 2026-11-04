package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import r "godot:replay"
import game "../../examples/replay_scrapyard/shared/game"
import profile "../../examples/replay_scrapyard/shared/profile"

@(test)
profile_record_is_identity_bound_and_rejects_corruption :: proc(t: ^testing.T) {
    record := profile.Record {
        identity = {0 = 17},
        profile = {meta = {7, 2}, name = game.name("axle"), look = 1, iron = 3, abilities = {1, 5}},
        epoch = 2,
        tick = 100,
    }
    bytes, err := profile.encode(record)
    defer delete(bytes)
    testing.expect_value(t, err, profile.Error.None)
    got, read := profile.decode(bytes, record.identity)
    testing.expect_value(t, read, profile.Error.None)
    testing.expect(t, reflect.equal(got, record))
    _, read = profile.decode(bytes, [32]u8{0 = 18})
    testing.expect_value(t, read, profile.Error.Identity)
    bytes[len(bytes) - 1] ~= 1
    _, read = profile.decode(bytes, record.identity)
    testing.expect_value(t, read, profile.Error.Codec)
}

@(test)
opening_meta_claim_is_applied_once_and_cannot_refund_a_purchase :: proc(t: ^testing.T) {
    w := game.initial()
    w.players[0].connected = true
    storage: [32]r.Occurrence(game.Event)
    ctx := r.Step(game.Event) {
        epoch  = 1,
        events = storage[:],
    }
    claim := game.Profile {
        meta      = {7, 2},
        name      = game.name("axle"),
        abilities = {1, 2},
    }
    testing.expect(t, game.action(&w, 1, game.Action{kind = .Profile, profile = claim}, &ctx))
    testing.expect_value(t, w.players[0].cores, u32(7))
    testing.expect_value(t, w.players[0].parts, u8(2))
    w.players[0].cores = 2 // authority expenditure after the opening claim
    claim.name = game.name("renamed")
    testing.expect(t, game.action(&w, 1, game.Action{kind = .Profile, profile = claim}, &ctx))
    testing.expect_value(t, w.players[0].cores, u32(2))
    testing.expect_value(t, w.players[0].profile.meta.cores, u32(2))
    game.enter(&w, 1, &ctx)
    testing.expect_value(t, w.players[0].hp, u8(14))
    testing.expect(t, !game.action(&w, 1, game.Action{kind = .Profile, profile = claim}, &ctx))
}
