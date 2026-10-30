package scrap_presentation

import game "../game"

Weapon_View :: struct {
	aim: [2]f32,
	region: [4]u16,
	visible: bool,
	generation: u32,
	epoch: u64,
}

Runner_View :: struct {
	position: [2]f32,
	tint: [4]f32,
	name: game.Name,
	generation, warp: u32,
	epoch: u64,
	seat: u16,
	look: u8,
	visible, alive, reloading: bool,
	revive_percent: u8,
	weapon: Weapon_View,
}

runner :: proc(world: game.World, player: game.Player, position: [2]f32, epoch: u64, seat: u16) -> Runner_View {
	value := Runner_View {
		position = position,
		tint = {1, 1, 1, 1},
		name = player.profile.name,
		generation = player.generation,
		warp = player.warp,
		epoch = epoch,
		seat = seat,
		look = player.profile.look,
		visible = player.in_yard,
		alive = player.hp > 0,
		reloading = player.hp > 0 && player.gun.mode == .Reloading,
		revive_percent = u8(u32(player.revive.elapsed) * 100 / u32(game.REVIVE_TICKS)),
		weapon = {player.aim, world.catalog.guns[player.gun_id].region, player.hp > 0, player.generation, epoch},
	}
	world := world
	if game.turret_operator(&world, seat) {
		value.weapon.visible = false
		value.reloading = false
	}
	if !value.alive {
		value.tint[3] = .45
	} else if !player.connected {
		value.tint = {.55, .6, .7, .45}
	} else {
		for effect in player.fx {
			if effect.kind != 0 {
				row := world.catalog.statuses[effect.kind]
				if row.tint[3] <= 0 {
					continue
				}
				value.tint = {
					1 - (1 - row.tint[0]) * row.tint[3],
					1 - (1 - row.tint[1]) * row.tint[3],
					1 - (1 - row.tint[2]) * row.tint[3],
					1,
				}
			}
		}
	}
	return value
}
