package main

import "core:fmt"
import "core:os"
import r "godot:replay"
import net "godot:replay/net"
import cave "godot:examples/replay_cavecrawl/shared/cave"
import storagegd "godot:replay/godot/storage"

main :: proc() {
    assert(len(os.args) == 2 && cave.CONTENT == 0x4341564552504c34)
    names := [3]string{"before-descent", "after-descent", "before-restart"}

    for name in names {
        w := cave.initial()
        w.clock = 100
        w.lobby.present = 1
        w.lobby.ready = 1
        w.players[0] = {
            initialized = true,
            connected   = true,
            position    = cave.floor(1).door,
            hp          = 65,
            stamina     = 3,
            rock_cd     = 7,
            heal_cd     = 11,
            chill       = 13,
            kills       = 4,
            deaths      = 1,
            damage      = 42,
            slain       = 5,
        }
        w.players[0].bag[0] = {cave.GEM, 3}
        w.director = {
            wave = 2,
            done = true,
        }
        w.door_open = true
        events: [32]r.Occurrence(cave.Event)
        ctx := r.Step(cave.Event) {
            tick   = 101,
            epoch  = 1,
            events = events[:],
        }

        if name == "after-descent" {
            cave.step(&w, [cave.SEATS]cave.Control{}, 0, 0, &ctx)
        }

        if name == "before-restart" {
            w.depth = 2
            w.won = true
        }

        server: net.Server(cave.World, cave.Control, cave.Action, cave.Event, cave.SEATS)
        cfg := net.DEFAULT_CONFIG
        cfg.content = cave.CONTENT
        cfg.hz = cave.HZ
        assert(
            net.server_init(
                &server,
                r.Frame(cave.World){state = cave.initial()},
                cave.model(),
                {},
                cfg,
                local_seat = 1,
            ) ==
            .None,
        )
        assert(net.server_set_local_token(&server, storagegd.session_token("cave-floor-legacy")) == .None)
        assert(net.server_step(&server) == .None)
        assert(r.reset_checkpoint(&server.timeline, r.Frame(cave.World){tick = w.clock, state = w}, 1) == .None)
        cp: net.Checkpoint(cave.World, cave.Control, cave.Action, cave.SEATS)
        assert(net.checkpoint_capture(&server, &cp) == .None)
        bytes, error := net.checkpoint_encode(&cp, cave.model())
        assert(error == .None)
        assert(os.write_entire_file(fmt.tprintf("%s/%s.replay", os.args[1], name), bytes) == nil)
        fmt.printf(
            "CAVE_C4_FIXTURE name=%s tick=%d depth=%d hp=%d stamina=%d rock=%d heal=%d chill=%d\n",
            name,
            cp.frame.tick,
            w.depth,
            w.players[0].hp,
            w.players[0].stamina,
            w.players[0].rock_cd,
            w.players[0].heal_cd,
            w.players[0].chill,
        )
        delete(bytes)
        net.checkpoint_destroy(&cp)
        net.server_destroy(&server)
    }
}
