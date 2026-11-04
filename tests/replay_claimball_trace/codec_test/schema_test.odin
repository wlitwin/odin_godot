package claimball_trace_test
import "core:testing"
import "core:reflect"
import sc "godot:replay/schema"
import net "godot:replay/net"
import view "godot:replay/view"
import trace "godot:tests/replay_claimball_trace/shared"
import game "godot:examples/replay_claimball/shared/pitch"

@(test)
metadata_is_portable_and_preserves_all_config_fields :: proc(t: ^testing.T) {
    h: sc.Schema
    defer sc.destroy(&h)
    testing.expect(t, sc.init(&h, trace.Header).error == .None)
    f: sc.Schema
    defer sc.destroy(&f)
    testing.expect(t, sc.init(&f, trace.Frame).error == .None)
    c: sc.Schema
    defer sc.destroy(&c)
    testing.expect(t, sc.init(&c, view.Change(net.Net_Event(game.Event))).error == .None)
    cfg := net.DEFAULT_CONFIG
    cfg.epoch = 42
    cfg.content = game.CONTENT
    cfg.history = 256
    cfg.packets_per_pump = 21
    cfg.require_permit = true
    header := trace.Header {
        settings = trace.settings(cfg),
        epoch    = cfg.epoch,
        content  = cfg.content,
    }
    testing.expect(t, reflect.equal(cfg, trace.config(header)))
}
