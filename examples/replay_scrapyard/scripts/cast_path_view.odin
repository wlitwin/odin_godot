package replay_scrapyard

import rgd "godot:replay/godot"

import "core:fmt"
import gd "godot:godot"
import game "../shared/game"
import flow "../shared/flow"
import play "godot:replay/play"

Flame_Rig :: struct {
	labels: [5]gd.Label,
	track: flow.Flame_Track,
}

cast_paths_paint :: proc(self: ^ReplayScrapyard, observed, predicted: ^game.World, seat: u16) {
	flame_paths_paint(self, observed, predicted, seat)
	arc_paths_paint(self, observed)
}

flame_paths_paint :: proc(self: ^ReplayScrapyard, observed, predicted: ^game.World, seat: u16) {
	epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
	for pass in 0 ..< 2 {
		world := pass == 0 ? predicted : observed
		for &rig, index in self.flame_rigs[pass] {
			flame_rig_paint(self, &rig, index, world, observed, seat, epoch, pass == 0)
		}
	}
}

// Reconciliation owns each rig's lifetime. Collision and node updates consume
// that result without changing either observed or predicted simulation state.
flame_rig_paint :: proc(
	self: ^ReplayScrapyard,
	rig: ^Flame_Rig,
	index: int,
	world, observed: ^game.World,
	seat: u16,
	epoch: u64,
	predicted_pass: bool,
) {
	f := &world.flashes.values[index]
	local := seat != 0 && f.seat == seat
	active :=
		world.flashes.alive[index] &&
		f.kind == .Cast &&
		world.catalog.abilities[f.ability].family == .Cone &&
		local == (predicted_pass)
	previous_tick, was_active := rig.track.tick, rig.track.seeded
	key := flow.Flame_Key {
		epoch,
		f.until,
		u64(f.generation) << 32 | u64(f.seat),
		world.flashes.generations[index],
		f.serial,
		f.origin,
		f.end,
	}
	reset := flow.flame_reconcile(&rig.track, key, world.clock, active)
	if !active {
		if was_active {
			for label in rig.labels {
				if label != nil {
					gd.canvas_item_set_visible(label, false)
				}
			}
		}
		return
	}
	for &label, tongue in rig.labels {
		if label == nil {
			label = gd.new_label()
			scenery_name(label, fmt.tprintf("Flame%d_%d_%d", int(!predicted_pass), index, tongue))
			gd.add_child(self.world_node, label)
			gd.set_string(label, "text", "*")
			gd.control_set_mouse_filter(label, .Mouse_Filter_Ignore)
		}
		position, valid := flow.flame_position(f.origin, f.end, world.clock, f.until, tongue - 2)
		visible := active && valid && (local || tongue == 2) && !rig.track.stopped[tongue]
		if visible && !reset && world.clock > previous_tick {
			if flame_hits_mob(observed, rig.track.previous[tongue], position) {
				rig.track.stopped[tongue] = true
				visible = false
			}
		}
		gd.canvas_item_set_visible(label, visible)
		if visible {
			half := gd.control_get_combined_minimum_size(label) / 2
			gd.control_set_position(label, position - half, false)
			rig.track.previous[tongue] = position
		}
	}
}

flame_hits_mob :: proc(observed: ^game.World, from, to: [2]f32) -> bool {
	for alive, index in observed.mobs.alive {
		if !alive || observed.mobs.values[index].hp == 0 {
			continue
		}
		mob := &observed.mobs.values[index]
		if _, hit := play.segment_circle(from, to, mob.position, observed.catalog.mobs[mob.kind].radius); hit {
			return true
		}
	}
	return false
}

arc_paths_paint :: proc(self: ^ReplayScrapyard, observed: ^game.World) {
	for &node, i in self.arc_rigs {
		f := &observed.flashes.values[i]
		if !observed.flashes.alive[i] || f.kind != .Arc {
			if node != nil {
				gd.canvas_item_set_visible(node, false)
			}
			continue
		}
		x, y, valid := flow.arc_axes(f.origin, f.end)
		if !valid {
			if node != nil {
				gd.canvas_item_set_visible(node, false)
			}
			continue
		}
		if node == nil {
			node = gd.new_mesh_instance2d()
			scenery_name(node, fmt.tprintf("Arc%d", i))
			gd.add_child(self.world_node, node)
			gd.canvas_item_set_z_index(node, 8)
			polygon, _ := flow.arc_polygon({}, {1, 0})
			points := gd.new_packed_vector2_array()
			for point in polygon {
				gd.packed_vector2_array_append(&points, point)
			}
			rgd.mesh2_polygon(node, points)
			gd.free_packed_vector2_array(points)
		}
		view := flow.disc_view(observed.clock, f.until, 1, area_color(observed, f.status, {0.75, 0.85, 1, 0.8}))
		gd.node2d_set_transform(node, {x * view.scale, y * view.scale, f.origin})
		gd.canvas_item_set_self_modulate(node, transmute(gd.Color)view.color)
		gd.canvas_item_set_visible(node, view.visible)
	}
}
