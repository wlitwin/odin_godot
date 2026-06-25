//gd:extends Node2D
//gd:class Weapon
package survivors_scripts

// ----------------------------------------------------------------------------
// Weapon — ONE script, three behaviours, chosen by its WeaponConfig.kind. A weapon is a child
// of the player; the player spawns one per equipped weapon and assigns its `config` TYPED.
//
//   * Projectile — every `cooldown` it finds the nearest enemy in range and fires `count`
//                  bullets (multishot fans out) that pierce `pierce` enemies.
//   * Orbit      — spawns `count` blade Polygon2D children that spin around the player at
//                  `range`; on a short tick it damages enemies a blade is touching.
//   * Aura       — every `cooldown` it pulses, damaging every enemy within `range`.
//
// FEATURES: the kind SWITCH over a custom-resource enum; typed cross-resource READ of the
// WeaponConfig; typed cross-script READ of the parent Player's live mults each shot; runtime
// node creation (bullets + blades); group/area queries (util) for targeting and area damage.
// ----------------------------------------------------------------------------

import gd "godot:godot"
import rt "godot:runtime"
import "core:math"

MAX_BLADES :: 16

// ---- Aura visual tuning ----
AURA_SEGMENTS :: 24 // circle resolution for the aura field (cheap: one Polygon2D)
AURA_ALPHA_BASE :: f32(0.22) // resting translucency of the aura ring
AURA_ALPHA_PULSE :: f32(0.6) // brightness right after a damage pulse (fades back to base)

Weapon :: struct {
	owner:        gd.Node2d,
	config:       ^gd.Resource `gd:"export,resource=WeaponConfig"`, // set by the player at spawn
	bullet_scene: ^gd.Resource `gd:"export,resource=PackedScene"`, // bullet.tscn (Projectile only)

	// ---- cached config (read once on _ready) ----
	kind:     Weapon_Kind,
	damage:   f32,
	cooldown: f32,
	pspeed:   f32,
	count:    int,
	pierce:   int,
	range:    f32,
	color:    gd.Color,

	// ---- runtime ----
	timer:  f32, // counts down to the next shot/pulse
	angle:  f32, // current orbit rotation (radians)
	blades: [MAX_BLADES]gd.Node2d, // orbit blade visuals
	nblades: int,

	// ---- Aura visual ----
	aura_vis: gd.Polygon2d, // the translucent field ring (Aura kind only)
	pulse:    f32, // counts down after each pulse; drives the brighten-then-fade flash
}

weapon_ready :: proc(self: ^Weapon) {
	// Defaults so a weapon with no config still behaves (a slow pistol).
	self.kind = .Projectile
	self.damage = 6
	self.cooldown = 0.5
	self.pspeed = 460
	self.count = 1
	self.pierce = 0
	self.range = 220
	self.color = gd.Color{1, 0.95, 0.4, 1}

	cfg := rt.script_of(cast(gd.Object)self.config, WeaponConfig)
	if cfg != nil {
		self.kind = Weapon_Kind(cfg.kind)
		self.damage = cfg.damage
		self.cooldown = cfg.cooldown
		self.pspeed = cfg.projectile_speed
		self.count = int(cfg.count)
		self.pierce = int(cfg.pierce)
		self.range = cfg.range
		self.color = cfg.color
	}

	if self.kind == .Orbit {weapon_build_blades(self)}
	if self.kind == .Aura {weapon_build_aura(self)}
}

weapon_process :: proc(self: ^Weapon, delta: f64) {
	switch self.kind {
	case .Projectile:
		weapon_tick_projectile(self, delta)
	case .Orbit:
		weapon_tick_orbit(self, delta)
	case .Aura:
		weapon_tick_aura(self, delta)
	}
}

// ---- the parent player's current combat mults (typed cross-script READ) ----
@(private = "file")
weapon_player :: proc(self: ^Weapon) -> ^Player {
	parent := gd.get_parent(self.owner)
	if parent == nil {return nil}
	return rt.script_of(parent, Player)
}

@(private = "file")
weapon_effective_count :: proc(self: ^Weapon, p: ^Player) -> int {
	n := self.count
	if p != nil {n += p.projectile_count}
	if n < 1 {n = 1}
	if n > MAX_BLADES {n = MAX_BLADES}
	return n
}

// ---------- Projectile ----------
@(private = "file")
weapon_tick_projectile :: proc(self: ^Weapon, delta: f64) {
	p := weapon_player(self)
	rate := f32(1)
	if p != nil && p.fire_rate_mult > 0 {rate = p.fire_rate_mult}

	self.timer -= f32(delta)
	if self.timer > 0 {return}

	origin := gd.node2d_get_global_position(self.owner)
	target, ok := nearest_enemy(self.owner, origin)
	if !ok {return}
	tpos := gd.node2d_get_global_position(target)
	aim := normalized(gd.Vector2{tpos.x - origin.x, tpos.y - origin.y})
	dist := math.sqrt((tpos.x - origin.x) * (tpos.x - origin.x) + (tpos.y - origin.y) * (tpos.y - origin.y))
	if dist > self.range {return} // nothing in range — hold fire

	self.timer = self.cooldown / rate

	n := weapon_effective_count(self, p)
	dmg := self.damage
	pierce := self.pierce
	if p != nil {
		dmg *= p.damage_mult
		pierce += p.pierce_bonus
	}

	// Fan the n shots across a small arc centered on the aim.
	spread := f32(0.20)
	base := f32(0)
	if n > 1 {base = -spread * f32(n - 1) * 0.5}
	for i in 0 ..< n {
		dir := rotate2(aim, base + spread * f32(i))
		weapon_fire_bullet(self, origin, dir, int(dmg), pierce)
	}
}

@(private = "file")
weapon_fire_bullet :: proc(self: ^Weapon, origin: gd.Vector2, dir: gd.Vector2, dmg: int, pierce: int) {
	if self.bullet_scene == nil {return}
	arena := find_game(self.owner)
	if arena == nil {return}
	b := gd.instantiate(cast(gd.Packed_Scene)self.bullet_scene)
	if b == nil {return}
	gd.add_child(arena, b)
	gd.node2d_set_global_position(cast(gd.Node2d)b, origin)
	bs := rt.script_of(b, Bullet)
	if bs != nil {
		bs.dir = dir
		bs.damage = dmg
		bs.speed = self.pspeed
		bs.pierce = pierce
		body := gd.get_node(b, "Body")
		if body != nil {gd.polygon2d_set_color(cast(gd.Polygon2d)body, self.color)}
	}
}

// ---------- Orbit ----------
@(private = "file")
weapon_build_blades :: proc(self: ^Weapon) {
	n := self.count
	if n < 1 {n = 1}
	if n > MAX_BLADES {n = MAX_BLADES}
	self.nblades = n
	for i in 0 ..< n {
		blade := gd.new_polygon2d()
		// A small diamond blade.
		pts := gd.new_packed_vector2_array()
		gd.packed_vector2_array_push_back(&pts, gd.Vector2{0, -7})
		gd.packed_vector2_array_push_back(&pts, gd.Vector2{6, 0})
		gd.packed_vector2_array_push_back(&pts, gd.Vector2{0, 7})
		gd.packed_vector2_array_push_back(&pts, gd.Vector2{-6, 0})
		gd.polygon2d_set_polygon(blade, pts)
		gd.polygon2d_set_color(blade, self.color)
		gd.add_child(self.owner, blade)
		self.blades[i] = cast(gd.Node2d)blade
	}
}

@(private = "file")
weapon_tick_orbit :: proc(self: ^Weapon, delta: f64) {
	self.angle += f32(delta) * 3.0 // rad/s spin
	origin := gd.node2d_get_global_position(self.owner)
	for i in 0 ..< self.nblades {
		blade := self.blades[i]
		if blade == nil {continue}
		a := self.angle + f32(i) * (math.TAU / f32(self.nblades))
		off := gd.Vector2{math.cos(a) * self.range, math.sin(a) * self.range}
		gd.node2d_set_position(blade, off)
		// Damage anything the blade is touching (a short reach around the blade tip).
		bp := gd.Vector2{origin.x + off.x, origin.y + off.y}
		p := weapon_player(self)
		dmg := self.damage
		if p != nil {dmg *= p.damage_mult}
		damage_enemies_in_radius(self.owner, bp, 14, int(dmg * f32(delta) * 6))
	}
}

// ---------- Aura ----------
// weapon_build_aura makes the aura's one visual: a translucent filled circle (Polygon2D)
// sized to `range`, tinted `color`, parented to the weapon (so it rides on the player). It is
// drawn behind the player body and pulses brighter on each strike.
@(private = "file")
weapon_build_aura :: proc(self: ^Weapon) {
	vis := gd.new_polygon2d()
	pts := gd.new_packed_vector2_array()
	for i in 0 ..< AURA_SEGMENTS {
		a := math.TAU * f32(i) / f32(AURA_SEGMENTS)
		gd.packed_vector2_array_push_back(
			&pts,
			gd.Vector2{math.cos(a) * self.range, math.sin(a) * self.range},
		)
	}
	gd.polygon2d_set_polygon(vis, pts)
	c := self.color
	c.a = AURA_ALPHA_BASE
	gd.polygon2d_set_color(vis, c)
	gd.canvas_item_set_z_index(cast(gd.Canvas_Item)vis, -1) // behind the player body
	gd.add_child(self.owner, vis)
	self.aura_vis = vis
}

@(private = "file")
weapon_tick_aura :: proc(self: ^Weapon, delta: f64) {
	// Every tick: fade the pulse flash back toward the resting alpha, so the ring visibly
	// brightens on a hit and eases off over the cooldown.
	if self.pulse > 0 {
		self.pulse -= f32(delta)
		if self.pulse < 0 {self.pulse = 0}
	}
	if self.aura_vis != nil {
		k := f32(0)
		if self.cooldown > 0 {k = self.pulse / self.cooldown}
		c := self.color
		c.a = AURA_ALPHA_BASE + (AURA_ALPHA_PULSE - AURA_ALPHA_BASE) * k
		gd.polygon2d_set_color(self.aura_vis, c)
	}

	self.timer -= f32(delta)
	if self.timer > 0 {return}
	self.timer = self.cooldown
	origin := gd.node2d_get_global_position(self.owner)
	p := weapon_player(self)
	dmg := self.damage
	if p != nil {dmg *= p.damage_mult}
	damage_enemies_in_radius(self.owner, origin, self.range, int(dmg))
	self.pulse = self.cooldown // flash on every pulse
}
