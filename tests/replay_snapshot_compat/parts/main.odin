package main
import "core:fmt"
import r "godot:replay"
import tr "godot:replay/transport"
import net "godot:replay/net"
import v "godot:replay/view"
import old "../parts_reference"

World :: struct {
    tick:   u64,
    values: [512]u32,
}

Control :: struct {
    held: bool,
}

Action :: struct {
    value: u8,
}

Event :: struct {
    value: u8,
}

model :: proc($M: typeid) -> M {
    return {step = proc(w: ^World, controls: [2]Control, joins, leaves: u64, ctx: ^r.Step(Event)) {
            w.tick = ctx.tick

            for &value, i in w.values {
                value = u32(ctx.tick * 1234567) ~ u32(i * 65537)
            }
        }, control_valid = proc(c: Control) -> bool {
            return true
        }, hold = proc(c: Control) -> Control {
            return c
        }, action_valid = proc(a: Action) -> bool {
            return true
        }, state_valid = proc(w: World) -> bool {
            if w.tick == 0 {
                return true
            }

            for value, i in w.values {
                if value != u32(w.tick * 1234567) ~ u32(i * 65537) {
                    return false
                }
            }

            return true
        }}
}

run :: proc(old_server, old_client: bool) {
    memory: tr.Memory
    assert(tr.memory_init(&memory, 99, {2, 512, 8192, 16384}, {latency_ticks = 7, retry_ticks = 3}))
    defer tr.memory_destroy(&memory)
    ends: [2]tr.Memory_Endpoint

    for &e, i in ends {
        assert(tr.memory_open(&memory, &e, tr.Peer_Id(i + 1)))
    }

    defer for &e in ends {
        wire := tr.memory_transport(&e)
        tr.close(&wire)
    }

    ns: net.Server(World, Control, Action, Event, 2)
    os: old.Server(World, Control, Action, Event, 2)
    nc: net.Client(World, Control, Action, Event, 2)
    oc: old.Client(World, Control, Action, Event, 2)
    defer net.server_destroy(&ns)
    defer old.server_destroy(&os)
    defer net.client_destroy(&nc)
    defer old.client_destroy(&oc)
    cfg := net.DEFAULT_CONFIG
    cfg.snapshot_every = 1
    old_cfg := old.DEFAULT_CONFIG
    old_cfg.snapshot_every = 1

    if old_server {
        assert(
            old.server_init(
                &os,
                r.Frame(World){},
                model(old.Model(World, Control, Action, Event, 2)),
                tr.memory_transport(&ends[0]),
                old_cfg,
                local_seat = 1,
            ) ==
            .None,
        )
    } else {
        assert(
            net.server_init(
                &ns,
                r.Frame(World){},
                model(net.Model(World, Control, Action, Event, 2)),
                tr.memory_transport(&ends[0]),
                cfg,
                local_seat = 1,
            ) ==
            .None,
        )
    }

    if old_client {
        assert(
            old.client_init(
                &oc,
                model(old.Model(World, Control, Action, Event, 2)),
                tr.memory_transport(&ends[1]),
                old.Token{0 = 2},
                cfg = old_cfg,
            ) ==
            .None,
        )
    } else {
        assert(
            net.client_init(
                &nc,
                model(net.Model(World, Control, Action, Event, 2)),
                tr.memory_transport(&ends[1]),
                net.Token{0 = 2},
                cfg = cfg,
            ) ==
            .None,
        )
    }

    contract := old_server ? os.contract : ns.contract
    assert(contract == (old_client ? oc.contract : nc.contract))

    for tick in u64(0) ..< 400 {
        assert(tr.memory_advance(&memory, tick))
        now := tick * 1000 / 60

        if old_server {
            assert(old.server_pump(&os, now) == .None)
        } else {
            assert(net.server_pump(&ns, now) == .None)
        }

        if old_client {
            assert(old.client_pump(&oc, now) == .None)
        } else {
            assert(net.client_pump(&nc, now) == .None)
        }

        if old_server {
            assert(old.server_step(&os) == .None)
        } else {
            assert(net.server_step(&ns) == .None)
        }

        if old_client {
            if oc.phase == .Running {
                err := old.client_step(&oc, Control{})
                assert(err == .None || err == .Capacity)
            }

            changes: [512]v.Change(old.Net_Event(Event))

            for v.drain(&oc.journal, changes[:]) > 0 {}
        } else {
            if nc.phase == .Running {
                err := net.client_step(&nc, Control{})
                assert(err == .None || err == .Capacity)
            }

            changes: [512]v.Change(net.Net_Event(Event))

            for v.drain(&nc.journal, changes[:]) > 0 {}
        }
    }

    received: u64

    if old_client {
        assert(oc.phase == .Running && oc.stats.resyncs == 0)
        received = oc.authority_frame.tick
        assert(oc.authority_frame.state.tick == received)
    } else {
        assert(nc.phase == .Running && nc.stats.resyncs == 0)
        received = nc.authority_frame.tick
        assert(nc.authority_frame.state.tick == received)
    }

    assert(received > 370)

    if !old_server {
        assert((ns.stats.lz4_snapshots > 200) == !old_client)

        if old_client {
            assert(ns.stats.fragmented_snapshots > 200)
        }
    }

    fmt.printf(
        "SNAPSHOT_COMPAT_OK old_server=%v old_client=%v contract=%d received=%d\n",
        old_server,
        old_client,
        contract,
        received,
    )
}

main :: proc() {
    run(true, false)
    run(false, true)
    run(false, false)
    fmt.println("REPLAY_SNAPSHOT_COMPAT_OK cases=3")
}
