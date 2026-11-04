//gd:extends Resource
//gd:class MobDef
package scrapyard_defs

// MobDef — one scrapbot variant as an Inspector-editable .tres
// (res://data/mobs/*.tres). The BRAIN (chaser/spitter/popper/titan phases)
// stays code — keyed by the mob's wire kind; these are the numbers a variant
// tweaks. defs.odin flattens each into the runtime Mob_Stats table at boot.
//
// `id` is the WIRE kind byte (Mob.kind). Base roster: 0 scrapbot, 1 hulk,
// 2 spitter, 3 popper, 4 titan, 5 barrel (a PROP). Id 0 doubles as the
// fallback row for any stray kind byte, so keep it a sane baseline mob.
//
// A PROP row stands where it spawned: no brain, no bite, excluded from the
// floor-clear count — but it's a real replicated mob, so every gun, blast,
// zone and dot can hurt it. The boom_* columns are its death payload:
// wound + status to everything in reach, THROUGH the rulebook — a napalm
// barrel can prime or trigger the same chains casts do (and mods can claim
// higher ids for nastier kegs).

import gd "godot:godot"

MobDef :: struct {
    owner: gd.Resource,
    id: gd.Int `gd:"export,range=0:254:1"`, // wire kind (Mob.kind)
    name: gd.String `gd:"export"`, // for humans reading the data (unused at runtime, for now)
    hp: gd.Int `gd:"export,range=1:65535:1"`,
    speed: f32 `gd:"export,range=10:400:1"`, // px/s (the tick divides it)
    bite: gd.Int `gd:"export,range=0:20:1"`, // melee damage (0 = doesn't bite)
    body_r: f32 `gd:"export,range=4:120:1"`, // slug target radius (the hulk body-blocks)
    scale: f32 `gd:"export,range=0.2:8:0.05"`, // presentation size
    prop: bool `gd:"export"`, // a standing PROP (barrel): brainless, shootable, doesn't gate the clear
    boom_dmg: gd.Int `gd:"export,range=0:250:1"`, // death blast wound (0 = dies quietly)
    boom_radius: f32 `gd:"export,range=0:600:1"`, // death blast reach
    pulse: ^gd.Resource `gd:"export,resource=PulseDef"`,
    boom_status: ^gd.Resource `gd:"export,resource=StatusDef"`, // death blast payload status (through the rulebook; 0 = none)
}
