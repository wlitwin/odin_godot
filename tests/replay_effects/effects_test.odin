package replay_effects_test

import "core:testing"
import "core:reflect"
import p "godot:replay/play"

@(test)
stack_cap_refresh_capacity_and_expiry :: proc(t: ^testing.T) {
    effects: [2]p.Effect

    for _ in 0 ..< 5 {
        index, ok := p.effect_stack(effects[:], 1, 3, 10)
        testing.expect(t, ok && index == 0)
    }

    testing.expect_value(t, effects[0].power, u8(3))
    p.effects_tick(effects[:])
    p.effect_stack(effects[:], 1, 3, 4)
    testing.expect_value(t, effects[0].left, u16(9))
    p.effect_stack(effects[:], 2, 1, 3)
    before := effects
    _, ok := p.effect_stack(effects[:], 3, 1, 4)
    testing.expect(t, !ok && reflect.equal(before, effects))

    for _ in 0 ..< 3 {
        p.effects_tick(effects[:])
    }

    testing.expect(t, reflect.equal(effects[1], p.Effect{}))
    effects[0].left = 0
    p.effects_tick(effects[:])
    testing.expect(t, reflect.equal(effects, [2]p.Effect{}))
    _, ok = p.effect_stack(effects[:], 0, 1, 4)
    testing.expect(t, !ok)
}

@(test)
telegraph_lands_once_and_cancel_clears_its_denominator :: proc(t: ^testing.T) {
    tele: p.Telegraph
    p.telegraph_start(&tele, 3)
    testing.expect_value(t, p.telegraph_fraction(tele), f32(0))
    testing.expect(t, !p.telegraph_tick(&tele))
    testing.expect(t, !p.telegraph_tick(&tele))
    testing.expect(t, p.telegraph_tick(&tele))
    testing.expect(t, !p.telegraph_tick(&tele))
    testing.expect_value(t, p.telegraph_fraction(tele), f32(1))
    p.telegraph_start(&tele, 3)
    p.telegraph_cancel(&tele)
    testing.expect(t, !p.telegraph_tick(&tele))
    testing.expect_value(t, tele.wind, u16(0))
}
