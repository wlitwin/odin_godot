package replay_deterministic_test

import "core:testing"
import d "godot:replay/deterministic"
import corpus "../../examples/replay_duel/shared/corpus"

@(test)
checked_fixed_math_rounds_toward_zero_and_refuses_overflow :: proc(t: ^testing.T) {
    a, ok := d.from_int(3)
    testing.expect(t, ok)
    testing.expect_value(t, a, d.Fixed(768))
    b, ok2 := d.mul(-385, 128)
    testing.expect(t, ok2)
    testing.expect_value(t, b, d.Fixed(-192))
    c, ok3 := d.div(-257, 512)
    testing.expect(t, ok3)
    testing.expect_value(t, c, d.Fixed(-128))
    _, overflow := d.add(d.Fixed(max(i32)), 1)
    testing.expect(t, !overflow)
    _, bad := d.div(1, 0)
    testing.expect(t, !bad)
    _, wide := d.from_int(max(i32))
    testing.expect(t, !wide)
}

@(test)
integer_queries_cover_extremes_without_squared_sum_overflow :: proc(t: ^testing.T) {
    testing.expect_value(t, d.isqrt(max(u64)), max(u32))
    testing.expect_value(t, d.isqrt(15), u32(3))
    testing.expect_value(t, d.isqrt(16), u32(4))
    testing.expect(t, d.circles_overlap({0, 0}, {3, 4}, 5, 0))
    testing.expect(
        t,
        !d.circles_overlap(
            {d.Fixed(min(i32)), d.Fixed(min(i32))},
            {d.Fixed(max(i32)), d.Fixed(max(i32))},
            d.Fixed(max(i32)),
            d.Fixed(max(i32)),
        ),
    )
}

@(test)
duel_corpus_exercises_projectiles_hits_deaths_and_respawns :: proc(t: ^testing.T) {
    result := corpus.run(42, 2400)
    testing.expect(t, result.ok)
    testing.expect(t, result.shots > 100 && result.hits > 20 && result.kills[0] > 2 && result.kills[1] > 2)
    other := corpus.run(42, 2400)
    testing.expect_value(t, other, result)
}
