package replay_claimball
import "core:fmt"
import "core:os"
import gd "godot:godot"
import sc "godot:replay/schema"
import tape "godot:replay/transport/trace"
import tr "godot:replay/transport"
import trace "godot:tests/replay_claimball_trace/shared"

Observer_Trace :: struct {
    log:           tape.Log,
    capture:       tape.Capture,
    frames:        u64,
    ready, paused: bool,
}

trace_start :: proc(self: ^ReplayClaimball) {
    seed := gd.env_int("RCB_TRACE_FAULT_SEED", 0)

    if seed > 0 && self.session.delay.packets != nil {
        delay := &self.session.delay
        assert(tr.delay_faults(delay, delay.jitter_ms, delay.loss_permyriad, delay.duplicate_permyriad, u64(seed)))
        gd.print_str(fmt.tprintf("RCB_TRACE_FAULT_SEED seed=%d", seed))
    }

    if self.session.authority || !self.session.client.spectator || gd.env_string("RCB_TRACE", "") == "" {
        return
    }

    t := &self.observer_trace[0]
    c := &self.session.client
    assert(tape.init(&t.log))
    c.wire = tape.capture(&t.capture, &t.log, c.wire)
    t.ready = true
    header := trace.Header {
        settings       = trace.settings(c.cfg),
        epoch          = c.cfg.epoch,
        content        = c.cfg.content,
        token          = c.token,
        query_nonce    = c.epoch_query_nonce,
        authority      = u64(c.authority),
        incarnation    = c.incarnation,
        drain_capacity = u32(len(self.session.changes)),
        query          = c.epoch_query_pending,
        mixed          = c.mixed_presentation,
        parts          = c.snapshot_parts_enabled,
        lz4            = c.lz4_snapshots_enabled,
        erasure        = c.snapshot_erasure_enabled,
        shuffle        = c.snapshot_shuffle_enabled,
        facts          = c.fact_repair_enabled,
        actions        = c.action_copies_enabled,
        reuse          = c.reuse_equal_corrections,
    }
    codec: sc.Schema
    assert(sc.init(&codec, trace.Header).error == .None)
    defer sc.destroy(&codec)
    data := make([]u8, codec.wire_size, context.temp_allocator)
    assert(sc.encode(&codec, header, data).error == .None)
    tape.mark(&t.log, 1, 0, data)
}

trace_frame :: proc(self: ^ReplayClaimball) {
    t := &self.observer_trace[0]

    if !t.ready {
        return
    }

    frame := trace.observation(&self.session.client, self.session.changes[:self.session.change_count])
    t.frames += 1
    codec: sc.Schema
    assert(sc.init(&codec, trace.Frame).error == .None)
    defer sc.destroy(&codec)
    data := make([]u8, codec.wire_size, context.temp_allocator)
    assert(sc.encode(&codec, frame, data).error == .None)
    tape.mark(&t.log, 2, frame.now, data)
    pause := gd.env_int("RCB_TRACE_PAUSE_MS", 0)

    if pause > 0 && !t.paused && frame.confirmed >= 174 {
        assert(pause <= 2000)
        t.paused = true
        gd.print_str(fmt.tprintf("RCB_TRACE_PAUSE tick=%d ms=%d", frame.confirmed, pause))
        gd.os_delay_msec(gd.singleton_os(), gd.Int(pause))
    }
}

trace_close :: proc(self: ^ReplayClaimball) {
    t := &self.observer_trace[0]

    if !t.ready {
        return
    }

    data, error := tape.encode(&t.log)
    defer delete(data)
    path := gd.env_string("RCB_TRACE", "")
    assert(error == .None && os.write_entire_file(path, data) == nil)
    gd.print_str(
        fmt.tprintf("RCB_TRACE_WRITTEN frames=%d operations=%d bytes=%d", t.frames, len(t.log.entries), len(data)),
    )
    self.session.client.wire = t.capture.base
    tape.destroy(&t.log)
    t.ready = false
}
