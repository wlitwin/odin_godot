#+build linux, darwin
package main

import "core:fmt"
import "core:reflect"
import "core:time"
import "core:sys/posix"
import r "godot:replay"
import rb "godot:replay/p2p"
import tr "godot:replay/transport"
import game "../../../examples/replay_duel/shared/duel"

TICKS :: u64(2400)

Case :: struct {
    name:   string,
    delay:  u32,
    faults: tr.Faults,
}

Result :: struct {
    cycles, cpu_us, wall_us, hash, tx_bytes, rollbacks, replayed, stalls, max_depth: u64,
    timings:                                                                         [rb.Profile_Metric]r.Timing,
}

control :: proc(tick: u64, seat: int) -> game.Input {
    // Every case executes identical simulation inputs, including the startup
    // prefix needed by the longest configured delay.
    return tick <= 8 ? game.Input{} : game.corpus_input(tick, seat)
}

cpu_time :: proc() -> u64 {
    usage: posix.rusage
    assert(posix.getrusage(.SELF, &usage) == .OK)
    return(
        u64(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1_000_000 +
        u64(usage.ru_utime.tv_usec) +
        u64(usage.ru_stime.tv_usec) \
    )
}

run :: proc(scenario: Case, profiled: bool, expected: game.World) -> Result {
    network: tr.Memory
    assert(tr.memory_init(&network, seed = 42, cfg = {2, 512, 8192, 65536}, faults = scenario.faults))
    defer tr.memory_destroy(&network)
    peers: [2]rb.Runner(game.World, game.Input, game.Event, 2)
    endpoints: [2]tr.Memory_Endpoint

    defer {
        for &peer in peers {
            rb.destroy(&peer)
        }

        for &endpoint in endpoints {
            wire := tr.memory_transport(&endpoint)
            tr.close(&wire)
        }
    }

    origin := time.tick_now()
    clock := r.Profile_Clock {
        user = &origin,
        read = proc(user: rawptr) -> (u64, bool) {
            elapsed := time.tick_since((cast(^time.Tick)user)^)
            return elapsed >= 0 ? u64(elapsed / time.Microsecond) : 0, elapsed >= 0
        },
    }

    for &peer, i in peers {
        assert(tr.memory_open(&network, &endpoints[i], tr.Peer_Id(i + 1)))
        cfg := rb.DEFAULT_CONFIG
        cfg.delay, cfg.content = scenario.delay, game.CONTENT
        assert(
            rb.init(
                &peer,
                r.Frame(game.World){state = game.initial(42)},
                game.model(),
                [2]tr.Peer_Id{1, 2},
                u16(i),
                tr.memory_transport(&endpoints[i]),
                cfg,
            ) ==
            .None,
        )

        if profiled {
            assert(rb.profile_set(&peer, clock) == .None)
        }
    }

    result: Result
    wall_begin, cpu_begin := time.tick_now(), cpu_time()

    for cycle in u64(0) ..< TICKS * 10 {
        assert(tr.memory_advance(&network, cycle))

        for &peer, i in peers {
            assert(rb.pump(&peer, cycle * 1000 / 60) == .None)

            if peer.phase == .Running && peer.timeline.head < TICKS {
                stepped := rb.advance(&peer, control(peer.timeline.head + u64(peer.cfg.delay) + 1, i))
                assert(stepped.error == .None || stepped.error == .Waiting || stepped.error == .Capacity)
            }
        }

        if peers[0].timeline.confirmed == TICKS &&
           peers[1].timeline.confirmed == TICKS &&
           peers[0].remote_hash[1].tick == TICKS &&
           peers[1].remote_hash[0].tick == TICKS {
            result.cycles = cycle + 1
            break
        }
    }

    result.cpu_us, result.wall_us = cpu_time() - cpu_begin, u64(time.tick_since(wall_begin) / time.Microsecond)
    assert(result.cycles != 0)

    for &peer in peers {
        frame, _ := r.current(&peer.timeline)
        assert(reflect.equal(frame.state, expected))
        assert(peer.chain == peers[0].chain)
        result.hash = peer.chain
        result.tx_bytes += peer.stats.tx_bytes
        result.rollbacks += peer.stats.rollbacks
        result.replayed += peer.stats.replayed_ticks
        result.stalls += peer.stats.stalls
        result.max_depth = max(result.max_depth, peer.stats.max_replay_depth)

        for metric in rb.Profile_Metric {
            to := &result.timings[metric]
            from := peer.profile.metrics[metric]
            to.samples += from.samples
            to.total_us += from.total_us
            to.errors += from.errors
            to.max_us = max(to.max_us, from.max_us)

            for count, bucket in from.histogram {
                to.histogram[bucket] += count
            }
        }
    }

    return result
}

main :: proc() {
    expected := game.initial(42)

    for tick in u64(1) ..= TICKS {
        storage: [32]r.Occurrence(game.Event)
        ctx := r.Step(game.Event) {
            tick   = tick,
            epoch  = 1,
            events = storage[:],
        }
        game.step(&expected, [2]game.Input{control(tick, 0), control(tick, 1)}, &ctx)
        assert(ctx.error == .None)
    }

    cases := [3]Case {
        {"lan_d2", 2, tr.DEFAULT_FAULTS},
        {
            "fault_d2",
            2,
            {latency_ticks = 7, jitter_ticks = 2, loss_permyriad = 1000, duplicate_permyriad = 1000, retry_ticks = 3},
        },
        {
            "fault_d8",
            8,
            {latency_ticks = 7, jitter_ticks = 2, loss_permyriad = 1000, duplicate_permyriad = 1000, retry_ticks = 3},
        },
    }
    baseline: u64

    for scenario in cases {
        // One unreported warm-up; alternate instrumentation order by trial.
        run(scenario, false, expected)

        for trial in 0 ..< 5 {
            values: [2]Result

            for order in 0 ..< 2 {
                profiled := (order + trial) % 2 == 1
                value := run(scenario, profiled, expected)
                values[profiled ? 1 : 0] = value

                if baseline == 0 {
                    baseline = value.hash
                }

                assert(value.hash == baseline)
                fmt.printf(
                    "RDP_BENCH case=%s trial=%d profiled=%d ticks=%d cycles=%d cpu_us=%d wall_us=%d hash=%d tx_bytes=%d rollbacks=%d replayed=%d stalls=%d max_depth=%d world_bytes=%d\n",
                    scenario.name,
                    trial,
                    int(profiled),
                    TICKS,
                    value.cycles,
                    value.cpu_us,
                    value.wall_us,
                    value.hash,
                    value.tx_bytes,
                    value.rollbacks,
                    value.replayed,
                    value.stalls,
                    value.max_depth,
                    size_of(game.World),
                )

                if profiled {
                    for metric in rb.Profile_Metric {
                        // Input latency in this accelerated loop is not real-time latency.
                        if metric == .Input_Latency {
                            continue
                        }

                        t := value.timings[metric]
                        fmt.printf(
                            "RDP_BENCH_WORK case=%s trial=%d metric=%v samples=%d total_us=%d max_us=%d p95_upper_us=%d p99_upper_us=%d errors=%d\n",
                            scenario.name,
                            trial,
                            metric,
                            t.samples,
                            t.total_us,
                            t.max_us,
                            r.timing_percentile_upper(t, 95),
                            r.timing_percentile_upper(t, 99),
                            t.errors,
                        )
                    }
                }
            }

            assert(
                values[0].cycles == values[1].cycles &&
                values[0].tx_bytes == values[1].tx_bytes &&
                values[0].replayed == values[1].replayed &&
                values[0].stalls == values[1].stalls,
            )
        }
    }
}
