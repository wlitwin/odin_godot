package scrap_presentation

import game "../game"
import r "godot:replay"
import content "../content"
import p "godot:replay/play"

Hud_Status :: struct {
	color: [4]f32,
	fill: f32,
}

Hud_View :: struct {
	inside, personal, clear, revive, boss: bool,
	mounted, turret_near, turret_busy: bool,
	hp, maximum: u8,
	pips: [3]f32,
	statuses: [4]Hud_Status,
	status_count: u8,
	gun_name: content.Name,
	ammo, mag: u16,
	mode: p.Gun_Mode,
	revive_percent: u8,
	boss_hp, boss_maximum: u16,
}

hud :: proc(world: game.World, player: game.Player, tick: u64, seat: u16, inside: bool) -> Hud_View {
	result := Hud_View {
		inside = inside,
		personal = seat > 0 && player.in_yard,
		clear = world.stage == .Clear,
		hp = player.hp,
		maximum = game.max_health(player.parts),
		gun_name = world.catalog.guns[player.gun_id].name,
		ammo = player.gun.ammo,
		mag = world.catalog.guns[player.gun_id].mechanism.mag,
		mode = player.gun.mode,
		revive_percent = u8(u32(player.revive.elapsed) * 100 / u32(game.REVIVE_TICKS)),
	}
	world := world
	if handle, mounted := game.turret_for(&world, seat); mounted {
		t, _ := r.pool_get(&world.turrets, handle)
		result.mounted = true
		result.gun_name = content.name("Shared turret")
		result.ammo = t.ammo
		result.mag = world.catalog.abilities[t.ability].turret.ammo
		result.mode = .Ready
	} else if handle, near := game.turret_nearest(&world, seat); near {
		t, _ := r.pool_get(&world.turrets, handle)
		result.turret_near = true
		result.turret_busy = t.operator.seat != 0
	}
	player := player
	for slot in 0 ..< 2 {
		id := game.ability_id(&player, slot)
		duration := world.catalog.abilities[id].cooldown
		result.pips[slot] = duration > 0 ? 1 - clamp(f32(player.ability_cd[slot].remaining) / f32(duration), 0, 1) : 1
	}
	left := player.dash_ready > tick ? player.dash_ready - tick : 0
	result.pips[2] = 1 - clamp(f32(left) / f32(game.DASH_COOLDOWN), 0, 1)
	for effect in player.fx {
		if effect.kind != 0 {
			row := world.catalog.statuses[effect.kind]
			result.statuses[result.status_count] = {
				{row.tint[0], row.tint[1], row.tint[2], .95},
				row.duration > 0 ? clamp(f32(effect.left) / f32(row.duration), 0, 1) : 0,
			}
			result.status_count += 1
		}
	}
	if result.personal && player.hp > 0 && !result.mounted {
		for other, i in world.players {
			if u16(i + 1) == seat || !other.connected || !other.in_yard || other.hp > 0 {
				continue
			}
			delta := other.position - player.position
			if delta[0] * delta[0] + delta[1] * delta[1] <= 56 * 56 {
				result.revive = true
				break
			}
		}
	}
	for mob, i in world.mobs.values {
		if world.mobs.alive[i] && mob.kind == 4 && mob.hp > 0 {
			result.boss, result.boss_hp, result.boss_maximum = true, mob.hp, mob.max_hp
			break
		}
	}
	return result
}
