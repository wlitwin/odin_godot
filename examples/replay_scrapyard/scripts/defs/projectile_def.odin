//gd:extends Resource
//gd:class ProjectileDef
package scrapyard_defs

// ProjectileDef — the sub-resource every GunDef carries: what leaves the
// barrel. Its two numbers mean what the gun's FAMILY says they mean:
//   ballistic — slug velocity (px/tick) and ticks to live (reach = product)
//   lobbed    — shell pace and FUSE (it caroms until fuse-out, then booms)
//   rail/mend — the beam's swept segment: reach = speed*ttl, landed instantly
// Authored in the Inspector inside each gun's .tres; defs.odin flattens it
// into the runtime Gun_Row at load.

import gd "godot:godot"

ProjectileDef :: struct {
    owner: gd.Resource,
    speed: f32 `gd:"export,range=1:40:0.5"`, // px per NET tick (60Hz)
    ttl: gd.Int `gd:"export,range=1:600:1"`, // ticks to live / fuse / reach term
}
