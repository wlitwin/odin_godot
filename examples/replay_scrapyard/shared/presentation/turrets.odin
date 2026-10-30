package scrap_presentation

import r "godot:replay"
import v "godot:replay/view"
import game "../game"

Turret_View :: struct {
	aim: [2]f32,
	ammo, capacity: u16,
	operator: u16,
	last_shot, tick: u64,
}

Turret_Batch :: struct {
	items: [game.MAX_TURRETS]v.View_Item(game.Turret, Turret_View),
	count: int,
}

turrets :: proc(world: game.World) -> Turret_Batch {
	result: Turret_Batch
	for alive, i in world.turrets.alive {
		if alive {
			t := world.turrets.values[i]
			result.items[result.count] = {
				handle = r.Handle(game.Turret){u32(i), world.turrets.generations[i]},
				tick = world.clock,
				source = .Predicted,
				view = {
					pose = {position = t.position},
					scale = {1, 1},
					color = {1, 1, 1, 1},
					value = {
						t.aim,
						t.ammo,
						world.catalog.abilities[t.ability].turret.ammo,
						t.operator.seat,
						t.last_shot,
						world.clock,
					},
				},
			}
			result.count += 1
		}
	}
	return result
}
