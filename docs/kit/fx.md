# kit/fx — bursts, flashes, tracers

Code-driven juice: one-shot particle bursts, hit-flash tweens, and the projectile TRACER pool
— the visual half of the zero-felt-lag story. No scene assets to install; any script can
summon these. An entity that keeps its own emitter (a carried torch, a pyre) authors it in
its scene instead — kit/fx is for FX with no authored home.

```odin
import kfx "godot:kit/fx"
```

## Mental model

Two lifetimes, two shapes:

- **flash** — fire-and-forget: paint the node a color NOW, let a Tween walk it back to white.
  The tween is owned by the node; if the node dies mid-flash the tween dies with it. No
  bookkeeping.
- **burst_at** — a one-shot spark burst parented to the WORLD (not the victim), so it
  outlives despawns: a slain enemy's node is gone next frame, its ashes are not. Spent
  emitters carry a TTL (`BURST_TTL :: f32(0.8)` seconds) in a `Bursts` pool the game owns;
  call `frame()` once per frame to reap them.

And **tracers**: a `kcombat.Fire` describes the authoritative cast (px/*tick* velocity, tick
ttl); a tracer is that cast on THIS screen — a plain glyph Label flying on the FRAME clock
(px/*s*), no entity, no wire. The pool owns flight, node bookkeeping, and contact detection;
the GAME owns what a hit means (the callbacks).

## API by task

**Bursts and flashes:**

```odin
burst_at :: proc(fx: ^Bursts, parent: gd.Node, x, y: f32, color: gd.Color)
frame :: proc(fx: ^Bursts, delta: f64)          // reap spent emitters, once per frame
bursts_destroy :: proc(fx: ^Bursts)             // frees the tracking list; nodes belong to the scene
flash :: proc(node: gd.Node, color: gd.Color)   // nil-safe — a victim's node may already be gone
burst_node :: proc(parent: gd.Node, x, y: f32, color: gd.Color) -> gd.Cpu_Particles2d
```

`burst_node` is the escape hatch: the configured emitter itself, unreaped, for FX with a home
of their own. World-positioned bursts go through `burst_at` so they get reaped.

**Tracers** — the game supplies two procs, the kit does the rest:

```odin
// Who can this shooter's tracer hit, right now. Slice from temp_allocator.
Targets_Proc :: proc(user: rawptr, shooter: knet.Player_Id) -> []kcombat.Target

Tracer_Hit :: struct {
	shooter: knet.Player_Id,
	target:  u32,     // the kcombat.Target id the game supplied (a Net_Id, usually)
	pos:     [3]f32,  // the victim's position (where the sparks go)
}
On_Hit_Proc :: proc(user: rawptr, hit: Tracer_Hit)

tracer_add :: proc(t: ^Tracers, parent: gd.Node, f: kcombat.Fire, glyph: string, tick_hz: int)
tracers_frame :: proc(t: ^Tracers, delta: f64, user: rawptr, targets: Targets_Proc, on_hit: On_Hit_Proc)
tracers_clear :: proc(t: ^Tracers)              // a level change: old rocks die with the old floor
tracers_destroy :: proc(t: ^Tracers)
```

`tracer_add` converts the Fire's tick-clock numbers to the frame clock — `vel = f.vel * hz`,
`left = f32(f.ttl) / hz` — so pass `ksess.session_tick_hz(&ses)` and visuals stay smooth at
any refresh rate. `tracers_frame` flies every tracer one frame, sweeps the frame's segment
for contact (same segments as the host's tick sim, just finer), calls `on_hit` on visual
contact, and reaps; expired tracers reap silently.

## The zero-felt-lag pattern

Proven by cavecrawl and the latency-injected acid tests:

1. The **shooter** draws its tracer at CAST time (prediction — this frame).
2. The **host** launches the authoritative sim projectile AND announces the `Fire` over
   SES_APP so every other screen draws one.
3. Everyone **skips their own echo** (`fire.shooter == me` at the handler).
4. Per frame, `tracers_frame` flies each tracer; on visual contact the game plays the impact
   NOW (predicted hp dip, sparks, flash) while truth arrives a beat later as ordinary deltas
   and squares the number.

From cavecrawl's `rocks.odin`:

```odin
// A rock on THIS screen: a ● tracer in the kit/fx pool (no entity, no wire).
add_visual_rock :: proc(self: ^CaveLobby, f: kcombat.Fire) {
    kfx.tracer_add(&self.tracers, self.world, f, "\xE2\x97\x8F", ksess.session_tick_hz(&self.ses))
}

// Every peer, once per FRAME:
cave_visual_frame :: proc(self: ^CaveLobby, delta: f64) {
    kfx.tracers_frame(&self.tracers, delta, self, rock_targets, rock_impact)
}

// Who a shooter's rock may hit right now: everybody alive except the shooter's own avatar.
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

And an impact: predicted hp dip through the `kcombat.Predicted_Hp` overlay, sparks at the
victim, a red flash — same frame as visual contact, no round trip. If the host saw a miss,
the dip heals back when truth lands.

```odin
rock_impact :: proc(user: rawptr, hit: kfx.Tracer_Hit) {
    self := cast(^CaveLobby)user
    // ... kcombat.php_note_hit on the victim ...
    fx_burst_at(self, hit.pos.x, hit.pos.y, {1, 0.9, 0.4, 1})
    fx_flash(self.nodes[knet.Net_Id(hit.target)], {1, 0.35, 0.35, 1})
    refresh_hud(self)
}
```

## Gotchas

- **px/tick vs px/s.** A `Fire` speaks the tick clock (the authoritative sim's units); a
  tracer flies on the frame clock. `tracer_add` does the conversion — but only if you hand
  it the real `session_tick_hz`. Hardcode 20 and a session at another rate flies wrong.
- **Targets are rebuilt per tracer per frame, from `context.temp_allocator`.** Eligibility
  depends on the shooter (never hit your own avatar), so there is no cached list — your
  `Targets_Proc` must be cheap and must not return long-lived memory.
- **The library is silent — games narrate their own log lines.** kit/fx prints nothing;
  cavecrawl keeps thin wrappers (`fx_burst_at`, `fx_flash` in its `fx.odin`) purely so its
  acid tests' `CAVE_FX` lines survive. If your tests grep logs, wrap likewise.
- **Call the reapers.** `kfx.frame(&fx, delta)` and `kfx.tracers_frame(...)` once per frame,
  or bursts linger and rocks fly forever. Fly visuals FIRST in process, before the host's
  ticks, so a seen impact is noted before the authority deals damage in the same frame.
- **Level change ≠ destroy.** `tracers_clear` frees the in-flight nodes and keeps the pool;
  `tracers_destroy` / `bursts_destroy` drop only tracking memory — nodes belong to the scene.
- The visual hit can differ from the authoritative one — that's the design. Play juice from
  `on_hit`; never mutate replicated state there (use the prediction overlay in
  [combat.md](combat.md)).

Siblings: [combat.md](combat.md) (`Fire`, `Target`, `projectile_hit`, predicted hp) ·
[session.md](session.md) (`session_tick_hz`, SES_APP fire announcements) ·
[ui.md](ui.md) (the HUD the impact repaints).
