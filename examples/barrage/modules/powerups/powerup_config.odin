//gd:extends Resource
//gd:class PowerupConfig
package barrage_powerups

// ----------------------------------------------------------------------------
// PowerupConfig — a custom Resource data asset (powerups MODULE): one .tres per drop
// type in res://config/. The `kind` int rides an `enum=` hint so the Inspector shows a
// dropdown; the values match Player.apply_powerup's switch (0/1/2) plus SlowEnemies (3),
// which the pickup applies to every enemy instead of the player.
//
// FEATURES: custom Resource class, enum= export, range= sliders, Color export.
// ----------------------------------------------------------------------------

import gd "godot:godot"

Powerup_Kind :: enum int {
	RapidFire   = 0,
	Spread      = 1,
	Shield      = 2,
	SlowEnemies = 3,
}

PowerupConfig :: struct {
	owner:     gd.Resource,
	name:      gd.String `gd:"export"`,
	kind:      gd.Int    `gd:"export,enum=RapidFire:Spread:Shield:SlowEnemies"`,
	magnitude: f32       `gd:"export,range=0.1:10:0.1"`, // meaning depends on kind
	color:     gd.Color  `gd:"export"`, // pickup tint
}
