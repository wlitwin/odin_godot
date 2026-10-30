# kit/nav — pathfinding adapters

Reach for `kit/nav` when a brain needs to walk around walls instead of through them. The
engine already owns the hard parts (nav meshes, region merging, funnel pathfinding);
kit/nav makes the two calls a game actually needs ergonomic, in both dimensions.

**Lane compatibility: never call these queries inside a resimulating pass; the module
enforces it.** These calls query the NavigationServer, which holds live engine state that
does not rewind. Inside `@(gd_tick)` or the everywhere `@(gd_step)`, a resim replay queries
today's mesh for yesterday's ticks and diverges from the prediction it is rebuilding. This is
the same rule as [engine casts](sim.md). A mispredicted cast snaps back, but a bad path
*steers*, so the error compounds every tick.

Every query is default-denied: it asserts that some enclosing scope has called
`pass_never_resims()`, the caller's claim about its own lane. Two scopes may claim it: a coop
host's own tick (the host never resims) and the sim lane's `@(gd_step = "authority")` pass
(the authority never resims). Path *following* from a stored polyline is pure math and
sim-safe anywhere; only the *query* is gated.

## Mental model

Three calls, and the first one is the lane claim:

```odin
knav.pass_never_resims()                                    // scoped, closes itself
path := knav.path_2d(self.owner, from, to, context.temp_allocator)
goal := knav.next_point(path, &self.path_idx, my_pos, reach = 8)
```

and the host's brain steps toward `goal` with [kit/ai](ai.md)'s `step_toward`. Positions use
the toolkit's `[3]f32` convention (2D in xy, z zero), so brain code doesn't care which
adapter fed it.

Unlike the rest of the brain verbs, the path queries **touch the engine**, which is why they
need the claim.

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

// The same, against an ALREADY-RESOLVED map. Use these in a loop over agents.
path_2d_on :: proc(nav_map: gd.Rid, from, to: [3]f32, allocator := context.allocator) -> [][3]f32
path_3d_on :: proc(nav_map: gd.Rid, from, to: [3]f32, allocator := context.allocator) -> [][3]f32

// The waypoint to walk toward RIGHT NOW. `idx` is the follower's cursor
// (start it at 0 per fresh path): waypoints within `reach` are consumed and
// never re-targeted — a stateless nearest-scan would walk you backwards to
// points you already passed. ok=false = the path is done (or empty).
next_point :: proc "contextless" (path: [][3]f32, idx: ^int, pos: [3]f32, reach: f32) -> (goal: [3]f32, ok: bool)
```

`path_2d`/`path_3d` query the node's *default* world map (via `map_2d`/`map_3d`), which is
what a bare NavigationRegion2D/3D in the scene registers into. Use the `_on` forms in a loop
over agents: resolving the default map is three engine round trips (node → viewport → world →
map), free for one agent but pure waste for a brain tick pathing a whole wave against the
same map.

## Worked example: cavecrawl (`examples/cavecrawl`)

Cavecrawl's floors are authored scenes, so the walkable cave is authored too. A
`NavigationRegion2D` sits in `levels/level_1.tscn` beside the chest and den markers, its
polygon a big floor minus a **rift**. Every peer loads that scene locally; only the host ever
queries it.

The host's brain tick (`scripts/host.odin`) is a single `@(gd_step = "authority")` pass, and
that is where the claim goes:

```odin
@(private = "file")
cave_dwellers_think :: proc(self: ^CaveLobby) {
	knav.pass_never_resims()          // closes itself when this proc returns
	nav_map := knav.map_2d(self.owner) // resolved ONCE for the whole wave
	...
	pos = cave_dweller_walk(self, nav_map, pos, seen.pos)
}
```

and one dweller's step is a query, a cursor, and a kit/ai step:

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

Three things about that shape are worth copying:

**The path is re-queried every think tick and thrown away.** No polyline is cached, so the
cursor is always 0 and `next_point`'s first job is to consume the dweller's own snapped
position. Cavecrawl's `Dweller_Brain` map is `gd:"backup"`, so it rides the host-migration
snapshot to the heir that inherits the host seat; a cached path would hand that heir routes
computed against a NavigationServer it never ran. Re-querying also sidesteps invalidation on
a descent, where the whole floor's region is swapped out underneath any dweller still
standing. The cost is one `map_get_path` per agent per tick, at 20 Hz, for single-digit
waves.

**An empty path is not an error and must not be a freeze.** It means unreachable *or*
not-yet-synced: cavecrawl's regions enter the tree with the floor's scenery, a few frames
before the first den opens. Falling back to the straight-line `step_toward` keeps a wave
moving through that gap.

**The fallback is silent, so the game prints a marker.** A navmesh that failed to load would
leave every dweller walking straight and every test still passing. A path with an interior
corner can only have come from the mesh, so the host prints `CAVE_NAV_BENT` once. This is the
integration test's proof that the rift is walked *around* and not through.

Pathfinding never reaches the wire: the dweller's `x/y` are ordinary owner-streamed
replicated fields, exactly as in the [kit/ai](ai.md) NPC model. Clients see a monster that
respects the terrain and run no navigation code at all.

## Gotchas

- **The lane claim is an assert, not a fallback.** An empty path is a legitimate answer, so
  a silent fallback in place of a lane violation would swallow the one bug this module exists
  to prevent.
- **Regions sync into the map on the server's physics cadence**, so a path queried the frame
  a region enters the tree is empty. Brains that re-query every think-tick (the normal
  pattern) shrug this off; one-shot queries must wait a few frames (`tests/kitnav` waits 5
  and retries).
- An empty slice means *unreachable or not-yet-synced*; treat it as "stand still and ask
  again" or "fall back to the dumb line", never as an error.
- The caller owns the returned slice. Pass `context.temp_allocator` for per-tick queries,
  or remember to free.
- `next_point` needs a persistent cursor per follower, reset to 0 per fresh path. Don't
  nearest-scan the path statelessly: consumed waypoints must never be re-targeted, or the
  follower walks backwards.
- **Path *around*, don't flee *around*.** Fleeing has a direction, not a destination, so
  cavecrawl's flee branch stays on `kai.step_away` and never queries. A panicked agent can
  back itself off the mesh; the next path home recovers, because `map_get_path` snaps an
  off-mesh `from` to the nearest walkable point.
- 2D paths come back with `z = 0`; `path_2d` drops the z of its inputs. Keep everything in
  the `[3]f32` convention and the same brain code drives both adapters.
- Nav geometry is a **detour, never a barrier**. Cavecrawl's rift leaves north and south
  ledges open, because a wave stranded on the wrong side would deadlock the floor-cleared
  gate. Authored obstacles interact with game rules that assume reachability.
