//gd:extends Resource
//gd:class GunDef
package scrapyard_defs

// GunDef — ONE iron as an Inspector-editable .tres (res://data/guns/*.tres).
// The FAMILY (kind) picks the behavior code path; everything else is numbers
// and art. A new gun inside an existing family is a new .tres file, no code:
// defs.odin scans the directory at boot and flattens each into a Gun_Row.
//
// `id` is the WIRE id — the u8 that replicated fields carry (runner.gun) and
// the shop/muster reference. Base irons hold 0..6; new files claim the next
// free id. Two files with one id: the alphabetically-later file wins (that
// IS the override mechanism mods will use).

import gd "godot:godot"

GunDef :: struct {
	owner: gd.Resource,
	id: gd.Int `gd:"export,range=0:254:1"`, // wire id (u8 on replicated fields)
	name: gd.String `gd:"export"`, // the HUD's word for it
	// The behavior family — maps to the FIRE_* wire vocabulary in defs.odin:
	// Bolt/Rivet fly as slugs (they differ only in tracer glyph), Nade caroms
	// and booms at fuse-out, Lance is the lag-compensated piercing rail,
	// Mend the lag-compensated healing dart.
	kind: gd.Int `gd:"export,enum=Bolt:Rivet:Nade:Lance:Mend"`,
	cooldown: gd.Int `gd:"export,range=1:240:1"`, // ticks between pulls (60Hz)
	dmg: gd.Int `gd:"export,range=0:50:1"`, // per hit — or the HEAL, for Mend
	// play.Gun mechanism knobs (mag / reload / jams).
	mag: gd.Int `gd:"export,range=1:250:1"`,
	reload_ticks: gd.Int `gd:"export,range=1:600:1"`,
	jam_per_mille: gd.Int `gd:"export,range=0:500:1"`, // per-shot jam chance in ‰
	jam_taps: gd.Int `gd:"export,range=1:9:1"`, // pulls to clear a jam
	projectile: ^gd.Resource `gd:"export,resource=ProjectileDef"`, // what leaves the barrel
	// The iron's rect in the weapons sheet (mixed sizes, so a region).
	sprite_pos: gd.Vector2 `gd:"export"`,
	sprite_size: gd.Vector2 `gd:"export"`,
}
