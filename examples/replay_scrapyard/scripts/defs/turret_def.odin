//gd:extends Resource
//gd:class TurretDef
package scrapyard_defs

import gd "godot:godot"

TurretDef :: struct {
    owner: gd.Resource,
    ammo: gd.Int `gd:"export,range=1:1000:1"`,
    cadence: gd.Int `gd:"export,range=1:120:1"`,
    damage: gd.Int `gd:"export,range=1:100:1"`,
    speed: f32 `gd:"export,range=1:100:1"`,
    ttl: gd.Int `gd:"export,range=1:600:1"`,
    use_radius: f32 `gd:"export,range=24:96:1"`,
}
