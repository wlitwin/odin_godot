package diagnostics_wasm

import r "godot:replay"
import sc "godot:replay/schema"
import d "godot:replay/diagnostic"

State :: struct {
    value: i32,
}

@(require) instantiate :: proc() {
    timeline: r.Timeline(State, u8, u8)
    r.init(&timeline, r.Frame(State){}, proc(w: ^State, input: u8, ctx: ^r.Step(u8)) {
        w.value += i32(input)
    })
    r.advance(&timeline, u8(1))
    capture: r.Audit_Capture(State, u8, u8)
    r.audit_capture(&timeline, 1, &capture)
    r.audit_capture_destroy(&capture)
    codec: sc.Schema
    sc.init(&codec, State)
    fields: [4]sc.Difference
    sc.diff(&codec, State{1}, State{2}, fields[:])
    text := sc.diff_value(&codec, fields[0], .Left)
    delete(text)
    sc.destroy(&codec)
    recording: d.Recording(State, u8, u8)
    d.recording_capture(&recording, &timeline, d.Recording_Context{1, 2, 60})
    bytes, _ := d.recording_encode(&recording)
    d.recording_destroy(&recording)
    d.recording_decode(&recording, bytes, d.Recording_Context{1, 2, 60})
    player: d.Playback(State, u8, u8)
    d.playback_load(
        &player,
        bytes,
        d.Recording_Context{1, 2, 60},
        d.Recording_Model(State, u8, u8){step = timeline.step},
    )
    d.playback_play(&player, true)
    d.playback_advance(&player, 0.1)
    d.playback_seek(&player, 0)
    d.playback_read(&player)
    d.playback_destroy(&player)
    delete(bytes)
    d.recording_verify(
        &recording,
        d.Recording_Context{1, 2, 60},
        d.Recording_Model(State, u8, u8){step = timeline.step},
        &capture,
    )
    d.recording_destroy(&recording)
    r.audit_capture_destroy(&capture)
    r.destroy(&timeline)
}
