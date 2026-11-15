# Waves and held channels

Use `Director` to pace waves with bounded spawn work, and `Channel` for sustained
interactions whose duration belongs in the simulation. `Wave` describes a count
and a post-clear rest in ticks. `Director` owns the current
wave, pending spawns, live count, rest deadline and completion flag. Put it in the
world when it determines gameplay; it then travels with rollback and checkpoints.

`director_tick` announces a new wave, starts spawning on the following tick, and
admits at most one spawn per call. Pass `can_spawn=false` when there is no storage
or valid prey: pending/live counts stay unchanged. Report directed deaths through
`director_note_death`. Its overflow failure preserves the prior director state.
The game decides what and where to spawn and which bodies belong to the director.

```odin
next := world.director
count, started := p.director_tick(&next, ctx.tick, waves, has_room)
if count > 0 && !spawn_enemy(world, ctx) {return}
world.director = next
```

`Channel` is a tick-owned sustained hold. `channel_tick` restarts when its target
identity changes, clears on target zero, and returns true once at completion.
The game must validate continuing range, liveness and input eligibility every tick.
Use a lifetime-qualified target key. The simulation advances the duration, so
the authority can enforce it rather than accepting owner-streamed progress.

Fifty 400-tick director traces match the original procedures compiled in isolation.
Native tests cover storage backpressure, rest/completion and interrupted/retargeted
channels; the helpers also type-check for freestanding WASM.
