package kit_nav

// kit/nav — thin adapters over the engine's NavigationServers (toolkit
// phase 5). The engine already owns the hard parts (nav meshes, region
// merging, funnel pathfinding); kit/nav makes the two calls a game actually
// needs ergonomic, in both dimensions:
//
//     knav.pass_never_resims() // the caller's claim about its own lane
//     path := knav.path_2d(self.owner, from, to, context.temp_allocator)
//     goal := knav.next_point(path, &self.path_idx, my_pos, reach = 8)
//
// and the host's brain steps toward `goal` with kit/ai. Positions use the
// toolkit's [3]f32 convention (2D in xy, z zero), so brain code doesn't care
// which adapter fed it.
//
// THE HAZARD, and the reason for that first line: these queries read the
// LIVE NavigationServer, which does not rewind. A resimulating pass replaying
// tick 400 would path it across the mesh as it stands at tick 460 — and
// unlike a mispredicted cast, a bad path STEERS the entity, so the divergence
// compounds every tick instead of snapping back. So the query is
// default-denied and the lane must claim itself in code (see below).
//
// The live consumer is examples/cavecrawl: the cave dwellers path around the
// rift in cave_dweller_walk (host.odin), inside the game's one authority pass.
//
// NOTE: regions sync into the map on the server's physics cadence — a path
// queried the frame a region enters the tree is empty. Brains that re-query
// every think-tick (the normal pattern) shrug this off.

import gd "godot:godot"

// ---------------------------------------------------------------------------
// The lane claim.

// How many enclosing scopes have claimed a never-resimulating lane. Main
// thread only — so is the NavigationServer, so no mutex, unlike kit/net's
// subset views.
@(private)
g_never_resims: int

// "The pass I am running in never resimulates." The caller is the only code
// that knows its own lane, so the caller says it — and says it in CODE, which
// a later refactor cannot quietly falsify the way it can falsify a comment.
// The claim covers the rest of the enclosing scope and closes itself.
//
// Exactly two lanes may say it: a coop/delta game's host-side tick (the host
// never resims — examples/cavecrawl's `@(gd_step = "authority")` brain tick is
// the worked example) and, in a kit/sim game, the same `@(gd_step =
// "authority")` world pass (the authority never resims there either). A
// `@(gd_tick)` body, a bare `@(gd_step)`, and anything on the frame clock may
// NOT: the first two replay, and the third is not the sim's timeline at all.
//
// Path FOLLOWING (next_point + kit/ai steps) is pure math over a stored
// polyline and needs no claim — it is sim-safe anywhere. Only the QUERY is
// gated.
@(deferred_none = pass_done)
pass_never_resims :: proc() {
	g_never_resims += 1
}

@(private)
pass_done :: proc() {
	g_never_resims -= 1
}

// The gate every query runs first. An assert and not a silent empty path on
// purpose: an empty path is a legitimate answer ("unreachable, or the map
// hasn't synced"), and a brain that treats them the same would swallow the one
// bug this module exists to prevent.
@(private)
lane_check :: proc() {
	assert(
		g_never_resims > 0,
		"kit/nav: path query outside a pass_never_resims() scope — the NavigationServer is live state that does not rewind, so a resimulating pass would steer YESTERDAY's ticks across TODAY's mesh. Claim the lane at the query site (see docs/kit/nav.md), or move the query to a pass that can honestly claim it",
	)
}

// ---------------------------------------------------------------------------
// The maps.

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

// ---------------------------------------------------------------------------
// The queries. Each has a node form (one agent, one call) and a map form (a
// LOOP of agents against one map).

// An optimized path across the node's default 2D map ([] when unreachable
// or the map hasn't synced yet). The caller owns the slice.
path_2d :: proc(node: gd.Node, from, to: [3]f32, allocator := context.allocator) -> [][3]f32 {
	return path_2d_on(map_2d(node), from, to, allocator)
}

// An optimized path across the node's default 3D map. The caller owns it.
path_3d :: proc(node: gd.Node, from, to: [3]f32, allocator := context.allocator) -> [][3]f32 {
	return path_3d_on(map_3d(node), from, to, allocator)
}

// A path across an ALREADY-RESOLVED map. `path_2d` re-walks node -> viewport
// -> world -> map on every call; that is three engine round trips per query,
// which is free for one agent and pure waste for a brain tick that paths a
// whole WAVE of them against the same map (cavecrawl's first real use, which
// is why this form exists). Resolve `map_2d` once outside the loop, call this
// inside it.
path_2d_on :: proc(nav_map: gd.Rid, from, to: [3]f32, allocator := context.allocator) -> [][3]f32 {
	lane_check()
	server := gd.singleton_navigation_server2d()
	pts := gd.navigation_server2d_map_get_path(server, nav_map, {from.x, from.y}, {to.x, to.y}, true, 1)
	n := int(gd.packed_vector2_array_size(&pts))
	out := make([][3]f32, n, allocator)
	for i in 0 ..< n {
		p := gd.packed_vector2_array_get(&pts, gd.Int(i))
		out[i] = {p.x, p.y, 0}
	}
	return out
}

// The 3D twin of path_2d_on — same reason, same shape.
path_3d_on :: proc(nav_map: gd.Rid, from, to: [3]f32, allocator := context.allocator) -> [][3]f32 {
	lane_check()
	server := gd.singleton_navigation_server3d()
	pts := gd.navigation_server3d_map_get_path(server, nav_map, {from.x, from.y, from.z}, {to.x, to.y, to.z}, true, 1)
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
