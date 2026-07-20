# kit/ai — NPC verbs and the wave director

Reach for `kit/ai` when the host needs NPCs that perceive, chase, flee, patrol — and a
director that paces enemy waves. It supplies the *verbs*; you write the brain.

**Lane compatibility: COOP model, sim-safe math.** The patterns here assume the coop
NPC shape — host-brained, owner-streamed poses. On the [sim lane](sim.md) an NPC is a
server-ticked entity with `predict` fields, its brain in the AUTHORITY pass. The
perception/steering math is pure and safe in either; the wave director is
authority-side logic and ports as-is. See [nav](nav.md) for the one genuinely
dangerous crossing.

## Mental model

**Patterns, not a framework**: kit/ai has no Brain type, no behavior tree, no update loop.
The game writes an ordinary `switch` over a replicated `state: u8` in its **host** tick,
built from these verbs — cavecrawl's dweller is the documented example.

The NPC model rides what already exists: an NPC is an entity **owned by the host player** —
the host's brain tick writes `x/y` like any owner writes streamed fields, and every client
interpolates the motion for free. Its state byte and hp are plain replicated fields. No new
machinery. The whole network presence of cavecrawl's dweller is this struct
(`examples/cavecrawl/scripts/dweller.odin`):

```odin
Dweller :: struct {
	owner:  gd.Node2d,
	glyph:  gd.Label `gd:"onready=Glyph"`,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"owner,interp"`, // the HOST owns it: brain writes, clients interp
	hp:     i32 `gd:"replicate"`,
	state:  u8 `gd:"replicate"`, // its mood, on every screen
	...
}
```

Replicated mood byte + owner-streamed position = **clients watch the hunt for free**: every
peer renders the same 🦇/😈/💨 from `state` and sees the chase as smooth interpolated
motion, without one line of AI or wire code on the client.

Everything here is deterministic, allocation-free, dimension-agnostic (`[3]f32`; 2D leaves
z zero) and engine-free.

## Perception

```odin
Target :: struct {
	id:  u32,
	pos: [3]f32,
}

// Is the straight line from `from` to `to` blocked (a wall between)? The
// GAME owns geometry — kit/ai only asks. nil = open world, everything seen.
Blocker_Proc :: proc(user: rawptr, from, to: [3]f32) -> bool

// The nearest target within `max_range` that line-of-sight reaches.
nearest :: proc(from: [3]f32, targets: []Target, max_range: f32, blocker: Blocker_Proc = nil, user: rawptr = nil) -> (best: Target, ok: bool)

in_reach :: proc "contextless" (from, to: [3]f32, reach: f32) -> bool
```

## Steering (per tick; returns the new position)

```odin
// One tick of walking toward `goal`. `arrived` = we are ON it now (never
// overshoots — the last step lands exactly).
step_toward :: proc "contextless" (pos, goal: [3]f32, speed: f32) -> (next: [3]f32, arrived: bool)

// One tick of running AWAY from `threat` (flee). Standing exactly on the
// threat picks +x arbitrarily — any direction beats none.
step_away :: proc "contextless" (pos, threat: [3]f32, speed: f32) -> [3]f32

// Patrol bookkeeping: advance (and wrap) the waypoint index once the current
// one is within `reach`. The game steps toward `points[current]` as usual.
patrol_next :: proc "contextless" (points: [][3]f32, current: int, pos: [3]f32, reach: f32) -> int
```

Speeds are per tick. To walk a navmesh instead of a straight line, feed `step_toward` the
goal from [kit/nav](nav.md)'s `next_point`.

## The wave director

Generalized from survivors: the director decides *when* and *how many*; the game decides
what and where (its spawn code runs per emitted spawn). One wave at a time, the next after
the field is clear and a breather passes.

```odin
Wave :: struct {
	count: u16, // how many this wave
	rest:  u16, // ticks of calm AFTER this wave clears, before the next
}

Director :: struct {
	wave:       int, // waves fully started so far (1-based once running)
	pending:    u16, // still to spawn in the current wave
	alive:      int, // living spawns (the game reports deaths)
	rest_until: u64, // calm gate before the next wave starts
	done:       bool, // all waves started and cleared
}

// Once per host tick. Returns how many to spawn NOW (the director paces one
// per tick — spawn bursts read badly and spike the delta batch).
director_tick :: proc(d: ^Director, tick: u64, waves: []Wave) -> (spawn: int)

// The game reports each director-spawned NPC's death. When the wave clears,
// the calm before the next one starts counting.
director_note_death :: proc(d: ^Director, tick: u64, waves: []Wave)

// The current wave number for HUDs ("wave 2/3"); 0 before the first.
director_wave :: proc "contextless" (d: ^Director) -> int
```

## Worked example: the dweller's whole brain

One think-tick per dweller, host only — perceive, then a plain switch. State and position
are replicated fields; writing them *is* the AI's entire network presence
(`examples/cavecrawl/scripts/host.odin`, `cave_dwellers_think`):

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

Damage on hit goes through [kit/combat](combat.md)'s `hit`/`credit_*`; spawns/despawns go
through the [session](session.md) factory (`session_spawn_make` / `session_despawn`).

## Gotchas

- **Hoist `director_tick` out of the range expression.** An Odin range bound is
  re-evaluated per iteration, and `director_tick` has side effects — inlining it in the
  range silently drains the wave. (The comment in `cave_host_tick` exists because it
  happened.)
- The director paces **one spawn per tick** on purpose — spawn bursts read badly and spike
  the delta batch. Don't loop it.
- Per-NPC scratch that no one else needs (bite cooldowns, home dens) lives in a host-side
  map (`self.brains[id]`), not in replicated fields — only the *consequences* (`x/y`,
  `state`, `hp`) ship.
- The host's own screen is only as smooth as the writer — the brain writes `x/y` in tick
  steps. `dweller_process` glides the node toward the sim with `kai.step_toward` at frame
  rate (+50% slack), on every role: clients shadow the already-smooth stream, the host
  melts the steps.
- `step_away` at distance zero picks +x arbitrarily; `nearest` with a nil blocker sees
  everything (open world).
