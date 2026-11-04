//gd:extends Resource
//gd:class StatusDef
package scrapyard_defs

// StatusDef — one status (buff OR debuff) as an Inspector-editable .tres
// (res://data/status/*.tres). A status is what an ability's payload leaves
// BEHIND: a timed row of multipliers and pulses the host interprets every
// tick. Buffs and debuffs are the same row type with different signs —
// freeze is move_mult 0, haste is 1.3, poison is a dot, regen is a NEGATIVE
// dot. What a status does when it lands on another status is the combo
// table's business (combo_def.odin), not this row's.
//
// `id` is the WIRE kind byte (kcombat.Effect.kind; 0 reserved for empty).
// Base roster: 1 slimed, 2 burn. Mods claim higher ids.

import gd "godot:godot"

StatusDef :: struct {
    owner: gd.Resource,
    id: gd.Int `gd:"export,range=1:254:1"`, // Effect.kind on the wire
    name: gd.String `gd:"export"`,
    duration: gd.Int `gd:"export,range=1:36000:1"`, // ticks (60/s)
    max_stacks: gd.Int `gd:"export,range=1:9:1"`, // 1 = classic refresh-only
    move_mult: f32 `gd:"export,range=0:3:0.05"`, // 1 = untouched; 0 = frozen solid
    dot_dmg: gd.Int `gd:"export,range=-20:20:1"`, // per pulse PER STACK; negative HEALS
    dot_every: gd.Int `gd:"export,range=0:600:1"`, // pulse cadence, ticks (0 = no dot)
    taken_mult: f32 `gd:"export,range=0:4:0.05"`, // damage-taken while afflicted (armor <1, vulnerable >1)
    dealt_mult: f32 `gd:"export,range=0:4:0.05"`, // damage-dealt (buff seats; consumed when runners wear statuses)
    tint: gd.Color `gd:"export"`, // the afflicted body's wash (alpha 0 = no tint)
}
