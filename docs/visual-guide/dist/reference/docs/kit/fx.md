# kit/fx — bursts, flashes, tracers

`kit/fx` creates one-shot particle bursts, hit-flash tweens, and projectile
tracers from code without requiring scene assets. Use it for temporary effects
created by scripts. Keep persistent emitters, such as a flaming torch or pyre,
in the entity's authored scene.

Bursts, flashes, and tweens can run from presentation code in either replication
model: cooperative `_edge` halves and announcements, or simulation `_fx` halves
and [declared events](sim.md). The tracer pool and `fire_announce` provide
cooperative projectile visuals. In a simulation game, projectiles are predicted
entities with their own visuals (see [sim.md](sim.md)).

This package supports 2D effects only. Bursts use `Cpu_Particles2d`, floating
text uses Control-positioned Labels, and shake moves a `Node2d`. A 3D game
must supply its own effects, including screen shake. These APIs take `(x, y)`;
dimension-independent packages such as combat/interact/ai use `[3]f32`
positions.

```odin
import kfx "godot:kit/fx"
```

<a id="mental-model"></a>

## Effect lifetimes and tracer timing

Flashes and bursts have different lifetimes:

- **flash** colors a node immediately, then uses a Tween to return it to white.
  The node owns the tween, which is released if the node is removed mid-flash.
- **burst_at** parents a one-shot spark emitter to the world so it can outlive
  the entity that triggered it. The game owns a `Bursts` pool that tracks
  emitters for `BURST_TTL :: f32(0.8)` seconds. Call `bursts_frame()` once per
  frame to remove expired emitters.

**Tracers** display a `kcombat.Fire`, which describes the authority's projectile
with velocity in px/tick and lifetime in ticks. Each tracer is a local glyph
Label animated per frame in px/s; it is neither an entity nor a network
message. The pool advances and tracks nodes and detects contacts. The game
handles visual hits through callbacks.

## API by task

**Bursts and flashes:**

```odin
burst_at :: proc(fx: ^Bursts, parent: gd.Node, x, y: f32, color: gd.Color)
bursts_frame :: proc(fx: ^Bursts, delta: f64)   // remove expired emitters, once per frame
bursts_destroy :: proc(fx: ^Bursts)             // frees the tracking list; nodes belong to the scene
flash :: proc(node: gd.Node, color: gd.Color)   // nil-safe — a victim's node may already be gone
burst_node :: proc(parent: gd.Node, x, y: f32, color: gd.Color) -> gd.Cpu_Particles2d
```

`burst_node` returns the configured emitter without adding it to the cleanup
pool, for effects whose lifetime the game manages separately. Use `burst_at`
for temporary world-positioned bursts that the pool should remove.

**Tracers**: the game supplies target and hit callbacks:

```odin
// Return eligible targets for this shooter's tracer; allocate the slice from temp_allocator.
Targets_Proc :: proc(user: rawptr, shooter: knet.Player_Id) -> []kcombat.Target

Tracer_Hit :: struct {
	shooter: knet.Player_Id,
	target:  u32,     // the kcombat.Target id the game supplied (a Net_Id, usually)
	pos:     [3]f32,  // the victim's position (where the sparks go)
}
On_Hit_Proc :: proc(user: rawptr, hit: Tracer_Hit)

tracer_add :: proc(t: ^Tracers, parent: gd.Node, f: kcombat.Fire, glyph: string, tick_hz: int)
tracers_frame :: proc(t: ^Tracers, delta: f64, user: rawptr, targets: Targets_Proc, on_hit: On_Hit_Proc)
tracers_clear :: proc(t: ^Tracers)              // remove active tracers on a level change
tracers_destroy :: proc(t: ^Tracers)
```

`tracer_add` converts the Fire's units for frame-based animation:
`vel = f.vel * hz` and `left = f32(f.ttl) / hz`. Pass
`ksess.session_tick_hz(&ses)` so the display matches the configured simulation
rate. Each frame, `tracers_frame` advances tracers and sweeps each movement
segment for contact. It calls `on_hit` for visual contact and removes that
tracer. Expired tracers are removed without a hit callback. The abbreviated
signature above omits the optional `on_expire: On_Expire_Proc = nil` argument;
supply it to receive the final position when a tracer expires.

<a id="the-zero-felt-lag-pattern"></a>

## Local projectile feedback before authority results

Cavecrawl and the latency-injected integration tests demonstrate local
projectile presentation before authority results arrive:

1. The shooter draws a predicted tracer in the frame the shot is cast.
2. The host launches the authoritative simulation projectile and announces
   `Fire` through SES_APP so other peers can draw it.
3. Receivers skip announcements for their own shots (`fire.shooter == me`
   in the handler) to avoid duplicate tracers.
4. `tracers_frame` advances each tracer per frame. On visual contact, the game
   displays predicted hp loss, sparks, and a flash. Later authority deltas
   supply the accepted hp value.

From cavecrawl's `rocks.odin`:

```odin
// Display a local rock as a ● tracer in the kit/fx pool; it has no entity or network message.
add_visual_rock :: proc(self: ^CaveLobby, f: kcombat.Fire) {
    kfx.tracer_add(&self.tracers, self.world, f, "\xE2\x97\x8F", ksess.session_tick_hz(&self.ses))
}

// Every peer, once per frame:
cave_visual_frame :: proc(self: ^CaveLobby, delta: f64) {
    kfx.tracers_frame(&self.tracers, delta, self, rock_targets, rock_impact)
}

// Eligible targets are living bodies except the shooter's own avatar.
rock_targets :: proc(user: rawptr, shooter: knet.Player_Id) -> []kcombat.Target {
    self := cast(^CaveLobby)user
    targets := make([dynamic]kcombat.Target, context.temp_allocator)
    for id, sp in self.spelunkers {
        if id == self.avatar_of[shooter] || sp.hp <= 0 {continue}
        append(&targets, kcombat.Target{id = u32(id), pos = {sp.x, sp.y, 0}, radius = BODY_RADIUS})
    }
    // ... dwellers too ...
    return targets[:]
}
```

An impact can display hp loss through the `kcombat.Predicted_Hp` overlay,
sparks at the victim, and a red flash in the frame of visual contact, without
waiting for a round trip. If the authority reports a miss, the displayed hp
returns to the accepted value.

```odin
rock_impact :: proc(user: rawptr, hit: kfx.Tracer_Hit) {
    self := cast(^CaveLobby)user
    // ... kcombat.php_note_hit on the victim ...
    fx_burst_at(self, hit.pos.x, hit.pos.y, {1, 0.9, 0.4, 1})
    fx_flash(self.nodes[knet.Net_Id(hit.target)], {1, 0.35, 0.35, 1})
    refresh_hud(self)
}
```

<a id="gotchas"></a>

## Pool lifetime and callback rules

- **Use the configured tick rate.** `Fire` uses px/tick, while tracers use
  px/s. `tracer_add` converts between them using `session_tick_hz`. Hardcoding
  20 gives the wrong velocity and lifetime when the session uses another rate.
- **Targets are rebuilt per tracer per frame, from `context.temp_allocator`.** Eligibility
  depends on the shooter (never hit your own avatar), so there is no cached list. Your
  `Targets_Proc` must be cheap and must not return long-lived memory.
- **The library does not log effects.** Games supply their own log lines.
  Cavecrawl wraps calls in `fx_burst_at` and `fx_flash` in its `fx.odin` to
  emit `CAVE_FX` lines for integration tests. Use wrappers if your tests
  inspect effect logs.
- **Advance pools every frame.** Call `kfx.bursts_frame(&fx, delta)` and
  `kfx.tracers_frame(...)` to animate and remove expired effects. Run visuals
  before host ticks in the frame loop so a predicted impact is recorded
  before authority damage can arrive in the same frame.
- **Choose clear or destroy by lifetime.** `tracers_clear` frees in-flight
  nodes and retains the pool. `tracers_destroy` / `bursts_destroy` release
  tracking memory; the scene owns the nodes.
- **A visual hit can differ from the authority's result.** Play effects from `on_hit`; never
  mutate replicated state there. Use the prediction overlay in [combat.md](combat.md) instead.

Siblings: [combat.md](combat.md) (`Fire`, `Target`, `projectile_hit`, predicted hp) ·
[session.md](session.md) (`session_tick_hz`, SES_APP fire announcements) ·
[ui.md](ui.md) (the HUD the impact repaints).

## Floating text (`Floats` / `float_text` / `floats_frame`)

Floating text displays a label such as "+2 wood" or "-14", moves it upward,
and fades it out. The game owns a `Floats` pool and calls
`floats_frame(&fx, delta)` once per frame to animate and remove labels. Parent
labels to the world so they can outlive the triggering entity. The engine
copies the text, so temporary strings from `fmt.ctprintf` are valid inputs.

```odin
kfx.float_text(&self.floats, self.boot.world, x - 16, y - 34, "+1 wood")
```

## Screen shake (`Shake` / `shake_add` / `shake_frame`)

`Shake` tracks an impact intensity called trauma. `shake_add(&s, 0.3)` increases
it; it decays linearly, and positional jitter scales with trauma². Larger
impacts therefore produce disproportionately larger offsets. Apply the offset
each frame to Boot's Node2D containers so their contents move together:

```odin
kfx.shake_frame(&self.shake, delta, self.boot.stage, self.boot.world)
```

For local action feedback, add shake on the acting player's screen using the
`mine` path of a presentation proc, as homestead does. Observing another
player's action need not shake the local screen. The final frame restores the
containers' original positions.
