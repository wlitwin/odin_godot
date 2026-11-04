//gd:extends Node
//gd:class PureProbe
package box3d_pure_probe

import gd "godot:godot"
import r "godot:replay"

PureProbe :: struct {
    owner: gd.Node,
}

Pure_State :: struct {
    value: i64,
}

@(gd_method)
pure_probe_check :: proc(self: ^PureProbe) -> bool {
    return r.value_supported(Pure_State)
}
