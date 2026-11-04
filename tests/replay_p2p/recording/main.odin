package main

import "core:fmt"
import "core:os"
import r "godot:replay"
import rb "godot:replay/p2p"
import tr "godot:replay/transport"
import game "../../../examples/replay_duel/shared/duel"
import recording "../../../examples/replay_duel/shared/recording"

main :: proc() {
    assert(len(os.args) == 2)
    cases := [2]bool{false, true}

    for faulty in cases {
        make_record(os.args[1], faulty)
    }
}

make_record :: proc(directory: string, faulty: bool) {
    network: tr.Memory
    assert(
        tr.memory_init(
            &network,
            seed = 42,
            cfg = {2, 512, 8192, 65536},
            faults = {latency_ticks = 3, jitter_ticks = 1, loss_permyriad = 1000, retry_ticks = 3},
        ),
    )
    defer tr.memory_destroy(&network)
    endpoints: [2]tr.Memory_Endpoint
    peers: [2]rb.Runner(game.World, game.Input, game.Event, 2)

    defer {
        for &peer in peers {
            rb.destroy(&peer)
        }

        for &endpoint in endpoints {
            wire := tr.memory_transport(&endpoint)
            tr.close(&wire)
        }
    }

    for &peer, i in peers {
        assert(tr.memory_open(&network, &endpoints[i], tr.Peer_Id(i + 1)))
        m := game.model()

        if faulty && i == 1 {
            m.step = proc(w: ^game.World, inputs: [2]game.Input, ctx: ^r.Step(game.Event)) {
                game.step(w, inputs, ctx)

                if ctx.tick == 12 {
                    w.fighters[0].position[0] += 1
                }
            }
        }

        cfg := rb.DEFAULT_CONFIG
        cfg.session, cfg.content = 123, game.CONTENT
        assert(
            rb.init(
                &peer,
                r.Frame(game.World){state = game.initial(42)},
                m,
                [2]tr.Peer_Id{1, 2},
                u16(i),
                tr.memory_transport(&endpoints[i]),
                cfg,
            ) ==
            .None,
        )
    }

    for clock in u64(0) ..< 500 {
        tr.memory_advance(&network, clock)

        for &peer, i in peers {
            if peer.phase == .Diverged {
                continue
            }

            err := rb.pump(&peer, clock * 1000 / 60)
            assert(err == .None || (faulty && err == .Diverged))

            if peer.phase == .Running && peer.timeline.head < 200 {
                rb.advance(&peer, game.corpus_input(peer.timeline.head + 3, i))
            }
        }

        if faulty && peers[1].phase == .Diverged {
            break
        }

        if !faulty && peers[1].timeline.head == 200 {
            break
        }
    }

    p := &peers[1]

    if faulty {
        assert(p.phase == .Diverged)
    } else {
        assert(p.timeline.head == 200 && p.timeline.confirmed < 200)
    }

    a: rb.Archive(game.World, game.Input, game.Event, 2)
    defer rb.archive_destroy(&a)
    assert(rb.archive_capture(p, &a) == .None)
    bytes, err := rb.archive_encode(&a, p.model)
    defer delete(bytes)
    assert(err == .None)
    name := faulty ? "divergence" : "session"
    path := fmt.tprintf("%s/%s.rply", directory, name)
    assert(os.write_entire_file(path, bytes) == nil)
    report := recording.verify(bytes)

    if faulty {
        assert(report.error == .Replay_Mismatch && report.replay.tick == 12)
    } else {
        assert(report.error == .None)
    }

    fmt.printf(
        "%s %d %d %d %d %d %d %d %d %d %d\n",
        name,
        int(report.error),
        int(report.phase),
        report.base,
        report.head,
        report.confirmed,
        report.chain,
        report.replay.tick,
        report.replay.expected,
        report.replay.actual,
        report.disagreement.tick,
    )
}
