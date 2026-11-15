# kit/ai — NPC verbs and the wave director

Use `kit/ai` to find targets, steer NPCs, and schedule enemy waves. The game
implements the decisions about when an NPC should chase, flee, or patrol; the
package provides perception, movement, and wave-scheduling helpers.

The examples here use coop replication: the host makes NPC decisions and
streams their positions as the entity owner. On the [sim lane](sim.md), an NPC
instead has `predict` fields, advances in server ticks, and makes decisions in
the authority pass. The pure perception and steering math works in either
model. The wave director also remains authority-side logic. See [nav](nav.md)
for restrictions on live NavigationServer queries during replay.

<a id="mental-model"></a>

## Host decisions and replicated NPC state

The game owns the NPC update loop. `kit/ai` provides no Brain type or behavior
tree. Cavecrawl's dweller uses a `switch` in its host tick to choose behavior
and writes the result to a replicated `state: u8`.

In this coop setup, the host player owns the NPC entity. The host's decision
procedure writes `x/y`, and clients interpolate those owner-streamed positions.
The NPC's state byte and hp use ordinary replication. Cavecrawl declares that
state in `examples/cavecrawl/scripts/dweller.odin`:

```odin
Dweller :: struct {
	owner:  gd.Node2d,
	glyph:  gd.Label `gd:"onready=Glyph"`,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"owner"`, // continuous owner fields interpolate by default
	hp:     i32 `gd:"replicate"`,
	state:  u8 `gd:"replicate"`, // behavior state displayed by every peer
	...
}
```

Clients use `state` to display the NPC's behavior and interpolate its streamed
position. Only the host runs the decision loop, so clients need presentation
code without a separate AI loop or NPC packet format.

The package's math is deterministic, allocation-free, and independent of Godot.
Positions use `[3]f32`; 2D games leave z at zero.

## Perception

```odin
Target :: struct {
	id:  u32,
	pos: [3]f32,
}

// Return whether geometry blocks the line from `from` to `to`.
// The game supplies geometry queries; nil treats the world as unobstructed.
Blocker_Proc :: proc(user: rawptr, from, to: [3]f32) -> bool

// The nearest target within `max_range` that line-of-sight reaches.
nearest :: proc(from: [3]f32, targets: []Target, max_range: f32, blocker: Blocker_Proc = nil, user: rawptr = nil) -> (best: Target, ok: bool)

in_reach :: proc "contextless" (from, to: [3]f32, reach: f32) -> bool
```

## Steering (per tick; returns the new position)

```odin
// Move toward `goal` for one tick. `arrived` reports reaching it.
// The final step lands exactly on the goal without overshooting.
step_toward :: proc "contextless" (pos, goal: [3]f32, speed: f32) -> (next: [3]f32, arrived: bool)

// Move away from `threat` for one tick. When position equals the
// threat position, use +x as the fallback direction.
step_away :: proc "contextless" (pos, threat: [3]f32, speed: f32) -> [3]f32

// Patrol bookkeeping: advance (and wrap) the waypoint index once the current
// one is within `reach`. The game steps toward `points[current]` as usual.
patrol_next :: proc "contextless" (points: [][3]f32, current: int, pos: [3]f32, reach: f32) -> int
```

Speeds are per tick. To walk a navmesh instead of a straight line, feed `step_toward` the
goal from [kit/nav](nav.md)'s `next_point`.

## The wave director

The wave director schedules spawns from a list of wave counts and rest times.
The game chooses each NPC type and spawn position when the director emits a
spawn. Only one wave runs at a time. The next starts after all NPCs in the
current wave die and its rest interval has elapsed.

```odin
Wave :: struct {
	count: u16, // how many this wave
	rest:  u16, // rest ticks after this wave clears and before the next
}

Director :: struct {
	wave:       int, // waves fully started so far (1-based once running)
	pending:    u16, // still to spawn in the current wave
	alive:      int, // living spawns (the game reports deaths)
	rest_until: u64, // tick when the next wave may start
	done:       bool, // all waves started and cleared
}

// Call once per host tick. Returns the number of NPCs to spawn this tick.
// The director limits spawning to one per tick to spread replication work.
director_tick :: proc(d: ^Director, tick: u64, waves: []Wave) -> (spawn: int)

// The game reports each director-spawned NPC's death. When the wave clears,
// the rest interval before the next wave begins.
director_note_death :: proc(d: ^Director, tick: u64, waves: []Wave)

// The current wave number for HUDs ("wave 2/3"); 0 before the first.
director_wave :: proc "contextless" (d: ^Director) -> int
```

## Worked example: the dweller's brain

The host updates each dweller once per tick. It finds a visible target, selects
a behavior with a `switch`, and writes the resulting position and state. Those
fields carry the result to clients. The procedure is `cave_dwellers_think` in
`examples/cavecrawl/scripts/host.odin`:

```odin
pos := [3]f32{dw.x, dw.y, 0}
seen, spotted := kai.nearest(pos, targets[:], DWELLER_AGGRO)

state := DWELLER_IDLE
switch {
case spotted && dw.hp <= FLEE_BELOW:
	state = DWELLER_FLEE
	pos = kai.step_away(pos, seen.pos, DWELLER_SPEED / 2)
case spotted:
	state = DWELLER_CHASE
	if kai.in_reach(pos, seen.pos, BITE_RANGE) {
		if brain.bite_cd == 0 {
			brain.bite_cd = BITE_CD
			cave_hurt_spelunker(self, victim_id, self.spelunkers[victim_id], BITE_DMG, knet.PLAYER_ID_INVALID, false)
		}
	} else {
		pos, _ = kai.step_toward(pos, seen.pos, DWELLER_SPEED)
	}
case:
	pos, _ = kai.step_toward(pos, brain.home, DWELLER_SPEED)
}
dw.x = pos.x
dw.y = pos.y
dw.state = state
```

The director drives spawning in the same tick, and deaths report back
(`cave_slay_dweller` calls `kai.director_note_death`):

```odin
to_spawn := kai.director_tick(&self.director, u64(self.host_ticks), self.waves[:self.waves_n])
for _ in 0 ..< to_spawn {
	cave_spawn_dweller(self)
}
```

Apply damage and record combat stats through [kit/combat](combat.md)'s
`hit`/`credit_*`. Create and remove entities through the generated typed helpers
`dweller_spawn`, `boot_spawn_send`, and `dweller_despawn`. See the
[Boot entity factory](boot.md#the-entity-factory).

<a id="gotchas"></a>

## Director and presentation constraints

- **Call `director_tick` before the range expression.** Odin reevaluates a
  range bound on each iteration. Calling `director_tick` there repeatedly
  changes director state and can drain the wave, so store its result first.
- Call the director once per tick. It schedules one spawn per tick.
- Keep private NPC state such as bite cooldowns and home positions in a
  host-side map (`self.brains[id]`). Replicate the results other peers need:
  `x/y`, `state`, and `hp`.
- The host writes positions in tick-sized steps, so its node still needs
  frame-rate smoothing. `dweller_process` uses `kai.step_toward` with +50% slack
  on every role. On clients it follows the interpolated stream; on the host it
  smooths the discrete tick updates.
- `step_away` picks +x when the position equals the threat position.
  `nearest` with a nil blocker treats the world as unobstructed.
