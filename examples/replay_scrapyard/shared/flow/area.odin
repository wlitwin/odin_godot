package scrapyard_flow

import r "godot:replay"
import game "../game"

Disc_View :: struct {
    visible: bool,
    scale: f32,
    color: [4]f32,
}

// Read the existing 17-tick flash lifetime. A late observation displays the
// remaining expansion/fade instead of restarting a local effect clock.
disc_view :: proc(clock, until: u64, radius: f32, color: [4]f32) -> Disc_View {
    if until <= clock {
        return {}
    }

    remaining := min(f32(until - clock) / 17, 1)
    result := Disc_View{true, radius * (1.06 - 0.14 * remaining), color}
    result.color[3] *= remaining
    return result
}

Buff_Observer :: struct {
    ready: bool,
    epoch, tick, high: u64,
    run: u32,
    floor: u8,
    dropped: u64,
}

Buff_Point :: struct {
    id: r.Event_Id,
    position: [2]f32,
}

// Confirmed/displayed forward observations only. Initial loads, recovery and
// rewinds seed silently; old flashes cannot produce a new launch burst.
buff_points :: proc(o: ^Buff_Observer, w: ^game.World, epoch: u64, out: []Buff_Point) -> int {
    if epoch == 0 || o.ready && epoch < o.epoch {
        return 0
    }

    reset := !o.ready || epoch != o.epoch || w.run != o.run || w.floor != o.floor
    previous := o.high
    o.ready, o.epoch, o.tick, o.run, o.floor = true, epoch, w.clock, w.run, w.floor

    if reset {
        o.high = w.clock
        return 0
    }

    if w.clock <= previous {
        return 0
    }

    o.high = w.clock
    count := 0

    for alive, i in w.flashes.alive {
        if alive {
            f := w.flashes.values[i]

            if f.kind != .Cast ||
               w.catalog.abilities[f.ability].family != .Buff ||
               f.until < 17 ||
               f.until <= w.clock {
                continue
            }

            born := f.until - 17

            if born <= previous || born > w.clock {
                continue
            }

            if count == len(out) {
                o.dropped += 1
                continue
            }

            out[count] = {
                {
                    epoch = epoch,
                    tick = born,
                    source = u64(f.generation) << 32 | u64(f.seat),
                    key = u64(1) << 40 | u64(f.serial),
                },
                f.origin,
            }
            count += 1
        }
    }

    return count
}
