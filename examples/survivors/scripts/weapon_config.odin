//gd:extends Resource
//gd:class WeaponConfig
package survivors_scripts

// ----------------------------------------------------------------------------
// WeaponConfig — the data asset describing ONE weapon. weapon.odin reads it (typed) and
// behaves accordingly: a Projectile weapon auto-fires bullets at the nearest enemy, an Orbit
// weapon spins blades around the player, an Aura weapon pulses damage to everything in range.
//
// We ship three instances: pistol.tres (Projectile), orbit_blade.tres (Orbit), aura.tres
// (Aura). The player starts with the pistol; the other two are unlocked by AddWeapon upgrades.
//
// FEATURES: a custom Resource with an `enum=` int `@export` (the Inspector shows a named
// dropdown for `kind`), several `range=` sliders, a String name, and a Color.
// ----------------------------------------------------------------------------

import gd "godot:godot"

// The three weapon archetypes. Kept as bare ints in the `kind` export (with an `enum=` hint)
// so the value round-trips through `.tres` + the Inspector as a named dropdown; weapon.odin
// switches on `Weapon_Kind(self.kind)`.
Weapon_Kind :: enum int {
	Projectile = 0,
	Orbit      = 1,
	Aura       = 2,
}

WeaponConfig :: struct {
	owner:            gd.Resource,
	name:             gd.String `gd:"export"`, // display name (e.g. "Pistol")
	kind:             gd.Int    `gd:"export,enum=Projectile:Orbit:Aura"`, // archetype
	damage:           f32       `gd:"export,range=1:200:1"`, // damage per hit (before player mult)
	cooldown:         f32       `gd:"export,range=0.05:3:0.05"`, // seconds between attacks/pulses
	projectile_speed: f32       `gd:"export,range=100:900:10"`, // Projectile: bullet speed (px/s)
	count:            gd.Int    `gd:"export,range=1:12:1"`, // multishot bullets / orbiting blades
	pierce:           gd.Int    `gd:"export,range=0:10:1"`, // Projectile: extra enemies pierced
	range:            f32       `gd:"export,range=40:400:10"`, // Projectile target / Orbit radius / Aura radius
	color:            gd.Color  `gd:"export"`, // bullet / blade / aura tint
}
