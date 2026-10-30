package replay_scrapyard

import rgd "godot:replay/godot"

import "core:math"
import gd "godot:godot"
import flow "../shared/flow"

Glob_Rig :: struct {
	node: gd.Mesh_Instance2d,
	pulse: flow.Glob_Pulse,
}

glob_make :: proc(self: ^ReplayScrapyard, rig: ^Glob_Rig, name: string, radius: f32) {
	rig.node = gd.new_mesh_instance2d()
	scenery_name(rig.node, name)
	gd.add_child(self.world_node, rig.node)
	points := gd.new_packed_vector2_array()
	for i in 0 ..< 10 {
		angle := f32(i) / 10 * math.TAU
		gd.packed_vector2_array_append(&points, {math.cos(angle) * radius, math.sin(angle) * radius})
	}
	rgd.mesh2_polygon(rig.node, points)
	gd.free_packed_vector2_array(points)
	gd.canvas_item_set_z_index(rig.node, 6)
	gd.canvas_item_set_visible(rig.node, false)
}

glob_hide :: proc(rig: ^Glob_Rig) {
	gd.canvas_item_set_visible(rig.node, false)
	rig.pulse = {}
}

glob_paint :: proc(
	rig: ^Glob_Rig,
	position: [2]f32,
	color: gd.Color,
	epoch, tick, source: u64,
	generation, serial: u32,
	dt: f64,
) {
	scale := flow.glob_pulse(&rig.pulse, epoch, tick, source, generation, serial, f32(dt))
	gd.node2d_set_position(rig.node, position)
	gd.node2d_set_scale(rig.node, {scale, scale})
	gd.node2d_set_rotation(rig.node, 0)
	gd.canvas_item_set_self_modulate(rig.node, color)
	gd.canvas_item_set_visible(rig.node, true)
}
