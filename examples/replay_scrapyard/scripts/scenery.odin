package replay_scrapyard

import rgd "godot:replay/godot"

import "core:math"
import gd "godot:godot"
import arena "../shared/arena"
import game "../shared/game"

// Original scripts/arena.odin and fx/gate_arrow.tscn presentation, derived from
// the floor key and confirmed stage. These nodes never enter a checkpoint.
Gate_Art :: struct {
	root: gd.Node2d,
	boom: gd.Sprite2d,
	pad: gd.Color_Rect,
	arrow: gd.Mesh_Instance2d,
	throb: f32,
}

scenery_name :: proc(node: gd.Node, text: string) {
	name := gd.new_string_name(text)
	gd.node_set_name(node, name)
	gd.free_string_name(name)
}

scenery_prop :: proc(parent: gd.Node, texture: gd.Texture2d, region: gd.Rect2, position: [2]f32) -> gd.Sprite2d {
	node := gd.new_sprite2d()
	gd.sprite2d_set_texture(node, texture)
	gd.sprite2d_set_region_enabled(node, true)
	gd.sprite2d_set_region_rect(node, region)
	gd.node2d_set_position(node, position)
	gd.node2d_set_scale(node, {2, 2})
	gd.add_child(parent, node)
	return node
}

scenery_dressing :: proc(self: ^ReplayScrapyard, key: u32) {
	dirt := gd.new_node2d()
	scenery_name(dirt, "Dirt")
	gd.add_child(self.arena_node, dirt)
	rng := key ~ 0xDEAD
	for _ in 0 ..< 24 {
		x := f32(arena.splitmix32(&rng) % u32(arena.WIDTH - 90))
		y := f32(arena.splitmix32(&rng) % u32(arena.HEIGHT - 90))
		width := f32(30 + arena.splitmix32(&rng) % 60)
		rect(dirt, {x, y}, {width, width * 0.6}, {0.19, 0.20, 0.09, 0.5})
	}
	tufts := gd.new_node2d()
	scenery_name(tufts, "Tufts")
	gd.add_child(self.arena_node, tufts)
	regions := [7]gd.Rect2 {
		{{6, 38}, {9, 6}},
		{{37, 36}, {9, 6}},
		{{4, 72}, {6, 5}},
		{{22, 78}, {6, 5}},
		{{53, 74}, {6, 5}},
		{{35, 55}, {6, 5}},
		{{86, 3}, {6, 5}},
	}
	rng = key ~ 0xF007
	for _ in 0 ..< 40 {
		region := regions[arena.splitmix32(&rng) % u32(len(regions))]
		x := f32(30 + arena.splitmix32(&rng) % u32(arena.WIDTH - 60))
		y := f32(30 + arena.splitmix32(&rng) % u32(arena.HEIGHT - 60))
		scenery_prop(tufts, self.textures.floor, region, {x, y})
	}
}

scenery_gate :: proc(self: ^ReplayScrapyard) -> (art: Gate_Art) {
	art.root = gd.new_node2d()
	scenery_name(art.root, "Gate")
	gd.add_child(self.arena_node, art.root)
	gd.node2d_set_position(art.root, game.GATE)
	rect(art.root, {-26, -60}, {40, 120}, {0.20, 0.28, 0.30, 1})
	art.pad = gd.new_color_rect()
	scenery_name(art.pad, "Pad")
	gd.color_rect_set_color(art.pad, {0.28, 0.42, 0.44, 1})
	gd.control_set_position(art.pad, {-20, -52}, false)
	gd.control_set_size(art.pad, {28, 104}, false)
	gd.control_set_mouse_filter(art.pad, .Mouse_Filter_Ignore)
	gd.add_child(art.root, art.pad)
	art.boom = scenery_prop(art.root, self.textures.objects, {{70, 166}, {49, 4}}, {-6, -52})
	scenery_name(art.boom, "Boom")
	gd.sprite2d_set_offset(art.boom, {26, 0})
	gd.node2d_set_rotation(art.boom, gd.Float(math.TAU / 4))
	art.arrow = gd.new_mesh_instance2d()
	scenery_name(art.arrow, "GateArrow")
	gd.add_child(self.arena_node, art.arrow)
	points := gd.new_packed_vector2_array()
	gd.packed_vector2_array_append(&points, {14, 0})
	gd.packed_vector2_array_append(&points, {-7, -8})
	gd.packed_vector2_array_append(&points, {-7, 8})
	rgd.mesh2_polygon(art.arrow, points)
	gd.free_packed_vector2_array(points)
	gd.canvas_item_set_self_modulate(art.arrow, {0.45, 0.95, 0.9, 0.85})
	gd.canvas_item_set_z_index(art.arrow, 30)
	gd.canvas_item_set_visible(art.arrow, false)
	return
}

scenery_gate_paint :: proc(self: ^ReplayScrapyard, world: ^game.World, seat: u16, dt: f64) {
	art := &self.gate
	open := world.rules.enabled && world.stage == .Clear
	gd.canvas_item_set_visible(art.root, world.rules.enabled)
	target := f32(math.TAU / 4) - (open ? 1.25 : 0)
	rotation := f32(gd.node2d_get_rotation(art.boom))
	gd.node2d_set_rotation(art.boom, gd.Float(rotation + (target - rotation) * min(f32(dt) * 6, 1)))
	tint := gd.Color{1, 1, 1, 1}
	if open {
		art.throb += f32(dt) * 4
		pulse := (math.sin(art.throb) + 1) * 0.5
		tint = {0.9 + pulse * 0.5, 1.4 + pulse * 0.5, 1.4 + pulse * 0.5, 1}
	}
	gd.canvas_item_set_modulate(art.pad, tint)
	show := false
	if open && seat > 0 {
		player := &world.players[seat - 1]
		if player.in_yard && player.hp > 0 {
			// Anchor to the same smoothed pose that the camera and runner display.
			position := self.rigs[seat - 1].previous
			delta := game.GATE - position
			distance := math.sqrt(delta[0] * delta[0] + delta[1] * delta[1])
			if distance > 360 {
				show = true
				gd.node2d_set_position(art.arrow, position + delta / distance * 110)
				gd.node2d_set_rotation(art.arrow, gd.Float(math.atan2(delta[1], delta[0])))
			}
		}
	}
	gd.canvas_item_set_visible(art.arrow, show)
}
