package main
import "core:fmt"
import "core:time"
import r "godot:replay"

Large_State :: struct {
    bytes: [65536]u8,
    value: u64,
}

large_step :: proc(w: ^Large_State, input: u8, ctx: ^r.Step(u64)) {
    w.value += u64(input)
    w.bytes[ctx.tick % 65536] = u8(w.value)
    r.emit(ctx, 1, 1, w.value)
}

bench :: proc() {
    times: [2]u64
    reused_total := 0

    for sample in 0 ..< 100 {
        for order in 0 ..< 2 {
            kind := (sample + order) % 2
            timeline: r.Timeline(Large_State, u8, u64)
            assert(r.init(&timeline, r.Frame(Large_State){}, large_step, cfg = {64, 2}) == .None)

            for _ in 0 ..< 48 {
                assert(r.advance(&timeline, u8(1)).error == .None)
            }

            truth, _ := r.read(&timeline, 16)
            events: [2]r.Occurrence(u64)
            n, err := r.copy_events(&timeline, 16, events[:])
            assert(err == .None)
            began := time.tick_now()
            result: r.Result

            if kind == 0 {
                result = r.correct(&timeline, truth, events[:n])
            } else {
                count: int
                result, count = r.correct_reusing(&timeline, truth, events[:n])
                reused_total += count
            }

            times[kind] += u64(time.tick_since(began))
            assert(result.error == .None && result.steps == 32)
            final, ok := r.current(&timeline)
            assert(ok && final.state.value == 48 && timeline.confirmed == 16)
            r.destroy(&timeline)
        }
    }

    assert(reused_total == 3200)
    fmt.printf(
        "CORRECTION_REUSE_BENCH bytes=%d depth=32 samples=100 plain_ns=%d reuse_ns=%d reused=%d\n",
        size_of(Large_State),
        times[0] / 100,
        times[1] / 100,
        reused_total,
    )
}
