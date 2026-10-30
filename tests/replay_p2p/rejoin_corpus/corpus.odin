package rejoin_corpus

import "core:reflect"
import r "godot:replay"
import rb "godot:replay/p2p"
import tr "godot:replay/transport"

World :: struct {position: [3]i32, shots: [3]u32}
Input :: struct {move: i8, fire: bool}
Event :: struct {seat: u8, shot: u32}
Peer :: rb.Runner(World, Input, Event, 3)
Fixture :: struct {network: tr.Memory, endpoints: [3]tr.Memory_Endpoint, peers: [3]Peer, clock: u64}
ROSTER :: [3]tr.Peer_Id{1, 2, 3}

step :: proc(w: ^World, inputs: [3]Input, ctx: ^r.Step(Event)) {
    for input, i in inputs {
        w.position[i] += i32(input.move)
        if input.fire {w.shots[i] += 1; r.emit(ctx, u64(i + 1), 1, Event{u8(i), w.shots[i]})}
    }
}
// Odin dev-2026-04 arm64 -o:speed miscompiles the inlined factory in the
// watch-failover caller: its step-address register is overwritten by an endpoint
// address before the model store. Keep this fixture factory out of line; runner
// initialization still receives model() directly. See the framework-audit receipt.
model :: #force_no_inline proc() -> rb.Model(World, Input, Event, 3) {
    return {step = step, input_valid = proc(i: Input) -> bool {return i.move >= -1 && i.move <= 1},
        state_valid = proc(w: World) -> bool {return true}, hold = proc(i: Input) -> Input {return {move = i.move}}}
}
control :: proc(tick: u64, seat: int) -> Input {
    return {move = (tick / 9 + u64(seat)) % 2 == 0 ? 1 : -1, fire = tick % (17 + u64(seat)) == 0}
}
cycle :: proc(f: ^Fixture, until: u64, absent := -1) {
    assert(tr.memory_advance(&f.network, f.clock))
    for &peer, i in f.peers {
        if i == absent {continue}
        error := rb.pump(&peer, f.clock * 1000 / 60)
        assert(error == .None || (absent >= 0 && error == .Transport && peer.phase == .Disconnected))
        if peer.phase == .Running && peer.timeline.head < until {
            result := rb.advance(&peer, control(peer.timeline.head + u64(peer.cfg.delay) + 1, i))
            assert(result.error == .None || result.error == .Waiting || result.error == .Capacity)
        }
    }
    f.clock += 1
}

// Each seed restarts two different participants, separately, while both other
// runners retain their live frames and allocations. Timeouts precede each rebind.
verify_case :: proc(seed: u64) -> u64 {
    f: Fixture
    assert(tr.memory_init(&f.network, seed, {3, 512, 1024, 8192},
        {latency_ticks = 3, jitter_ticks = 2, loss_permyriad = 1000, duplicate_permyriad = 1000, retry_ticks = 3}))
    defer tr.memory_destroy(&f.network)
    defer {for &peer in f.peers {rb.destroy(&peer)}; for &endpoint in f.endpoints {wire := tr.memory_transport(&endpoint); tr.close(&wire)}}
    cfg := rb.DEFAULT_CONFIG; cfg.history = 64; roster := ROSTER
    for &peer, i in f.peers {
        assert(tr.memory_open(&f.network, &f.endpoints[i], roster[i]))
        assert(rb.init(&peer, r.Frame(World){}, model(), ROSTER, u16(i), tr.memory_transport(&f.endpoints[i]), cfg) == .None)
    }
    for restart in 0 ..< 2 {
        target := u64(90 + restart * 110)
        for _ in 0 ..< 360 {cycle(&f, target)}
        absent := int((seed + u64(restart)) % 3)
        archive: rb.Archive(World, Input, Event, 3)
        assert(rb.archive_capture(&f.peers[absent], &archive) == .None)
        rb.destroy(&f.peers[absent])
        for _ in 0 ..< 360 {cycle(&f, target + 50, absent)}
        // Provider retires all old deliveries, including between survivors.
        for &packet in f.network.packets {packet.active = false}
        assert(rb.restore(&f.peers[absent], &archive, model(), ROSTER, u16(absent), tr.memory_transport(&f.endpoints[absent])) == .None)
        rb.archive_destroy(&archive)
        for &peer, i in f.peers {
            if i == absent {continue}
            assert(peer.phase == .Disconnected && peer.stats.stalls > 0)
            before, ok := r.current(&peer.timeline); assert(ok)
            storage := raw_data(peer.timeline.records); sampled := peer.sampled
            received := peer.received; confirmed := peer.timeline.confirmed
            assert(rb.reconnect(&peer, peer.wire, f.clock * 1000 / 60) == .None)
            after, valid := r.current(&peer.timeline); assert(valid)
            assert(reflect.equal(before, after) && raw_data(peer.timeline.records) == storage)
            assert(peer.sampled == sampled && peer.received == received && peer.timeline.confirmed == confirmed)
        }
    }
    for _ in 0 ..< 600 {cycle(&f, 360)}
    expected: World; events: [3]r.Occurrence(Event)
    for tick in u64(1) ..= 360 {
        inputs: [3]Input
        if tick > u64(cfg.delay) {for &input, i in inputs {input = control(tick, i)}}
        ctx := r.Step(Event){tick = tick, epoch = 1, events = events[:]}
        step(&expected, inputs, &ctx)
    }
    for &peer in f.peers {
        frame, ok := r.current(&peer.timeline)
        assert(ok && frame.tick == 360 && peer.timeline.confirmed == 360)
        assert(reflect.equal(frame.state, expected) && peer.chain == f.peers[0].chain)
    }
    return f.peers[0].chain
}
