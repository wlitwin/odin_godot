package replay_scrapyard

import rgd "godot:replay/godot"

import "core:math"
import gd "godot:godot"
import game "../shared/game"
import flow "../shared/flow"

area_disc_make :: proc(self: ^ReplayScrapyard, name: string, depth: int) -> gd.Mesh_Instance2d {
	node := gd.new_mesh_instance2d()
	scenery_name(node, name)
	gd.add_child(self.world_node, node)
	points := gd.new_packed_vector2_array()
	for i in 0 ..< 24 {
		angle := f32(i) / 24 * math.TAU
		gd.packed_vector2_array_append(&points, {math.cos(angle), math.sin(angle)})
	}
	rgd.mesh2_polygon(node, points)
	gd.free_packed_vector2_array(points)
	gd.canvas_item_set_z_index(node, gd.Int(depth))
	gd.canvas_item_set_visible(node, false)
	return node
}

area_color :: proc(world: ^game.World, status: u8, fallback: [4]f32) -> [4]f32 {
	if status != 0 {
		tint := world.catalog.statuses[status].tint
		if tint[3] > 0 {
			return {tint[0], tint[1], tint[2], fallback[3]}
		}
	}
	return fallback
}

area_flash :: proc(world: ^game.World, flash: ^game.Flash) -> bool {
	return(
		flash.kind == .Boom ||
		flash.kind == .Reaction ||
		flash.kind == .Cast && world.catalog.abilities[flash.ability].family == .Nova \
	)
}

area_paint :: proc(self: ^ReplayScrapyard, observed, predicted: ^game.World, seat: u16) {
	for pass in 0 ..< 2 {
		world := pass == 0 ? predicted : observed
		for node, i in self.disc_rigs[pass] {
			f := &world.flashes.values[i]
			local := f.kind == .Boom && seat != 0 && f.seat == seat
			if !world.flashes.alive[i] || !area_flash(world, f) || local != (pass == 0) {
				gd.canvas_item_set_visible(node, false)
				continue
			}
			fallback := f.kind == .Cast ? [4]f32{0.65, 0.8, 1, 0.5} : [4]f32{1, 0.72, 0.32, 0.45}
			view := flow.disc_view(world.clock, f.until, f.radius, area_color(world, f.status, fallback))
			gd.canvas_item_set_visible(node, view.visible)
			gd.node2d_set_position(node, f.origin)
			gd.node2d_set_scale(node, {view.scale, view.scale})
			gd.canvas_item_set_self_modulate(node, transmute(gd.Color)view.color)
		}
	}
}

area_zones :: proc(self: ^ReplayScrapyard, world: ^game.World) {
	for node, i in self.zone_rigs {
		gd.canvas_item_set_visible(node, world.zones.alive[i])
		if !world.zones.alive[i] {
			continue
		}
		zone := world.zones.values[i]
		row := world.catalog.abilities[zone.ability]
		gd.node2d_set_position(node, zone.position)
		gd.node2d_set_scale(node, {row.radius, row.radius})
		gd.canvas_item_set_self_modulate(node, transmute(gd.Color)area_color(world, row.status, {1, 0.5, 0.2, 0.22}))
	}
	points: [game.MAX_FLASHES]flow.Buff_Point
	epoch := self.session.authority ? self.session.server.cfg.epoch : self.session.client.cfg.epoch
	count := flow.buff_points(&self.feedback[0].buffs, world, epoch, points[:])
	for point in points[:count] {
		feedback_burst(self, point.id, point.position, {1, 0.9, 0.4, 1})
	}
}
