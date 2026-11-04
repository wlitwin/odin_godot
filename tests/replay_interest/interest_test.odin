package interest_test

import "core:testing"
import "core:reflect"
import "core:fmt"
import r "godot:replay"
import net "godot:replay/net"
import tr "godot:replay/transport"
import sc "godot:replay/schema"
import v "godot:replay/view"
import game "godot/shared/arena"

Server :: net.Server(game.World, game.Control, game.Action, game.Event, game.SEATS)
Client :: net.Client(game.World, game.Control, game.Action, game.Event, game.SEATS)

Fixture :: struct {
    memory:   tr.Memory,
    ep:       [4]tr.Memory_Endpoint,
    server:   Server,
    clients:  [3]Client,
    tick:     u64,
    wire:     tr.Transport,
    bytes:    [3]u64,
    leaks:    u64,
    filtered: bool,
}

start :: proc(f: ^Fixture, filtered: bool = true, invalid: bool = false) {
    f.filtered = filtered
    assert(
        tr.memory_init(
            &f.memory,
            42,
            {4, 1024, 8192, 65536},
            {latency_ticks = 2, jitter_ticks = 1, loss_permyriad = 500, duplicate_permyriad = 500, retry_ticks = 2},
        ),
    )

    for &ep, i in f.ep {
        assert(tr.memory_open(&f.memory, &ep, tr.Peer_Id(i + 1)))
    }

    f.wire = tr.memory_transport(&f.ep[0])
    wire := f.wire
    wire.user = f
    wire.send = tap_send
    wire.receive = tap_receive
    wire.poll = tap_poll
    wire.status = tap_status
    wire.connected = tap_connected
    wire.close = nil
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    cfg.history = 256
    cfg.snapshot_every = 2
    m := game.model(filtered)

    if invalid {
        m.replication.project = proc(
            _: r.Frame(game.World),
            _: [game.SEATS]game.Control,
            _: net.Recipient,
        ) -> (
            net.Replica(game.World, game.Control, game.SEATS),
            bool,
        ) {
            return {}, false
        }
    }

    if !filtered {
        m.state_valid = proc(w: game.World) -> bool {
            return w.complete && w.visible == (u64(1) << game.OBJECTS) - 1
        }
    }

    assert(net.server_init(&f.server, r.Frame(game.World){state = game.initial()}, m, wire, cfg) == .None)

    for &client, i in f.clients {
        cm := filtered && i < 2 ? game.player_model() : m
        assert(
            net.client_init(
                &client,
                cm,
                tr.memory_transport(&f.ep[i + 1]),
                net.Token{0 = u8(i + 1)},
                spectator = !filtered || i == 2,
                cfg = cfg,
            ) ==
            .None,
        )
    }
}

finish :: proc(f: ^Fixture) {
    for &client in f.clients {
        net.client_destroy(&client)
    }

    net.server_destroy(&f.server)

    for &ep in f.ep {
        wire := tr.memory_transport(&ep)
        tr.close(&wire)
    }

    tr.memory_destroy(&f.memory)
}

step :: proc(f: ^Fixture, moving: i8 = 0) {
    f.tick += 1
    tr.memory_advance(&f.memory, f.tick)
    now := f.tick * 1000 / 60
    assert(net.server_pump(&f.server, now) == .None)

    for &client in f.clients {
        assert(net.client_pump(&client, now) == .None)
    }

    assert(net.server_step(&f.server) == .None)

    for &client, i in f.clients {
        if client.phase == .Running && !client.spectator {
            err := net.client_step(&client, game.Control{move = i == 0 ? moving : 0, private_hint = u32(0xbad000 + i)})
            assert(err == .None || err == .Capacity)
        }

        changes: [512]v.Change(net.Net_Event(game.Event))

        for v.drain(&client.journal, changes[:]) > 0 {}

        outcomes: [16]net.Action_Outcome
        net.client_outcomes(&client, outcomes[:])
    }
}

tap_send :: proc(raw: rawptr, to: tr.Peer_Id, channel: tr.Channel, bytes: []u8) -> tr.Send_Result {
    f := cast(^Fixture)raw
    result := tr.send(&f.wire, to, channel, bytes)

    if result != .Sent {
        return result
    }

    if to >= 2 && to <= 4 {
        f.bytes[int(to) - 2] += u64(len(bytes))
        meta, _, report := sc.inspect(bytes)

        // Inspect each compact entry against its own historical recipient view;
        // the outer tick alone is insufficient when membership changed recently.
        if f.filtered && report.error == .None && meta.kind == 27 {
            body := bytes[sc.HEADER_BYTES:]
            cursor := 17

            for _ in 0 ..< int(body[16]) {
                tick := meta.tick - u64(body[cursor])
                count := int(body[cursor + 1]) | int(body[cursor + 2]) << 8
                size := 3 + count * f.server.codecs.occurrence.wire_size
                frame, found := r.read(&f.server.timeline, tick)

                if found {
                    who := net.Recipient {
                        seat      = to == 4 ? 0 : u16(to - 1),
                        spectator = to == 4,
                    }
                    entry := body[cursor + 3:cursor + size]

                    for object, i in frame.state.objects {
                        if !game.visible(frame.state, who, i) && contains_u64(entry, object.nonce) {
                            f.leaks += 1
                        }
                    }

                    if contains_u64(entry, game.SECRET) {
                        f.leaks += 1
                    }
                }

                cursor += size
            }
        }

        if f.filtered &&
           report.error == .None &&
           (meta.kind == 2 || meta.kind == 6 || meta.kind == 7 || meta.kind == 10) {
            frame, found := r.read(&f.server.timeline, meta.tick)

            if found {
                who := net.Recipient {
                    seat      = to == 4 ? 0 : u16(to - 1),
                    spectator = to == 4,
                }

                for object, i in frame.state.objects {
                    if !game.visible(frame.state, who, i) && contains_u64(bytes, object.nonce) {
                        f.leaks += 1
                    }
                }

                if contains_u64(bytes, game.SECRET) {
                    f.leaks += 1
                }
            }
        }
    }

    return result
}

contains_u64 :: proc(bytes: []u8, value: u64) -> bool {
    if value == 0 || len(bytes) < 8 {
        return false
    }

    for i in 0 ..= len(bytes) - 8 {
        found := true

        for j in 0 ..< 8 {
            if bytes[i + j] != u8(value >> uint(j * 8)) {
                found = false
                break
            }
        }

        if found {
            return true
        }
    }

    return false
}

tap_receive :: proc(raw: rawptr, dst: []u8) -> tr.Received {
    f := cast(^Fixture)raw
    return tr.receive(&f.wire, dst)
}

tap_poll :: proc(raw: rawptr) {
    f := cast(^Fixture)raw
    tr.poll(&f.wire)
}

tap_status :: proc(raw: rawptr) -> tr.Status {
    f := cast(^Fixture)raw
    return tr.status(&f.wire)
}

tap_connected :: proc(raw: rawptr, peer: tr.Peer_Id) -> bool {
    f := cast(^Fixture)raw
    return tr.peer_connected(&f.wire, peer)
}

check_views :: proc(t: ^testing.T, f: ^Fixture) {
    for &client, i in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Running)
        frame := client.authority_frame
        source, found := r.read(&f.server.timeline, frame.tick)
        testing.expect(t, found)

        if !found {
            continue
        }

        who := net.Recipient{client.seat, client.spectator}
        expected, ok := game.model().replication.project(source, f.server.held, who)
        expected.state.secret = 0
        testing.expect(t, ok && reflect.equal(frame.state, expected.state))

        for control, j in client.held {
            if j + 1 != int(client.seat) {
                testing.expect_value(t, control, game.Control{})
            }
        }

        for value in client.facts {
            fact := value

            if fact.tick == 0 {
                continue
            }

            past, exists := r.read(&f.server.timeline, fact.tick)

            if !exists {
                continue
            }

            for event in fact.events[:fact.count] {
                if event.value.kind == .Action_Result {
                    testing.expect(t, !client.spectator && event.value.seat == client.seat)
                } else {
                    testing.expect(t, game.visible(past.state, who, int(event.value.value.object)))
                    testing.expect_value(t, event.value.value.value, u64(0))
                }
            }
        }

        if i < 2 {
            prediction, valid := net.client_prediction(&client)
            testing.expect(t, valid && prediction.frame.state.visible == 0 && prediction.frame.state.secret == 0)
        }
    }

    testing.expect_value(t, f.leaks, u64(0))

    if f.server.timeline.head > 80 {
        testing.expect(t, f.server.stats.compact_recent_facts > 0)
    }
}

@(test)
recipient_views_filter_snapshots_controls_facts_and_dynamic_membership :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)

    for _ in 0 ..< 80 {
        step(&f)
    }

    check_views(t, &f)
    initial_mask := f.clients[0].authority_frame.state.visible
    net.client_issue(&f.clients[0], game.Action{claim = true})
    net.client_issue(&f.clients[1], game.Action{claim = true})

    for _ in 0 ..< 95 {
        step(&f, 1)
    }

    for _ in 0 ..< 25 {
        step(&f)
    }

    check_views(t, &f)
    testing.expect(t, f.clients[0].authority_frame.state.visible != initial_mask)
    testing.expect_value(t, f.clients[0].authority_frame.state.objects[0], game.Object{})
    testing.expect(t, f.server.stats.filtered_events > 0 && f.server.stats.delta_snapshots > 0)
    cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    testing.expect_value(t, net.checkpoint_capture(&f.server, &cp), net.Error.None)
    testing.expect(
        t,
        game.state_valid(cp.frame.state) &&
        cp.frame.state.secret == game.SECRET &&
        cp.frame.state.objects[0].nonce != 0,
    )
    bytes, err := net.checkpoint_encode(&cp, game.model())
    defer delete(bytes)
    testing.expect_value(t, err, net.Error.None)
    decoded: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&decoded)
    testing.expect_value(t, net.checkpoint_decode(&decoded, bytes, game.model(), game.CONTENT), net.Error.None)
    wrong := game.model()
    wrong.replication.id += 1
    bad: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&bad)
    testing.expect_value(t, net.checkpoint_decode(&bad, bytes, wrong, game.CONTENT), net.Error.Checkpoint_Contract)
}

@(test)
scoped_reconnect_and_new_authority_keep_complete_recovery_and_filtered_views :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)

    for _ in 0 ..< 80 {
        step(&f, 1)
    }

    client := &f.clients[0]
    tr.close(&client.wire)
    step(&f)
    tr.memory_open(&f.memory, &f.ep[1], 2)
    testing.expect_value(t, net.client_reconnect(client, tr.memory_transport(&f.ep[1])), net.Error.None)

    for _ in 0 ..< 60 {
        step(&f)
    }

    check_views(t, &f)
    cp: net.Checkpoint(game.World, game.Control, game.Action, game.SEATS)
    defer net.checkpoint_destroy(&cp)
    net.checkpoint_capture(&f.server, &cp)
    wire := f.server.wire
    net.server_destroy(&f.server)
    testing.expect_value(t, net.server_restore(&f.server, &cp, game.model(), wire, {epoch = 2}), net.Error.None)

    for &c, i in f.clients {
        testing.expect_value(t, net.client_authority(&c, 2, tr.memory_transport(&f.ep[i + 1])), net.Error.None)
    }

    for _ in 0 ..< 70 {
        step(&f)
    }

    check_views(t, &f)
}

@(test)
filtered_policy_requires_group_and_reduces_observer_bytes :: proc(t: ^testing.T) {
    client: Client
    testing.expect_value(t, net.client_init(&client, game.model(), {}, net.Token{0 = 1}), net.Error.Invalid_Model)
    filtered, full: Fixture
    start(&filtered)
    defer finish(&filtered)
    start(&full, false)
    defer finish(&full)

    for _ in 0 ..< 180 {
        step(&filtered)
        step(&full)
    }

    testing.expect_value(t, full.clients[2].phase, net.Phase.Running)
    testing.expect(t, filtered.bytes[2] < full.bytes[2] * 3 / 4)
    fmt.printf("REPLAY_INTEREST_BYTES observer_filtered=%d observer_full=%d\n", filtered.bytes[2], full.bytes[2])
}

@(test)
invalid_recipient_projection_never_falls_back_to_full_authority_state :: proc(t: ^testing.T) {
    f: Fixture
    start(&f, invalid = true)
    defer finish(&f)

    for _ in 0 ..< 70 {
        step(&f)
    }

    testing.expect(t, f.server.stats.rejected_replica_views > 0)

    for &client in f.clients {
        testing.expect_value(t, client.phase, net.Phase.Joining)
        testing.expect(t, !client.has_world)
    }

    for bytes in f.bytes {
        testing.expect_value(t, bytes, u64(0))
    }

    world, _ := r.current(&f.server.timeline)
    testing.expect(t, game.state_valid(world.state))
}

@(test)
departing_host_is_sanitized_before_becoming_a_predicting_client :: proc(t: ^testing.T) {
    server: Server
    cfg := net.DEFAULT_CONFIG
    cfg.content = game.CONTENT
    testing.expect_value(
        t,
        net.server_init(
            &server,
            r.Frame(game.World){state = game.initial()},
            game.player_model(),
            {},
            cfg,
            local_seat = 1,
        ),
        net.Error.None,
    )
    defer net.server_destroy(&server)
    net.server_set_local_token(&server, net.Token{0 = 1})
    net.server_step(&server)
    history := net.server_departing(&server)
    history.held[1] = {
        move = 1,
    }
    testing.expect_value(t, history.frame.state.secret, game.SECRET)
    client: Client
    testing.expect_value(
        t,
        net.client_init(&client, game.player_model(), {}, net.Token{0 = 1}, cfg = cfg),
        net.Error.None,
    )
    defer net.client_destroy(&client)
    testing.expect_value(t, net.client_seed_departing(&client, history), net.Error.None)
    prediction, ok := net.client_prediction(&client)
    testing.expect(t, ok && prediction.frame.state.secret == 0 && prediction.frame.state.visible == 0)
    testing.expect_value(t, client.held[1], game.Control{})
}

@(test)
policy_mismatch_is_rejected_before_any_world_is_received :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)
    client := &f.clients[0]
    token, cfg := client.token, client.cfg
    net.client_destroy(client)
    wrong := game.player_model()
    wrong.replication.id += 1
    testing.expect_value(
        t,
        net.client_init(client, wrong, tr.memory_transport(&f.ep[1]), token, cfg = cfg),
        net.Error.None,
    )

    for _ in 0 ..< 80 {
        step(&f)
    }

    testing.expect_value(t, client.phase, net.Phase.Rejected)
    testing.expect_value(t, client.rejection, net.Reject.Contract)
    testing.expect(t, !client.has_world)
}

@(test)
repaired_facts_preserve_historical_recipient_filtering :: proc(t: ^testing.T) {
    f: Fixture
    start(&f)
    defer finish(&f)
    tr.memory_set_faults(&f.memory, tr.Faults{latency_ticks = 2, retry_ticks = 2})

    for _ in 0 ..< 80 {
        step(&f)
    }

    target := f.server.timeline.head + 1
    release := f.tick + 100

    for _ in 0 ..< 45 {
        step(&f, 1)

        for &packet, i in f.memory.packets {
            if !packet.active || packet.from != 1 {
                continue
            }

            bytes := f.memory.bytes[i * f.memory.config.packet_bytes:i * f.memory.config.packet_bytes + packet.count]
            meta, _, report := sc.inspect(bytes)

            if report.error != .None {
                continue
            }

            if meta.kind == 6 && meta.tick == target && packet.channel == .Reliable {
                packet.ready = false
                packet.due = release
            }

            if (meta.kind == 19 || meta.kind == 27) && meta.tick >= target && meta.tick - target <= 3 {
                packet.active = false
            }
        }
    }

    testing.expect(t, f.server.stats.fact_repairs >= 3)

    for &client in f.clients {
        testing.expect(t, client.stats.fact_repair_requests > 0 && client.facts_contiguous > target + 20)
        testing.expect_value(t, client.stats.rejected_packets, u64(0))
    }

    check_views(t, &f)
}
