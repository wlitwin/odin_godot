// Dockyard network-condition harness.
//
// Runs the actual Dockyard model (authored world, rules, complete Box3D codec)
// as a listen host and one predicting client inside one process, joined by the
// deterministic Memory transport with per-direction latency, jitter, loss and
// bandwidth. Both seats are driven by Dockyard's own carry controller from
// their OWN view of the world (host: authority head, client: predicted head),
// so inputs change the way real play does. Each side renders on its own frame
// clock and drives the runner exactly like replay/godot session_frame.
//
// Everything that can affect feel is measured: client stalls/frozen frames,
// prediction depth, host-held inputs, corrections and replayed ticks, raw
// rendered robot snaps, displayed error against the authority's own pose for
// the same tick, per-frame CPU of the runner calls, bytes on the wire, and a
// periodic complete-state (solver + game) equality check.
//
//   odin build tests/replay_dockyard/netsim -collection:godot=. \
//     -define:BOX3D_LIBRARY=/abs/libogb3.dylib -define:DOCKYARD_DEFINITION=/abs/definition.json ...
//   ./netsim rtt=100 jitter=10 loss=100 kbps=8000 seconds=60
package dockyard_netsim

import "core:fmt"
import "core:math"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"
import a "godot:box3d/authoring"
import bp "godot:box3d/presentation"
import game "godot:examples/replay_dockyard/modules/dockyard"
import r "godot:replay"
import rgd "godot:replay/godot"
import net "godot:replay/net"
import ph "godot:replay/physics"
import tr "godot:replay/transport"
import "godot:replay/view"

DEFINITION :: #load(#config(DOCKYARD_DEFINITION, ""))
HZ :: 60
HISTORY_TICKS :: 1 << 16

Args :: struct {
    rtt_ms, jitter_ms, loss_permyriad, kbps, seconds, seed: int,
    snapshot_every, frame_jitter_ms, layout, retry_ms:      int,
    window:                                                 int, // 0 = runner default
    delay, ping:                                            int, // input delay max ticks / ping threshold ms
    label:                                                  string,
}

Side :: struct {
    clock:      r.Clock,
    next_frame: f64,
    last_frame: f64,
    controller: game.Carry_Controller,
    control:    game.Control,
    cpu_us:     [dynamic]f64,
}

Metrics :: struct {
    client_frames, frozen_frames, stalled_steps, consumed_steps: int,
    snaps, big_snaps, host_snaps, host_big_snaps:                int,
    depth_samples, ahead_samples:                                [dynamic]u64,
    margin_samples:                                              [dynamic]f64,
    local_error, remote_error:                                   [dynamic]f64,
    equal_checks, unequal_checks, check_errors:                  int,
    host_control_changes, guest_control_changes:                 int,
    errors:                                                      [dynamic]string,
}

args_parse :: proc() -> Args {
    out := Args {
        rtt_ms          = 0,
        ping            = 100,
        seconds         = 60,
        seed            = 1,
        snapshot_every  = 1,
        frame_jitter_ms = 2,
        label           = "run",
    }

    for arg in os.args[1:] {
        parts := strings.split_n(arg, "=", 2, context.temp_allocator)

        if len(parts) != 2 {
            fmt.eprintln("ignored argument", arg)
            continue
        }

        if parts[0] == "label" {
            out.label = parts[1]
            continue
        }

        value, ok := strconv.parse_int(parts[1])

        if !ok {
            fmt.eprintln("bad value", arg)
            os.exit(2)
        }

        switch parts[0] {
        case "rtt":
            out.rtt_ms = value
        case "jitter":
            out.jitter_ms = value
        case "loss":
            out.loss_permyriad = value
        case "kbps":
            out.kbps = value
        case "seconds":
            out.seconds = value
        case "seed":
            out.seed = value
        case "snapshot_every":
            out.snapshot_every = value
        case "frame_jitter":
            out.frame_jitter_ms = value
        case "layout":
            out.layout = value
        case "retry":
            out.retry_ms = value
        case "window":
            out.window = value
        case "delay":
            out.delay = value
        case "ping":
            out.ping = value
        case:
            fmt.eprintln("unknown argument", arg)
            os.exit(2)
        }
    }

    return out
}

fail :: proc(m: ^Metrics, message: string) {
    if len(m.errors) < 16 {
        append(&m.errors, strings.clone(message))
    }
}

// Seat robot position from a complete checkpoint of either side's timeline.
robot_positions :: proc(
    cp: ^r.Complete_Checkpoint(game.Game, net.Net_Event(game.Event)),
) -> (
    out: [2][3]f32,
    frame: bp.Frame,
    ok: bool,
) {
    f, projection_error, owner_error := rgd.physics_presentation_frame(cp, game.project, 0, .Predicted)

    if projection_error != .None || owner_error != .None {
        return
    }

    for seat in 1 ..= 2 {
        key := bp.Body_Key(cp.frame.state.bodies[seat])

        for row in f.rows[:f.count] {
            if row.body == key {
                out[seat - 1] = row.pose.position
            }
        }
    }

    return out, f, true
}

percentile :: proc(values: []f64, p: f64) -> f64 {
    if len(values) == 0 {
        return 0
    }

    sorted := slice.clone(values, context.temp_allocator)
    slice.sort(sorted)
    index := clamp(int(math.ceil(p * f64(len(sorted)))) - 1, 0, len(sorted) - 1)
    return sorted[index]
}

percentile_u64 :: proc(values: []u64, p: f64) -> u64 {
    if len(values) == 0 {
        return 0
    }

    sorted := slice.clone(values, context.temp_allocator)
    slice.sort(sorted)
    index := clamp(int(math.ceil(p * f64(len(sorted)))) - 1, 0, len(sorted) - 1)
    return sorted[index]
}

distance :: proc(x, y: [3]f32) -> f64 {
    d := x - y
    return math.sqrt(f64(d.x * d.x + d.y * d.y + d.z * d.z))
}

main :: proc() {
    args := args_parse()
    metrics: Metrics

    baked, diagnostic := a.parse_and_bake(DEFINITION)

    if diagnostic.error != .None {
        fmt.eprintln("definition bake failed", diagnostic.error)
        os.exit(1)
    }

    built, problem := a.build(&baked, game.PROFILE)

    if problem.error != .None {
        fmt.eprintln("definition build failed", problem.error)
        os.exit(1)
    }

    state, valid := game.initial_game(&baked, &built)

    if !valid || !game.prepare_initial_round(built.world, &state, u8(args.layout)) {
        fmt.eprintln("initial round failed")
        os.exit(1)
    }

    config, config_error := ph.authoring_config(&baked)
    codec := new(game.Codec)

    if config_error != .None || ph.network_codec_init(codec, &built.catalog, config, game.rules()) != .None {
        fmt.eprintln("codec failed")
        os.exit(1)
    }

    initial, initial_error := ph.authoring_checkpoint(
        &built,
        config,
        r.Frame(game.Game){state = state},
        net.Net_Event(game.Event),
    )

    if initial_error != .None {
        fmt.eprintln("initial checkpoint failed", initial_error)
        os.exit(1)
    }

    model := game.model(codec)
    one_way := u32(args.rtt_ms / 2)
    retry := args.retry_ms > 0 ? u32(args.retry_ms) : max(u32(args.rtt_ms) + 2 * u32(args.jitter_ms), 40)
    faults := tr.Faults {
        latency_ticks  = one_way,
        jitter_ticks   = u32(args.jitter_ms),
        loss_permyriad = u32(args.loss_permyriad),
        retry_ticks    = retry,
        bytes_per_tick = u32(args.kbps * 1000 / 8 / 1000), // kbit/s -> bytes per ms
    }
    memory := new(tr.Memory)

    if !tr.memory_init(memory, u64(args.seed), {2, 4096, 40 * 1024, 1}, faults) {
        fmt.eprintln("memory transport init failed")
        os.exit(1)
    }

    endpoints := new([2]tr.Memory_Endpoint)

    for &endpoint, index in endpoints {
        tr.memory_open(memory, &endpoint, tr.Peer_Id(index + 1))
    }

    cfg := net.physics_config_default()
    cfg.snapshot_every = u32(args.snapshot_every)

    if args.window > 0 {
        cfg.max_prediction = u32(args.window)
        cfg.max_future = u32(args.window)
        cfg.max_rewind = u32(args.window)
        cfg.max_view_span = u32(args.window)
    }

    cfg.input_delay_max, cfg.input_delay_ping_ms = u32(args.delay), u32(args.ping)
    server := new(net.Server(game.Game, game.Control, game.Action, game.Event, 2))
    client := new(net.Client(game.Game, game.Control, game.Action, game.Event, 2))

    if error := net.server_init_complete(
        server,
        &initial,
        model,
        tr.memory_transport(&endpoints[0]),
        cfg,
        local_seat = 1,
    ); error != .None {
        fmt.eprintln("server init", error)
        os.exit(1)
    }

    net.server_set_local_token(server, net.Token{0 = 101})

    if error := net.client_init(client, model, tr.memory_transport(&endpoints[1]), net.Token{0 = 202}, cfg = cfg);
       error != .None {
        fmt.eprintln("client init", error)
        os.exit(1)
    }

    r.complete_checkpoint_destroy(&initial)

    host, guest: Side
    r.clock_init(&host.clock, HZ)
    r.clock_init(&guest.clock, HZ)
    guest.next_frame = 7
    frame_ms := 1000.0 / 60.0
    rng := r.rng_make(u64(args.seed) * 7919 + 13)

    // Authority pose per tick (seat robots) and the client's latest displayed
    // predicted pose per tick, compared once both exist.
    host_pose := make([][2][3]f32, HISTORY_TICKS)
    host_pose_tick := make([]u64, HISTORY_TICKS)
    shown_pose := make([dynamic][2][3]f32)
    shown_tick := make([dynamic]u64)
    trail, host_trail: [3][3]f32
    trail_count, host_trail_count := 0, 0
    changes: [256]view.Change(net.Net_Event(game.Event))
    total_ms := u64(args.seconds * 1000)
    running_at := u64(0)

    for now in u64(0) ..= total_ms {
        tr.memory_advance(memory, now)

        if f64(now) >= host.next_frame {
            dt := host.last_frame == 0 ? frame_ms / 1000 : (f64(now) - host.last_frame) / 1000
            host.last_frame = f64(now)
            started := time.tick_now()
            cpu := time.Duration(0)

            if error := net.server_pump(server, now, flush_egress = false); error != .None {
                fail(&metrics, fmt.tprintf("server_pump %v at %d", error, now))
            }

            cpu += time.tick_since(started)
            steps, _ := r.clock_add(&host.clock, dt)

            for _ in 0 ..< steps {
                // Host input comes from its own authority view.
                cp, capture_error := r.capture_complete(&server.timeline, server.timeline.head)

                if capture_error == .None {
                    _, frame, ok := robot_positions(&cp)

                    if ok {
                        previous := host.control
                        host.control = game.canonical_control(
                            game.suggest_control(cp.frame.state, frame, 1, &host.controller),
                        )
                        metrics.host_control_changes += previous == host.control ? 0 : 1
                    }

                    r.complete_checkpoint_destroy(&cp)
                }

                step_started := time.tick_now()
                net.server_local(server, host.control)

                if error := net.server_step(server); error != .None {
                    fail(&metrics, fmt.tprintf("server_step %v at %d", error, now))
                }

                cpu += time.tick_since(step_started)
                r.clock_consume(&host.clock)
                head := server.timeline.head
                cp2, e2 := r.capture_complete(&server.timeline, head)

                if e2 == .None {
                    poses, _, ok := robot_positions(&cp2)

                    if ok {
                        host_pose[head % HISTORY_TICKS] = poses
                        host_pose_tick[head % HISTORY_TICKS] = head
                    }

                    // Baseline: the authority's own robot never corrects, so
                    // its second difference is ordinary driving motion.
                    if ok && steps == 1 {
                        host_trail[0], host_trail[1], host_trail[2] = host_trail[1], host_trail[2], poses[0]
                        host_trail_count += 1

                        if host_trail_count >= 3 {
                            jerk := distance(host_trail[2] - host_trail[1], host_trail[1] - host_trail[0])
                            metrics.host_snaps += jerk > 0.03 ? 1 : 0
                            metrics.host_big_snaps += jerk > 0.15 ? 1 : 0
                        }
                    }

                    r.complete_checkpoint_destroy(&cp2)
                }
            }

            flush_started := time.tick_now()
            net.server_flush_pending(server)
            cpu += time.tick_since(flush_started)
            append(&host.cpu_us, f64(time.duration_microseconds(cpu)))
            host.next_frame +=
                frame_ms + f64(i64(r.rng_next(&rng) % u64(2 * args.frame_jitter_ms + 1)) - i64(args.frame_jitter_ms))
        }

        if f64(now) >= guest.next_frame {
            dt := guest.last_frame == 0 ? frame_ms / 1000 : (f64(now) - guest.last_frame) / 1000
            guest.last_frame = f64(now)
            started := time.tick_now()
            catchups := client.stats.snapshot_catchups

            if error := net.client_pump(client, now); error != .None {
                fail(&metrics, fmt.tprintf("client_pump %v at %d", error, now))
            }

            cpu := time.tick_since(started)
            elapsed := dt * client.clock_scale

            if client.stats.snapshot_catchups != catchups {
                r.clock_init(&guest.clock, HZ)
                elapsed = 0
            }

            steps, _ := r.clock_add(&guest.clock, elapsed)
            head_before := client.timeline.head

            for _ in 0 ..< steps {
                if client.phase == .Running {
                    step_started := time.tick_now()
                    error := net.client_step(client, guest.control)
                    cpu += time.tick_since(step_started)

                    if error == .None {
                        metrics.consumed_steps += 1
                    } else if error == .Capacity {
                        metrics.stalled_steps += 1
                    } else {
                        fail(&metrics, fmt.tprintf("client_step %v at %d", error, now))
                    }
                }

                r.clock_consume(&guest.clock)
            }

            for view.drain(&client.journal, changes[:]) == len(changes) {}

            append(&guest.cpu_us, f64(time.duration_microseconds(cpu)))

            if client.phase == .Running {
                if running_at == 0 {
                    running_at = now
                }

                metrics.client_frames += 1

                if steps > 0 && client.timeline.head == head_before {
                    metrics.frozen_frames += 1
                }

                append(&metrics.depth_samples, client.timeline.head - client.timeline.confirmed)
                append(
                    &metrics.ahead_samples,
                    client.timeline.head > server.timeline.head ? client.timeline.head - server.timeline.head : 0,
                )
                append(&metrics.margin_samples, client.input_timing.arrival_lead)
                cp, capture_error := r.capture_complete(&client.timeline, client.timeline.head)

                if capture_error == .None {
                    poses, frame, ok := robot_positions(&cp)

                    if ok {
                        previous := guest.control
                        guest.control = game.canonical_control(
                            game.suggest_control(cp.frame.state, frame, 2, &guest.controller),
                        )
                        metrics.guest_control_changes += previous == guest.control ? 0 : 1
                        append(&shown_pose, poses)
                        append(&shown_tick, client.timeline.head)
                        // Raw rendered local-robot snap: second difference of
                        // the displayed position, frame to frame.
                        trail[0], trail[1], trail[2] = trail[1], trail[2], poses[1]
                        trail_count += 1

                        if trail_count >= 3 {
                            jerk := distance(trail[2] - trail[1], trail[1] - trail[0])

                            if jerk > 0.03 {
                                metrics.snaps += 1
                            }

                            if jerk > 0.15 {
                                metrics.big_snaps += 1
                            }
                        }
                    }

                    r.complete_checkpoint_destroy(&cp)
                }
            }

            guest.next_frame +=
                frame_ms + f64(i64(r.rng_next(&rng) % u64(2 * args.frame_jitter_ms + 1)) - i64(args.frame_jitter_ms))
        }

        // Periodic complete equality: the client's confirmed frame must be
        // byte-identical (solver dump + game) to the authority's same tick.
        if now % 2000 == 1999 && client.phase == .Running && client.timeline.confirmed > 0 {
            tick := client.timeline.confirmed

            if tick + 100 < server.timeline.head {
                metrics.check_errors += 1
            } else {
                left, le := r.capture_complete(&client.timeline, tick)
                right, re := r.capture_complete(&server.timeline, tick)

                if le == .None && re == .None {
                    n, _ := ph.dump(&left, nil)
                    m, _ := ph.dump(&right, nil)
                    x := make([]u8, int(n), context.temp_allocator)
                    y := make([]u8, int(m), context.temp_allocator)
                    ph.dump(&left, x)
                    ph.dump(&right, y)

                    if n == m && mem.compare(x, y) == 0 && left.frame.state == right.frame.state {
                        metrics.equal_checks += 1
                    } else {
                        metrics.unequal_checks += 1
                    }
                } else {
                    metrics.check_errors += 1
                }

                if le == .None {
                    r.complete_checkpoint_destroy(&left)
                }

                if re == .None {
                    r.complete_checkpoint_destroy(&right)
                }
            }
        }

        free_all(context.temp_allocator)
    }

    for poses, i in shown_pose {
        tick := shown_tick[i]
        slot := tick % HISTORY_TICKS

        if host_pose_tick[slot] == tick && tick != 0 {
            append(&metrics.local_error, distance(poses[1], host_pose[slot][1]))
            append(&metrics.remote_error, distance(poses[0], host_pose[slot][0]))
        }
    }

    cs, ss := client.stats, server.stats
    running_s := f64(total_ms - running_at) / 1000
    sb := strings.builder_make()
    fmt.sbprintf(
        &sb,
        `{{"label":%q,"rtt_ms":%d,"jitter_ms":%d,"loss_permyriad":%d,"kbps":%d,"seconds":%d,`,
        args.label,
        args.rtt_ms,
        args.jitter_ms,
        args.loss_permyriad,
        args.kbps,
        args.seconds,
    )
    fmt.sbprintf(
        &sb,
        `"snapshot_every":%d,"window":%d,"seed":%d,"input_delay":%d,`,
        args.snapshot_every,
        cfg.max_prediction,
        args.seed,
        client.input_delay,
    )
    fmt.sbprintf(
        &sb,
        `"client_phase":%q,"host_head":%d,"client_head":%d,"client_confirmed":%d,`,
        fmt.tprint(client.phase),
        server.timeline.head,
        client.timeline.head,
        client.timeline.confirmed,
    )
    fmt.sbprintf(
        &sb,
        `"host_held_inputs":%d,"host_held_pct":%.1f,`,
        ss.held_inputs,
        100 * f64(ss.held_inputs) / max(f64(server.timeline.head), 1),
    )
    fmt.sbprintf(
        &sb,
        `"client_corrections":%d,"client_replayed_ticks":%d,"client_reused_ticks":%d,"client_stalls":%d,"client_resyncs":%d,"snapshot_catchups":%d,"lead_updates":%d,"lead_ticks":%d,`,
        cs.corrections,
        cs.replayed_ticks,
        cs.reused_correction_ticks,
        cs.stalls,
        cs.resyncs,
        cs.snapshot_catchups,
        cs.lead_updates,
        client.lead_ticks,
    )
    fmt.sbprintf(
        &sb,
        `"stalled_steps":%d,"consumed_steps":%d,"frozen_frame_pct":%.2f,"snaps_per_min":%.1f,"big_snaps_per_min":%.1f,`,
        metrics.stalled_steps,
        metrics.consumed_steps,
        100 * f64(metrics.frozen_frames) / max(f64(metrics.client_frames), 1),
        f64(metrics.snaps) / max(running_s / 60, 1e-9),
        f64(metrics.big_snaps) / max(running_s / 60, 1e-9),
    )
    fmt.sbprintf(
        &sb,
        `"host_snaps_per_min":%.1f,"host_big_snaps_per_min":%.1f,`,
        f64(metrics.host_snaps) / max(f64(args.seconds) / 60, 1e-9),
        f64(metrics.host_big_snaps) / max(f64(args.seconds) / 60, 1e-9),
    )
    fmt.sbprintf(
        &sb,
        `"host_control_change_pct":%.1f,"guest_control_change_pct":%.1f,`,
        100 * f64(metrics.host_control_changes) / max(f64(server.timeline.head), 1),
        100 * f64(metrics.guest_control_changes) / max(f64(metrics.client_frames), 1),
    )
    fmt.sbprintf(
        &sb,
        `"ahead_p50":%d,"ahead_p95":%d,"margin_p05":%.1f,"margin_p50":%.1f,"margin_p95":%.1f,`,
        percentile_u64(metrics.ahead_samples[:], .5),
        percentile_u64(metrics.ahead_samples[:], .95),
        percentile(metrics.margin_samples[:], .05),
        percentile(metrics.margin_samples[:], .5),
        percentile(metrics.margin_samples[:], .95),
    )
    fmt.sbprintf(
        &sb,
        `"depth_p50":%d,"depth_p95":%d,"depth_max":%d,`,
        percentile_u64(metrics.depth_samples[:], .5),
        percentile_u64(metrics.depth_samples[:], .95),
        percentile_u64(metrics.depth_samples[:], 1),
    )
    fmt.sbprintf(
        &sb,
        `"local_err_p50_m":%.3f,"local_err_p95_m":%.3f,"local_err_max_m":%.3f,"remote_err_p50_m":%.3f,"remote_err_p95_m":%.3f,`,
        percentile(metrics.local_error[:], .5),
        percentile(metrics.local_error[:], .95),
        percentile(metrics.local_error[:], 1),
        percentile(metrics.remote_error[:], .5),
        percentile(metrics.remote_error[:], .95),
    )
    fmt.sbprintf(
        &sb,
        `"client_cpu_p50_ms":%.3f,"client_cpu_p95_ms":%.3f,"client_cpu_p99_ms":%.3f,"client_cpu_max_ms":%.3f,`,
        percentile(guest.cpu_us[:], .5) / 1000,
        percentile(guest.cpu_us[:], .95) / 1000,
        percentile(guest.cpu_us[:], .99) / 1000,
        percentile(guest.cpu_us[:], 1) / 1000,
    )
    fmt.sbprintf(
        &sb,
        `"host_cpu_p50_ms":%.3f,"host_cpu_p95_ms":%.3f,"host_cpu_max_ms":%.3f,`,
        percentile(host.cpu_us[:], .5) / 1000,
        percentile(host.cpu_us[:], .95) / 1000,
        percentile(host.cpu_us[:], 1) / 1000,
    )
    fmt.sbprintf(
        &sb,
        `"host_tx_kbps":%.1f,"client_tx_kbps":%.1f,`,
        f64(ss.tx_bytes) * 8 / 1000 / max(f64(args.seconds), 1),
        f64(cs.tx_bytes) * 8 / 1000 / max(f64(args.seconds), 1),
    )
    fmt.sbprintf(
        &sb,
        `"equal_checks":%d,"unequal_checks":%d,"check_errors":%d,"errors":[`,
        metrics.equal_checks,
        metrics.unequal_checks,
        metrics.check_errors,
    )

    for e, i in metrics.errors {
        fmt.sbprintf(&sb, "%s%q", i == 0 ? "" : ",", e)
    }

    fmt.sbprint(&sb, "]}")
    fmt.println(strings.to_string(sb))
    net.client_destroy(client)
    net.server_destroy(server)
    ph.network_codec_destroy(codec)
    a.built_destroy(&built)
    a.destroy(&baked)
}
