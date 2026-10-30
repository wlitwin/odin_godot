package replay_scrapyard


import "core:math"
import "core:fmt"
import gd "godot:godot"
import game "../shared/game"
import p "godot:replay/play"
import content "../shared/content"
import arena "../shared/arena"
import scenegd "godot:replay/godot/scene"

combat_rigs_make :: proc(self: ^ReplayScrapyard) {
	for &line in self.shot_rigs {
		line = gd.new_line2d()
		gd.add_child(self.world_node, line)
		gd.line2d_add_point(line, {0, 0}, -1)
		gd.line2d_add_point(line, {-12, 0}, -1)
		gd.line2d_set_width(line, 2)
		gd.line2d_set_default_color(line, {1, 0.85, 0.4, 1})
		gd.canvas_item_set_z_index(line, 3)
		gd.canvas_item_set_visible(line, false)
	}
	for &shell, i in self.shell_rigs {
		shell = gd.new_mesh_instance2d()
		scenery_name(shell, fmt.tprintf("Grenade%d", i))
		gd.add_child(self.world_node, shell)
		points := gd.new_packed_vector2_array()
		for point in ([6]gd.Vector2{{5, 0}, {2, 4}, {-3, 3}, {-5, 0}, {-3, -3}, {2, -4}}) {
			gd.packed_vector2_array_append(&points, point)
		}
		scenegd.mesh2_polygon(shell, points)
		gd.free_packed_vector2_array(points)
		gd.canvas_item_set_self_modulate(shell, {0.62, 0.64, 0.46, 1})
		gd.canvas_item_set_z_index(shell, 12)
		gd.canvas_item_set_visible(shell, false)
	}
	for &line in self.flash_rigs {
		line = gd.new_line2d()
		gd.add_child(self.world_node, line)
		gd.line2d_set_width(line, 2)
		gd.canvas_item_set_z_index(line, 4)
		gd.canvas_item_set_visible(line, false)
	}
	for &rig, i in self.spit_rigs {
		glob_make(self, &rig, fmt.tprintf("Spit%d", i), 5)
	}
	for &bank, pass in self.lob_rigs {
		for &rig, i in bank {
			glob_make(self, &rig, fmt.tprintf("Lob%d_%d", pass, i), 7)
		}
	}
	for &node, i in self.zone_rigs {
		node = area_disc_make(self, fmt.tprintf("Zone%d", i), 2)
	}
	for &bank, pass in self.disc_rigs {
		for &node, i in bank {
			node = area_disc_make(self, fmt.tprintf("Area%d_%d", pass, i), 8)
		}
	}

}

combat_paint :: proc(self: ^ReplayScrapyard, observed, predicted: game.World, seat: u16, dt: f64) {
	shown := observed
	forecast := predicted
	epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
	combat_bridge_paint(self, observed, dt)
	// Spit is always observed. Its simulation slot keeps an independent pulse
	// even when unrelated predicted ballistic views compact their output slots.
	for &rig, i in self.spit_rigs {
		if !observed.shots.alive[i] || observed.shots.values[i].kind != .Spit {
			glob_hide(&rig)
			continue
		}
		shot := observed.shots.values[i]
		glob_paint(
			&rig,
			shot.position,
			{0.45, 0.9, 0.5, 1},
			epoch,
			observed.clock,
			u64(i + 1),
			observed.shots.generations[i],
			shot.serial,
			dt,
		)
	}
	// Predicted shots for my seat; observed shots for other seats. Slot choices
	// can differ after correction, so pack the view independently of world slots.
	count := 0
	for pass in 0 ..< 2 {
		world := pass == 0 ? &forecast : &shown
		for alive, i in world.shots.alive {
			if alive {
				shot := world.shots.values[i]
				if shot.kind == .Spit ||
				   (seat != 0 && shot.seat == seat) != (pass == 0) ||
				   count >= len(self.shot_rigs) {
					continue
				}
				line := self.shot_rigs[count]
				shell := self.shell_rigs[count]
				count += 1
				gd.canvas_item_set_visible(shell, shot.kind == .Grenade)
				if shot.kind == .Grenade {
					gd.node2d_set_position(shell, shot.position)
				}
				gd.canvas_item_set_visible(line, shot.kind != .Grenade)
				gd.node2d_set_position(line, shot.position)
				gd.node2d_set_rotation(line, gd.Float(math.atan2(shot.velocity[1], shot.velocity[0])))
				gd.line2d_set_width(line, 2)
				gd.line2d_set_default_color(line, {1, 0.85, 0.4, 1})
				gd.line2d_set_point_position(line, 1, shot.kind != .Ballistic ? gd.Vector2{-4, 0} : gd.Vector2{-12, 0})
			}
		}
	}
	for i in count ..< len(self.shot_rigs) {
		gd.canvas_item_set_visible(self.shot_rigs[i], false)
		gd.canvas_item_set_visible(self.shell_rigs[i], false)
	}
	cast_paths_paint(self, &shown, &forecast, seat)
	area_paint(self, &shown, &forecast, seat)
	flash_count := 0
	for pass in 0 ..< 2 {
		world := pass == 0 ? &forecast : &shown
		for alive, i in world.flashes.alive {
			if alive {
				flash := world.flashes.values[i]
				if flash.kind != .Lance && flash.kind != .Mend {
					continue
				}
				local := seat != 0 && flash.seat == seat
				if flash.kind == .Cast && world.catalog.abilities[flash.ability].family != .Cone {
					local = false
				}
				if local != (pass == 0) || flash_count >= len(self.flash_rigs) {
					continue
				}
				line := self.flash_rigs[flash_count]
				flash_count += 1
				gd.canvas_item_set_visible(line, true)
				gd.node2d_set_position(line, flash.origin)
				gd.line2d_clear_points(line)
				gd.line2d_add_point(line, {0, 0}, -1)
				gd.line2d_add_point(line, flash.end - flash.origin, -1)
				color := flash.kind == .Mend ? gd.Color{0.45, 0.95, 0.55, 0.9} : gd.Color{0.75, 0.95, 1, 0.9}
				left := flash.until > world.clock ? flash.until - world.clock : 0
				color.a *= min(f32(left) / 9, 1)
				gd.line2d_set_default_color(line, color)
			}
		}
	}
	for i in flash_count ..< len(self.flash_rigs) {
		gd.canvas_item_set_visible(self.flash_rigs[i], false)
	}

}

// Test driver supplies ordinary controls through Session, including prediction
// and unreliable input delivery. It never changes simulation state directly.
combat_intent :: proc(w: game.World, seat: u16) -> game.Control {
	w := w
	player := w.players[seat - 1]
	input: game.Control
	best := f32(1e30)
	target := -1
	for alive, i in w.mobs.alive {
		if alive && w.mobs.values[i].hp > 0 {
			d := w.mobs.values[i].position - player.position
			distance := d[0] * d[0] + d[1] * d[1]
			if distance < best {
				best, target = distance, i
			}
		}
	}
	if target >= 0 {
		delta := w.mobs.values[target].position - player.position
		input.aim = unit(delta)
		input.fire = true
		input.move = best < 100 * 100 ? -input.aim : best > 180 * 180 ? input.aim : [2]f32{}
		if _, blocked := arena.clip(&w.layout, player.position + input.aim * 24, delta); blocked {
			input.move = bot_path(&w.layout, player.position, w.mobs.values[target].position)
		}
	} else {
		for alive, i in w.drops.alive {
			if alive {
				d := w.drops.values[i].position - player.position
				distance := d[0] * d[0] + d[1] * d[1]
				if distance < best {
					best, input.move = distance, bot_path(&w.layout, player.position, w.drops.values[i].position)
				}
			}
		}
	}
	if input.move[0] != 0 || input.move[1] != 0 {
		wanted := arena.move(&w.layout, player.position, input.move * game.RUNNER_SPEED, 1.0 / f32(game.HZ))
		if abs(wanted[0] - player.position[0]) + abs(wanted[1] - player.position[1]) < 0.5 {
			input.move = {-input.move[1], input.move[0]}
		}
	}
	return input
}

// A coarse input-driver route around solid cover, with a goal inside pickup
// reach. This is runtime test navigation; it does not become world state.
bot_path :: proc(layout: ^arena.Layout, from, target: [2]f32) -> [2]f32 {
	COLS :: 60
	ROWS :: 34
	CELLS :: COLS * ROWS
	if d := target - from; d[0] * d[0] + d[1] * d[1] < 35 * 35 {
		return {}
	}
	start := clamp(int(from[1] / 32), 0, ROWS - 1) * COLS + clamp(int(from[0] / 32), 0, COLS - 1)
	previous: [CELLS]int
	for &value in previous {
		value = -2
	}
	queue: [CELLS]int
	queue[0] = start
	previous[start] = -1
	head, tail, goal := 0, 1, -1
	for head < tail {
		at := queue[head]
		head += 1
		position := [2]f32{f32(at % COLS) * 32 + 16, f32(at / COLS) * 32 + 16}
		d := target - position
		if d[0] * d[0] + d[1] * d[1] < 40 * 40 {
			goal = at
			break
		}
		neighbors := [4]int{at - 1, at + 1, at - COLS, at + COLS}
		for next in neighbors {
			if next < 0 ||
			   next >= CELLS ||
			   previous[next] != -2 ||
			   abs(next % COLS - at % COLS) + abs(next / COLS - at / COLS) != 1 {
				continue
			}
			point := [2]f32{f32(next % COLS) * 32 + 16, f32(next / COLS) * 32 + 16}
			blocked :=
				point[0] < arena.MARGIN ||
				point[0] > arena.WIDTH - arena.MARGIN ||
				point[1] < arena.MARGIN ||
				point[1] > arena.HEIGHT - arena.MARGIN
			for c in layout.covers {
				if point[0] > f32(c.x) - 16 &&
				   point[0] < f32(c.x + u16(c.w)) + 16 &&
				   point[1] > f32(c.y) - 16 &&
				   point[1] < f32(c.y + u16(c.h)) + 16 {
					blocked = true
					break
				}
			}
			if blocked {
				continue
			}
			previous[next] = at
			queue[tail] = next
			tail += 1
		}
	}
	if goal < 0 {
		return unit(target - from)
	}
	if goal == start {
		return unit(target - from)
	}
	for previous[goal] != start {
		goal = previous[goal]
	}
	return unit([2]f32{f32(goal % COLS) * 32 + 16, f32(goal / COLS) * 32 + 16} - from)
}

status_tint :: proc(w: game.World, effects: []p.Effect) -> gd.Color {
	color := gd.Color{1, 1, 1, 1}
	for effect in effects {
		if effect.kind != 0 {
			tint := w.catalog.statuses[effect.kind].tint
			color.r *= 1 + (tint[0] - 1) * tint[3]
			color.g *= 1 + (tint[1] - 1) * tint[3]
			color.b *= 1 + (tint[2] - 1) * tint[3]
		}
	}
	return color
}

abilities_paint :: proc(self: ^ReplayScrapyard, observed, predicted: game.World, seat: u16, dt: f64) {
	shown := observed
	forecast := predicted
	epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
	for pass in 0 ..< 2 {
		world := pass == 0 ? &forecast : &shown
		for &rig, i in self.lob_rigs[pass] {
			lob := world.lobs.values[i]
			if !world.lobs.alive[i] || (seat != 0 && lob.credit.seat == seat) != (pass == 0) {
				glob_hide(&rig)
				continue
			}
			color := gd.Color{0.6, 0.95, 0.3, 1}
			status := world.catalog.abilities[lob.ability].status
			if status != 0 {
				tint := world.catalog.statuses[status].tint
				if tint[3] > 0 {
					color = {tint[0], tint[1], tint[2], 1}
				}
			}
			glob_paint(
				&rig,
				lob.position,
				color,
				epoch,
				world.clock,
				u64(lob.credit.generation) << 32 | u64(lob.credit.seat),
				world.lobs.generations[i],
				lob.serial,
				dt,
			)
		}
	}
	area_zones(self, &shown)
}
