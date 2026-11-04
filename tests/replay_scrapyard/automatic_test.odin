package replay_scrapyard_test

import "core:testing"
import "core:reflect"
import sc "godot:replay/schema"
import game "../../examples/replay_scrapyard/shared/game"
import profile "../../examples/replay_scrapyard/shared/profile"

@(test)
automatic_loadout_resolves_again_for_a_new_seat :: proc(t: ^testing.T) {
    w := game.initial()
    value := game.Profile {
        look      = 0,
        iron      = 5,
        abilities = {5, 6},
        meta      = {7, 2},
        name      = game.name("axle"),
    }
    first, ok := profile.resolve(value, profile.AUTOMATIC_ALL, 1, &w.catalog)
    testing.expect(t, ok)
    second, valid := profile.resolve(value, profile.AUTOMATIC_ALL, 2, &w.catalog)
    testing.expect(t, valid)
    testing.expect_value(t, first.look, u8(1))
    testing.expect_value(t, first.iron, u8(0))
    testing.expect_value(t, second.look, u8(2))
    testing.expect_value(t, second.iron, u8(1))
    testing.expect_value(t, first.abilities, [2]u8{1, 2})
    testing.expect_value(t, first.meta, value.meta)
    mixed, mixed_ok := profile.resolve(value, 3, 3, &w.catalog)
    testing.expect(t, mixed_ok)
    testing.expect_value(t, mixed.look, u8(0))
    testing.expect_value(t, mixed.iron, u8(2))
    testing.expect_value(t, mixed.abilities, value.abilities)
    explicit, explicit_ok := profile.resolve(value, 0, 4, &w.catalog)
    testing.expect(t, explicit_ok && reflect.equal(explicit, value))
    _, bad := profile.resolve(value, 16, 1, &w.catalog)
    testing.expect(t, !bad)
    _, observer := profile.resolve(value, 15, 0, &w.catalog)
    testing.expect(t, !observer)
}

@(test)
every_picker_can_enter_and_leave_auto_without_exposing_sparse_holes :: proc(t: ^testing.T) {
    w := game.initial()
    w.catalog.guns[1] = {}
    w.catalog.guns[2] = {}
    w.catalog.abilities[1] = {}
    w.catalog.abilities[2] = {}
    value := game.Profile {
        ready     = true,
        abilities = {3, 4},
    }

    for field in 0 ..< 4 {
        bit := u8(1) << uint(field)
        next, mask := profile.cycle(&w.catalog, value, 15, field, 1)
        testing.expect(t, mask & bit == 0 && !next.ready)

        if field >= 2 {
            testing.expect_value(t, next.abilities[field - 2], u8(3))
        }

        _, back := profile.cycle(&w.catalog, next, mask, field, -1)
        testing.expect_value(t, back, u8(15))
        last, last_mask := profile.cycle(&w.catalog, value, 15, field, -1)
        testing.expect(t, last_mask & bit == 0)
        _, wrapped := profile.cycle(&w.catalog, last, last_mask, field, 1)
        testing.expect_value(t, wrapped, u8(15))
    }

    resolved, ok := profile.resolve(value, 15, 2, &w.catalog)
    testing.expect(t, ok)
    testing.expect_value(t, resolved.iron, u8(3))
    testing.expect_value(t, resolved.abilities, [2]u8{3, 3})
}

@(test)
profile_v2_keeps_automatic_flags_and_rejects_undefined_bits :: proc(t: ^testing.T) {
    record := profile.Record {
        identity = {0 = 17},
        profile = {look = 2, iron = 1, abilities = {1, 2}},
        automatic = 15,
    }
    bytes, err := profile.encode(record)
    defer delete(bytes)
    testing.expect_value(t, err, profile.Error.None)
    got, read := profile.decode(bytes, record.identity)
    testing.expect_value(t, read, profile.Error.None)
    testing.expect(t, reflect.equal(got, record))
    record.automatic = 16
    bad, write := profile.encode(record)
    defer delete(bad)
    testing.expect_value(t, write, profile.Error.Value)
}

@(test)
frozen_profile_v1_import_keeps_its_explicit_choices_and_identity :: proc(t: ^testing.T) {
    bytes := transmute([]u8)#load("fixtures/profile1/profile.bin")
    codec: sc.Schema
    defer sc.destroy(&codec)
    testing.expect_value(t, sc.init(&codec, profile.Legacy_Record).error, sc.Error.None)
    old: profile.Legacy_Record
    _, unpacked := sc.unpack(&codec, &old, bytes, {kind = profile.KIND, epoch = 1, content = profile.LEGACY_CONTENT})
    testing.expect_value(t, unpacked.error, sc.Error.None)
    before := sc.digest(bytes)
    record, err := profile.decode(bytes, old.identity)
    testing.expect_value(t, err, profile.Error.None)
    testing.expect_value(t, record.automatic, u8(0))
    testing.expect(t, reflect.equal(record.profile, old.profile))
    testing.expect_value(t, record.epoch, old.epoch)
    testing.expect_value(t, record.tick, old.tick)
    converted, written := profile.encode(record)
    defer delete(converted)
    testing.expect_value(t, written, profile.Error.None)
    restored, read := profile.decode(converted, old.identity)
    testing.expect_value(t, read, profile.Error.None)
    testing.expect(t, reflect.equal(restored, record))
    testing.expect_value(t, sc.digest(bytes), before)
    _, wrong := profile.decode(bytes, [32]u8{0 = 99})
    testing.expect_value(t, wrong, profile.Error.Identity)
}
