package main
import "core:fmt"
import "core:os"
import sc "godot:replay/schema"
import tape "godot:replay/transport/trace"
import trace "godot:tests/replay_claimball_trace/shared"

main :: proc() {
    assert(len(os.args) == 2)
    data, e := os.read_entire_file(os.args[1], context.allocator)
    assert(e == nil)
    defer delete(data)
    log: tape.Log
    assert(tape.decode(&log, data) == .None)
    defer tape.destroy(&log)
    hc, fc: sc.Schema
    assert(sc.init(&hc, trace.Header).error == .None && sc.init(&fc, trace.Frame).error == .None)
    defer sc.destroy(&hc)
    defer sc.destroy(&fc)
    frames, received, sent, pump_gap, fact_lead, previous, first, last, changes, resyncs :=
        u64(0), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0), u64(0)
    h: trace.Header

    for entry in log.entries {
        if entry.operation == .Receive && entry.size > 0 {
            received += 1
        }

        if entry.operation == .Send {
            sent += 1
        }

        if entry.operation != .Mark {
            continue
        }

        if entry.peer == 1 {
            assert(sc.decode(&hc, &h, tape.payload(&log, entry)).error == .None)
            continue
        }

        assert(entry.peer == 2)
        f: trace.Frame
        assert(sc.decode(&fc, &f, tape.payload(&log, entry)).error == .None)

        if frames == 0 {
            first = f.now
        } else {
            assert(f.now >= previous)
            pump_gap = max(pump_gap, f.now - previous)
        }

        if f.facts >= f.confirmed {
            fact_lead = max(fact_lead, f.facts - f.confirmed)
        }

        previous, last = f.now, f.world_tick
        changes += u64(f.changes)
        resyncs = f.resyncs
        frames += 1
    }

    fmt.print("{")
    fmt.printf(
        "\"frames\":%d,\"operations\":%d,\"record_bytes\":%d,\"received\":%d,\"send_attempts\":%d,\"duration_ms\":%d,\"max_pump_gap_ms\":%d,\"max_facts_ahead\":%d,\"world_tick\":%d,\"changes\":%d,\"resyncs\":%d,\"history\":%d,\"packets_per_pump\":%d",
        frames,
        len(log.entries),
        len(data),
        received,
        sent,
        previous - first,
        pump_gap,
        fact_lead,
        last,
        changes,
        resyncs,
        h.settings.history,
        h.settings.packets_per_pump,
    )
    fmt.println("}")
}
