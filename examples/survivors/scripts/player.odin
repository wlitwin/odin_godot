//gd:extends CharacterBody2D
//gd:class Player
//gd:signal health_changed(value: int)
//gd:signal leveled_up()
//gd:signal died()
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
//   * signals                     — health_changed(value), leveled_up(), died(); the HUD/Game
//                                   listen.
//   * custom @(gd_method) take_damage — an enemy calls it TYPED on contact.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"

Player :: struct {
	owner:          gd.Node2d, // base is CharacterBody2D (a Node2d)

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
}

// ---- cached input action names (interned once) ----
@(private = "file")
left_name, right_name, up_name, down_name: gd.String_Name
@(private = "file")
names_ready: bool

@(private = "file")
ensure_names :: proc "contextless" () {
	if names_ready {return}
	left_name = gd.new_string_name_cstring("ui_left", true)
	right_name = gd.new_string_name_cstring("ui_right", true)
	up_name = gd.new_string_name_cstring("ui_up", true)
	down_name = gd.new_string_name_cstring("ui_down", true)
	names_ready = true
}

player_ready :: proc(self: ^Player) {
	if self.move_speed == 0 {self.move_speed = 200}
	if self.max_health == 0 {self.max_health = 100}
	if self.pickup_range == 0 {self.pickup_range = 70}
	if self.damage_mult == 0 {self.damage_mult = 1}
	if self.fire_rate_mult == 0 {self.fire_rate_mult = 1}

	self.health = self.max_health

	// Join the "player" group so enemies, gems and the HUD can find us by group.
	gd.add_to_group(self.owner, GROUP_PLAYER)

	// Equip the starting weapon (the pistol).
	if self.starting_weapon != nil {
		player_add_weapon(self, self.starting_weapon)
	}
}

player_process :: proc(self: ^Player, delta: f64) {
	ensure_names()
	if self.health <= 0 {return}

	// Movement: read the real input axes and translate (a kinematic move).
	input := gd.singleton_input()
	dx := f32(gd.input_get_axis(input, left_name, right_name))
	dy := f32(gd.input_get_axis(input, up_name, down_name))
	pos := gd.node2d_get_position(self.owner)
	pos.x += dx * self.move_speed * f32(delta)
	pos.y += dy * self.move_speed * f32(delta)
	// Keep the hero inside the arena.
	if pos.x < 8 {pos.x = 8}
	if pos.x > ARENA_W - 8 {pos.x = ARENA_W - 8}
	if pos.y < 8 {pos.y = 8}
	if pos.y > ARENA_H - 8 {pos.y = ARENA_H - 8}
	gd.node2d_set_position(self.owner, pos)
}

// player_add_weapon instantiates weapon_scene, assigns it the given WeaponConfig (TYPED), and
// parents it under the player so it moves with us. Used for the starting weapon and by
// AddWeapon upgrades.
@(private = "file")
player_add_weapon :: proc(self: ^Player, cfg: ^gd.Resource) {
	if self.weapon_scene == nil || cfg == nil {return}
	w := gd.instantiate(cast(gd.Packed_Scene)self.weapon_scene)
	if w == nil {return}
	ws := rt.script_of(w, Weapon)
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
