package replay_p2p_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import rb "godot:replay/p2p"
import tr "godot:replay/transport"

World :: struct {
    x:     [2]i32,
    shots: [2]u32,
}

Input :: struct {
    move: i8,
    fire: bool,
}

Event :: struct {
    seat: u8,
    shot: u32,
}

Peer :: rb.Runner(World, Input, Event, 2)

model_step :: proc(w: ^World, inputs: [2]Input, ctx: ^r.Step(Event)) {
    for input, i in inputs {
        w.x[i] += i32(input.move)

        if input.fire {
            w.shots[i] += 1
            r.emit(ctx, u64(i + 1), 1, Event{u8(i), w.shots[i]})
        }
    }
}

model :: proc() -> rb.Model(World, Input, Event, 2) {
    return {step = model_step, input_valid = proc(i: Input) -> bool {
            return i.move >= -1 && i.move <= 1
        }, state_valid = proc(w: World) -> bool {
            return true
        }, hold = proc(i: Input) -> Input {
            return {move = i.move}
        }}
}

control :: proc(tick: u64, seat: int) -> Input {
    return {move = (tick / 9 + u64(seat)) % 2 == 0 ? 1 : -1, fire = tick % (17 + u64(seat)) == 0}
}

Fixture :: struct {
    network:   tr.Memory,
    endpoints: [2]tr.Memory_Endpoint,
    peers:     [2]Peer,
    clock:     u64,
}

setup :: proc(f: ^Fixture, faults := tr.DEFAULT_FAULTS) {
    assert(tr.memory_init(&f.network, seed = 42, cfg = {2, 512, 16384, 65536}, faults = faults))
    roster := [2]tr.Peer_Id{1, 2}

    for &endpoint, i in f.endpoints {
        assert(tr.memory_open(&f.network, &endpoint, roster[i]))
    }

    cfg := rb.DEFAULT_CONFIG
    cfg.history, cfg.max_prediction = 64, 8

    for &peer, i in f.peers {
        assert(
            rb.init(&peer, r.Frame(World){}, model(), roster, u16(i), tr.memory_transport(&f.endpoints[i]), cfg) ==
            .None,
        )
    }
}

cleanup :: proc(f: ^Fixture) {
    for &peer in f.peers {
        rb.destroy(&peer)
    }

    for &endpoint in f.endpoints {
        wire := tr.memory_transport(&endpoint)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.network)
}

cycle :: proc(f: ^Fixture, until: u64) {
    assert(tr.memory_advance(&f.network, f.clock))

    for &peer, i in f.peers {
        err := rb.pump(&peer, f.clock * 1000 / 60)
        assert(err == .None)

        if peer.phase == .Running && peer.timeline.head < until {
            result := rb.advance(&peer, control(peer.timeline.head + u64(peer.cfg.delay) + 1, i))
            assert(result.error == .None || result.error == .Waiting || result.error == .Capacity)
        }
    }

    f.clock += 1
}

expect_reference :: proc(t: ^testing.T, f: ^Fixture, tick: u64) {
    w: World
    storage: [4]r.Occurrence(Event)

    for at in u64(1) ..= tick {
        inputs: [2]Input

        if at > u64(f.peers[0].cfg.delay) {
            for &value, i in inputs {
                value = control(at, i)
            }
        }

        ctx := r.Step(Event) {
            tick   = at,
            epoch  = 1,
            events = storage[:],
        }
        model_step(&w, inputs, &ctx)
    }

    for &peer in f.peers {
        frame, _ := r.current(&peer.timeline)
        testing.expect_value(t, frame.tick, tick)
        testing.expect_value(t, peer.timeline.confirmed, tick)
        testing.expect(t, reflect.equal(frame.state, w))
    }

    testing.expect_value(t, f.peers[0].chain, f.peers[1].chain)
}

@(test)
peer_inputs_rollback_and_confirm_equal_worlds_under_faults :: proc(t: ^testing.T) {
    f: Fixture
    setup(
        &f,
        {latency_ticks = 3, jitter_ticks = 2, loss_permyriad = 1500, duplicate_permyriad = 1000, retry_ticks = 3},
    )
    defer cleanup(&f)

    for _ in 0 ..< 900 {
        cycle(&f, 240)
    }

    expect_reference(t, &f, 240)
    testing.expect(t, f.peers[0].stats.rollbacks + f.peers[1].stats.rollbacks > 0)
    testing.expect(t, f.peers[0].stats.duplicate_inputs + f.peers[1].stats.duplicate_inputs > 0)
}

@(test)
blackout_stalls_at_bounded_horizon_then_repairs_without_authority_snapshots :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer cleanup(&f)

    for _ in 0 ..< 50 {
        cycle(&f, 180)
    }

    tr.memory_set_faults(&f.network, {loss_permyriad = 10000, retry_ticks = 3})

    for _ in 0 ..< 90 {
        cycle(&f, 180)
    }

    for &peer in f.peers {
        testing.expect(t, peer.stats.stalls > 0)
        testing.expect(t, peer.timeline.head - peer.timeline.confirmed <= u64(peer.cfg.max_prediction))
    }

    tr.memory_set_faults(&f.network, tr.DEFAULT_FAULTS)

    for _ in 0 ..< 400 {
        cycle(&f, 180)
    }

    expect_reference(t, &f, 180)
}

@(test)
different_execution_is_detected_by_rolling_confirmed_checksums :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer cleanup(&f)
    f.peers[1].model.step = proc(w: ^World, inputs: [2]Input, ctx: ^r.Step(Event)) {
        model_step(w, inputs, ctx)

        if ctx.tick == 12 {
            w.x[0] += 1
        }
    }
    detected := false

    for _ in 0 ..< 100 {
        tr.memory_advance(&f.network, f.clock)

        for &peer, i in f.peers {
            err := rb.pump(&peer, f.clock * 1000 / 60)

            if err == .Diverged {
                detected = true
                break
            }

            if peer.phase == .Running {
                rb.advance(&peer, control(peer.timeline.head + u64(peer.cfg.delay) + 1, i))
            }
        }

        if detected {
            break
        }

        f.clock += 1
    }

    testing.expect(t, detected)
}

@(test)
contract_mismatch_fails_before_running_the_match :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer cleanup(&f)
    f.peers[1].contract ~= 1

    for tick in 0 ..< 10 {
        tr.memory_advance(&f.network, u64(tick))

        for &peer in f.peers {
            rb.pump(&peer, u64(tick * 16))
        }
    }

    testing.expect(t, f.peers[0].phase == .Failed || f.peers[1].phase == .Failed)
    testing.expect_value(t, f.peers[0].timeline.head, u64(0))
}

@(test)
changed_peer_input_is_refused_even_after_the_tick_was_confirmed :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer cleanup(&f)

    for _ in 0 ..< 80 {
        cycle(&f, 30)
    }

    // Simulate a faulty/malicious sender retransmitting a different value for
    // an already accepted tick. This still travels through the real wire codec.
    sender := &f.peers[0]
    sender.inputs[5].value.move = sender.inputs[5].value.move == 1 ? -1 : 1
    sender.acknowledged[1] = 4
    rb.pump(sender, f.clock * 1000 / 60 + 100)
    tr.memory_advance(&f.network, f.clock + 1)
    testing.expect_value(t, rb.pump(&f.peers[1], f.clock * 1000 / 60 + 101), rb.Error.Conflict)
    testing.expect_value(t, f.peers[1].phase, rb.Phase.Failed)
    testing.expect_value(t, f.peers[1].timeline.confirmed, u64(30))
}

@(test)
timeout_freezes_the_peer_without_inventing_replacement_inputs :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer cleanup(&f)

    for _ in 0 ..< 30 {
        cycle(&f, 100)
    }

    c := &f.peers[0]
    head := c.timeline.head
    tr.memory_set_faults(&f.network, {loss_permyriad = 10000, retry_ticks = 3})
    tr.memory_advance(&f.network, f.clock + 1000)
    // Drain anything already in flight, then leave the remote silent.
    rb.pump(c, f.clock * 1000 / 60 + 100)
    testing.expect_value(t, rb.pump(c, f.clock * 1000 / 60 + 10000), rb.Error.Transport)
    testing.expect_value(t, c.phase, rb.Phase.Disconnected)
    testing.expect_value(t, rb.advance(c, Input{}).error, rb.Error.Not_Ready)
    testing.expect_value(t, c.timeline.head, head)
}

@(test)
floating_state_is_refused_by_the_strict_runner :: proc(t: ^testing.T) {
    Float_World :: struct {
        x: f32,
    }

    p: rb.Runner(Float_World, Input, Event, 2)
    defer rb.destroy(&p)
    m := rb.Model(Float_World, Input, Event, 2) {
        step = proc(w: ^Float_World, inputs: [2]Input, ctx: ^r.Step(Event)) {},
        input_valid = proc(i: Input) -> bool {
            return true
        },
        state_valid = proc(w: Float_World) -> bool {
            return true
        },
        hold = proc(i: Input) -> Input {
            return i
        },
    }
    testing.expect_value(t, rb.init(&p, r.Frame(Float_World){}, m, [2]tr.Peer_Id{1, 2}, 0, {}), rb.Error.Schema)
    testing.expect(t, !p.ready)
}

@(test)
three_peer_mesh_confirms_all_input_streams :: proc(t: ^testing.T) {
    Mesh_World :: struct {
        x: [3]i32,
    }

    network: tr.Memory
    tr.memory_init(
        &network,
        seed = 19,
        cfg = {3, 512, 8192, 65536},
        faults = {latency_ticks = 2, jitter_ticks = 1, loss_permyriad = 1000, retry_ticks = 2},
    )
    defer tr.memory_destroy(&network)
    endpoints: [3]tr.Memory_Endpoint
    peers: [3]rb.Runner(Mesh_World, Input, Event, 3)

    defer {
        for &peer in peers {
            rb.destroy(&peer)
        }

        for &endpoint in endpoints {
            wire := tr.memory_transport(&endpoint)
            tr.close(&wire)
        }
    }

    m := rb.Model(Mesh_World, Input, Event, 3) {
        step = proc(w: ^Mesh_World, inputs: [3]Input, ctx: ^r.Step(Event)) {
            for input, i in inputs {
                w.x[i] += i32(input.move)
            }
        },
        input_valid = proc(i: Input) -> bool {
            return i.move >= -1 && i.move <= 1
        },
        state_valid = proc(w: Mesh_World) -> bool {
            return true
        },
        hold = proc(i: Input) -> Input {
            return i
        },
    }
    roster := [3]tr.Peer_Id{1, 2, 3}

    for &peer, i in peers {
        tr.memory_open(&network, &endpoints[i], roster[i])
        testing.expect_value(
            t,
            rb.init(&peer, r.Frame(Mesh_World){}, m, roster, u16(i), tr.memory_transport(&endpoints[i])),
            rb.Error.None,
        )
    }

    for clock in 0 ..< 300 {
        tr.memory_advance(&network, u64(clock))

        for &peer, i in peers {
            testing.expect_value(t, rb.pump(&peer, u64(clock * 16)), rb.Error.None)

            if peer.phase == .Running && peer.timeline.head < 90 {
                rb.advance(&peer, control(peer.timeline.head + 3, i))
            }
        }
    }

    for &peer in peers {
        testing.expect_value(t, peer.timeline.confirmed, u64(90))
        testing.expect_value(t, peer.chain, peers[0].chain)
    }
}

@(test)
oversized_packets_are_consumed_without_blocking_the_input_stream :: proc(t: ^testing.T) {
    f: Fixture
    setup(&f)
    defer cleanup(&f)

    for _ in 0 ..< 50 {
        cycle(&f, 30)
    }

    oversized: [9000]u8
    testing.expect_value(t, tr.send(&f.peers[1].wire, 1, .Unreliable, oversized[:]), tr.Send_Result.Sent)

    for _ in 0 ..< 140 {
        cycle(&f, 90)
    }

    testing.expect(t, f.peers[0].stats.rejected > 0)
    expect_reference(t, &f, 90)
}
