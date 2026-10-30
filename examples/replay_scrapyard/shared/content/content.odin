package scrapyard_content

import "core:math"
import "core:unicode/utf8"
import "core:reflect"
import p "godot:replay/play"
import sc "godot:replay/schema"

MAX_GUNS :: 16

MAX_MOBS :: 8

MAX_STATUS :: 16

MAX_COMBOS :: 32

MAX_ABILITIES :: 16

Name :: struct {
	count: u8,
	bytes: [31]u8,
}

Gun :: struct {
	name: Name,
	family: u8,
	cooldown: u16,
	damage: u8,
	mechanism: p.Gun_Def,
	speed: f32,
	ttl: u16,
	region: [4]u16,
}

Pulse_Def :: struct {
	windup, cooldown: u16,
	radius: f32,
	damage: u8,
}

Mob :: struct {
	name: Name,
	hp: u16,
	speed: f32,
	bite: u8,
	radius, scale: f32,
	prop: bool,
	boom_damage: u8,
	boom_radius: f32,
	boom_status: u8,
	pulse: Pulse_Def,
}

Status :: struct {
	name: Name,
	duration: u16,
	max_stacks: u8,
	move_mult: f32,
	dot_damage: i8,
	dot_every: u16,
	taken_mult, dealt_mult: f32,
	tint: [4]f32,
}

Reaction :: enum u8 {
	Detonate,
	Transmute,
	Spread,
}

Combo :: struct {
	present, incoming: u8,
	reaction: Reaction,
	damage: u8,
	radius: f32,
	output: u8,
	consume: bool,
}

Ability_Family :: enum u8 {
	Lob,
	Cone,
	Nova,
	Buff,
	Zone,
	Turret,
}

Turret_Def :: struct {
	ammo, cadence: u16,
	damage: u8,
	speed: f32,
	ttl: u16,
	use_radius: f32,
}

Ability :: struct {
	name: Name,
	family: Ability_Family,
	cooldown: u16,
	range, radius, arc_cos, speed: f32,
	damage, status: u8,
	self_buff: bool,
	duration, pulse: u16,
	turret: Turret_Def,
}

Catalog :: struct {
	gun_count, mob_count, status_count, combo_count, ability_count: u8,
	guns: [MAX_GUNS]Gun,
	mobs: [MAX_MOBS]Mob,
	statuses: [MAX_STATUS]Status,
	combos: [MAX_COMBOS]Combo,
	abilities: [MAX_ABILITIES]Ability,
}

name :: proc(text: string) -> Name {
	result: Name
	result.count = u8(min(len(text), len(result.bytes)))
	for result.count > 0 && !utf8.valid_string(text[:result.count]) {
		result.count -= 1
	}
	copy(result.bytes[:result.count], transmute([]u8)text[:result.count])
	return result
}

name_string :: proc(value: ^Name) -> string {
	return string(value.bytes[:value.count])
}

name_valid :: proc(value: Name) -> bool {
	value := value
	if value.count > u8(len(value.bytes)) || !utf8.valid_string(string(value.bytes[:value.count])) {
		return false
	}
	for b, i in value.bytes {
		if i < int(value.count) {
			if b < 32 || b == 127 {
				return false
			}
		} else if b != 0 {
			return false
		}
	}
	return true
}

finite :: proc(v: f32) -> bool {
	return !math.is_nan(v) && !math.is_inf(v)
}

gun_present :: proc(c: ^Catalog, id: u8) -> bool {
	return id < c.gun_count && id < MAX_GUNS && c.guns[id].name.count > 0
}

mob_present :: proc(c: ^Catalog, id: u8) -> bool {
	return id < c.mob_count && id < MAX_MOBS && c.mobs[id].name.count > 0
}

status_present :: proc(c: ^Catalog, id: u8) -> bool {
	return id > 0 && id < c.status_count && id < MAX_STATUS && c.statuses[id].name.count > 0
}

ability_present :: proc(c: ^Catalog, id: u8) -> bool {
	return id > 0 && id < c.ability_count && id < MAX_ABILITIES && c.abilities[id].name.count > 0
}

cycle_gun :: proc(c: ^Catalog, current: u8, direction: int) -> u8 {
	if c.gun_count == 0 {
		return 0
	}
	assert(direction == -1 || direction == 1)
	for n in 1 ..= int(c.gun_count) {
		id := u8((int(current) + int(c.gun_count) + direction * n) % int(c.gun_count))
		if gun_present(c, id) {
			return id
		}
	}
	return 0
}

cycle_ability :: proc(c: ^Catalog, current: u8, direction: int) -> u8 {
	if c.ability_count < 2 {
		return 0
	}
	assert(direction == -1 || direction == 1)
	for n in 1 ..= int(c.ability_count) {
		id := u8((int(current) + int(c.ability_count) + direction * n) % int(c.ability_count))
		if ability_present(c, id) {
			return id
		}
	}
	return 0
}

next_gun :: proc(c: ^Catalog, current: u8) -> u8 {
	return cycle_gun(c, current, 1)
}

next_ability :: proc(c: ^Catalog, current: u8) -> u8 {
	return cycle_ability(c, current, 1)
}

gun_valid :: proc(g: Gun) -> bool {
	return(
		name_valid(g.name) &&
		g.name.count > 0 &&
		g.family <= 4 &&
		g.cooldown > 0 &&
		g.cooldown <= 240 &&
		p.gun_def_valid(g.mechanism) &&
		finite(g.speed) &&
		g.speed > 0 &&
		g.speed <= 100 &&
		g.ttl > 0 &&
		g.ttl <= 600 &&
		g.region[2] > 0 &&
		g.region[3] > 0 \
	)
}

mob_valid :: proc(m: Mob) -> bool {
	return(
		name_valid(m.name) &&
		m.name.count > 0 &&
		m.hp > 0 &&
		finite(m.speed) &&
		m.speed >= 0 &&
		m.speed <= 1000 &&
		finite(m.radius) &&
		m.radius > 0 &&
		m.radius <= 200 &&
		finite(m.scale) &&
		m.scale > 0 &&
		m.scale <= 20 &&
		finite(m.boom_radius) &&
		m.boom_radius >= 0 &&
		m.boom_radius <= 1000 &&
		pulse_valid(m.pulse) &&
		!(m.prop && m.pulse.windup > 0) \
	)
}

valid :: proc(c: Catalog) -> bool {
	c := c
	if c.gun_count == 0 || c.gun_count > MAX_GUNS || c.mob_count == 0 || c.mob_count > MAX_MOBS {
		return false
	}
	for g in c.guns[:c.gun_count] {
		if g.name.count == 0 {
			if !reflect.equal(g, Gun{}) {
				return false
			}
		} else if !gun_valid(g) {
			return false
		}
	}
	for m in c.mobs[:c.mob_count] {
		if m.name.count == 0 {
			if !reflect.equal(m, Mob{}) {
				return false
			}
		} else if !mob_valid(m) {
			return false
		}
	}
	if !gun_present(&c, c.gun_count - 1) || !mob_present(&c, c.mob_count - 1) {
		return false
	}
	if c.status_count < 2 ||
	   c.status_count > MAX_STATUS ||
	   c.combo_count > MAX_COMBOS ||
	   !reflect.equal(c.statuses[0], Status{}) {
		return false
	}
	for i in 1 ..< int(c.status_count) {
		row := c.statuses[i]
		if row.name.count == 0 {
			if !reflect.equal(row, Status{}) {
				return false
			}
		} else if !status_valid(row) {
			return false
		}
	}
	if !status_present(&c, c.status_count - 1) {
		return false
	}
	for row in c.combos[:c.combo_count] {
		if !status_present(&c, row.present) ||
		   !status_present(&c, row.incoming) ||
		   (row.output != 0 && !status_present(&c, row.output)) ||
		   row.reaction > .Spread ||
		   !finite(row.radius) ||
		   row.radius < 0 ||
		   row.radius > 1000 {
			return false
		}
	}
	if c.ability_count < 2 || c.ability_count > MAX_ABILITIES || !reflect.equal(c.abilities[0], Ability{}) {
		return false
	}
	for i in 1 ..< int(c.ability_count) {
		row := c.abilities[i]
		if row.name.count == 0 {
			if !reflect.equal(row, Ability{}) {
				return false
			}
		} else if !ability_valid(row, c.status_count) || row.status != 0 && !status_present(&c, row.status) {
			return false
		}
	}
	if !ability_present(&c, c.ability_count - 1) {
		return false
	}
	for row in c.mobs[:c.mob_count] {
		if row.boom_status != 0 && !status_present(&c, row.boom_status) {
			return false
		}
	}
	return true
}

ability_valid :: proc(a: Ability, status_count: u8) -> bool {
	if !name_valid(a.name) ||
	   a.name.count == 0 ||
	   a.family > .Turret ||
	   a.cooldown == 0 ||
	   a.cooldown > 3600 ||
	   a.status >= status_count ||
	   !finite(a.range) ||
	   a.range < 0 ||
	   a.range > 1000 ||
	   !finite(a.radius) ||
	   a.radius < 0 ||
	   a.radius > 1000 ||
	   !finite(a.arc_cos) ||
	   a.arc_cos < -1 ||
	   a.arc_cos > 1 ||
	   !finite(a.speed) ||
	   a.speed < 1 ||
	   a.speed > 100 ||
	   a.duration > 36000 ||
	   a.pulse == 0 ||
	   a.pulse > 600 {
		return false
	}
	return(
		(a.family != .Zone || a.duration > 0) &&
		(a.family == .Turret ? turret_valid(a.turret) : a.turret == (Turret_Def{})) \
	)
}

status_valid :: proc(s: Status) -> bool {
	if !name_valid(s.name) ||
	   s.name.count == 0 ||
	   s.duration == 0 ||
	   s.duration > 36000 ||
	   s.max_stacks == 0 ||
	   s.max_stacks > 9 ||
	   s.dot_damage < -20 ||
	   s.dot_damage > 20 ||
	   s.dot_every > 600 {
		return false
	}
	for value in ([3]f32{s.move_mult, s.taken_mult, s.dealt_mult}) {
		if !finite(value) || value < 0 || value > 4 {
			return false
		}
	}
	for value in s.tint {
		if !finite(value) || value < 0 || value > 4 {
			return false
		}
	}
	return s.tint[3] <= 1
}

combo_find :: proc(c: ^Catalog, present, incoming: u8) -> (Combo, bool) {
	for row in c.combos[:c.combo_count] {
		if row.present == present && row.incoming == incoming {
			return row, true
		}
	}
	return {}, false
}

fingerprint :: proc(c: Catalog) -> u64 {
	codec: sc.Schema
	defer sc.destroy(&codec)
	if sc.init(&codec, Catalog).error != .None {
		return 0
	}
	bytes := make([]u8, codec.wire_size)
	defer delete(bytes)
	if sc.encode(&codec, c, bytes).error != .None {
		return 0
	}
	return sc.digest(bytes)
}

// Zero is an explicit disabled component for existing enemies and old archives.
pulse_valid :: proc(p: Pulse_Def) -> bool {
	if p.windup == 0 {
		return p == (Pulse_Def{})
	}
	return(
		p.windup <= 180 &&
		p.cooldown >= 30 &&
		p.cooldown <= 3600 &&
		finite(p.radius) &&
		p.radius >= 32 &&
		p.radius <= 400 &&
		p.damage > 0 &&
		p.damage <= 20 \
	)
}

turret_valid :: proc(d: Turret_Def) -> bool {
	return(
		d.ammo > 0 &&
		d.ammo <= 1000 &&
		d.cadence > 0 &&
		d.cadence <= 120 &&
		d.damage > 0 &&
		d.damage <= 100 &&
		finite(d.speed) &&
		d.speed > 0 &&
		d.speed <= 100 &&
		d.ttl > 0 &&
		d.ttl <= 600 &&
		finite(d.use_radius) &&
		d.use_radius >= 24 &&
		d.use_radius <= 96 \
	)
}
