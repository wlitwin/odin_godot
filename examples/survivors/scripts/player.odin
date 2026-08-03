//gd:extends CharacterBody2D
//gd:class Player
//gd:group player
package survivors_scripts

// ----------------------------------------------------------------------------
// Player — the hero. WASD/arrows move it; its weapons auto-attack; it gains XP from gems and
// levels up; upgrades make it stronger; enemy contact hurts it; at 0 HP the run ends.
//
// It is the hub every other system talks to:
//   * INPUT                       — reads the ui_left/right/up/down axes (Input.get_axis); the
//                                   Game node also binds WASD onto those actions at startup.
//   * @export tunables            — move_speed, max_health, pickup_range, and the three combat
//                                   MULTIPLIERS (damage_mult, fire_rate_mult, projectile_count)
//                                   that UPGRADES mutate; weapons read them every shot.
//   * PackedScene + Resource slots — weapon_scene (the Weapon node) + a starting WeaponConfig.
//   * weapon ownership            — spawns Weapon nodes as children; AddWeapon upgrades add more.
//   * XP / leveling               — player_gain_xp (called by a gem) banks XP via the shared
//                                   game_state module and emits `leveled_up` on a level.
//   * apply_upgrade (@(gd_method)) — reads an UpgradeConfig (typed) and mutates a stat / grants
//                                   a weapon — the observable effect the test asserts.
//   * signals                     — the health_changed/leveled_up/died signal FIELDS; the
//                                   HUD/Game listen.
//   * custom @(gd_method) take_damage — an enemy calls it TYPED on contact.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

Player :: struct {
	owner:          gd.Node2d, // base is CharacterBody2D (a Node2d)

	// ---- signals (typed fields; the HUD/Game listen) ----
	health_changed: gd.Signal1(int) `gd:"args=value"`, // every HP change (damage, heal, level)
	leveled_up:     gd.Signal0, // crossing an XP level boundary
	died:           gd.Signal0, // HP hit 0 — the run is over

	// ---- base stats (Inspector-tunable) ----
	move_speed:     f32          `gd:"export,range=60:400:10,group=Stats"`, // px/s
	max_health:     int          `gd:"export,range=10:500:10"`, // starting / max HP
	pickup_range:   f32          `gd:"export,range=20:300:5"`, // XP-gem magnet radius

	// ---- combat multipliers (upgrades raise these; weapons read them) ----
	damage_mult:      f32 `gd:"export,group=Combat"`, // x weapon damage
	fire_rate_mult:   f32 `gd:"export"`, // divides weapon cooldown (higher = faster)
	projectile_count: int `gd:"export"`, // BONUS bullets/blades added to every weapon
	pierce_bonus:     int `gd:"export"`, // BONUS pierce added to projectile weapons

	// ---- references ----
	weapon_scene:     ^gd.Resource `gd:"export,resource=PackedScene,group=Setup"`, // weapon.tscn
	starting_weapon:  ^gd.Resource `gd:"export,resource=WeaponConfig"`, // the pistol

	// ---- runtime state (untagged -> private) ----
	health: int,
	vel:    gd.Vector2, // current velocity — accelerates toward input, coasts to a stop (momentum)
}

// How fast velocity chases the input target, as a multiple of move_speed per second: 8 => reach
// full speed (or stop) in ~1/8 s. Scales with move_speed so fast builds stay equally responsive.
MOVE_ACCEL_RATE :: f32(8.0)

// approach moves `cur` toward `target` by at most `max_delta` (a 1-D move_toward).
@(private = "file")
approach :: proc(cur, target, max_delta: f32) -> f32 {
	if cur < target {
		r := cur + max_delta
		return target if r > target else r
	}
	if cur > target {
		r := cur - max_delta
		return target if r < target else r
	}
	return cur
}

player_ready :: proc(self: ^Player) {
	// Ready-time ZERO-GUARDS, deliberately not `gd:"default=..."`: game.tscn STORES all of
	// these properties (damage_mult / fire_rate_mult explicitly at 0.0), so a declared
	// default would be overwritten by the scene load — the guards are load-bearing.
	if self.move_speed == 0 {self.move_speed = 200}
	if self.max_health == 0 {self.max_health = 100}
	if self.pickup_range == 0 {self.pickup_range = 70}
	if self.damage_mult == 0 {self.damage_mult = 1}
	if self.fire_rate_mult == 0 {self.fire_rate_mult = 1}

	self.health = self.max_health

	// (Group membership — "player", so enemies, gems and the HUD can find us — is declared
	// with `//gd:group` at the top of the file; the core joins it at READY.)

	// Equip the starting weapon (the pistol).
	if self.starting_weapon != nil {
		player_add_weapon(self, self.starting_weapon)
	}
}

player_process :: proc(self: ^Player, delta: f64) {
	if self.health <= 0 {return}

	// Movement: read the real input axes, build a target velocity, then EASE the actual velocity
	// toward it so the hero accelerates from rest and coasts to a stop (momentum) instead of
	// snapping on/off with the keys. gd.sname interns each literal ONCE (static StringNames),
	// so the per-frame calls are cheap — no hand-kept name cache needed.
	input := gd.singleton_input()
	dx := f32(gd.input_get_axis(input, gd.sname("ui_left"), gd.sname("ui_right")))
	dy := f32(gd.input_get_axis(input, gd.sname("ui_up"), gd.sname("ui_down")))
	tvx := dx * self.move_speed
	tvy := dy * self.move_speed
	if dx != 0 && dy != 0 { // normalize diagonals so they aren't ~1.41x faster
		inv := f32(0.70710677) // 1/sqrt(2)
		tvx *= inv
		tvy *= inv
	}
	step := self.move_speed * MOVE_ACCEL_RATE * f32(delta)
	self.vel.x = approach(self.vel.x, tvx, step)
	self.vel.y = approach(self.vel.y, tvy, step)
	pos := gd.node2d_get_position(self.owner)
	pos.x += self.vel.x * f32(delta)
	pos.y += self.vel.y * f32(delta)
	// Keep the hero inside the arena.
	if pos.x < 8 {pos.x = 8}
	if pos.x > ARENA_W - 8 {pos.x = ARENA_W - 8}
	if pos.y < 8 {pos.y = 8}
	if pos.y > ARENA_H - 8 {pos.y = ARENA_H - 8}
	gd.node2d_set_position(self.owner, pos)
}

// player_add_weapon spawns weapon_scene, assigns it the given WeaponConfig (TYPED), and
// parents it under the player so it moves with us. Used for the starting weapon and by
// AddWeapon upgrades. rt.spawn_scripted is the poke-BEFORE-add shape: it resolves the typed
// ref WITHOUT parenting, so the weapon's _ready sees `config` already assigned.
@(private = "file")
player_add_weapon :: proc(self: ^Player, cfg: ^gd.Resource) {
	if self.weapon_scene == nil || cfg == nil {return}
	w, ws := rt.spawn_scripted(cast(gd.Packed_Scene)self.weapon_scene, Weapon)
	if w == nil {return}
	if ws != nil {ws.config = cfg} // typed cross-script WRITE, before _ready reads it
	gd.add_child(self.owner, w)
}

// player_gain_xp — a gem calls this on pickup (TYPED). It banks XP through the shared module;
// if that crossed a level boundary it emits `leveled_up` so the Game node opens the menu.
player_gain_xp :: proc(self: ^Player, value: int) {
	if game_state_add_xp(value) {
		player_emit_leveled_up(self)
	}
}

// apply_upgrade — the level-up menu calls this with the chosen UpgradeConfig. It reads the
// config TYPED and mutates the player; the change is immediately visible to weapons (which
// read the mults each shot) and to the test.
@(gd_method)
player_apply_upgrade :: proc(self: ^Player, upgrade: ^gd.Resource) {
	cfg := rt.script_of(cast(gd.Object)upgrade, UpgradeConfig)
	if cfg == nil {return}
	switch Upgrade_Kind(cfg.kind) {
	case .StatMod:
		switch Upgrade_Stat(cfg.stat) {
		case .MoveSpeed:
			self.move_speed += cfg.amount
		case .MaxHealth:
			self.max_health += int(cfg.amount)
			self.health += int(cfg.amount) // heal by the same amount
			if self.health > self.max_health {self.health = self.max_health}
			player_emit_health_changed(self, i64(self.health))
		case .Damage:
			self.damage_mult += cfg.amount
		case .FireRate:
			self.fire_rate_mult += cfg.amount
		case .PickupRange:
			self.pickup_range += cfg.amount
		case .ProjectileCount:
			self.projectile_count += int(cfg.amount)
		}
	case .WeaponMod:
		self.projectile_count += int(cfg.amount)
		self.pierce_bonus += 1
	case .AddWeapon:
		player_add_weapon(self, cfg.weapon)
	}
}

// take_damage — an enemy calls this TYPED on contact. Emits health_changed every hit; on
// reaching 0 HP it emits `died` and flags the run over via the shared module.
@(gd_method)
player_take_damage :: proc(self: ^Player, amount: int) {
	if self.health <= 0 {return}
	self.health -= amount
	if self.health < 0 {self.health = 0}
	player_emit_health_changed(self, i64(self.health))
	if self.health == 0 {
		game_state_set_state(.GameOver)
		player_emit_died(self)
	}
}
