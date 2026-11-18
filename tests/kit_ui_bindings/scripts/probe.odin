//gd:extends Node
//gd:class UIProbe
package kit_ui_probe

import gd "godot:godot"
import "godot:gdext"
import ui "godot:kit/ui"
import binding "godot:kit/ui/bindings"
import boot "godot:kit/boot"
import session "godot:kit/session"
import comms "godot:kit/comms"

UIProbe :: struct {
    owner:       gd.Node,
    frame_count: i64,
}

@(gd_method = "owned_return")
ui_probe_validate :: proc(self: ^UIProbe, node: gd.Node, kind: i64) -> gd.String {
    result := binding.resolve(node, binding.Kind(kind))
    return gd.new_string_odin(binding.text(&result.report))
}

@(gd_method = "owned_return")
ui_probe_prepare :: proc(self: ^UIProbe, lobby, chat, score: gd.Packed_Scene) -> gd.String {
    prepared, report := ui.prepare_scenes(lobby, chat, score)
    defer ui.prepared_destroy(&prepared)
    return gd.new_string_odin(ui.binding_report_text(&report))
}

@(gd_method)
ui_probe_attach :: proc(self: ^UIProbe, lobby, chat, score: gd.Packed_Scene) -> i64 {
    b: boot.Boot
    s: session.Session
    c: comms.Comms
    before := gd.node_get_child_count(self.owner, false)
    ok := boot.boot_attach(
        &b,
        self.owner,
        &s,
        &c,
        boot.Options {
            lobby_scene = lobby,
            chat_scene = chat,
            score_scene = score,
            methods = boot.Methods{host = "noop", join = "noop", start = "noop"},
        },
    )

    if ok {
        boot.boot_detach(&b)
        comms.comms_destroy(&c)
        session.session_destroy(&s)
        return 0
    }

    return(
        b.ses == nil && b.ui_layer == nil && b.wire.node == nil && gd.node_get_child_count(self.owner, false) == before ? 1 : 2 \
    )
}

@(gd_method)
ui_probe_noop :: proc(self: ^UIProbe) {}

ui_probe_process :: proc(self: ^UIProbe, delta: f64) {
    self.frame_count += 1
}

@(gd_method)
ui_probe_frames :: proc(self: ^UIProbe) -> i64 {
    return self.frame_count
}
