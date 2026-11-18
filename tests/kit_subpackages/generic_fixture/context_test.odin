#+build !freestanding
package generic_game

import "core:testing"
import ksim "godot:kit/sim"
import knet "godot:kit/net"
import ksess "godot:kit/session"
import c "containers"
import v "values"
import actors "actors"
import rt "godot:runtime"

@(test)
generic_contexts_and_rules :: proc(t: ^testing.T) {
    testing.expect_value(t, len(rt.registration_errors()), 0)
    game: Game
    session: ksess.Session
    lane: ksim.Lane
    game_lane_init(&game, &lane, &session)
    defer ksim.lane_destroy(&lane)
    testing.expect_value(t, len(lane.inputs), 3)
    testing.expect_value(t, size_of(c.Envelope(v.Local_Type, 2)), 16)
    testing.expect_value(t, size_of(v.Sample_Input), 8)
    checked := false
    checked_vector := false
    for input in lane.inputs {
        if input.type == typeid_of(v.Sample_Input) {
            testing.expect(t, input.validate != nil)
            value := v.Sample_Input{move = {5, -5}, flags = 3, mode = .First}
            testing.expect(t, input.validate(&game, &value))
            testing.expect_value(t, value.move, [2]i16{1, -1})
            value.flags = 4
            testing.expect(t, !input.validate(&game, &value))
            value.flags = 1
            value.mode = cast(v.Mode)99
            testing.expect(t, !input.validate(&game, &value))
            checked = true
        } else if input.type == typeid_of(v.Vector_Input) {
            value := v.Vector_Input{move = {3, 4}}
            testing.expect(t, input.validate != nil && input.validate(&game, &value))
            testing.expect(t, abs(value.move[0] - 0.6) < 0.0001 && abs(value.move[1] - 0.8) < 0.0001)
            checked_vector = true
        }
    }
    testing.expect(t, checked)
    testing.expect(t, checked_vector)
    // The composed generic field must use the caller's i32, not the
    // container package's same-named i64 declaration.
    fields := actors.actor_net_desc.fields
    testing.expect_value(t, len(fields), 2)
    testing.expect_value(t, fields[1].size, size_of(i32))
}

@(test)
generic_backups_roundtrip :: proc(t: ^testing.T) {
    source, target: actors.Actor
    defer delete(source.block.state.values)
    defer delete(source.block.state.lookup)
    defer delete(target.block.state.values)
    defer delete(target.block.state.lookup)
    append(&source.block.state.values, v.Local_Type{axis = 7})
    source.block.state.lookup[3] = {axis = 9}
    writer := knet.writer_make()
    defer knet.writer_destroy(&writer)
    actors.actor_backup_write(&source, &writer)
    reader := knet.reader_make(knet.writer_bytes(&writer))
    testing.expect(t, actors.actor_backup_read(&target, &reader))
    testing.expect_value(t, len(target.block.state.values), 1)
    testing.expect_value(t, target.block.state.values[0].axis, i32(7))
    testing.expect_value(t, target.block.state.lookup[3].axis, i32(9))
}
