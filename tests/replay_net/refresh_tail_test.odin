package replay_net_test

import "core:testing"
import "core:reflect"
import "core:mem"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import v "godot:replay/view"

refresh_tail_begin :: proc(f: ^Fixture, c: ^Client) {
    for &packet in f.network.packets {
        packet.active = false
    }

    begin_test_resync(c)
    c.hello_sent = true
    c.last_hello = c.now
}

refresh_tail_pump :: proc(f: ^Fixture, c: ^Client) {
    f.clock += 1
    assert(tr.memory_advance(&f.network, f.clock))
    now := f.clock * 1000 / 60
    c.last_hello = now // deliver the explicit test packets without sending a real request
    assert(net.client_pump(c, now) == .None)
}

refresh_tail_fact :: proc(
    f: ^Fixture,
    c: ^Client,
    peer: tr.Peer_Id,
    tick, epoch, generation, serial: u64,
    events: []r.Occurrence(net.Net_Event(Event)),
) {
    header := struct {
        generation, serial, tick: u64,
        count:                    u16,
    }{generation, serial, tick, u16(len(events))}
    schema: sc.Schema
    assert(sc.init(&schema, type_of(header)).error == .None)
    defer sc.destroy(&schema)
    assert(schema.fingerprint == c.codecs.fact_header.fingerprint)
    bytes: [8192]u8
    size := schema.wire_size + len(events) * c.codecs.occurrence.wire_size
    body := bytes[sc.HEADER_BYTES:sc.HEADER_BYTES + size]
    assert(sc.encode(&schema, header, body[:schema.wire_size]).error == .None)

    for event, i in events {
        at := schema.wire_size + i * c.codecs.occurrence.wire_size
        assert(sc.encode(&c.codecs.occurrence, event, body[at:at + c.codecs.occurrence.wire_size]).error == .None)
    }

    assert(
        sc.pack_bytes(c.codecs.facts.fingerprint, {kind = 6, epoch = epoch, content = c.cfg.content, tick = tick}, body, bytes[:]).error ==
        .None,
    )
    assert(tr.send(&f.server.wire, peer, .Reliable, bytes[:sc.HEADER_BYTES + size]) == .Sent)
}

refresh_tail_welcome :: proc(
    f: ^Fixture,
    c: ^Client,
    peer: tr.Peer_Id,
    tick, epoch, generation, serial: u64,
    outcome: ^net.Action_Outcome = nil,
) {
    packet := f.server.checkpoints[0]
    packet.generation, packet.serial, packet.seat = generation, serial, c.seat
    packet.frame, _ = r.current(&f.server.timeline)
    packet.frame.tick, packet.echo_ms = tick, c.now
    packet.action_received, packet.action_settled, packet.completed_count = 0, 0, 0

    if outcome != nil {
        packet.action_received, packet.action_settled, packet.completed_count = outcome.sequence, outcome.sequence, 1
        packet.completed[0] = outcome^
    }

    bytes: [8192]u8
    assert(
        sc.pack(&c.codecs.welcome, packet, {kind = 2, epoch = epoch, content = c.cfg.content, tick = tick}, bytes[:]).error ==
        .None,
    )
    assert(tr.send(&f.server.wire, peer, .Reliable, bytes[:sc.HEADER_BYTES + c.codecs.welcome.wire_size]) == .Sent)
}

refresh_tail_event :: proc(c: ^Client, tick: u64) -> r.Occurrence(net.Net_Event(Event)) {
    return {
        id = {epoch = c.cfg.epoch, tick = tick, source = 91, key = 17},
        value = {kind = .Gameplay, value = {seat = 1, value = 991}},
    }
}

@(test)
refresh_retains_only_current_stream_facts_without_publishing_before_matching_welcome :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f)
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    c := &f.clients[2]
    refresh_tail_begin(&f, c)
    tick := c.facts_contiguous + 1
    before, _ := r.current(&c.timeline)
    serial := c.serial
    events := [2]r.Occurrence(net.Net_Event(Event)){refresh_tail_event(c, tick), refresh_tail_event(c, tick)}

    for variant in 0 ..< 5 {
        generation, stream, epoch := c.generation, c.serial, c.cfg.epoch
        count := 1

        switch variant {
        case 0:
            generation += 1
        case 1:
            stream += 1
        case 2:
            epoch += 1
        case 3:
            events[0].id.tick = tick + 1
        case 4:
            events[0].id.tick = tick
            count = 2
        }

        refresh_tail_fact(&f, c, 4, tick, epoch, generation, stream, events[:count])
        refresh_tail_pump(&f, c)
        testing.expect(t, c.facts_contiguous == tick - 1 && c.journal.queue_count == 0 && c.serial == serial)
    }

    refresh_tail_fact(&f, c, 4, tick, c.cfg.epoch, c.generation, c.serial, events[:1])
    refresh_tail_fact(&f, c, 4, tick, c.cfg.epoch, c.generation, c.serial, events[:1]) // exact duplicate
    refresh_tail_fact(&f, c, 4, tick + 1, c.cfg.epoch, c.generation, c.serial, nil) // a known empty tick
    refresh_tail_pump(&f, c)
    after, _ := r.current(&c.timeline)
    testing.expect(
        t,
        reflect.equal(before, after) &&
        c.facts_contiguous == tick + 1 &&
        c.journal.queue_count == 0 &&
        c.phase == .Resyncing,
    )

    for variant in 0 ..< 3 {
        epoch, generation, stream := c.cfg.epoch, c.generation, c.serial + 1

        switch variant {
        case 0:
            epoch += 1
        case 1:
            generation = 0
        case 2:
            stream = c.serial
        }

        refresh_tail_welcome(&f, c, 4, tick + 1, epoch, generation, stream)
        refresh_tail_pump(&f, c)
        after, _ = r.current(&c.timeline)
        testing.expect(t, reflect.equal(before, after) && c.serial == serial && c.journal.queue_count == 0)
    }

    refresh_tail_welcome(&f, c, 4, tick + 1, c.cfg.epoch, c.generation, c.serial + 1)
    refresh_tail_pump(&f, c)
    changes: [16]v.Change(net.Net_Event(Event))
    testing.expect_value(t, v.drain(&c.journal, changes[:]), 1)
    testing.expect(
        t,
        changes[0].kind == .Begin &&
        changes[0].confirmed &&
        changes[0].occurrence.id.tick == tick &&
        c.serial == serial + 1,
    )
}

@(test)
refresh_reset_failure_and_output_backpressure_preserve_world_and_tail_for_retry :: proc(t: ^testing.T) {
    for blocked_queue in ([2]bool{false, true}) {
        f: Fixture
        fixture_init(&f)
        defer fixture_destroy(&f)

        for _ in 0 ..< 45 {
            fixture_step(&f)
        }

        c := &f.clients[2]
        refresh_tail_begin(&f, c)
        tick := c.facts_contiguous + 1

        if blocked_queue {
            v.journal_destroy(&c.journal)
            assert(v.journal_init(&c.journal, epoch = c.cfg.epoch, baseline = tick - 1, cfg = {4, 1, 4}) == .None)
            v.journal_set_policy(&c.journal, proc(_: net.Net_Event(Event)) -> v.Policy {
                return .Speculative
            })

            for future in ([2]u64{tick + 2, tick + 3}) {
                predicted := [1]r.Occurrence(net.Net_Event(Event)){refresh_tail_event(c, future)}
                assert(v.sync_tick(&c.journal, future, predicted[:]) == .None)
            }
        }

        event := [1]r.Occurrence(net.Net_Event(Event)){refresh_tail_event(c, tick)}
        refresh_tail_fact(&f, c, 4, tick, c.cfg.epoch, c.generation, c.serial, event[:])
        refresh_tail_pump(&f, c)
        before, _ := r.current(&c.timeline)
        serial, confirmed, queue := c.serial, c.journal.confirmed, c.journal.queue_count
        storage := make([]u8, len(c.journal.storage) * size_of(c.journal.storage[0]))
        defer delete(storage)
        copy(storage, mem.slice_to_bytes(c.journal.storage))
        c.timeline.busy = !blocked_queue
        refresh_tail_welcome(&f, c, 4, tick + 1, c.cfg.epoch, c.generation, c.serial + 1)
        refresh_tail_pump(&f, c)
        c.timeline.busy = false
        after, _ := r.current(&c.timeline)
        testing.expect(
            t,
            reflect.equal(before, after) &&
            c.serial == serial &&
            c.journal.confirmed == confirmed &&
            c.journal.queue_count == queue,
        )
        testing.expect(t, reflect.equal(storage, mem.slice_to_bytes(c.journal.storage), true))
        testing.expect_value(t, c.facts_contiguous, tick)
        changes: [16]v.Change(net.Net_Event(Event))
        v.drain(&c.journal, changes[:])
        refresh_tail_welcome(&f, c, 4, tick + 1, c.cfg.epoch, c.generation, c.serial + 1)
        refresh_tail_pump(&f, c)
        testing.expect(t, c.serial == serial + 1 && c.phase == .Running)
        testing.expect_value(t, v.drain(&c.journal, changes[:]), blocked_queue ? 3 : 1)
    }
}

@(test)
refresh_tail_only_action_verdict_uses_one_journal_route_without_synthetic_recovery :: proc(t: ^testing.T) {
    f: Fixture
    fixture_init(&f, action_timing = .Receipt)
    defer fixture_destroy(&f)

    for _ in 0 ..< 45 {
        fixture_step(&f)
    }

    c := &f.clients[0]
    sequence, error := net.client_issue(c, Action{take = true})
    assert(error == .None)
    refresh_tail_begin(&f, c)
    tick := c.facts_contiguous + 1
    event := [1]r.Occurrence(net.Net_Event(Event)) {
        {
            id = {epoch = c.cfg.epoch, tick = tick, source = 1, key = sequence},
            value = {kind = .Action_Result, seat = c.seat, sequence = sequence, applied = true},
        },
    }
    refresh_tail_fact(&f, c, 2, tick, c.cfg.epoch, c.generation, c.serial, event[:])
    refresh_tail_pump(&f, c)
    outcome := net.Action_Outcome {
        sequence = sequence,
        tick     = tick,
        applied  = true,
    }
    refresh_tail_welcome(&f, c, 2, tick, c.cfg.epoch, c.generation, c.serial + 1, &outcome)
    refresh_tail_pump(&f, c)
    changes: [16]v.Change(net.Net_Event(Event))
    n := v.drain(&c.journal, changes[:])
    verdicts := 0

    for change in changes[:n] {
        if change.occurrence.value.kind == .Action_Result && change.occurrence.value.sequence == sequence {
            testing.expect(t, change.kind == .Begin && change.confirmed)
            verdicts += 1
        }
    }

    testing.expect_value(t, verdicts, 1)
    outcomes: [8]net.Action_Outcome
    recovered: [8]bool
    testing.expect_value(t, net.client_outcomes(c, outcomes[:], recovered[:]), 1)
    testing.expect(t, outcomes[0] == outcome && !recovered[0])
    testing.expect_value(t, net.client_outcomes(c, outcomes[:], recovered[:]), 0)
}
