# kit/nav — pathfinding adapters

Reach for `kit/nav` when a brain needs to walk around walls instead of through them. The
engine already owns the hard parts (nav meshes, region merging, funnel pathfinding);
kit/nav makes the two calls a game actually needs ergonomic, in both dimensions.

**Lane compatibility: NEVER inside a resimulating pass.** These calls query the
NavigationServer — live engine state that does not rewind. Inside `@(gd_tick)` or the
everywhere `@(gd_step)` a resim replay would query TODAY's mesh state for YESTERDAY's
ticks and diverge from the prediction it is rebuilding — the same law as
[engine casts](sim.md) but worse, because paths steer entities. Legal homes: coop host
brains (the host never resims) and the sim lane's `@(gd_step="authority")` pass (the
authority never resims). Path FOLLOWING from a stored polyline is pure math and
sim-safe anywhere; it's the *query* that must stay on a never-resimming pass.

## Mental model

Two calls:

```odin
path := knav.path_2d(self.owner, from, to, context.temp_allocator)
goal := knav.next_point(path, &self.path_idx, my_pos, reach = 8)
```

and the host's brain steps toward `goal` with [kit/ai](ai.md)'s `step_toward`. Positions
use the toolkit's `[3]f32` convention (2D in xy, z zero), so brain code doesn't care which
adapter fed it.

Unlike the rest of the brain verbs, the path queries **touch the engine** (they ask Godot's
NavigationServer through a node in the tree) — so they belong in host tick code, not inside
predicted commands.

## API

```odin
// The default 2D navigation map of the world `node` lives in.
map_2d :: proc(node: gd.Node) -> gd.Rid

// The default 3D navigation map of the world `node` lives in.
map_3d :: proc(node: gd.Node) -> gd.Rid

// An optimized path across the node's default 2D map ([] when unreachable
// or the map hasn't synced yet). The caller owns the slice.
path_2d :: proc(node: gd.Node, from, to: [3]f32, allocator := context.allocator) -> [][3]f32

// An optimized path across the node's default 3D map. The caller owns it.
path_3d :: proc(node: gd.Node, from, to: [3]f32, allocator := context.allocator) -> [][3]f32

// The waypoint to walk toward RIGHT NOW. `idx` is the follower's cursor
// (start it at 0 per fresh path): waypoints within `reach` are consumed and
// never re-targeted — a stateless nearest-scan would walk you backwards to
// points you already passed. ok=false = the path is done (or empty).
next_point :: proc "contextless" (path: [][3]f32, idx: ^int, pos: [3]f32, reach: f32) -> (goal: [3]f32, ok: bool)
```

`path_2d`/`path_3d` query the node's *default* world map (via `map_2d`/`map_3d`), which is
what a bare NavigationRegion2D/3D in the scene registers into.

## Worked example: a brain walks a navmesh

From `tests/kitnav/scripts/navtest.odin` — the scene's walkable area is a U, so the path
from arm-tip to arm-tip must bend down and around; then a kit/ai walker follows it with the
`next_point` cursor:

```odin
path := knav.path_2d(self.owner, FROM, TO, context.temp_allocator)

// A brain following it: kit/ai steps + the kit/nav cursor.
pos := FROM
idx := 0
for _ in 0 ..< 500 {
	goal, ok := knav.next_point(path, &idx, pos, 8)
	if !ok {break}
	pos, _ = kai.step_toward(pos, goal, 5)
}
```

In a live game this shape sits inside the host tick: re-query the path on the brain's think
cadence, reset the cursor to 0 with each fresh path, and feed `goal` to `step_toward` every
tick. The NPC's `x/y` writes replicate to clients exactly as in the [kit/ai](ai.md) NPC
model — pathfinding stays a host-only detail.

## Gotchas

- **Regions sync into the map on the server's physics cadence** — a path queried the frame
  a region enters the tree is empty. Brains that re-query every think-tick (the normal
  pattern) shrug this off; one-shot queries must wait a few frames (the test waits 5 and
  retries).
- An empty slice means *unreachable or not-yet-synced* — treat it as "stand still and ask
  again", not an error.
- The caller owns the returned slice. Pass `context.temp_allocator` for per-tick queries,
  or remember to free.
- `next_point` needs a persistent cursor per follower, reset to 0 per fresh path. Don't
  nearest-scan the path statelessly — consumed waypoints must never be re-targeted or the
  follower walks backwards.
- 2D paths come back with `z = 0`; `path_2d` drops the z of its inputs. Keep everything in
  the `[3]f32` convention and the same brain code drives both adapters.
