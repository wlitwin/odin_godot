//gd:extends Resource
//gd:class ComboDef
package scrapyard_defs

// ComboDef — one rule in the element rulebook: what happens when `incoming`
// lands on a target already wearing `present`. THE CHAIN: a reaction's
// `output` status is applied THROUGH the table again (bounded depth), so
// rules can cascade — and four friends each carrying one element can chain
// casts none of them could alone. Rules are data: a mod can add elements AND
// the reactions between them.
//
//   Detonate  — consume, splash `dmg` in `radius` around the target
//   Transmute — consume, apply `output` to the SAME target (re-enters the table)
//   Spread    — apply `output` to every mob in `radius` (each re-enters the table)
//
// First matching rule wins (filename order — the same override story as
// every other def). Base rulebook: slimed + burn = detonate.

import gd "godot:godot"

ComboDef :: struct {
	owner: gd.Resource,
	present: ^gd.Resource `gd:"export,resource=StatusDef"`, // status already on the target
	incoming: ^gd.Resource `gd:"export,resource=StatusDef"`, // status being applied
	reaction: gd.Int `gd:"export,enum=Detonate:Transmute:Spread"`,
	dmg: gd.Int `gd:"export,range=0:250:1"`, // Detonate: the splash's wound
	radius: f32 `gd:"export,range=0:600:1"`, // Detonate splash / Spread reach
	output: ^gd.Resource `gd:"export,resource=StatusDef"`, // Transmute/Spread: the status produced (0 = none)
	consume: bool `gd:"export"`, // the trigger pair vanishes in the reaction
}
