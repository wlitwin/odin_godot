# kit/interact

`kit/interact` helps select nearby chests, doors, or pickups for a use prompt
and check interaction geometry when a command executes. It provides three
procedures and one struct, with no engine types or action dispatch.

The procedures perform pure geometric checks and may run inside a simulation
tick. The example below uses cooperative commands; simulation games can use
the same checks in their commands and authority steps.

<a id="mental-model"></a>

## Target discovery and command validation

Discovery selects the target to offer in the UI. Command validation decides
whether an attempted interaction passes its geometric requirements:

- **Discovery** runs on the client each frame. `pick` selects a nearby target
  from candidates the game collects from its registry.
- **Validation** runs inside the command on the host. Call
  `in_range`/`facing_ok` with the same constants used for discovery.

Using the same procedures and constants keeps the client prompt and authority
validation geometrically consistent. They can still evaluate different
snapshots of a moving world; the authority's result is final.

Implement the action as a command on the target entity, such as opening a door
or looting slot 2. `kit/interact` does not dispatch the command. See
[items.md](items.md) for a loot command that applies these checks.

Positions use `[3]f32`: 2D games leave `z` at zero, while 3D games supply it.
The API uses no engine types.

## API

```odin
Candidate :: struct {
	id:     u32, // knet.Net_Id-sized; kept engine- and package-free
	pos:    [3]f32,
	radius: f32, // per-target extra reach (a chest is easier to touch than a lever)
}

// Check distance against `reach` plus the target's radius. Uses squared
// distance without sqrt; suitable for commands and frame code.
in_range :: proc "contextless" (origin, target: [3]f32, reach: f32, radius: f32 = 0) -> bool

// Check the facing cone. `min_dot` expresses the cone half-angle as a
// dot-product threshold (0 = 180° cone, 0.5 = 120°, 0.7071 = 90°). A zero
// `facing` vector means omnidirectional; standing on the target always passes.
facing_ok :: proc "contextless" (origin, target, facing: [3]f32, min_dot: f32) -> bool

// The nearest candidate within reach and facing — what the prompt points at.
pick :: proc(cands: []Candidate, origin: [3]f32, reach: f32, facing := [3]f32{}, min_dot: f32 = 0) -> (best: Candidate, ok: bool)
```

## Worked example: prompt and gate share the reach constant

Declare one constant (`examples/cavecrawl/scripts/cavecrawl.odin`):

```odin
REACH :: f32(40) // interaction reach in pixels, shared by the prompt and host check
```

Discovery runs every frame in `world.odin`'s `update_prompt`. The game
collects candidates from its entity maps, then selects a target:

```odin
cands := make([dynamic]kinter.Candidate, context.temp_allocator)
for id, c in self.chests {
	append(&cands, kinter.Candidate{id = u32(id), pos = {c.x, c.y, 0}})
}
for id, d in self.doors {
	append(&cands, kinter.Candidate{id = u32(id), pos = {d.x, d.y, 0}})
}
best, ok := kinter.pick(cands[:], {me.x, me.y, 0}, REACH)
```

When `ok` is true, the game displays [kit/ui](ui.md) prompt text such as
"E — loot chest" or "E — open door" and retains `best.id` as the interaction
target.

The predicted command in `door.odin` uses the same geometry and constant. Both
the predicting client and the host execute the check:

```odin
@(gd_command = knet.ACTION_ANY_SEAT_PREDICTED)
door_toggle :: proc(self: ^Door, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	self.open = !self.open
	return true
}
```

The command carries the issuer's claimed position `(px, py)` as arguments;
`chest_take` and `pickup_grab` use the same check. This validates distance from
the supplied position; the geometry helper does not establish that the
position is trustworthy. In `host.odin`, the host also uses
`kinter.in_range` with `REACH` to check that the whole party is at an open door.

<a id="gotchas"></a>

## Validation limits and target selection

- **Share the reach constant.** The prompt and the host gate must use the *same* `REACH`
  and the same `in_range` check, or the UI may offer an interaction the host
  refuses, or hide one it would allow.
- Position samples can represent different times. Choose `REACH` with expected
  movement delay in mind. When accepting client-supplied positions, validate
  them against host state, as [combat](combat.md) does for cast origins.
- `facing = {}` (the default) means omnidirectional; `min_dot = 0` is a 180° cone, not "no
  cone". Standing exactly on the target always passes the facing check.
- `pick` returns the nearest passing candidate. Per-target `radius` extends
  interaction range; selection still measures center-to-center distance.
- Candidate collection is the game's job: walk your own entity maps into a
  `temp_allocator` array each frame, as `update_prompt` does.
