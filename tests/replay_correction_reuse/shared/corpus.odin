package reuse_corpus
import r "godot:replay"
import sc "godot:replay/schema"
import "core:reflect"

State :: struct {
    value:   i32,
    clock:   u64,
    history: [16]i32,
}

Input :: struct {
    add:         i32,
    reset, fail: bool,
}

Rewrite :: struct {
    change, fail_at: u64,
    calls:           u32,
    order:           u64,
}

step :: proc(w: ^State, input: Input, ctx: ^r.Step(i32)) {
    if input.fail {
        r.abort(ctx)
        return
    }

    if input.reset {
        w.value = 0
    }

    w.value += input.add
    w.clock = ctx.tick
    w.history[ctx.tick % 16] = w.value
    r.emit(ctx, 1, 1, w.value)
}

rewrite :: proc(user: rawptr, tick: u64, input: Input) -> Input {
    data := cast(^Rewrite)user
    data.calls += 1
    data.order = (data.order ~ tick) * 0x100000001b3
    out := input

    if tick == data.change {
        out.add += 3
    }

    out.fail = tick == data.fail_at
    return out
}

verify :: proc() -> (hash: u64, reused: u64, ok: bool) {
    hash = 0xcbf29ce484222325
    codec: sc.Schema

    if sc.init(&codec, State).error != .None {
        return
    }

    defer sc.destroy(&codec)
    bytes := make([]u8, codec.wire_size)
    defer delete(bytes)

    for test in 0 ..< 128 {
        a, b: r.Timeline(State, Input, i32)
        defer r.destroy(&a)
        defer r.destroy(&b)

        if r.init(&a, r.Frame(State){}, step, cfg = {64, 4}) != .None ||
           r.init(&b, r.Frame(State){}, step, cfg = {64, 4}) != .None {
            return
        }

        for tick in 1 ..= 40 {
            input := Input {
                add   = i32((tick + test) % 3),
                reset = tick % 7 == 0,
            }

            if r.advance(&a, input).error != .None || r.advance(&b, input).error != .None {
                return
            }
        }

        truth, found := r.read(&a, 8)

        if !found {
            return
        }

        if test % 4 == 0 {
            truth.state.value += 1
        }

        x := Rewrite {
            change  = test % 5 == 0 ? 0 : u64(10 + test % 9),
            fail_at = test % 7 == 0 ? 31 : 0,
        }
        y := x
        events := [1]r.Occurrence(i32){{id = {epoch = 1, tick = 8, source = 99, key = 2}, value = i32(test)}}
        first := r.correct(&a, truth, events[:], r.Input_Rewrite(Input){user = &x, apply = rewrite})
        second, count := r.correct_reusing(&b, truth, events[:], r.Input_Rewrite(Input){user = &y, apply = rewrite})

        if first.error != second.error ||
           first.steps != second.steps ||
           first.tick != second.tick ||
           x.calls != y.calls ||
           x.order != y.order ||
           a.confirmed != b.confirmed {
            return
        }

        if second.error != .None && count != 0 {
            return
        }

        reused += u64(count)

        for tick in u64(0) ..= 40 {
            fa, ka := r.read(&a, tick)
            fb, kb := r.read(&b, tick)
            ia, ja := r.read_input(&a, tick)
            ib, jb := r.read_input(&b, tick)

            if ka != kb || ja != jb || !reflect.equal(fa, fb) || !reflect.equal(ia, ib) {
                return
            }

            ea, eb: [4]r.Occurrence(i32)
            na, erra := r.copy_events(&a, tick, ea[:])
            nb, errb := r.copy_events(&b, tick, eb[:])

            if erra != errb || na != nb || !reflect.equal(ea[:na], eb[:nb], true) {
                return
            }

            if sc.encode(&codec, fb.state, bytes).error != .None {
                return
            }

            hash = sc.digest(bytes, hash)
        }
    }

    ok = reused > 0
    return
}
