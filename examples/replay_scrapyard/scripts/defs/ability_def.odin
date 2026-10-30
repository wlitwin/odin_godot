//gd:extends Resource
//gd:class AbilityDef
package scrapyard_defs

// AbilityDef — one cast as an Inspector-editable .tres
// (res://data/abilities/*.tres). The FAMILY is the delivery — how the cast
// reaches space — and stays code (each family has its own netcode shape);
// everything else is numbers and a STATUS payload (status_def.odin):
//
//   Lob  — an arcing glob to the aim (leashed to `range`), splashing the
//          payload in `radius` at fuse-out. Slime's shape.
//   Cone — instant host-judged sweep: `range` deep, `arc_cos` wide, payload
//          (and `dmg`, if any) to every mob inside. Ignite's shape.
//   Nova — instant ring around the CASTER: `radius`, payload + dmg to all.
//   Buff — the payload status lands on a RUNNER: the caster (`self_buff`)
//          or the nearest living friend within `range`. Buffs are just
//          status rows with friendly signs (dealt_mult 2, regen, haste).
//   Zone — a PATCH at the leashed aim point: for `duration` ticks it pulses
//          the payload (dmg + status) every `pulse` ticks to every mob
//          inside `radius`. Napalm, slow fields — and the payload lands
//          through the RULEBOOK, so zones participate in chains.
//
// `id` is the wire byte the runner's two slots (ab_l/ab_r) reference. Base:
// 1 slime, 2 ignite. The direct `dmg` scales with the caster's dealt_mult.

import gd "godot:godot"

AbilityDef :: struct {
	owner: gd.Resource,
	turret: ^gd.Resource `gd:"export,resource=TurretDef"`,
	id: gd.Int `gd:"export,range=1:254:1"`,
	name: gd.String `gd:"export"`,
	family: gd.Int `gd:"export,enum=Lob:Cone:Nova:Buff:Zone:Turret"`,
	cooldown: gd.Int `gd:"export,range=1:3600:1"`, // ticks (60/s)
	range: f32 `gd:"export,range=0:800:1"`, // lob leash / cone reach / buff friend-reach
	radius: f32 `gd:"export,range=0:600:1"`, // lob splash / nova ring
	arc_cos: f32 `gd:"export,range=-1:1:0.05"`, // cone half-angle cosine
	speed: f32 `gd:"export,range=1:40:0.5"`, // lob glob px/tick
	dmg: gd.Int `gd:"export,range=0:250:1"`, // direct wound (nova/cone; dealt_mult scales it)
	status: ^gd.Resource `gd:"export,resource=StatusDef"`, // payload status id (0 = none)
	self_buff: bool `gd:"export"`, // Buff: me (true) or the nearest friend (false)
	duration: gd.Int `gd:"export,range=0:36000:1"`, // Zone: patch lifetime, ticks
	pulse: gd.Int `gd:"export,range=1:600:1"`, // Zone: payload cadence, ticks
}
