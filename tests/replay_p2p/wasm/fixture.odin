package replay_p2p_wasm
import r "godot:replay"
import rb "godot:replay/p2p"
import tr "godot:replay/transport"
import game "../../../examples/replay_duel/shared/duel"

@(require) instantiate :: proc() {
    p: rb.Runner(game.World, game.Input, game.Event, 2)
    rb.init(&p, r.Frame(game.World){state = game.initial()}, game.model(), [2]tr.Peer_Id{1, 2}, 0, {})
    rb.profile_set(&p, r.Profile_Clock {
        read = proc(user: rawptr) -> (u64, bool) {
            return 0, true
        },
    })
    rb.pump(&p, 0)
    rb.advance(&p, game.Input{})
    rb.reconnect(&p, p.wire, 0)
    a, decoded: rb.Archive(game.World, game.Input, game.Event, 2)
    rb.archive_capture(&p, &a)
    bytes, _ := rb.archive_encode(&a, game.model())
    defer delete(bytes)
    rb.archive_decode(&decoded, bytes, game.model(), p.cfg.content)
    rb.destroy(&p)
    report: rb.Replay_Report
    rb.restore(&p, &decoded, game.model(), [2]tr.Peer_Id{1, 2}, 0, {}, report = &report)
    rb.destroy(&p)
    rb.archive_destroy(&a)
    rb.archive_destroy(&decoded)
    watch: rb.Watch(game.World, game.Input, game.Event, 2)
    rb.watch_init(&watch, r.Frame(game.World){state = game.initial()}, game.model(), [2]tr.Peer_Id{1, 2}, 1, {}, 77)
    rb.watch_pump(&watch, 0)
    rb.watch_current(&watch)
    rb.watch_timeline(&watch)
    anchor, _ := rb.watch_rebind(&watch, 1, {}, 78, 0)
    rb.watch_anchor(&watch)
    rb.watch_destroy(&watch)
    source: rb.Watch_Source(game.World, game.Input, game.Event, 2)
    rb.watch_source_init(&source, &p, 2, {}, 78, resume = &anchor)
    rb.watch_source_pump(&source, 0)
    rb.watch_source_destroy(&source)
}
