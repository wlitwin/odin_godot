package scrap_presentation

import r "godot:replay"
import v "godot:replay/view"
import p "godot:replay/play"
import game "../game"

// Derived presentation values only. No nodes, mutable catalog pointer, World
// pointer, or animation timer crosses the boundary into the Godot rig.
Mob_View :: struct {
	position: [2]f32,
	tint: [4]f32,
	scale, growth, telegraph_radius: f32,
	hp: u16,
	kind: u8,
	prop, pulse, near, prey_left, telegraph, charged_attack: bool,
	tick, epoch, source: u64,
}

Mob_Batch :: struct {
	items: [game.MAX_MOBS]v.View_Item(game.Mob, Mob_View),
	count: int,
}

mobs :: proc(world: game.World, epoch: u64) -> Mob_Batch {
	batch: Mob_Batch
	for mob, i in world.mobs.values {
		if !world.mobs.alive[i] {
			continue
		}
		definition := world.catalog.mobs[mob.kind]
		value := Mob_View {
			position = mob.position,
			tint = {1, 1, 1, 1},
			scale = definition.scale,
			hp = mob.hp,
			kind = mob.kind,
			prop = definition.prop,
			telegraph = mob.hp > 0 && mob.tele.left > 0,
			charged_attack = definition.pulse.windup > 0,
			telegraph_radius = definition.pulse.windup > 0 ? definition.pulse.radius : f32(180),
			growth = p.telegraph_fraction(mob.tele),
			tick = world.clock,
			epoch = epoch,
			source = u64(world.mobs.generations[i]) << 32 | u64(i + 1),
		}
		for effect in mob.fx {
			if effect.kind != 0 {
				status := world.catalog.statuses[effect.kind]
				if status.tint[3] <= 0 {
					continue
				}
				value.tint = {status.tint[0], status.tint[1], status.tint[2], 1}
				value.pulse = status.dot_every > 0 && status.dot_damage > 0
			}
		}
		reach := 24 + definition.radius + 6
		for player in world.players {
			if player.connected && player.in_yard && player.hp > 0 {
				delta := player.position - mob.position
				if delta[0] * delta[0] + delta[1] * delta[1] <= reach * reach {
					value.near, value.prey_left = true, player.position[0] < mob.position[0]
					break
				}
			}
		}
		batch.items[batch.count] = {
			handle = r.Handle(game.Mob){u32(i), world.mobs.generations[i]},
			tick = world.clock,
			source = .Observed,
			view = {pose = {position = mob.position}, scale = {1, 1}, color = {1, 1, 1, 1}, value = value},
		}
		batch.count += 1
	}
	return batch
}

Drop_Batch :: struct {
	items: [game.MAX_DROPS]v.View_Item(game.Drop, u8),
	count: int,
}

drops :: proc(world: game.World) -> Drop_Batch {
	batch: Drop_Batch
	for drop, i in world.drops.values {
		if world.drops.alive[i] {
			batch.items[batch.count] = {
				handle = r.Handle(game.Drop){u32(i), world.drops.generations[i]},
				tick = world.clock,
				source = .Observed,
				view = {pose = {position = drop.position}, scale = {1, 1}, color = {1, 1, 1, 1}},
			}
			batch.count += 1
		}
	}
	return batch
}
