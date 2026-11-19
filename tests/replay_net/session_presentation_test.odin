package replay_net_test

import "core:reflect"
import "core:testing"
import r "godot:replay"
import net "godot:replay/net"
import rgd "godot:replay/godot"
import tr "godot:replay/transport"
import view "godot:replay/view"
import sc "godot:replay/schema"

Presentation_Session :: rgd.Session(World, Control, Action, Event, 2)
Presentation_Fixture :: struct {
    network:   tr.Memory,
    endpoints: [4]tr.Memory_Endpoint,
    sessions:  [4]Presentation_Session,
    clock:     u64,
}

presentation_fixture_init :: proc(f: ^Presentation_Fixture) {
    assert(
        tr.memory_init(
            &f.network,
            seed = 123,
            cfg = {4, 512, 8192, 65536},
            faults = {latency_ticks = 3, retry_ticks = 3},
        ),
    )
    cfg := net.DEFAULT_CONFIG
    cfg.content, cfg.epoch = 0x54455354, 7
    for &endpoint, i in f.endpoints {assert(tr.memory_open(&f.network, &endpoint, tr.Peer_Id(i + 1)))}
    // Real network runtimes live in the Session shells. Only transport setup
    // is engine-free, allowing the public presentation readers to run natively.
    for &s, i in f.sessions {
        s.ready = true
        if i == 0 {
            s.authority, s.role = true, .Server
            assert(
                net.server_init(
                    &s.server,
                    r.Frame(World){state = {chest = 5}},
                    model(),
                    tr.memory_transport(&f.endpoints[i]),
                    cfg,
                ) ==
                .None,
            )
            s.server.epoch_discovery = true
        } else {
            s.role = i == 3 ? .Observer : .Client
            hint := cfg
            hint.epoch = 1
            assert(
                net.client_init(
                    &s.client,
                    model(),
                    tr.memory_transport(&f.endpoints[i]),
                    net.Token{0 = u8(i)},
                    spectator = i == 3,
                    cfg = hint,
                ) ==
                .None,
            )
            assert(net.client_discover_epoch(&s.client, net.Token{0 = u8(100 + i)}) == .None)
        }
    }
}

presentation_fixture_destroy :: proc(f: ^Presentation_Fixture) {
    for &s in f.sessions {assert(rgd.session_close(&s) == .None)}
    for &endpoint in f.endpoints {wire := tr.memory_transport(&endpoint); tr.close(&wire)}
    tr.memory_destroy(&f.network)
}

presentation_fixture_step :: proc(f: ^Presentation_Fixture, moving: bool = true) {
    assert(tr.memory_advance(&f.network, f.clock))
    now := f.clock * 1000 / 60
    assert(net.server_pump(&f.sessions[0].server, now) == .None)
    for &s in f.sessions[1:] {assert(net.client_pump(&s.client, now) == .None)}
    assert(net.server_step(&f.sessions[0].server) == .None)
    for &s, i in f.sessions[1:] {
        if s.client.phase == .Running && !s.client.spectator {
            error := net.client_step(&s.client, Control{move = moving ? (i == 0 ? 1 : -1) : 0})
            assert(error == .None || error == .Capacity)
        }
        changes: [512]view.Change(net.Net_Event(Event))
        for view.drain(&s.client.journal, changes[:]) > 0 {}
    }
    f.clock += 1
}

@(test)
session_context_and_corrections_follow_admission_and_resets :: proc(t: ^testing.T) {
    f := new(Presentation_Fixture)
    defer free(f)
    presentation_fixture_init(f)
    defer presentation_fixture_destroy(f)
    for &s in f.sessions[1:] {
        _, ok := rgd.session_presentation(&s)
        testing.expect(t, !ok, "a configured epoch hint is not an admitted view")
    }
    var_seen: rgd.Presentation_Context
    observed_difference, stale_rejected := false, false
    for _ in 0 ..< 100 {
        presentation_fixture_step(f)
        s := &f.sessions[1]
        info, ok := rgd.session_presentation(s)
        if !ok {continue}
        testing.expect(t, info.epoch == 7 && info.seat == 1 && !info.authority && !info.observer)
        if info.correction_serial == 0 {continue}
        first, second: net.State_Correction(World)
        testing.expect(t, rgd.session_correction(s, info, &first))
        testing.expect(t, rgd.session_correction(s, info, &second))
        testing.expect(t, reflect.equal(first, second) && reflect.equal(first, s.client.correction))
        testing.expect_value(t, first.before.tick, first.after.tick)
        observed_difference |= !reflect.equal(first.before.state, first.after.state)
        first.after.state.players[0].x = max(i32)
        testing.expect(
            t,
            second.after.state.players[0].x != max(i32) && s.client.correction.after.state.players[0].x != max(i32),
        )
        if var_seen.correction_serial != 0 && var_seen.correction_serial != info.correction_serial {
            testing.expect(t, !rgd.session_correction(s, var_seen, &first))
            stale_rejected = true
        }
        var_seen = info
    }
    testing.expect(t, observed_difference && stale_rejected)
    observer, ok := rgd.session_presentation(&f.sessions[3])
    testing.expect(t, ok && observer.observer && !observer.authority && observer.seat == 0 && observer.epoch == 7)
    s := &f.sessions[1]
    old, _ := rgd.session_presentation(s)
    s.fenced = true
    fenced, fenced_ok := rgd.session_presentation(s)
    testing.expect(t, fenced_ok && fenced == old)
    s.fenced = false
    correction: net.State_Correction(World)
    s.client.model.complete_state = true
    complete, complete_ok := rgd.session_presentation(s)
    testing.expect(t, complete_ok && complete.correction_serial == 0 && !rgd.session_correction(s, old, &correction))
    s.client.model.complete_state = false

    // A same-generation Welcome is ordinary catch-up, not a new connection.
    for &packet in f.network.packets {packet.active = false}
    c := &s.client
    begin_test_resync(c)
    generation := c.generation
    packet := f.sessions[0].server.checkpoints[0]
    packet.generation, packet.serial, packet.seat = generation, c.serial + 1, c.seat
    packet.frame, _ = r.current(&f.sessions[0].server.timeline)
    packet.action_received, packet.action_settled, packet.completed_count = 0, 0, 0
    bytes: [8192]u8
    testing.expect(
        t,
        sc.pack(&c.codecs.welcome, packet, {kind = 2, epoch = 7, content = c.cfg.content, tick = packet.frame.tick}, bytes[:]).error ==
        .None,
    )
    testing.expect(
        t,
        tr.send(&f.sessions[0].server.wire, 2, .Reliable, bytes[:sc.HEADER_BYTES + c.codecs.welcome.wire_size]) ==
        .Sent,
    )
    for _ in 0 ..< 8 {
        f.clock += 1
        assert(tr.memory_advance(&f.network, f.clock))
        c.hello_sent, c.last_hello = true, f.clock * 1000 / 60
        assert(net.client_pump(c, c.last_hello) == .None)
    }
    reset, reset_ok := rgd.session_presentation(s)
    testing.expect(t, reset_ok && reset.epoch == old.epoch && reset.reset > old.reset && reset.correction_serial == 0)
    testing.expect_value(t, c.generation, generation)
    testing.expect(t, !rgd.presentation_same_scope(old, reset))
    testing.expect(t, !rgd.session_correction(s, old, &correction) && !rgd.session_correction(s, reset, &correction))
    changes: [512]view.Change(net.Net_Event(Event))
    for view.drain(&c.journal, changes[:]) > 0 {}

    // Adopt a newer authority epoch through the real recovery handshake.
    checkpoint: net.Checkpoint(World, Control, Action, 2)
    defer net.checkpoint_destroy(&checkpoint)
    testing.expect(t, net.checkpoint_capture(&f.sessions[0].server, &checkpoint) == .None)
    testing.expect(t, net.server_destroy(&f.sessions[0].server) == .None)
    testing.expect(
        t,
        net.server_restore(
            &f.sessions[0].server,
            &checkpoint,
            model(),
            tr.memory_transport(&f.endpoints[0]),
            {epoch = 8},
        ) ==
        .None,
    )
    for &peer, i in f.sessions[1:] {
        testing.expect(t, net.client_authority(&peer.client, 8, tr.memory_transport(&f.endpoints[i + 1])) == .None)
    }
    recovering, recovering_ok := rgd.session_presentation(s)
    testing.expect(
        t,
        recovering_ok && recovering.epoch == 7,
        "retained world uses its admitted epoch, not the next-epoch hint",
    )
    changed := false
    for _ in 0 ..< 40 {
        presentation_fixture_step(f, false)
        info, available := rgd.session_presentation(s)
        if available && info.epoch == 8 {
            testing.expect(t, !rgd.presentation_same_scope(reset, info))
            testing.expect(t, !rgd.session_correction(s, old, &correction))
            changed = true
            break
        }
    }
    testing.expect(t, changed)
}

@(test)
render_sample_defaults_to_one_observed_clock_and_preserves_a_contact_tick :: proc(t: ^testing.T) {
    f := new(Presentation_Fixture)
    defer free(f)
    presentation_fixture_init(f)
    defer presentation_fixture_destroy(f)
    s := &f.sessions[1]
    _, ready := rgd.session_render_sample(s)
    testing.expect(t, !ready)
    for _ in 0 ..< 60 {presentation_fixture_step(f)}
    _, err := net.client_issue(&s.client, Action{take = true})
    testing.expect(t, err == .None)
    at: u64
    pinned := false
    for _ in 0 ..< 80 {
        presentation_fixture_step(f)
        authority, ok := rgd.session_render_sample(&f.sessions[0])
        testing.expect(t, ok && authority.from.tick == authority.to.tick)
        batch: [2]Event
        n, found := rgd.session_render_events(&f.sessions[0], &authority, authority.tick, batch[:])
        if found && n == 1 {at = authority.tick}
        sample, visible := rgd.session_render_sample(s)
        predictive, pok := rgd.session_render_sample(s, .Predicted)
        if !visible || !pok {continue}
        testing.expect(t, sample.to.tick <= s.client.timeline.confirmed && predictive.tick == s.client.timeline.head)
        testing.expect(
            t,
            s.client.presented.from_tick == sample.from.tick && s.client.presented.to_tick == sample.to.tick,
        )
        if at == 0 || sample.tick < at + 2 {continue}
        all_events := proc(_: Event) -> bool {return true}
        cursor := rgd.Render_Cursor{true, sample.scope, at - 1}
        contact, hit := rgd.session_render_sample(s, .Observed, &cursor, all_events)
        testing.expect(t, hit && contact.tick == at && contact.fraction == 0)
        var_seen: Event
        rgd.session_render_events(s, &contact, &var_seen, proc(dst: ^Event, _: u64, e: Event) {dst^ = e})
        testing.expect_value(t, var_seen.seat, s.client.seat)
        synthetic := contact
        synthetic.clock = .Predicted
        _, mixed := rgd.session_render_events(s, &synthetic, at, batch[:])
        testing.expect(t, !mixed)
        needed, short := rgd.session_render_events(s, &contact, at, batch[:0])
        testing.expect(t, !short && needed == 1)
        count, has := rgd.session_render_events(s, &contact, at, batch[:])
        testing.expect(t, has && count == 1 && batch[0].seat == s.client.seat)
        next, advanced := rgd.session_render_sample(s, .Observed, &cursor, all_events)
        testing.expect(t, advanced && next.tick > at)
        invalid := contact
        invalid.scope.reset += 1
        _, stale := rgd.session_render_events(s, &invalid, at, batch[:])
        testing.expect(t, !stale)
        pinned = true
        break
    }
    testing.expect(t, pinned, "expected a real accepted pickup and a later watched frame")
}
