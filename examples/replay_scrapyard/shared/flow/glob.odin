package scrapyard_flow

import "core:math"

// Local presentation phase. Identity/scope changes and observed rewinds seed
// silently; display-slot reuse must never inherit another projectile's pulse.
Glob_Pulse :: struct {
    epoch, tick, source: u64,
    generation, serial: u32,
    phase: f32,
}

glob_pulse :: proc(cue: ^Glob_Pulse, epoch, tick, source: u64, generation, serial: u32, dt: f32) -> f32 {
    if cue.epoch != epoch ||
       cue.source != source ||
       cue.generation != generation ||
       cue.serial != serial ||
       tick < cue.tick {
        cue^ = {
            epoch = epoch,
            source = source,
            generation = generation,
            serial = serial,
        }
    }

    cue.tick = tick
    cue.phase = math.mod(cue.phase + max(dt, 0) * 14, 2 * math.PI)
    return 1 + math.sin(cue.phase) * 0.18
}
