package replay_lobby_test
import "core:testing"
import lb "godot:replay/lobby"
import sc "godot:replay/schema"

@(test)
ready_start_rename_and_replayable_leader_succession :: proc(t: ^testing.T) {
    l := lb.initial(4)
    lb.roster(&l, 3, 0)
    guest, _ := lb.name("Mushroom Scout 🍄")
    testing.expect_value(t, lb.apply(&l, 2, {verb = .Profile, name = guest}), lb.Result.Changed)
    testing.expect_value(t, lb.apply(&l, 2, {verb = .Start}), lb.Result.Rejected)
    lb.apply(&l, 1, {verb = .Ready, ready = true})
    lb.apply(&l, 2, {verb = .Ready, ready = true})
    testing.expect(t, lb.all_ready(&l))
    renamed, _ := lb.name("Renamed Scout")
    lb.apply(&l, 2, {verb = .Profile, name = renamed})
    testing.expect(t, !lb.all_ready(&l))
    lb.apply(&l, 2, {verb = .Ready, ready = true})
    lb.roster(&l, 0, 1)
    testing.expect_value(t, l.leader, u16(2))
    testing.expect(t, lb.all_ready(&l))
    testing.expect_value(t, lb.apply(&l, 1, {verb = .Start}), lb.Result.Rejected)
    testing.expect_value(t, lb.apply(&l, 2, {verb = .Start}), lb.Result.Started)
    testing.expect_value(t, lb.apply(&l, 2, {verb = .Restart}), lb.Result.Rejected)
    testing.expect_value(t, lb.apply(&l, 2, {verb = .Restart}, can_restart = true), lb.Result.Restarted)
    testing.expect_value(t, l.run, u32(2))
    testing.expect(t, lb.valid(l))
    codec: sc.Schema
    testing.expect_value(t, sc.init(&codec, lb.Lobby(4)).error, sc.Error.None)
    defer sc.destroy(&codec)
    bytes := make([]u8, codec.wire_size)
    defer delete(bytes)
    sc.encode(&codec, l, bytes)
    copy: lb.Lobby(4)
    testing.expect_value(t, sc.decode(&codec, &copy, bytes).error, sc.Error.None)
    testing.expect_value(t, copy, l)
}

@(test)
automatic_start_and_connection_reset_have_explicit_rules :: proc(t: ^testing.T) {
    l := lb.initial(2, automatic = true)
    testing.expect(t, !lb.auto_start(&l))
    lb.roster(&l, 3, 0)
    lb.apply(&l, 1, {verb = .Ready, ready = true})
    lb.apply(&l, 2, {verb = .Ready, ready = true})
    lb.roster(&l, 0, 2)
    lb.roster(&l, 2, 0)
    testing.expect(t, !lb.all_ready(&l))
    lb.apply(&l, 2, {verb = .Ready, ready = true})
    testing.expect(t, lb.auto_start(&l))
    testing.expect(t, !lb.auto_start(&l))
    testing.expect(t, lb.valid(l))
    l.ready = 8
    testing.expect(t, !lb.valid(l))
}

@(test)
names_are_bounded_utf8_values :: proc(t: ^testing.T) {
    for value in ([]string{"", "   ", "x\nname", "x\u2028name", "bad\xff"}) {
        _, ok := lb.name(value)
        testing.expect(t, !ok)
    }

    name, ok := lb.name("spelunker")
    testing.expect(t, ok && lb.name_valid(name, false))
    name.bytes[47] = 1
    testing.expect(t, !lb.name_valid(name))
    long: [50]u8

    for &b in long {
        b = 'a'
    }

    long[46], long[47], long[48], long[49] = 0xf0, 0x9f, 0xaa, 0xa8
    clipped, valid := lb.name(string(long[:]))
    testing.expect(t, valid && clipped.length == 46)
}

@(test)
profile_encoding_is_versioned_and_ready_can_assign_a_name_atomically :: proc(t: ^testing.T) {
    chosen, _ := lb.name("Torch keeper")
    bytes, ok := lb.profile_encode(chosen)
    testing.expect(t, ok)
    loaded, valid := lb.profile_decode(bytes[:])
    testing.expect(t, valid && loaded == chosen)
    bytes[2] = 99
    _, accepted := lb.profile_decode(bytes[:])
    testing.expect(t, !accepted)
    l := lb.initial(2)
    lb.roster(&l, 3, 0)
    testing.expect_value(t, lb.apply(&l, 2, {verb = .Ready, name = chosen, ready = true}), lb.Result.Changed)
    testing.expect(t, l.names[1] == chosen && l.ready == 2)
    lb.apply(&l, 2, {verb = .Profile, name = chosen})
    testing.expect_value(t, l.ready, u64(2))
}
