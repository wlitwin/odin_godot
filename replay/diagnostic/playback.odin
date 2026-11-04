package replay_diagnostic

import "core:math"
import "core:mem"
import r "godot:replay"

// Offline presentation cursor. Loading executes verification once; seeking and
// playing only sample recorded frame copies, without publishing old effects.
Playback :: struct($S, $I, $E: typeid) {
    recording:    Recording(S, I, E),
    verification: Recording_Result,
    capture:      r.Audit_Capture(S, I, E),
    report:       string,
    selected:     u64,
    playing:      bool,
    fraction:     f64,
    allocator:    mem.Allocator,
}

Playback_Load :: struct {
    accepted: bool,
    result:   Recording_Result,
}

playback_destroy :: proc(p: ^Playback($S, $I, $E)) {
    recording_destroy(&p.recording)
    r.audit_capture_destroy(&p.capture)
    delete(p.report, p.allocator)
    p^ = {}
}

// Transactional replacement. Structurally invalid/context/model-invalid files
// preserve the old recording and cursor. A verified state/event mismatch remains
// inspectable, with owned evidence describing its first divergent tick.
playback_load :: proc(
    p: ^Playback($S, $I, $E),
    bytes: []u8,
    identity: Recording_Context,
    model: Recording_Model(S, I, E),
    allocator := context.allocator,
) -> Playback_Load {
    next := Playback(S, I, E) {
        allocator = allocator,
    }
    committed := false

    defer if !committed {
        playback_destroy(&next)
    }

    if error := recording_decode(&next.recording, bytes, identity, allocator); error != .None {
        return {result = {error = error}}
    }

    next.verification = recording_verify(&next.recording, identity, model, &next.capture, allocator)

    if next.verification.error != .None && !next.capture.ready {
        return {result = next.verification}
    }

    next.report = audit_text(next.verification.replay, &next.capture, 16, allocator)
    next.selected = next.recording.base.tick

    if next.capture.ready {
        next.selected = next.capture.result.tick
    }

    playback_destroy(p)
    p^ = next
    committed = true
    return {accepted = true, result = next.verification}
}

playback_read :: proc(p: ^Playback($S, $I, $E)) -> (r.Frame(S), bool) {
    if !p.recording.ready || p.selected < p.recording.base.tick || p.selected > p.recording.header.head {
        return {}, false
    }

    if p.selected == p.recording.base.tick {
        return p.recording.base, true
    }

    index := p.selected - p.recording.base.tick - 1

    if index >= u64(len(p.recording.ticks)) {
        return {}, false
    }

    return p.recording.ticks[int(index)].frame, true
}

playback_seek :: proc(p: ^Playback($S, $I, $E), tick: u64) -> bool {
    if !p.recording.ready || tick < p.recording.base.tick || tick > p.recording.header.head {
        return false
    }

    p.selected = tick
    p.fraction = 0
    return true
}

playback_play :: proc(p: ^Playback($S, $I, $E), playing: bool) -> bool {
    if !p.recording.ready {
        return false
    }

    if playing && p.selected == p.recording.header.head {
        p.selected = p.recording.base.tick
        p.fraction = 0
    }

    p.playing = playing && p.selected < p.recording.header.head
    return true
}

// O(1) movement through a bounded recording. A render stall contributes at most
// 250 ms. No simulation callback or event delivery occurs here.
playback_advance :: proc(p: ^Playback($S, $I, $E), dt: f64) -> bool {
    if dt < 0 || math.is_nan(dt) || math.is_inf(dt) {
        return false
    }

    if !p.recording.ready || !p.playing {
        return true
    }

    p.fraction += min(dt, 0.25) * f64(p.recording.header.identity.tick_hz)
    steps := u64(math.floor(p.fraction + 1e-9))
    p.fraction = max(p.fraction - f64(steps), 0)
    p.selected += min(steps, p.recording.header.head - p.selected)

    if p.selected == p.recording.header.head {
        p.playing = false
        p.fraction = 0
    }

    return true
}
