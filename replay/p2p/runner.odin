package replay_p2p

import "core:reflect"
import r "godot:replay"
import sc "godot:replay/schema"
import tr "godot:replay/transport"

init :: proc(
    p: ^Runner($S, $I, $E, $N),
    initial: r.Frame(S),
    model: Model(S, I, E, N),
    roster: [N]tr.Peer_Id,
    local: u16,
    wire: tr.Transport,
    cfg := DEFAULT_CONFIG,
    allocator := context.allocator,
) -> Error {
    #assert(N >= 2 && N <= 8)
    roster := roster

    if p.ready || int(local) >= N || !config_valid(cfg, initial.tick) {
        return .Invalid_Config
    }

    storage :=
        2 *
        u64(cfg.history) *
        (u64(size_of(r.Frame(S))) + u64(size_of([N]I)) + u64(cfg.events_per_tick) * u64(size_of(r.Occurrence(E))) + 64)

    if storage > 256 * 1024 * 1024 {
        return .Capacity
    }

    for peer, i in roster {
        if peer == 0 {
            return .Invalid_Config
        }

        for previous in roster[:i] {
            if previous == peer {
                return .Invalid_Config
            }
        }
    }

    if model.step == nil ||
       model.hold == nil ||
       model.input_valid == nil ||
       model.state_valid == nil ||
       !model.input_valid(model.neutral) ||
       !model.state_valid(initial.state) {
        return .Invalid_Model
    }

    p.allocator, p.cfg, p.model, p.roster, p.local, p.wire = allocator, cfg, model, roster, local, wire

    if sc.init(&p.state_codec, S, allocator = allocator).error != .None ||
       sc.init(&p.input_codec, I, allocator = allocator).error != .None ||
       sc.init(&p.event_codec, r.Occurrence(E), allocator = allocator).error != .None ||
       sc.init(&p.hello_codec, Hello, allocator = allocator).error != .None ||
       sc.init(&p.packet_codec, Packet(I), allocator = allocator).error != .None {
        destroy(p)
        return .Schema
    }

    strict_codecs := [3]^sc.Schema{&p.state_codec, &p.input_codec, &p.event_codec}

    for codec in strict_codecs {
        for field in codec.fields {
            if field.kind == .Float {
                destroy(p)
                return .Schema
            }
        }
    }

    if p.packet_codec.wire_size + sc.HEADER_BYTES > MAX_PACKET || p.input_codec.wire_size > 256 {
        destroy(p)
        return .Schema
    }

    step := proc(state: ^S, inputs: [N]I, ctx: ^r.Step(E)) {
        m := cast(^Model(S, I, E, N))ctx.user

        for input in inputs {
            if !m.input_valid(input) {
                r.abort(ctx)
                return
            }
        }

        ctx.user = m.user
        m.step(state, inputs, ctx)

        if !m.state_valid(state^) {
            r.abort(ctx)
        }
    }

    if r.init(
           &p.timeline,
           initial,
           step,
           cfg = {cfg.history, cfg.events_per_tick},
           epoch = cfg.epoch,
           allocator = allocator,
           user = &p.model,
       ) !=
       .None {
        destroy(p)
        return .Invalid_Model
    }

    p.inputs = make([]Input_Record(I), N * cfg.history, allocator)
    p.hashes = make([]Hash_Record, cfg.history, allocator)
    p.state_bytes = make([]u8, p.state_codec.wire_size, allocator)
    p.event_bytes = make([]u8, p.event_codec.wire_size, allocator)
    p.event_scratch = make([]r.Occurrence(E), cfg.events_per_tick, allocator)
    p.tx, p.rx = make([]u8, MAX_PACKET, allocator), make([]u8, tr.MAX_PACKET_BYTES, allocator)
    p.initial_tick, p.sampled, p.hash_tick = initial.tick, initial.tick + u64(cfg.delay), initial.tick
    p.chain = 0xcbf29ce484222325

    if !hash_frame(p, initial.tick) {
        destroy(p)
        return .Invalid_Model
    }

    p.initial_hash = p.chain
    p.contract = contract_for(
        p.initial_hash,
        cfg,
        roster,
        p.state_codec.fingerprint,
        p.input_codec.fingerprint,
        p.event_codec.fingerprint,
    )

    for i in 0 ..< N {
        p.held[i] = model.neutral
        p.received[i], p.acknowledged[i] = p.sampled, p.sampled

        for offset in u64(1) ..= u64(cfg.delay) {
            slot := input_slot(p, i, initial.tick + offset)
            slot^ = {initial.tick + offset, model.neutral, true}
        }
    }

    p.hello_seen[local] = true
    p.ready = true
    return .None
}

@(private)
config_valid :: proc(cfg: Config, initial_tick: u64) -> bool {
    return(
        cfg.session != 0 &&
        cfg.epoch != 0 &&
        cfg.content != 0 &&
        cfg.hz >= 1 &&
        cfg.hz <= 240 &&
        cfg.history >= 32 &&
        cfg.history <= 1024 &&
        cfg.max_prediction >= 1 &&
        u64(cfg.max_prediction) + u64(cfg.delay) + 2 < u64(cfg.history) &&
        cfg.events_per_tick >= 0 &&
        cfg.events_per_tick <= 256 &&
        cfg.retry_ms >= 1 &&
        cfg.timeout_ms <= 120000 &&
        cfg.retry_ms <= cfg.timeout_ms / 4 &&
        initial_tick <= max(u64) - u64(cfg.history) \
    )
}

@(private)
contract_for :: proc(initial_hash: u64, cfg: Config, roster: [$N]tr.Peer_Id, state, input, event: u64) -> u64 {
    hash := initial_hash
    values := [?]u64 {
        VERSION,
        cfg.session,
        cfg.content,
        u64(N),
        u64(cfg.hz),
        u64(cfg.delay),
        u64(cfg.max_prediction),
        u64(cfg.history),
        u64(cfg.events_per_tick),
        state,
        input,
        event,
    }

    for value in values {
        hash = mix(hash, value)
    }

    for peer in roster {
        hash = mix(hash, u64(peer))
    }

    return hash
}

destroy :: proc(p: ^Runner($S, $I, $E, $N)) {
    r.destroy(&p.timeline)
    sc.destroy(&p.state_codec)
    sc.destroy(&p.input_codec)
    sc.destroy(&p.event_codec)
    sc.destroy(&p.hello_codec)
    sc.destroy(&p.packet_codec)
    delete(p.inputs, p.allocator)
    delete(p.hashes, p.allocator)
    delete(p.state_bytes, p.allocator)
    delete(p.event_bytes, p.allocator)
    delete(p.tx, p.allocator)
    delete(p.rx, p.allocator)
    delete(p.event_scratch, p.allocator)
    delete(p.profile.captures, p.allocator)
    p^ = {}
}

advance :: proc(p: ^Runner($S, $I, $E, $N), local_input: I) -> Result {
    if !p.ready || p.phase != .Running {
        return {error = .Not_Ready}
    }

    if !p.model.input_valid(local_input) {
        return {error = .Invalid_Input}
    }

    if p.timeline.head > max(u64) - u64(p.cfg.delay) - 1 {
        return {error = .Capacity}
    }

    tick := p.timeline.head + 1
    target := tick + u64(p.cfg.delay)
    result := Result {
        tick = tick,
    }

    if target > p.sampled {
        slot := input_slot(p, int(p.local), target)

        if slot.valid {
            for ack, i in p.acknowledged {
                if i != int(p.local) && ack < slot.tick {
                    result.error = .Capacity
                    return result
                }
            }
        }

        slot^ = {target, local_input, true}
        p.sampled, p.received[p.local] = target, target
        result.captured = true
        profile_capture(p, target)
        broadcast(p, true)
    }

    if tick - p.timeline.confirmed > u64(p.cfg.max_prediction) {
        p.stats.stalls += 1
        result.error = .Waiting
        return result
    }

    batch := p.held

    for &value, i in batch {
        slot := input_slot(p, i, tick)

        if slot.valid && slot.tick == tick {
            value = slot.value
        } else {
            value = p.model.hold(value)
            p.stats.predicted_inputs += 1
        }
    }

    started, timed := r.profile_read(p.profile.clock)
    stepped := r.advance(&p.timeline, batch)
    ended, valid := r.timing_finish(&p.profile.metrics[.Step], p.profile.clock, started, timed)

    if stepped.error != .None {
        fail(p, .Simulation)
        result.error = .Simulation
        return result
    }

    profile_applied(p, tick, ended, valid)
    p.held = batch
    result.error = settle(p)

    if result.error != .None {
        fail(p, result.error)
    }

    return result
}

@(private)
input_slot :: proc(p: ^Runner($S, $I, $E, $N), seat: int, tick: u64) -> ^Input_Record(I) {
    return &p.inputs[seat * p.cfg.history + int(tick % u64(p.cfg.history))]
}

@(private)
repair :: proc(p: ^Runner($S, $I, $E, $N)) -> Error {
    if p.dirty == 0 {
        return .None
    }

    previous := p.held

    if p.dirty - 1 == p.initial_tick {
        for &input in previous {
            input = p.model.neutral
        }
    } else {
        known: bool
        previous, known = r.read_input(&p.timeline, p.dirty - 1)

        if !known {
            return .History
        }
    }

    forecast := Forecast(S, I, E, N){p, previous}
    rewrite := r.Input_Rewrite([N]I) {
        user = &forecast,
        apply = proc(user: rawptr, tick: u64, original: [N]I) -> [N]I {
            f := cast(^Forecast(S, I, E, N))user

            for &value, i in f.held {
                slot := input_slot(f.runner, i, tick)
                value = slot.valid && slot.tick == tick ? slot.value : f.runner.model.hold(value)
            }

            return f.held
        },
    }
    started, timed := r.profile_read(p.profile.clock)
    result := r.revise_inputs(&p.timeline, p.dirty, rewrite)
    r.timing_finish(&p.profile.metrics[.Replay], p.profile.clock, started, timed)

    if result.error != .None {
        return .Simulation
    }

    p.held, p.dirty = forecast.held, 0
    p.stats.rollbacks += 1
    p.stats.replayed_ticks += u64(result.steps)
    p.stats.max_replay_depth = max(p.stats.max_replay_depth, u64(result.steps))
    return .None
}

@(private)
Forecast :: struct($S, $I, $E: typeid, $N: int) {
    runner: ^Runner(S, I, E, N),
    held:   [N]I,
}

@(private)
settle :: proc(p: ^Runner($S, $I, $E, $N)) -> Error {
    through := p.timeline.head

    for received in p.received {
        through = min(through, received)
    }

    for p.hash_tick < through {
        if !hash_frame(p, p.hash_tick + 1) {
            return .History
        }

        p.hash_tick += 1
    }

    if r.confirm_through(&p.timeline, through) != .None {
        return .History
    }

    for remote, i in p.remote_hash {
        if i == int(p.local) || !remote.valid || remote.tick > through {
            continue
        }

        local := p.hashes[remote.tick % u64(p.cfg.history)]

        if local.valid && local.tick == remote.tick && local.value != remote.value {
            p.mismatch = {remote.tick, u16(i), local.value, remote.value}
            fail(p, .Diverged)
            return .Diverged
        }
    }

    return .None
}

@(private)
hash_frame :: proc(p: ^Runner($S, $I, $E, $N), tick: u64) -> bool {
    started, timed := r.profile_read(p.profile.clock)
    defer r.timing_finish(&p.profile.metrics[.Hash], p.profile.clock, started, timed)
    hash, ok := frame_digest(p, tick, p.chain)

    if !ok {
        return false
    }

    p.chain = hash
    p.hashes[tick % u64(p.cfg.history)] = {tick, hash, true}
    return true
}

@(private)
frame_digest :: proc(p: ^Runner($S, $I, $E, $N), tick, seed: u64) -> (u64, bool) {
    f, found := r.read(&p.timeline, tick)

    if !found || sc.encode(&p.state_codec, f.state, p.state_bytes).error != .None {
        return 0, false
    }

    hash := sc.digest(p.state_bytes, mix(seed, tick))
    n, err := r.copy_events(&p.timeline, tick, p.event_scratch)

    if err != .None {
        return 0, false
    }

    hash = mix(hash, u64(n))

    for event in p.event_scratch[:n] {
        if sc.encode(&p.event_codec, event, p.event_bytes).error != .None {
            return 0, false
        }

        hash = sc.digest(p.event_bytes, hash)
    }

    return hash, true
}

@(private)
mix :: proc(hash, value: u64) -> u64 {
    h := hash

    for shift in 0 ..< 8 {
        h = (h ~ u64(u8(value >> uint(shift * 8)))) * 0x100000001b3
    }

    return h
}

@(private)
fail :: proc(p: ^Runner($S, $I, $E, $N), error: Error) {
    p.error, p.phase = error, error == .Diverged ? .Diverged : .Failed
}
