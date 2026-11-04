package scrapyard_flow

import game "../game"

Trail_Track :: struct {
    pool_generation, owner_generation, serial: u32,
    seat: u16,
    tick: u64,
}

Trails :: struct {
    ready: bool,
    epoch, tick: u64,
    run: u32,
    floor: u8,
    shots: [game.MAX_SHOTS]Trail_Track,
    dropped: u64,
}

Trail_Point :: struct {
    position: [2]f32,
    source: u64,
}

// Sample confirmed flight every three observed simulation ticks. Seed restored
// shots silently, emit no backlog across skipped snapshots, and forget old pool
// lifetimes. This is local presentation state, never part of World/checkpoints.
trail_points :: proc(trails: ^Trails, world: ^game.World, epoch: u64, out: []Trail_Point) -> int {
    if epoch == 0 || trails.ready && epoch < trails.epoch {
        return 0
    }

    reset :=
        !trails.ready ||
        trails.epoch != epoch ||
        trails.run != world.run ||
        trails.floor != world.floor ||
        world.clock < trails.tick

    if !reset && world.clock == trails.tick {
        return 0
    }

    if reset {
        dropped := trails.dropped
        trails^ = {
            ready = true,
            epoch = epoch,
            run = world.run,
            floor = world.floor,
            dropped = dropped,
        }
    }

    trails.tick = world.clock
    count := 0

    for &track, i in trails.shots {
        shot := &world.shots.values[i]

        if !world.shots.alive[i] || shot.kind != .Grenade {
            track = {}
            continue
        }

        if reset ||
           track.pool_generation != world.shots.generations[i] ||
           track.owner_generation != shot.generation ||
           track.serial != shot.serial ||
           track.seat != shot.seat {
            track = {world.shots.generations[i], shot.generation, shot.serial, shot.seat, world.clock}
            continue
        }

        if world.clock - track.tick < 3 {
            continue
        }

        track.tick = world.clock

        if count == len(out) {
            trails.dropped += 1
            continue
        }

        out[count] = {shot.position, u64(world.shots.generations[i]) << 32 | u64(i + 1)}
        count += 1
    }

    return count
}
