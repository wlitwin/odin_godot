//gd:extends Node
//gd:class ReplayInputCapture
package input_capture
import "core:fmt"
import gd "godot:godot"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import rgd "godot:replay/godot"
import v "godot:replay/view"
import inputgd "godot:replay/godot/input"

World :: struct {
    presses: u32,
}

Control :: struct {
    pulse: bool,
}

ReplayInputCapture :: struct {
    owner:            gd.Node,
    network:          tr.Memory,
    endpoints:        [2]tr.Memory_Endpoint,
    server:           net.Server(World, Control, u8, u8, 1),
    session:          rgd.Session(World, Control, u8, u8, 1),
    tick:             u64,
    receipt_sequence: u64,
    receipt_results:  u32,
    await_receipt:    bool,
    deadline:         u64,
    intent:           [1]net.Action_Intent(u8),
}

model :: proc() -> net.Model(World, Control, u8, u8, 1) {
    return {action_schedule = {id = 0x4341505455524531, timing = proc(amount: u8) -> net.Action_Timing {
                return amount == 3 ? .Receipt : .Scheduled
            }}, action = proc(w: ^World, seat: u16, amount: u8, ctx: ^r.Step(u8)) -> bool {
            w.presses += u32(amount)
            return true
        }, action_valid = proc(amount: u8) -> bool {
            return amount > 0 && amount <= 3
        }, step = proc(w: ^World, controls: [1]Control, joins, leaves: u64, ctx: ^r.Step(u8)) {
            if controls[0].pulse {
                w.presses += 1
                r.emit(ctx, 1, 1, 1)
            }
        }, control_valid = proc(c: Control) -> bool {
            return true
        }, state_valid = proc(w: World) -> bool {
            return w.presses < 100
        }, hold = proc(c: Control) -> Control {
            return {}
        }}
}

drain :: proc(self: ^ReplayInputCapture) {
    changes: [256]v.Change(net.Net_Event(u8))

    for {
        n := rgd.session_changes(&self.session, changes[:])

        if n == 0 {
            break
        }

        for change in changes[:n] {
            event := change.occurrence.value

            if inputgd.intent_observe(&self.intent[0], &self.session, change) {
                assert(event.applied && !inputgd.intent_observe(&self.intent[0], &self.session, change))
                self.receipt_results += 1
            }
        }
    }
}

server_frame :: proc(self: ^ReplayInputCapture) {
    assert(tr.memory_advance(&self.network, self.tick))
    self.tick += 1
    assert(net.server_pump(&self.server, gd.time_get_ticks_msec(gd.singleton_time())) == .None)
    assert(net.server_step(&self.server) == .None)
}

replay_input_capture_ready :: proc(self: ^ReplayInputCapture) {
    room := new(rgd.Room(World, Control, u8, u8, 1))
    defer free(room)
    room_intent: net.Action_Intent(u8)
    assert(net.intent_capture(&room_intent, u8(3)) == .None)
    _, blocked := inputgd.room_intent(room, &room_intent)
    assert(blocked == .Fenced && room_intent.captured)

    room.session.control_consumed = true
    assert(rgd.room_frame(room, 0, Control{}) == .Not_Initialized && !room.session.control_consumed)
    room.ready = true
    room.phase = .Failed
    room.error = .Fenced
    room.session.control_consumed = true
    assert(rgd.room_frame(room, 0, Control{}) == .Fenced && !room.session.control_consumed)
    assert(tr.memory_init(&self.network, cfg = {2, 512, 8192, 4096}))

    for &e, i in self.endpoints {
        assert(tr.memory_open(&self.network, &e, tr.Peer_Id(i + 1)))
    }

    cfg := net.DEFAULT_CONFIG
    cfg.lead = 2
    cfg.max_prediction = 12
    assert(
        net.server_init(&self.server, r.Frame(World){}, model(), tr.memory_transport(&self.endpoints[0]), cfg) ==
        .None,
    )
    s := &self.session
    s.ready = true
    s.role = .Client
    s.options = rgd.SESSION_OPTIONS
    s.options.role = .Client
    s.options.network = cfg
    s.allocator = context.allocator
    s.base_wire = tr.memory_transport(&self.endpoints[1])
    s.wire = s.base_wire
    r.clock_init(&s.clock, 60)
    assert(net.client_init(&s.client, model(), s.wire, net.Token{0 = 42}, cfg = cfg) == .None)

    for _ in 0 ..< 45 {
        server_frame(self)
        assert(rgd.session_frame(s, 1.0 / 60, Control{}) == .None)
        drain(self)
    }

    assert(s.client.phase == .Running)
    // A packet-driven bootstrap advances the head, but does not sample this press.
    before := s.client.timeline.head

    for _ in 0 ..< 20 {
        server_frame(self)
    }

    assert(tr.memory_advance(&self.network, self.tick))
    self.tick += 1
    buttons := r.Buttons{}
    r.buttons_set(&buttons, 1)
    assert(rgd.session_frame(s, 0, Control{pulse = true}) == .None)
    drain(self)
    assert(s.client.timeline.head > before && s.client.stats.snapshot_catchups > 0 && !s.control_consumed)

    if s.control_consumed {
        r.buttons_consume(&buttons)
    }

    assert(buttons.pressed == 1)
    assert(rgd.session_frame(s, 1.0 / 60, Control{pulse = buttons.pressed != 0}) == .None)
    drain(self)
    assert(s.control_consumed)
    r.buttons_consume(&buttons)
    frame, _ := r.current(&s.client.timeline)
    assert(frame.state.presses == 1 && buttons.pressed == 0)

    // Capacity also preserves the pending edge until an actual input step succeeds.
    for &packet in self.network.packets {
        packet.active = false
    }

    for s.client.timeline.head - s.client.timeline.confirmed < u64(cfg.max_prediction) {
        assert(net.client_step(&s.client, Control{}) == .None)
    }

    drain(self)
    r.buttons_set(&buttons, 0)
    r.buttons_set(&buttons, 1)
    assert(rgd.session_frame(s, 1.0 / 60, Control{pulse = true}) == .None)
    drain(self)
    assert(!s.control_consumed && buttons.pressed == 1)

    for _ in 0 ..< 80 {
        server_frame(self)
        assert(rgd.session_frame(s, 1.0 / 60, Control{pulse = buttons.pressed != 0}) == .None)
        drain(self)

        if s.control_consumed {
            r.buttons_consume(&buttons)
        }
    }

    frame2, _ := r.current(&s.client.timeline)
    authority, _ := r.current(&self.server.timeline)
    assert(frame2.state.presses == 2 && authority.state.presses == 2 && buttons.pressed == 0)
    fmt.printf(
        "REPLAY_INPUT_CAPTURE_OK head=%d catchups=%d stalls=%d presses=%d\n",
        frame2.tick,
        s.client.stats.snapshot_catchups,
        s.client.stats.stalls,
        frame2.state.presses,
    )

    // Force the real receiver's fact-overflow path while the facade stays open.
    for _ in 0 ..< int(cfg.history) + 4 {
        server_frame(self)
    }

    c := &s.client
    fact := self.server.facts[self.server.timeline.head % u64(cfg.history)]
    fact.generation, fact.serial = c.generation, c.serial
    assert(fact.count == 0)
    body, packet: [8192]u8
    assert(sc.encode(&c.codecs.facts, fact, body[:]).error == .None)
    size := c.codecs.fact_header.wire_size
    assert(
        sc.pack_bytes(c.codecs.facts.fingerprint, {kind = 6, epoch = c.cfg.epoch, tick = fact.tick, content = c.cfg.content}, body[:size], packet[:]).error ==
        .None,
    )

    for &pending in self.network.packets {
        pending.active = false
    }

    assert(tr.send(&self.server.wire, 2, .Reliable, packet[:sc.HEADER_BYTES + size]) == .Sent)
    assert(tr.memory_advance(&self.network, self.tick))
    self.tick += 1
    assert(rgd.session_frame(s, 0, Control{}) == .None)
    drain(self)
    assert(c.phase == .Resyncing)
    _, readable := rgd.session_authority_state(s)
    assert(!readable)
    _, scheduled := rgd.session_issue(s, u8(1))
    assert(scheduled == .Wrong_Phase && c.action_count == 0)
    assert(net.intent_capture(&self.intent[0], u8(3)) == .None)
    sent := c.stats.tx_packets
    sequence, error := inputgd.session_intent(s, &self.intent[0])
    assert(error == .None && sequence != 0 && c.stats.tx_packets == sent && !self.intent[0].captured)
    fake := v.Change(net.Net_Event(u8)) {
        kind = .Begin,
        occurrence = {
            id = {epoch = c.cfg.epoch, tick = 1},
            value = {kind = .Action_Result, seat = c.seat, sequence = sequence, applied = true},
        },
    }
    assert(!inputgd.intent_observe(&self.intent[0], s, fake))
    fake.confirmed = true
    fake.kind = .Cancel
    assert(!inputgd.intent_observe(&self.intent[0], s, fake))
    fake.kind = .Begin
    fake.occurrence.value.seat += 1
    assert(!inputgd.intent_observe(&self.intent[0], s, fake))
    fake.occurrence.value.seat = c.seat
    fake.occurrence.id.epoch += 1
    assert(!inputgd.intent_observe(&self.intent[0], s, fake))
    assert(self.intent[0].pending_count == 1 && self.intent[0].confirmed == 0)
    self.receipt_sequence = sequence
    self.await_receipt = true
    self.deadline = gd.time_get_ticks_msec(gd.singleton_time()) + 5000
}

replay_input_capture_process :: proc(self: ^ReplayInputCapture, dt: f64) {
    if !self.await_receipt {
        return
    }

    server_frame(self)
    assert(rgd.session_frame(&self.session, dt, Control{}) == .None)
    drain(self)
    truth, _ := r.current(&self.server.timeline)
    visible, ready := rgd.session_authority_state(&self.session)

    if ready && truth.state.presses == 5 && visible.state.presses == 5 && self.receipt_results == 1 {
        self.await_receipt = false
        assert(self.intent[0].submitted == 1 && self.intent[0].confirmed == 1 && self.intent[0].pending_count == 0)
        fmt.printf("REPLAY_ACTION_INTENT_SESSION_OK queued=1 confirmed=1 filtered_prediction_cancel_seat_epoch=true\n")
        fmt.printf(
            "REPLAY_RECEIPT_RESYNC_SESSION_OK sequence=%d results=%d presses=%d\n",
            self.receipt_sequence,
            self.receipt_results,
            truth.state.presses,
        )
        fmt.printf(
            "REPLAY_MIXED_ACTION_SESSION_OK schedule=%x scheduled_resync=Wrong_Phase receipt_results=%d\n",
            self.session.client.model.action_schedule.id,
            self.receipt_results,
        )
        intent_room_recovery(self)
        gd.scene_tree_quit(gd.get_tree(self.owner), 0)
    } else {
        assert(gd.time_get_ticks_msec(gd.singleton_time()) < self.deadline)
    }
}

intent_room_recovery :: proc(self: ^ReplayInputCapture) {
    c := &self.session.client
    i := &self.intent[0]
    assert(net.intent_capture(i, u8(3)) == .None)
    retained, error := inputgd.session_intent(&self.session, i)
    assert(error == .None)
    assert(tr.memory_advance(&self.network, self.tick))
    assert(net.server_pump(&self.server, gd.time_get_ticks_msec(gd.singleton_time())) == .None)
    cp: net.Checkpoint(World, Control, u8, 1)
    defer net.checkpoint_destroy(&cp)
    assert(net.checkpoint_capture(&self.server, &cp) == .None && len(cp.actions) == 1)
    // A later old-epoch request is not in this durable frontier.
    assert(net.intent_capture(i, u8(3)) == .None)
    retired, error2 := inputgd.session_intent(&self.session, i)
    assert(error2 == .None && retired == retained + 1)
    report, valid := net.client_checkpoint_recovery(c, &cp, 2)
    assert(valid)
    room := new(rgd.Room(World, Control, u8, u8, 1))
    defer free(room)
    room.ready = true
    room.phase = .Hosting
    room.session.ready = true
    room.session.authority = true
    room.session.recovery, room.session.recovery_serial = report, 1
    assert(
        net.server_restore(
            &room.session.server,
            &cp,
            model(),
            {},
            {epoch = 2, local_seat = 1, preserve_pending = true, retain_membership = true},
        ) ==
        .None,
    )
    defer net.server_destroy(&room.session.server)
    intent := i^
    none, recovered := inputgd.room_intent(room, &intent)
    assert(none == 0 && recovered == .None && intent.retired == 1 && intent.pending_count == 1)
    assert(net.intent_capture(&intent, u8(3)) == .None)
    fresh, issued := inputgd.room_intent(room, &intent)
    assert(issued == .None && fresh == retired)
    old := v.Change(net.Net_Event(u8)) {
        kind = .Begin,
        confirmed = true,
        occurrence = {
            id = {epoch = 1, tick = cp.frame.tick + 1},
            value = {kind = .Action_Result, seat = 1, sequence = fresh, applied = true},
        },
    }
    assert(!inputgd.intent_observe(&intent, &room.session, old))

    for _ in 0 ..< 2 {
        assert(net.server_step(&room.session.server) == .None)
        events: [net.WIRE_EVENTS]r.Occurrence(net.Net_Event(u8))
        n, result := r.copy_events(&room.session.server.timeline, room.session.server.timeline.head, events[:])
        assert(result == .None)

        for event in events[:n] {
            if event.value.kind == .Action_Result {
                assert(
                    inputgd.intent_observe(
                        &intent,
                        &room.session,
                        v.Change(net.Net_Event(u8)){kind = .Begin, confirmed = true, occurrence = event},
                    ),
                )
            }
        }
    }

    frame, _ := r.current(&room.session.server.timeline)
    assert(
        frame.state.presses == 11 &&
        intent.confirmed == 3 &&
        intent.retired == 1 &&
        intent.pending_count == 0 &&
        intent.unknown == 0,
    )
    fmt.printf(
        "REPLAY_ACTION_INTENT_ROOM_RECOVERY_OK retained=1 retired=1 reused_sequence=%d confirmed=%d presses=%d\n",
        fresh,
        intent.confirmed,
        frame.state.presses,
    )
}

replay_input_capture_exit_tree :: proc(self: ^ReplayInputCapture) {
    rgd.session_close(&self.session)
    net.server_destroy(&self.server)

    for &e in self.endpoints {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    tr.memory_destroy(&self.network)
}
