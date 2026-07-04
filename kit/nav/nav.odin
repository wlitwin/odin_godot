package kit_nav

// kit/nav — thin adapters over the engine's NavigationServers (toolkit
// phase 5). The engine already owns the hard parts (nav meshes, region
// merging, funnel pathfinding); kit/nav makes the two calls a game actually
// needs ergonomic, in both dimensions:
//
//     path := knav.path_2d(self.owner, from, to, context.temp_allocator)
//     goal := knav.next_point(path, my_pos, reach = 8)
//
// and the host's brain steps toward `goal` with kit/ai. Positions use the
// toolkit's [3]f32 convention (2D in xy, z zero), so brain code doesn't care
// which adapter fed it.
//
// NOTE: regions sync into the map on the server's physics cadence — a path
// queried the frame a region enters the tree is empty. Brains that re-query
// every think-tick (the normal pattern) shrug this off.

import gd "godot:godot"

// The default 2D navigation map of the world `node` lives in.
map_2d :: proc(node: gd.Node) -> gd.Rid {
	vp := gd.node_get_viewport(node)
	world := gd.viewport_find_world_2d(vp)
	return gd.world2d_get_navigation_map(world)
}

// The default 3D navigation map of the world `node` lives in.
map_3d :: proc(node: gd.Node) -> gd.Rid {
	vp := gd.node_get_viewport(node)
	world := gd.viewport_find_world_3d(vp)
	return gd.world3d_get_navigation_map(world)
}

// An optimized path across the node's default 2D map ([] when unreachable
// or the map hasn't synced yet). The caller owns the slice.
path_2d :: proc(node: gd.Node, from, to: [3]f32, allocator := context.allocator) -> [][3]f32 {
	server := gd.singleton_navigation_server2d()
	pts := gd.navigation_server2d_map_get_path(server, map_2d(node), {from.x, from.y}, {to.x, to.y}, true, 1)
	n := int(gd.packed_vector2_array_size(&pts))
	out := make([][3]f32, n, allocator)
	for i in 0 ..< n {
		p := gd.packed_vector2_array_get(&pts, gd.Int(i))
		out[i] = {p.x, p.y, 0}
	}
	return out
}

// An optimized path across the node's default 3D map. The caller owns it.
path_3d :: proc(node: gd.Node, from, to: [3]f32, allocator := context.allocator) -> [][3]f32 {
	server := gd.singleton_navigation_server3d()
	pts := gd.navigation_server3d_map_get_path(server, map_3d(node), {from.x, from.y, from.z}, {to.x, to.y, to.z}, true, 1)
	n := int(gd.packed_vector3_array_size(&pts))
	out := make([][3]f32, n, allocator)
	for i in 0 ..< n {
		p := gd.packed_vector3_array_get(&pts, gd.Int(i))
		out[i] = {p.x, p.y, p.z}
	}
	return out
}

// The waypoint to walk toward RIGHT NOW. `idx` is the follower's cursor
// (start it at 0 per fresh path): waypoints within `reach` are consumed and
// never re-targeted — a stateless nearest-scan would walk you backwards to
// points you already passed. ok=false = the path is done (or empty).
next_point :: proc "contextless" (path: [][3]f32, idx: ^int, pos: [3]f32, reach: f32) -> (goal: [3]f32, ok: bool) {
	for idx^ < len(path) {
		d := path[idx^] - pos
		if d.x * d.x + d.y * d.y + d.z * d.z > reach * reach {
			return path[idx^], true
		}
		idx^ += 1
	}
	return {}, false
}
