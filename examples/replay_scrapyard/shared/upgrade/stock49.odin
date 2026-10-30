package scrapyard_upgrade

// Generated from data/guns and data/mobs by tools/stock.py.
stock_49 :: proc() -> Catalog_49 {
	c: Catalog_49
	c.guns[0] = {
		name = name_49("bolter"),
		family = 0,
		cooldown = 20,
		damage = 2,
		mechanism = {8, 72, 12, 3},
		speed = 16.0,
		ttl = 40,
		region = {32, 48, 32, 16},
	}
	c.gun_count = max(c.gun_count, 1)
	c.guns[5] = {
		name = name_49("lance"),
		family = 3,
		cooldown = 50,
		damage = 2,
		mechanism = {5, 110, 6, 3},
		speed = 30.0,
		ttl = 12,
		region = {96, 48, 32, 16},
	}
	c.gun_count = max(c.gun_count, 6)
	c.guns[4] = {
		name = name_49("lobber"),
		family = 2,
		cooldown = 45,
		damage = 3,
		mechanism = {3, 120, 4, 3},
		speed = 7.0,
		ttl = 66,
		region = {96, 64, 32, 16},
	}
	c.gun_count = max(c.gun_count, 5)
	c.guns[6] = {
		name = name_49("mender"),
		family = 4,
		cooldown = 42,
		damage = 4,
		mechanism = {6, 100, 8, 3},
		speed = 30.0,
		ttl = 12,
		region = {64, 64, 32, 16},
	}
	c.gun_count = max(c.gun_count, 7)
	c.guns[3] = {
		name = name_49("nailer"),
		family = 1,
		cooldown = 16,
		damage = 2,
		mechanism = {10, 90, 14, 3},
		speed = 22.0,
		ttl = 40,
		region = {96, 48, 32, 16},
	}
	c.gun_count = max(c.gun_count, 4)
	c.guns[1] = {
		name = name_49("riveter"),
		family = 1,
		cooldown = 6,
		damage = 1,
		mechanism = {20, 108, 30, 3},
		speed = 12.0,
		ttl = 45,
		region = {64, 64, 32, 16},
	}
	c.gun_count = max(c.gun_count, 2)
	c.guns[2] = {
		name = name_49("scrapper"),
		family = 0,
		cooldown = 33,
		damage = 4,
		mechanism = {4, 96, 8, 3},
		speed = 14.0,
		ttl = 35,
		region = {0, 64, 32, 16},
	}
	c.gun_count = max(c.gun_count, 3)
	c.mobs[5] = {
		name = name_49("barrel"),
		hp = 4,
		speed = 10.0,
		bite = 0,
		radius = 10.0,
		scale = 1.6,
		prop = true,
		boom_damage = 12,
		boom_radius = 90.0,
		boom_status = 2,
	}
	c.mob_count = max(c.mob_count, 6)
	c.mobs[1] = {
		name = name_49("hulk"),
		hp = 20,
		speed = 52.0,
		bite = 2,
		radius = 26.0,
		scale = 2.0,
		prop = false,
		boom_damage = 0,
		boom_radius = 0,
		boom_status = 0,
	}
	c.mob_count = max(c.mob_count, 2)
	c.mobs[3] = {
		name = name_49("popper"),
		hp = 2,
		speed = 175.0,
		bite = 0,
		radius = 11.0,
		scale = 0.8,
		prop = false,
		boom_damage = 0,
		boom_radius = 0,
		boom_status = 0,
	}
	c.mob_count = max(c.mob_count, 4)
	c.mobs[0] = {
		name = name_49("scrapbot"),
		hp = 3,
		speed = 125.0,
		bite = 1,
		radius = 14.0,
		scale = 1.0,
		prop = false,
		boom_damage = 0,
		boom_radius = 0,
		boom_status = 0,
	}
	c.mob_count = max(c.mob_count, 1)
	c.mobs[2] = {
		name = name_49("spitter"),
		hp = 4,
		speed = 95.0,
		bite = 0,
		radius = 15.0,
		scale = 1.15,
		prop = false,
		boom_damage = 0,
		boom_radius = 0,
		boom_status = 0,
	}
	c.mob_count = max(c.mob_count, 3)
	c.mobs[4] = {
		name = name_49("titan"),
		hp = 600,
		speed = 40.0,
		bite = 3,
		radius = 40.0,
		scale = 3.5,
		prop = false,
		boom_damage = 0,
		boom_radius = 0,
		boom_status = 0,
	}
	c.mob_count = max(c.mob_count, 5)
	c.statuses[2] = {
		name = name_49("burn"),
		duration = 240,
		max_stacks = 1,
		move_mult = 1.0,
		dot_damage = 1,
		dot_every = 30,
		taken_mult = 1.0,
		dealt_mult = 1.0,
		tint = {1.0, 0.55, 0.25, 0.6},
	}
	c.status_count = max(c.status_count, 3)
	c.statuses[3] = {
		name = name_49("chill"),
		duration = 240,
		max_stacks = 1,
		move_mult = 0.55,
		dot_damage = 0,
		dot_every = 0,
		taken_mult = 1.0,
		dealt_mult = 1.0,
		tint = {0.5, 0.75, 1.0, 0.55},
	}
	c.status_count = max(c.status_count, 4)
	c.statuses[7] = {
		name = name_49("frozen"),
		duration = 180,
		max_stacks = 1,
		move_mult = 0.0,
		dot_damage = 0,
		dot_every = 0,
		taken_mult = 1.25,
		dealt_mult = 1.0,
		tint = {0.8, 0.93, 1.0, 0.7},
	}
	c.status_count = max(c.status_count, 8)
	c.statuses[4] = {
		name = name_49("rally"),
		duration = 480,
		max_stacks = 1,
		move_mult = 1.0,
		dot_damage = 0,
		dot_every = 0,
		taken_mult = 1.0,
		dealt_mult = 1.5,
		tint = {1.0, 0.85, 0.3, 0.5},
	}
	c.status_count = max(c.status_count, 5)
	c.statuses[5] = {
		name = name_49("salve"),
		duration = 120,
		max_stacks = 1,
		move_mult = 1.0,
		dot_damage = -1,
		dot_every = 30,
		taken_mult = 1.0,
		dealt_mult = 1.0,
		tint = {0.5, 1.0, 0.6, 0.5},
	}
	c.status_count = max(c.status_count, 6)
	c.statuses[6] = {
		name = name_49("shock"),
		duration = 240,
		max_stacks = 3,
		move_mult = 1.0,
		dot_damage = 1,
		dot_every = 30,
		taken_mult = 1.0,
		dealt_mult = 1.0,
		tint = {0.75, 0.85, 1.0, 0.6},
	}
	c.status_count = max(c.status_count, 7)
	c.statuses[1] = {
		name = name_49("slimed"),
		duration = 360,
		max_stacks = 1,
		move_mult = 0.55,
		dot_damage = 0,
		dot_every = 0,
		taken_mult = 1.0,
		dealt_mult = 1.0,
		tint = {0.45, 0.9, 0.5, 0.55},
	}
	c.status_count = max(c.status_count, 2)
	c.statuses[8] = {
		name = name_49("surge"),
		duration = 600,
		max_stacks = 1,
		move_mult = 1.3,
		dot_damage = -1,
		dot_every = 45,
		taken_mult = 1.0,
		dealt_mult = 1.5,
		tint = {1.0, 0.95, 0.55, 0.55},
	}
	c.status_count = max(c.status_count, 9)
	c.combos[0] = {
		present = 1,
		incoming = 2,
		reaction = .Detonate,
		damage = 16,
		radius = 90.0,
		output = 0,
		consume = true,
	}
	c.combo_count = 1
	c.combos[1] = {
		present = 1,
		incoming = 3,
		reaction = .Transmute,
		damage = 0,
		radius = 0.0,
		output = 7,
		consume = true,
	}
	c.combo_count = 2
	c.combos[2] = {
		present = 7,
		incoming = 2,
		reaction = .Detonate,
		damage = 24,
		radius = 110.0,
		output = 0,
		consume = true,
	}
	c.combo_count = 3
	c.combos[3] = {
		present = 2,
		incoming = 3,
		reaction = .Transmute,
		damage = 0,
		radius = 0.0,
		output = 0,
		consume = true,
	}
	c.combo_count = 4
	c.combos[4] = {
		present = 3,
		incoming = 2,
		reaction = .Transmute,
		damage = 0,
		radius = 0.0,
		output = 0,
		consume = true,
	}
	c.combo_count = 5
	c.combos[5] = {
		present = 1,
		incoming = 6,
		reaction = .Spread,
		damage = 0,
		radius = 140.0,
		output = 0,
		consume = true,
	}
	c.combo_count = 6
	c.combos[6] = {
		present = 4,
		incoming = 5,
		reaction = .Transmute,
		damage = 0,
		radius = 0.0,
		output = 8,
		consume = true,
	}
	c.combo_count = 7
	c.combos[7] = {
		present = 5,
		incoming = 4,
		reaction = .Transmute,
		damage = 0,
		radius = 0.0,
		output = 8,
		consume = true,
	}
	c.combo_count = 8
	c.abilities[4] = {
		name = name_49("battlecry"),
		family = .Buff,
		cooldown = 900,
		range = 200,
		radius = 0,
		arc_cos = 0.7,
		speed = 10.0,
		damage = 0,
		status = 4,
		self_buff = true,
		duration = 0,
		pulse = 30,
	}
	c.ability_count = max(c.ability_count, 5)
	c.abilities[3] = {
		name = name_49("frostwave"),
		family = .Nova,
		cooldown = 480,
		range = 0,
		radius = 150,
		arc_cos = 0.7,
		speed = 10.0,
		damage = 0,
		status = 3,
		self_buff = false,
		duration = 0,
		pulse = 30,
	}
	c.ability_count = max(c.ability_count, 4)
	c.abilities[2] = {
		name = name_49("igniter"),
		family = .Cone,
		cooldown = 180,
		range = 150.0,
		radius = 0.0,
		arc_cos = 0.7,
		speed = 10.0,
		damage = 0,
		status = 2,
		self_buff = false,
		duration = 0,
		pulse = 30,
	}
	c.ability_count = max(c.ability_count, 3)
	c.abilities[5] = {
		name = name_49("salvefield"),
		family = .Zone,
		cooldown = 900,
		range = 220,
		radius = 90,
		arc_cos = 0.7,
		speed = 10.0,
		damage = 0,
		status = 5,
		self_buff = false,
		duration = 360,
		pulse = 30,
	}
	c.ability_count = max(c.ability_count, 6)
	c.abilities[1] = {
		name = name_49("slime lob"),
		family = .Lob,
		cooldown = 300,
		range = 320.0,
		radius = 80.0,
		arc_cos = 0.7,
		speed = 14.0,
		damage = 0,
		status = 1,
		self_buff = false,
		duration = 0,
		pulse = 30,
	}
	c.ability_count = max(c.ability_count, 2)
	c.abilities[6] = {
		name = name_49("sparkjar"),
		family = .Lob,
		cooldown = 300,
		range = 240.0,
		radius = 90.0,
		arc_cos = 0.7,
		speed = 14.0,
		damage = 0,
		status = 6,
		self_buff = false,
		duration = 0,
		pulse = 30,
	}
	c.ability_count = max(c.ability_count, 7)
	return c
}
