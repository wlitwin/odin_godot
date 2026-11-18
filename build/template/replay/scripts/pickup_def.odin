//gd:extends Resource
//gd:class PickupDef
package scripts

import gd "godot:godot"
import d "godot:replay/definitions"
import scene "godot:replay/godot/scene"
import game "../shared/game"

PickupDef :: struct {
    owner: gd.Resource,
    reach: gd.Int `gd:"export,range=1:96:1"`,
}

// One checked extraction is shared by gameplay, preview and validation.
// The result contains values only; the live World never borrows a Resource.
pickup_rules :: proc(resource: gd.Resource) -> (game.Pickup_Rules, d.Report) {
    ctx: scene.Bake_Context
    source := scene.bake_resource(&ctx, resource, PickupDef, "definition")
    result: game.Pickup_Rules
    if source != nil {result.reach = scene.bake_integer(&ctx, i32, source.reach, 1, 96, "reach")}
    return result, ctx.report
}
