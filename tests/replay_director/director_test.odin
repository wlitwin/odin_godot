package replay_director_test

import "core:testing"
import "core:reflect"
import p "godot:replay/play"

@(test)
backpressure_does_not_create_phantom_enemies :: proc(t: ^testing.T) {
    d: p.Director
    waves := [1]p.Wave{{2, 3}}
    n, started := p.director_tick(&d, 1, waves[:])
    testing.expect(t, n == 0 && started)
    before := d

    for tick in u64(2) ..< 10 {
        n, _ = p.director_tick(&d, tick, waves[:], false)
        testing.expect(t, n == 0 && reflect.equal(d, before))
    }

    n, _ = p.director_tick(&d, 10, waves[:])
    testing.expect_value(t, n, u16(1))
    testing.expect_value(t, d.alive, u32(1))
    p.director_tick(&d, 11, waves[:])
    p.director_note_death(&d, 12, waves[:])
    p.director_note_death(&d, 13, waves[:])
    p.director_tick(&d, 15, waves[:])
    testing.expect(t, !d.done)
    p.director_tick(&d, 16, waves[:])
    testing.expect(t, d.done)
}

@(test)
channel_requires_a_continuous_target_and_completes_once :: proc(t: ^testing.T) {
    c: p.Channel
    testing.expect(t, !p.channel_tick(&c, 1, 3))
    testing.expect(t, !p.channel_tick(&c, 1, 3))
    testing.expect(t, !p.channel_tick(&c, 2, 3))
    testing.expect_value(t, c.elapsed, u16(1))
    testing.expect(t, !p.channel_tick(&c, 0, 3))
    testing.expect_value(t, c, p.Channel{})

    for _ in 0 ..< 2 {
        testing.expect(t, !p.channel_tick(&c, 2, 3))
    }

    testing.expect(t, p.channel_tick(&c, 2, 3))
    testing.expect_value(t, c, p.Channel{})
}
