//gd:extends Resource
//gd:class PulseDef
package scrapyard_defs

import gd "godot:godot"

// Owned attack configuration after baking. Presentation never controls these ticks.
PulseDef :: struct {
    owner: gd.Resource,
    windup_ticks: gd.Int `gd:"export,range=1:180:1"`,
    cooldown_ticks: gd.Int `gd:"export,range=30:3600:1"`,
    radius: f32 `gd:"export,range=32:400:1"`,
    damage: gd.Int `gd:"export,range=1:20:1"`,
}
