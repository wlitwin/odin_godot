//gd:extends Node
//gd:class WebKeeper
package web_probe

import gd "godot:godot"
import bg "godot:box3d/godot"

WebKeeper :: struct {
    owner: gd.Node,
}

@(gd_method)
web_keeper_weak_rejected :: proc(self: ^WebKeeper) -> bool {
    if weak_owner.user == nil {
        return false
    }

    rejected := weak_owner.check(weak_owner.user, bg.EXECUTE) == bg.INVALID_HANDLE
    dropped := weak_owner.drop(weak_owner.user) == bg.OK

    if dropped {
        weak_owner = {}
    }

    return rejected && dropped
}
