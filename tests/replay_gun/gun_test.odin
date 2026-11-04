package replay_gun_test

import "core:testing"
import "core:reflect"
import p "godot:replay/play"

@(test)
last_dud_clears_before_empty_starts_reload :: proc(t: ^testing.T) {
    d := p.Gun_Def{1, 3, 1000, 2}
    g: p.Gun_State
    testing.expect_value(t, p.gun_equip(&g, d), p.Gun_Error.None)
    testing.expect_value(t, p.gun_pull(&g, d).pull, p.Gun_Pull.Jammed)
    testing.expect_value(t, g.ammo, u16(0))
    testing.expect_value(t, g.spent, u32(1))

    for _ in 0 ..< 5 {
        p.gun_tick(&g, d)
    }

    testing.expect_value(t, g.mode, p.Gun_Mode.Jammed)
    testing.expect_value(t, p.gun_pull(&g, d).pull, p.Gun_Pull.Clear_Tap)
    testing.expect_value(t, p.gun_pull(&g, d).pull, p.Gun_Pull.Cleared)
    testing.expect_value(t, p.gun_pull(&g, d).pull, p.Gun_Pull.Empty)

    for _ in 0 ..< 2 {
        p.gun_tick(&g, d)
        testing.expect_value(t, p.gun_pull(&g, d).pull, p.Gun_Pull.Held)
    }

    p.gun_tick(&g, d)
    testing.expect_value(t, g.ammo, u16(1))
    testing.expect_value(t, g.mode, p.Gun_Mode.Ready)
}

@(test)
last_live_round_reloads_and_saved_state_continues :: proc(t: ^testing.T) {
    d := p.Gun_Def{3, 4, 0, 3}
    g: p.Gun_State
    p.gun_equip(&g, d, 42)

    for _ in 0 ..< 3 {
        testing.expect_value(t, p.gun_pull(&g, d).pull, p.Gun_Pull.Fired)
    }

    testing.expect_value(t, g.mode, p.Gun_Mode.Reloading)
    p.gun_tick(&g, d)
    resumed := g

    for _ in 0 ..< 40 {
        p.gun_tick(&g, d)
        p.gun_tick(&resumed, d)
        testing.expect(t, reflect.equal(p.gun_pull(&g, d), p.gun_pull(&resumed, d)))
        testing.expect(t, reflect.equal(g, resumed) && p.gun_valid(g, d))
    }
}

@(test)
invalid_and_exhausted_transitions_preserve_state :: proc(t: ^testing.T) {
    d := p.Gun_Def{1, 3, 0, 2}
    g: p.Gun_State
    p.gun_equip(&g, d)
    g.spent = max(u32)
    before := g
    testing.expect_value(t, p.gun_pull(&g, d).error, p.Gun_Error.Exhausted)
    testing.expect(t, reflect.equal(g, before))
    g.mode = .Jammed
    before = g
    testing.expect_value(t, p.gun_pull(&g, d).error, p.Gun_Error.Invalid)
    testing.expect_value(t, p.gun_tick(&g, d), p.Gun_Error.Invalid)
    testing.expect_value(t, p.gun_equip(&g, p.Gun_Def{}), p.Gun_Error.Invalid)
    testing.expect(t, reflect.equal(g, before))
}
