package replay_scrapyard

import "core:fmt"
import gd "godot:godot"
import flow "../shared/flow"
import game "../shared/game"

Camera_Follow :: struct {
    seat: u16,
    generation, warp: u32,
    active: bool,
}

camera_paint :: proc(self: ^ReplayScrapyard, world: ^game.World, seat: u16) {
    follow := &self.camera_follow
    target := flow.camera_target(world, seat, {follow.seat, follow.generation})
    gd.canvas_item_set_visible(self.follow_label, false)

    if target.seat == 0 {
        follow^ = {}
        return
    }

    rig := self.rigs[target.seat - 1]

    // The confirmed roster can advance before the observed render clock. Do
    // not follow an older body still being presented in a reused seat.
    if rig.value.generation != target.generation || !gd.canvas_item_is_visible(rig.owner) {
        return
    }

    cut :=
        !follow.active ||
        target.seat == follow.seat && (target.generation != follow.generation || rig.value.warp != follow.warp)
    gd.node2d_set_global_position(self.camera, gd.node2d_get_global_position(rig.owner))

    if cut {
        gd.camera2d_reset_smoothing(self.camera)
    }

    follow^ = {target.seat, target.generation, rig.value.warp, true}

    if target.seat != seat {
        player := world.players[target.seat - 1]
        name :=
            player.profile.name.count > 0 ? game.name_string(&player.profile.name) : fmt.tprintf("runner %d", target.seat)
        gd.set_string(self.follow_label, "text", fmt.ctprintf("Watching %s", name))
        gd.canvas_item_set_visible(self.follow_label, true)
    }
}
