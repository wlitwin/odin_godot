//gd:extends Node
//gd:class PreviewProbe
//gd:tool
package preview_probe

import "core:encoding/json"
import b "godot:box3d"
import gd "godot:godot"

PreviewProbe :: struct {
    owner: gd.Node,
}

Stats :: struct {
    ok:                                                     bool,
    engine_live, wrapper_live, engine_calls, wrapper_calls: u64,
}

@(gd_method = "owned_return")
preview_probe_stats :: proc(self: ^PreviewProbe) -> gd.String {
    engine, es := b.engine_allocation_stats()
    wrapper, ws := b.snapshot_allocation_stats()
    bytes, error := json.marshal(
        Stats{es == .Ok && ws == .Ok, engine.live_bytes, wrapper.live_bytes, engine.total_calls, wrapper.total_calls},
    )

    if error != nil {
        return gd.new_string_odin("{}")
    }

    defer delete(bytes)
    return gd.new_string_odin(string(bytes))
}
