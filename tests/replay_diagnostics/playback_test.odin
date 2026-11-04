package diagnostic_test

import "core:testing"
import "core:reflect"
import "core:strings"
import r "godot:replay"
import d "godot:replay/diagnostic"

@(test)
playback_seeks_and_plays_copies_without_changing_recording :: proc(t: ^testing.T) {
    tl: r.Timeline(Record_State, i32, i32)
    r.init(&tl, r.Frame(Record_State){tick = 50}, record_step, {8, 2})
    defer r.destroy(&tl)

    for _ in 0 ..< 5 {
        r.advance(&tl, 1)
    }

    recording: d.Recording(Record_State, i32, i32)
    defer d.recording_destroy(&recording)
    d.recording_capture(&recording, &tl, RECORD_ID)
    bytes, _ := d.recording_encode(&recording)
    defer delete(bytes)
    player: d.Playback(Record_State, i32, i32)
    defer d.playback_destroy(&player)
    model := d.Recording_Model(Record_State, i32, i32) {
        step = record_step,
    }
    loaded := d.playback_load(&player, bytes, RECORD_ID, model)
    testing.expect(t, loaded.accepted)
    testing.expect_value(t, loaded.result.error, d.Recording_Error.None)
    testing.expect_value(t, player.selected, u64(50))
    testing.expect(t, !player.playing)
    frame, ok := d.playback_read(&player)
    testing.expect(t, ok)
    frame.state.value = 999
    same, _ := d.playback_read(&player)
    testing.expect_value(t, same.state.value, i32(0))
    testing.expect(t, d.playback_play(&player, true))
    d.playback_advance(&player, 1.0 / 60)
    testing.expect_value(t, player.selected, u64(51))
    testing.expect(t, d.playback_seek(&player, 54))
    testing.expect(t, !d.playback_seek(&player, 49))
    testing.expect_value(t, player.selected, u64(54))
    d.playback_advance(&player, 100)
    testing.expect_value(t, player.selected, u64(55))
    testing.expect(t, !player.playing)
    testing.expect(t, !d.playback_advance(&player, -1))
    testing.expect(t, !d.playback_advance(&player, transmute(f64)u64(0x7ff8000000000000)))
    d.playback_play(&player, true)
    testing.expect_value(t, player.selected, u64(50))
    again, error := d.recording_encode(&player.recording)
    defer delete(again)
    testing.expect_value(t, error, d.Recording_Error.None)
    testing.expect(t, reflect.equal(bytes, again, true))
}

@(test)
playback_load_retains_valid_old_view_and_exposes_owned_divergence :: proc(t: ^testing.T) {
    tl: r.Timeline(Record_State, i32, i32)
    r.init(&tl, r.Frame(Record_State){}, record_step, {8, 2})
    defer r.destroy(&tl)
    r.advance(&tl, 1)
    r.advance(&tl, 2)
    recording: d.Recording(Record_State, i32, i32)
    defer d.recording_destroy(&recording)
    d.recording_capture(&recording, &tl, RECORD_ID)
    bytes, _ := d.recording_encode(&recording)
    defer delete(bytes)
    player: d.Playback(Record_State, i32, i32)
    defer d.playback_destroy(&player)
    model := d.Recording_Model(Record_State, i32, i32) {
        step = record_step,
    }
    testing.expect(t, d.playback_load(&player, bytes, RECORD_ID, model).accepted)
    d.playback_seek(&player, 2)
    before, _ := d.playback_read(&player)
    testing.expect(t, !d.playback_load(&player, bytes[:len(bytes) - 1], RECORD_ID, model).accepted)
    after, _ := d.playback_read(&player)
    testing.expect(t, reflect.equal(before, after))
    testing.expect(t, !d.playback_load(&player, bytes, d.Recording_Context{1, 3, 60}, model).accepted)
    model.state_valid = reject_record_state
    testing.expect_value(t, d.playback_load(&player, bytes, RECORD_ID, model).result.error, d.Recording_Error.Model)
    testing.expect_value(t, player.selected, u64(2))
    model.state_valid = nil
    model.step = wrong_state_step
    loaded := d.playback_load(&player, bytes, RECORD_ID, model)
    testing.expect(t, loaded.accepted && player.capture.ready)
    testing.expect_value(t, loaded.result.replay.error, r.Error.Diverged_State)
    testing.expect_value(t, player.selected, u64(1))
    testing.expect(t, strings.contains(player.report, "$.secret"))
    d.recording_destroy(&recording)
    testing.expect_value(t, player.capture.expected.state.secret, u32(1))
    model.step = wrong_event_step
    testing.expect_value(
        t,
        d.playback_load(&player, bytes, RECORD_ID, model).result.replay.error,
        r.Error.Diverged_Event,
    )
    model.step = abort_record_step
    testing.expect(t, !d.playback_load(&player, bytes, RECORD_ID, model).accepted)
    testing.expect_value(t, player.verification.replay.error, r.Error.Diverged_Event)
}

@(test)
playback_preserves_u64_ticks_and_zero_step_boundaries :: proc(t: ^testing.T) {
    tl: r.Timeline(Record_State, i32, i32)
    r.init(&tl, r.Frame(Record_State){tick = max(u64) - 2}, record_step, {4, 1})
    defer r.destroy(&tl)
    r.advance(&tl, 1)
    r.advance(&tl, 1)
    recording: d.Recording(Record_State, i32, i32)
    defer d.recording_destroy(&recording)
    d.recording_capture(&recording, &tl, RECORD_ID)
    bytes, _ := d.recording_encode(&recording)
    defer delete(bytes)
    player: d.Playback(Record_State, i32, i32)
    defer d.playback_destroy(&player)
    model := d.Recording_Model(Record_State, i32, i32) {
        step = record_step,
    }
    testing.expect(t, d.playback_load(&player, bytes, RECORD_ID, model).accepted)
    d.playback_play(&player, true)
    d.playback_advance(&player, 1)
    testing.expect_value(t, player.selected, max(u64))
    frame, ok := d.playback_read(&player)
    testing.expect(t, ok)
    testing.expect_value(t, frame.tick, max(u64))
    d.recording_destroy(&recording)
    r.reset_checkpoint(&tl, r.Frame(Record_State){tick = 900}, 2)
    d.recording_capture(&recording, &tl, RECORD_ID)
    empty, _ := d.recording_encode(&recording)
    defer delete(empty)
    testing.expect(t, d.playback_load(&player, empty, RECORD_ID, model).accepted)
    d.playback_play(&player, true)
    testing.expect(t, !player.playing)
    testing.expect_value(t, player.selected, u64(900))
}
