# kit/interact — "what can I use right now?"

Reach for `kit/interact` when a player should get a *use* prompt near chests, doors, and
pickups, and the host must validate the use from the same geometry. It is deliberately
thin: three procs and one struct, no engine types, no dispatch.

**Lane compatibility: lane-agnostic math, coop-shaped pattern.** The three procs are pure
geometry — legal anywhere, including inside a sim tick. The prompt-then-validate PATTERN
around them is written for coop verbs; a sim game runs the same geometry inside its own
verbs and the authority pass.

## Mental model

Interaction is two questions:

- **Discovery** (client, every frame): which nearby interactable should the prompt point
  at? → `pick` over candidates the game collects from its registry walk.
- **Gating** (host, inside the command): is this player actually allowed to use that entity
  from where they stand? → the command proc calls `in_range`/`facing_ok` with the *same*
  numbers.

Same procs, same constants, zero role branches — the prompt the client shows and the
validation the host runs cannot disagree about geometry (the host's positions stay the
truth when they differ in time).

The *use* itself is just a command on the target entity (open the door, loot slot 2) —
kit/interact never dispatches anything. See [items.md](items.md) for what a loot command
does once the gate passes.

Positions are dimension-agnostic `[3]f32` everywhere: 2D games leave `z` at zero, 3D games
fill it. No engine type in sight.

## API

```odin
Candidate :: struct {
	id:     u32, // knet.Net_Id-sized; kept engine- and package-free
	pos:    [3]f32,
	radius: f32, // per-target extra reach (a chest is easier to touch than a lever)
}

// Within `reach` of the target (plus the target's own radius)? Squared math,
// no sqrt — call it in commands as freely as in frame code.
in_range :: proc "contextless" (origin, target: [3]f32, reach: f32, radius: f32 = 0) -> bool

// Is the target inside the facing cone? `min_dot` is the cone half-angle as a
// dot-product threshold (0 = 180° cone, 0.5 = 120°, 0.7071 = 90°). A zero
// `facing` vector means omnidirectional; standing ON the target always passes.
facing_ok :: proc "contextless" (origin, target, facing: [3]f32, min_dot: f32) -> bool

// The nearest candidate within reach and facing — what the prompt points at.
pick :: proc(cands: []Candidate, origin: [3]f32, reach: f32, facing := [3]f32{}, min_dot: f32 = 0) -> (best: Candidate, ok: bool)
```

## Worked example: prompt and gate share REACH

One constant, declared once (`examples/cavecrawl/scripts/cavecrawl.odin`):

```odin
REACH :: f32(40) // interaction reach in pixels — prompt AND host gate use it
```

Discovery, every frame (`world.odin`, `update_prompt`) — the game collects candidates from
its own entity maps and picks:

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

`ok` drives the [kit/ui](ui.md) prompt text ("E — loot chest", "E — open door"); `best.id`
is remembered as the interact target.

Gating, inside the predicted command (`door.odin`) — the same math, the same constant, run
identically as the client's prediction and the host's authoritative re-run:

```odin
@(gd_command = "predict")
door_toggle :: proc(self: ^Door, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	self.open = !self.open
	return true
}
```

The command carries the issuer's claimed position `(px, py)` as args; `chest_take` and
`pickup_grab` gate identically. The host even reuses the gate for non-interaction logic —
"is the whole party at the open door?" in `host.odin` is the same `kinter.in_range` call
with the same `REACH`.

## Gotchas

- **Share the reach constant.** The prompt and the host gate must use the *same* `REACH`
  and the same `in_range` math, or the UI will promise uses the host refuses (or hide uses
  it would allow). This is the package's whole reason to exist — don't fork the numbers.
- Positions can still differ *in time* (the issuer's claimed spot vs. the host's replicated
  copy); the host's view is the truth. Keep `REACH` generous enough to absorb a stream of
  lag, or leash claims like [combat](combat.md) does for cast origins.
- `facing = {}` (the default) means omnidirectional; `min_dot = 0` is a 180° cone, not "no
  cone". Standing exactly on the target always passes the facing check.
- `pick` returns the *nearest* passing candidate; per-target `radius` widens the touch,
  not the tiebreak (distance is measured center-to-center).
- Candidate collection is the game's job — walk your own entity maps into a
  `temp_allocator` array each frame, as `update_prompt` does.
