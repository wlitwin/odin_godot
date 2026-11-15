package replay_play

Wave :: struct {
    count, rest: u16,
}

Director :: struct {
    wave:           u16,
    pending, alive: u32,
    rest_until:     u64,
    done:           bool,
}

// One spawn per tick. A caller without storage/prey can withhold admission;
// pending/alive do not advance until that spawn can actually be installed.
director_tick :: proc(
    d: ^Director,
    tick: u64,
    waves: []Wave,
    can_spawn: bool = true,
) -> (
    spawn: u16,
    wave_started: bool,
) {
    if d.done {
        return
    }

    if d.pending > 0 {
        if can_spawn {
            d.pending -= 1
            d.alive += 1
            return 1, false
        }

        return
    }

    if d.alive > 0 || tick < d.rest_until {
        return
    }

    if int(d.wave) >= len(waves) {
        d.done = true
        return
    }

    d.pending = u32(waves[d.wave].count)
    d.wave += 1
    return 0, true
}

director_note_death :: proc(d: ^Director, tick: u64, waves: []Wave) -> bool {
    before := d^

    if d.alive > 0 {
        d.alive -= 1
    }

    if d.alive == 0 && d.pending == 0 && d.wave > 0 && int(d.wave) <= len(waves) {
        rest := u64(waves[d.wave - 1].rest)

        if tick > max(u64) - rest {
            d^ = before
            return false
        }

        d.rest_until = tick + rest
    }

    return true
}

// A tick-owned hold that resets when its target/lifetime changes. The game
// validates geometry and continued eligibility before calling it each tick.
Channel :: struct {
    target:  u64,
    elapsed: u16,
}

channel_tick :: proc(c: ^Channel, target: u64, duration: u16) -> bool {
    if target == 0 || duration == 0 {
        c^ = {}
        return false
    }

    if c.target != target {
        c^ = {
            target = target,
        }
    }

    if c.elapsed < duration {
        c.elapsed += 1
    }

    if c.elapsed == duration {
        c^ = {}
        return true
    }

    return false
}
