# kit/nav — pathfinding adapters

`kit/nav` queries Godot’s 2D and 3D navigation maps and returns positions in
Kit’s `[3]f32` format. Use it when an AI character needs a route around scene
obstacles. Godot owns the navigation meshes, region synchronization, and path search.

Path queries read the live NavigationServer, which cannot restore a historical
mesh for replay. Run them from a non-resimulating authority pass: a cooperative
host tick or a simulation-lane `@(gd_step = "authority")` world pass. Do not query
from `@(gd_tick)`, an everywhere `@(gd_step)`, or a frame-clock callback.
A historical tick queried against the current mesh can choose a different route
and change every subsequent movement step.

Before querying, call `pass_never_resims()` in the enclosing scope. Path queries
assert that this declaration is active. The declaration records the caller’s
scheduling requirement; it does not prove that the caller is in the right pass.
The [simulation guide](sim.md) describes the same restriction for engine casts.
Following an already recorded path with `next_point` and movement helpers is pure
math, provided the path and cursor used for replay are also available.

<a id="mental-model"></a>

## Query and follow a path

Declare the query scope, request the path, then select a waypoint:

```odin
knav.pass_never_resims()                                    // scoped, closes itself
path := knav.path_2d(self.owner, from, to, context.temp_allocator)
goal, ok := knav.next_point(path, &self.path_idx, my_pos, reach = 8)
```

When `ok` is true, the host’s AI can move toward `goal` with
[kit/ai](ai.md)’s `step_toward`. Both adapters return `[3]f32`; 2D positions use
xy with z zero.

## API

```odin
// "The pass I am running in never resimulates." Scoped to the enclosing block,
// closes itself. Every query below asserts this was called.
pass_never_resims :: proc()

// The default 2D / 3D navigation map of the world `node` lives in.
map_2d :: proc(node: gd.Node) -> gd.Rid
map_3d :: proc(node: gd.Node) -> gd.Rid

// An optimized path across the node's default map ([] when unreachable or the
// map hasn't synced yet). The caller owns the slice.
path_2d :: proc(node: gd.Node, from, to: [3]f32, allocator := context.allocator) -> [][3]f32
path_3d :: proc(node: gd.Node, from, to: [3]f32, allocator := context.allocator) -> [][3]f32

// Query an already resolved map when several agents share it.
path_2d_on :: proc(nav_map: gd.Rid, from, to: [3]f32, allocator := context.allocator) -> [][3]f32
path_3d_on :: proc(nav_map: gd.Rid, from, to: [3]f32, allocator := context.allocator) -> [][3]f32

// Return the next waypoint. `idx` is the follower's cursor
// (start it at 0 per fresh path): waypoints within `reach` are consumed and
// never re-targeted — a stateless nearest-scan would walk you backwards to
// points you already passed. ok=false = the path is done (or empty).
next_point :: proc "contextless" (path: [][3]f32, idx: ^int, pos: [3]f32, reach: f32) -> (goal: [3]f32, ok: bool)
```

`path_2d` and `path_3d` use the node’s default world map, the map used by a
NavigationRegion2D/3D added without a custom map. Resolving it requires three
engine calls: node → viewport → world → navigation map. For a group of AI
characters on the same map, resolve it once and pass the resulting RID to the
`_on` query procedures.

## Worked example: cavecrawl (`examples/cavecrawl`)

Cavecrawl authors navigation with its floor scenes. In `levels/level_1.tscn`, a
`NavigationRegion2D` contains a floor polygon around a rift. Every peer loads the
scene, but only the host queries its navigation map.

The host’s AI update in `scripts/host.odin` runs in an authority-only pass. It
opens the query scope and resolves the map once for the group:

```odin
@(private = "file")
cave_dwellers_think :: proc(self: ^CaveLobby) {
	knav.pass_never_resims()          // closes itself when this proc returns
	nav_map := knav.map_2d(self.owner) // resolved ONCE for the whole wave
	...
	pos = cave_dweller_walk(self, nav_map, pos, seen.pos)
}
```

A dweller queries a route, selects a waypoint, and advances toward it:

```odin
cave_dweller_walk :: proc(self: ^CaveLobby, nav_map: gd.Rid, from, to: [3]f32) -> [3]f32 {
	path := knav.path_2d_on(nav_map, from, to, context.temp_allocator)
	idx := 0
	if goal, ok := knav.next_point(path, &idx, from, DWELLER_SPEED); ok {
		p, _ := kai.step_toward(from, goal, DWELLER_SPEED)
		return p
	}
	p, _ := kai.step_toward(from, to, DWELLER_SPEED) // empty path: walk the dumb way
	return p
}
```

The example makes three game-specific choices:

- **Query on each AI tick.** It discards the path after the movement step, so
  the cursor starts at 0 and consumes the current snapped position. This avoids
  a separate path-cache invalidation policy when a floor changes or a successor
  resumes the host’s backed-up `Dweller_Brain` state. The cost is one
  `map_get_path` per agent per tick, at 20 Hz, for single-digit waves.
- **Choose a fallback for an empty path.** The destination may be unreachable,
  or the map may not have synchronized after the floor entered the tree.
  Cavecrawl uses straight-line `step_toward` in that case. Another game may
  choose to wait and retry instead.
- **Check that navigation was used.** The host prints `CAVE_NAV_BENT` once when
  a path contains an interior corner. The integration test requires that marker;
  visible movement alone would not establish that the navigation query produced
  a route around the rift.

The path is not replicated. The host streams the dweller’s `x/y` fields through
the normal owner-state path described in [kit/ai](ai.md). Clients display those
positions without running navigation queries.

<a id="gotchas"></a>

## Navigation constraints

- The query-scope check is an assertion. An unsupported query is not converted
  into an empty path, because an empty path is already a valid query result.
- Regions synchronize at the NavigationServer’s physics cadence. A query made
  in the frame that adds a region may return an empty path. Repeated queries can
  wait for synchronization; a one-shot query must handle that initial delay
  (`tests/kitnav` waits 5 frames and retries).
- The caller owns the returned slice. Use `context.temp_allocator` for a path
  discarded during the tick, or free an allocation that you retain.
- Keep a cursor per follower and reset it to 0 for each new path. A stateless
  nearest-waypoint search can select points the follower has already passed.
- Cavecrawl uses `kai.step_away` directly for fleeing. That operation chooses a
  direction, while a path query needs a destination. A later path home can start
  off the mesh: `map_get_path` snaps `from` to a walkable point.
- 2D queries discard input z and return `z = 0`. Keep the `[3]f32` convention
  consistent when sharing AI code between the 2D and 3D adapters.
- Check reachability against the game’s progression rules. Cavecrawl leaves
  ledges north and south of the rift so enemies cannot remain stranded and block
  the floor-cleared condition.
