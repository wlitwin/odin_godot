package replay_scrapyard

import "core:fmt"
import "core:strings"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import game "../shared/game"
import storagegd "godot:replay/godot/storage"

BENCH_CAPACITY :: 32768

Bench_Metric :: enum {
    Advance,
    Pump,
    Snapshot,
    Replay,
    Snapshot_Encode,
    Snapshot_Delta,
    Snapshot_Hash,
    Snapshot_Cache,
    Snapshot_Validate,
    Snapshot_Send,
    Paint,
    Frame,
}

Bench_Sample :: struct {
    metric: Bench_Metric,
    tick, us: u64,
}

Bench :: struct {
    active: bool,
    samples: [dynamic]Bench_Sample,
    dropped, tick, started_us, start_tick, tx, rx, corrections, replayed, shots: u64,
}

bench_note :: proc(b: ^Bench, metric: Bench_Metric, us: u64) {
    if !b.active {
        return
    }

    if len(b.samples) == cap(b.samples) {
        b.dropped += 1
        return
    }

    append(&b.samples, Bench_Sample{metric, b.tick, us})
}

bench_network :: proc(user: rawptr, metric: net.Profile_Metric, elapsed: u64) {
    bench_note(cast(^Bench)user, Bench_Metric(metric), elapsed)
}

@(gd_method)
replay_scrapyard_bench_start :: proc(self: ^ReplayScrapyard) {
    b := &self.bench[0]
    delete(b.samples)
    b^ = {
        samples = make([dynamic]Bench_Sample, 0, BENCH_CAPACITY),
    }
    clock := r.Profile_Clock {
        read = proc(user: rawptr) -> (u64, bool) {
            return gd.time_get_ticks_usec(gd.singleton_time()), true
        },
    }

    if self.session.authority {
        self.session.server.profile_clock = clock
        self.session.server.profile_user = b
        self.session.server.profile_sample = bench_network
    } else {
        self.session.client.profile_clock = clock
        self.session.client.profile_user = b
        self.session.client.profile_sample = bench_network
    }

    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        return
    }

    stats := self.session.authority ? self.session.server.stats : self.session.client.stats
    b.started_us = gd.time_get_ticks_usec(gd.singleton_time())
    b.tick, b.start_tick = frame.tick, frame.tick
    b.tx, b.rx, b.corrections, b.replayed = stats.tx_bytes, stats.rx_bytes, stats.corrections, stats.replayed_ticks

    for player in frame.state.players {
        b.shots += u64(player.shots)
    }

    b.active = true
}

@(gd_method)
replay_scrapyard_bench_finish :: proc(self: ^ReplayScrapyard) -> bool {
    b := &self.bench[0]

    if !b.active {
        return false
    }

    b.active = false
    ended := gd.time_get_ticks_usec(gd.singleton_time())
    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        return false
    }

    stats := self.session.authority ? self.session.server.stats : self.session.client.stats
    builder: strings.Builder
    defer strings.builder_destroy(&builder)
    fmt.sbprintf(&builder, "metric,observed_tick,us\n")
    names := [Bench_Metric]string {
        .Advance = "advance",
        .Pump = "pump",
        .Snapshot = "snapshot",
        .Replay = "replay",
        .Paint = "paint",
        .Frame = "frame",
        .Snapshot_Encode = "snapshot_codec",
        .Snapshot_Delta = "snapshot_delta",
        .Snapshot_Hash = "snapshot_hash",
        .Snapshot_Cache = "snapshot_cache",
        .Snapshot_Validate = "snapshot_validate",
        .Snapshot_Send = "snapshot_send",
    }

    for sample in b.samples {
        fmt.sbprintf(&builder, "%s,%d,%d\n", names[sample.metric], sample.tick, sample.us)
    }

    role := scrap_param("RSY_ROLE", "")
    text := strings.to_string(builder)

    if storagegd.storage_write(
           fmt.tprintf("%s/timing-%s.csv", scrap_param("RSY_RESULT_DIR", "user://"), role),
           transmute([]u8)text,
           8 * 1024 * 1024,
       ) !=
       .None {
        return false
    }

    timeline := self.session.authority ? &self.session.server.timeline : &self.session.client.timeline
    allocated := u64(
        len(timeline.records) * size_of(type_of(timeline.records[0])) +
        len(timeline.staged) * size_of(type_of(timeline.staged[0])) +
        len(timeline.event_storage) * size_of(type_of(timeline.event_storage[0])) +
        len(timeline.staged_events) * size_of(type_of(timeline.staged_events[0])),
    )
    shots := u64(0)

    for player in frame.state.players {
        shots += u64(player.shots)
    }

    gd.print_str(
        fmt.tprintf(
            "RSY_BENCH role=%s start_tick=%d end_tick=%d us=%d samples=%d dropped=%d tx=%d rx=%d corrections=%d replayed=%d shots=%d history=%d timeline_bytes=%d",
            role,
            b.start_tick,
            frame.tick,
            ended - b.started_us,
            len(b.samples),
            b.dropped,
            stats.tx_bytes - b.tx,
            stats.rx_bytes - b.rx,
            stats.corrections - b.corrections,
            stats.replayed_ticks - b.replayed,
            shots - b.shots,
            self.session.options.network.history,
            allocated,
        ),
    )
    return b.dropped == 0
}

// The stress driver uses the same cast actions as mouse input, aimed at the
// nearest observed mob. Only the driver's targeting policy lives outside the sim.
@(gd_method)
replay_scrapyard_dev_stress_cast :: proc(self: ^ReplayScrapyard, slot: gd.Int) -> bool {
    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || seat == 0 || slot < 0 || slot > 1 {
        return false
    }

    player := frame.state.players[seat - 1]
    best := f32(1e30)
    target := [2]f32{}
    found := false

    for alive, i in frame.state.mobs.alive {
        if alive && frame.state.mobs.values[i].hp > 0 {
            position := frame.state.mobs.values[i].position
            delta := position - player.position
            distance := delta[0] * delta[0] + delta[1] * delta[1]

            if distance < best {
                best, target, found = distance, position, true
            }
        }
    }

    if !found {
        return false
    }

    return issue(self, game.Action{kind = .Cast, slot = u8(slot), aim = target, aim_is_point = true})
}

@(gd_method)
replay_scrapyard_dev_stress_fire :: proc(self: ^ReplayScrapyard) {
    frame, ok := rgd.session_authority_state(self.session)
    seat := rgd.session_seat(self.session)

    if !ok || seat == 0 {
        return
    }

    local, local_ok := rgd.session_state(self.session)

    if !local_ok {
        return
    }

    // Match ordinary mouse aim: the local predicted body supplies the origin.
    // Target membership/positions still come from the same authority observation.
    best := f32(1e30)
    aim := [2]f32{1, 0}
    origin := local.state.players[seat - 1].position

    for alive, i in frame.state.mobs.alive {
        if alive && frame.state.mobs.values[i].hp > 0 {
            delta := frame.state.mobs.values[i].position - origin
            distance := delta[0] * delta[0] + delta[1] * delta[1]

            if distance < best {
                best, aim = distance, unit(delta)
            }
        }
    }

    self.manual, self.auto_combat, self.manual_move, self.manual_aim, self.manual_fire = true, false, {}, aim, true
}

@(gd_method)
replay_scrapyard_stress_statuses :: proc(self: ^ReplayScrapyard) -> gd.Int {
    frame, ok := rgd.session_authority_state(self.session)

    if !ok {
        return 0
    }

    mask := u16(0)

    for alive, i in frame.state.mobs.alive {
        if alive {
            for fx in frame.state.mobs.values[i].fx {
                if fx.kind != 0 {
                    mask |= u16(1) << fx.kind
                }
            }
        }
    }

    return gd.Int(mask)
}
