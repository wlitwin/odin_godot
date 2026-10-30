# Replay gun mechanism

`Gun_State` owns magazine, reload countdown, jam-clear taps and lifetime jam
sequence. `Gun_Def` supplies the immutable knobs. Both are value-only and can
live inside any saved world; there is no node or networking dependency.

```odin
def := p.Gun_Def{mag = 8, reload_ticks = 72, jam_per_mille = 12, jam_taps = 3}
p.gun_equip(&player.gun, def, salt)

// Once per simulation tick, including replay:
p.gun_tick(&player.gun, def)
if trigger_due {
    result := p.gun_pull(&player.gun, def)
    if result.error != .None {r.abort(ctx); return}
    if result.pull == .Fired {spawn_projectile(world, player, ctx)}
}
```

The caller owns cadence, input semantics and world effects. A pull reports Fired,
Jammed, Empty, Clear_Tap, Cleared or Held. The last live round starts a reload
immediately. A last-round dud stays jammed; clearing it leaves an empty Ready gun,
and the next pull starts the reload. Ticking alone never clears a jam.

`gun_equip`, `gun_tick` and `gun_pull` reject invalid definitions/state without
mutation. A ready gun with `spent == max(u32)` returns Exhausted rather than
reusing a jam-sequence value. Equip deliberately starts a new sequence. Keep
definitions unchanged while a gun is equipped, or explicitly equip again.

The legacy Kit gun remains intact. `tests/replay_gun/run.sh` compiles its original
procedures in isolation and compares all transition/state hashes against Replay
for 16 scenarios of 4,096 ticks and 6,144 pulls each. Native boundary tests and a
freestanding WASM check accompany that comparison. This verifies the mechanism;
it does not claim equivalence between a game's wall-clock and fixed-tick pacers.
