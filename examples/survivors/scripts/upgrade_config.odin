//gd:extends Resource
//gd:class UpgradeConfig
package survivors_scripts

// ----------------------------------------------------------------------------
// UpgradeConfig — one level-up choice. The level-up menu draws 3 random ones from a pool of
// these and shows each as a button; picking it calls player.apply_upgrade(cfg), which reads
// the fields below (typed) and mutates the player.
//
// Three kinds (an `enum=` int export):
//   * StatMod   — bump a player stat (`stat` enum + `amount`): more damage, faster fire,
//                 move speed, max health (+heal), pickup range, +projectile count.
//   * AddWeapon — give the player a new weapon (`weapon` is a WeaponConfig picker slot).
//   * WeaponMod — a combined projectile buff (+multishot and +pierce), driven by `amount`.
//
// FEATURES: a custom Resource mixing a String name, a `multiline` String description, TWO
// `enum=` int exports, an f32 amount, AND a typed cross-resource picker (`resource=WeaponConfig`)
// — i.e. one custom resource that references ANOTHER custom resource.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Upgrade_Kind :: enum int {
	StatMod   = 0,
	AddWeapon = 1,
	WeaponMod = 2,
}

// Which player stat a StatMod upgrade adjusts. Matches the switch in player_apply_upgrade.
Upgrade_Stat :: enum int {
	MoveSpeed       = 0,
	MaxHealth       = 1, // also heals by `amount`
	Damage          = 2, // damage_mult
	FireRate        = 3, // fire_rate_mult
	PickupRange     = 4,
	ProjectileCount = 5,
}

UpgradeConfig :: struct {
	owner:       gd.Resource,
	name:        gd.String   `gd:"export"`, // short title shown on the button
	description: gd.String   `gd:"export,multiline"`, // one-line effect blurb
	kind:        gd.Int      `gd:"export,enum=StatMod:AddWeapon:WeaponMod"`,
	stat:        gd.Int      `gd:"export,enum=MoveSpeed:MaxHealth:Damage:FireRate:PickupRange:ProjectileCount"`,
	amount:      f32         `gd:"export"`, // StatMod/WeaponMod magnitude (units depend on `stat`)
	weapon:      ^gd.Resource `gd:"export,resource=WeaponConfig"`, // AddWeapon: the weapon to grant
	color:       gd.Color    `gd:"export"`, // button accent tint
}
