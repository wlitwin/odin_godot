# Building gameplay: the kit + play recipe

Godot's composition guides teach one move: build an entity from small, focused
**components** — a `HealthComponent`, a `HitboxComponent`, a `VelocityComponent` — each
owning one concern, attached to a node. That pattern maps cleanly onto single-player, which
has exactly one runtime (the frame) and one authority (you). A `kit` game has neither: many
peers run the behavior, and only the host decides. So you still compose — just along a
different axis.

> Single-player composition asks *"what are its parts?"* — health, movement, hitbox.
> kit + play composition asks *"where does each part live across the wire?"* Same behavior,
> sliced by authority instead of by concern.

This page is the applied recipe: two layers of composition, the seven slots a networked
gameplay item is sliced into, one fully worked example (a gun), and the same skeleton shown
five ways. It assumes the toolkit's three foundations:

- **state-not-messages** — peers converge on replicated state; they don't send each other
  events.
- **verbs-not-RPCs** — a client's only reach into the world is a command that runs on the
  host.
- **the two timelines** — the fixed net tick the host simulates on, distinct from the render
  frame.

---

## Layer 1: an entity is a struct of `play` fields

An entity is a struct, and its behaviors are `play` primitives embedded as fields. From
scrapyard, the co-op twin-stick example:

```odin
Runner :: struct {
    owner:  gd.Node2d,
    x, y:   f32 `gd:"owner,interp,wire=f16"`,
    hp:     u8  `gd:"replicate"`,
    gun:    u8  `gd:"replicate"`,

    ammo:      u8 `gd:"replicate"`,       // rounds in the mag
    gun_fsm:   play.Machine(Gun_State),   // Ready / Reloading / Jammed — cur replicates
    reload_cd: u16 `gd:"replicate"`,      // host countdown to reload done

    rev_target: u32 `gd:"owner"`, // who I'm reviving
    rev_pct:    u8  `gd:"owner"`, // channel progress 0..255

    seen_hp: play.Edge(u8),               // local: damage-flash edge detector
}
```

`Runner` has a gun state machine, a damage edge, and a revive channel. Adding a behavior is
adding a field — the same ergonomics as attaching a component node.

**scriptgen recurses into nested structs.** Embedding `play.Machine(Gun_State)` composes its
inner `cur: Gun_State \`gd:"replicate"\`` into the `Runner`'s own wire descriptor
automatically, as if you'd written a flat field. The machine's local `shadow` is untagged, so
it never crosses the wire. One embedded field gives you both the replicated state and its
local presentation shadow.

How these differ from Godot components:

- The "components" are **plain Odin sub-structs** (data + free procs), not nodes. No tree, no
  `get_node`, no per-instance allocation — they're fields, resolved at build time.
- Their **"signals" are edges**, not engine signals: you read a `play.Edge` / `play.step`
  transition in the render path, rather than connecting a callback (see
  [Pure-Odin Events](events.md) for when you *do* want a real dispatch).
- They compose at the **struct** level, flattened by scriptgen, not at the scene-tree level
  at runtime.

scriptgen carries an embedded primitive's wire, export, `@onready`, and signal needs up into
the parent for free — and so do its **verbs**. A block that declares a `@(gd_command)` on
itself has that command hoisted onto whatever entity embeds it (with the wielder threaded
in), so a self-contained gameplay block — a gun that carries its own `fire`, a door its own
`open` — drops in as one field and brings both its replicated state *and* its Intent seam.
The composition is recursive: you keep leveling up (gun → loadout → character) without
threading a command declaration back up to the entity by hand. See
[kit/ — composing verbs from embedded blocks](kit/net.md#composing-verbs-from-embedded-blocks).

### The `play` toolbox

The primitives you compose from. Four are pure — safe in any timeline. The rest touch the
engine: `marker` is presentation-only; `Puppet` and `Puppet3` drive physics. Each usually
fills a particular *slot* in Layer 2 (next section); the last column previews which.

| Primitive | What it is | Pure? | Usually the… |
|---|---|---|---|
| `play.Edge(T)` | A client-local shadow of a value; `see` reports the one frame it moved. | ✅ | **Cue** trigger |
| `play.Pace(T)` | A re-armable deadline: *is it time yet? then schedule the next.* `Deadlines(K,T)` keys several. | ✅ | **Cadence** gate |
| `play.Machine(S)` | A state machine that **owns** its replicated `cur` (host writes, every peer steps). | ✅ | **State** (a mode) |
| `play.anim` | Presentation float clocks — `decay`/`ramp`/`advance`/`hold`/`pulse`. | ✅ | **Cue** rendering |
| `play.marker` | Lazy world-markers — `show`/`follow`/`fill`/`depth` over a built node. | ❌ engine | **Cue** rendering |
| `play.Puppet` | Single-owner engine physics: the owner's RigidBody2D solver streams pose+velocity; every other screen freezes the body and glides it. `session_set_owner` moves the seat, momentum crosses the seam. | ❌ engine | **State** (a shared body) |
| `play.Puppet3` | The 3D sibling: RigidBody3D, quaternion rotation (stream-layer `.Quat` nlerp — 3D rotation interps *correctly*, unlike 2D's snap), angular velocity across the seam. Same feel ledger, meters. | ❌ engine | **State** (a shared body) |

The one wire rule to keep straight: **only `Machine.cur` crosses the wire** — it's a plain
`gd:"replicate"` field. `Edge`, `Pace`, `anim` clocks, and marker handles are all *local
scratch*: they live in an entity's host brain or its render-side `view`, off the replication
boundary. `play` never puts anything on the network unless you tag it.

---

## Layer 2: one behavior, sliced by authority

Layer 1 gets the *pieces* onto the entity. Layer 2 is the part with no single-player analog:
a single behavior — "the gun" — isn't one component. It's one concern spread across the
client, the host, and the wire, and the recipe names the slices. A networked gameplay item
fills some subset of seven slots:

| # | Slot | The question it answers | Lives on | Filled by |
|---|---|---|---|---|
| 1 | **State** | What's true on every screen? | everyone (replicated) | kit `gd:"replicate"`; `play.Machine` for a mode |
| 2 | **Cadence** | When is it allowed to act? | client gate + host | `play.Pace` / `Deadlines` |
| 3 | **Intent** | The one seam a client touches the world. | client → host | `@(gd_command)` |
| 4 | **Authority** | Who decides — and what decays each tick? | host only | the command hook + `host_*_tick` |
| 5 | **Prediction** | How does it feel instant? | client | the `predict` command body |
| 6 | **Reconcile** | How does the guess heal back to truth? | client | snap on a host *transition* |
| 7 | **Cue** | How does it read, once per change, on every screen? | everyone (presentation) | `play.Edge`/`step` → `anim`/`marker` |

**Not every item fills every slot.** A cosmetic pickup is State + Authority + Cue with no
Intent. A mob has no player behind it, so it skips Intent, Prediction, and Reconcile
entirely. Treat the skeleton as a *checklist to walk*, not a mandate to fill; the
[matrix](#the-same-skeleton-five-ways) below shows which items skip what.

Two of these slots — **Prediction** and **Reconcile** — are the ones single-player never
forces you to think about, and they decide the feel of a `kit` game. Most of this page is
about getting them right.

---

## Worked example: the fire / reload / jam gun

The gun fills **all seven** slots and composes the whole toolbox. Its states are
`Ready → (fire) → Reloading` on an empty mag, or `Ready → Jammed` on a dud round that you
mash the trigger to clear. It's host-authoritative, yet feels instant: the client predicts
every transition and the host silently agrees.

Several of these items also ship as drop-in **blocks**: `play.Gun` packages the gun's State +
Authority + Prediction (plus kit/net's built-in Reconcile), `play.Ability` a cooldown cast,
`play.Channel` the revive-style hold-to-progress. The walkthrough below hand-rolls each slot,
which is the clearest way to see what a slot is; with a block you *fill* most slots by
embedding a field, and the slot anatomy is identical. See
[composing verbs from embedded blocks](kit/net.md#composing-verbs-from-embedded-blocks).

Here's the item, slot by slot (code condensed to each slot's essence).

**1. State** — the minimum every screen needs to render the HUD and let the host gate:

```odin
ammo:      u8 `gd:"replicate"`,
gun_fsm:   play.Machine(Gun_State),   // cur ∈ {Ready, Reloading, Jammed}, replicated
reload_cd: u16 `gd:"replicate"`,      // ticks left on the reload dwell
jam_taps:  u8,                        // host-only scratch — never replicated
```

**2. Cadence** — one clock gates *every* state (a fire cooldown, a reload gap, a jam-clear
beat), so the trigger can never out-run any of them:

```odin
if !play.due(&self.next_shot, now) { return false }
cd := gun_cooldown(r.gun, r.boost_rate, r.parts)
play.arm(&self.next_shot, now + f64(cd + 1) / hz)   // +1 tick of grace over the host's gate
```

**3. Intent** — the one seam. A `predict` command runs on the *client's* predictor **and** the
host from the same code:

```odin
@(gd_command = "predict")
runner_fire :: proc(self: ^Runner, dx, dy, ox, oy: f32) -> bool { ... }
```

**4. Authority** — the host owns truth. The command hook decides fire-vs-jam-vs-clear, and
the per-tick `host_*_tick` runs the reload countdown. Every `play.set` here is the *only*
side allowed to move the state:

```odin
// in the command hook — the host's verdict on this pull:
switch r.gun_fsm.cur {
case .Reloading: return                       // a shot that raced the reload — dropped
case .Jammed:
    if r.jam_taps > 0 { r.jam_taps -= 1 }
    if r.jam_taps == 0 { play.set(&r.gun_fsm, Gun_State.Ready) }
    return
case .Ready:
    if jam_roll(player, r.ammo, floor, r.gun) {
        r.ammo -= 1; play.set(&r.gun_fsm, Gun_State.Jammed); r.jam_taps = JAM_TAPS
        return
    }
    r.ammo -= 1
    if r.ammo == 0 { play.set(&r.gun_fsm, Gun_State.Reloading); r.reload_cd = gun_reload_ticks(r.gun) }
    // ... spawn the one authoritative slug that actually wounds ...
}

// in host_combat_tick — the authoritative half of the reload dwell:
if r.gun_fsm.cur == .Reloading && r.reload_cd > 0 {
    r.reload_cd -= 1
    if r.reload_cd == 0 { r.ammo = gun_mag(r.gun); play.set(&r.gun_fsm, Gun_State.Ready) }
}
```

**5. Prediction** — the client runs the *identical* verdict locally, so the shot flies this
frame with zero felt lag. It works because the jam is **deterministic from state both sides
share**: the same seed produces the same roll on both machines, so the client isn't guessing
— it computes the answer the host will reach:

```odin
// runner.odin — same inputs on client and host → same result, no wire round-trip:
jam_roll :: proc "contextless" (player: knet.Player_Id, ammo, floor, gun: u8) -> bool {
    if g_no_jam { return false }
    h := u32(player)*2654435761 + u32(ammo)*40503 + u32(floor)*2246822519 + u32(gun)*668265263
    h ~= h>>15; h *= 2246822519; h ~= h>>13
    thresh := gun == GUN_RIVETER ? u32(30) : u32(12)   // 3% / 1.2% per shot
    return (h % 1000) < thresh
}
```

The client predicts the fire, the ammo decrement, the auto-reload gap (it holds the pacer for
the reload duration), and the jam — all locally, all instant.

**6. Reconcile** — prediction and truth re-align without ever clawing back a *good* in-flight
guess. Snap only on a host **transition**: transitions land at mag boundaries, where
prediction and authority already agree:

```odin
gun_reconcile :: proc(self: ^Scrapyard, r: ^Runner) {
    if !self.gun_init { /* adopt the host's opening mag once */ ... return }
    if _, moved := play.see(&self.gun_seen, r.gun_fsm.cur); moved {
        self.gun_state = r.gun_fsm.cur   // a reload finished / a jam landed or cleared
        self.gun_ammo  = r.ammo
    }
}
```

**7. Cue** — presentation reacts once per change, on every screen, driven by `play.step` off
the replicated `cur`. It never decides anything:

```odin
gun_edges :: proc(self: ^Scrapyard) {
    for id, r in self.runners {
        _, to, moved := play.step(&r.gun_fsm)
        if !moved { continue }
        #partial switch to {
        case .Jammed: kfx.burst_at(...); kfx.float_text(..., "JAM"); kfx.flash(...)
        case .Ready:  kfx.burst_at(..., {0.5, 0.95, 0.55, 1})   // a small confirming pop
        }
    }
}
```

The host observes its own `set`; each client observes replication deliver `cur`; **both** run
`step`, so the enter/exit cues fire identically on every screen with no RPC and no
coordination. Host and client running the same `step` off the same state is the mechanism
underneath the whole recipe.

---

## The same skeleton, five ways

The gun fills all seven slots; most items don't. Here are five real items from scrapyard
against the skeleton — read the empty cells as the insight: **an item's shape is which slots
it skips.**

| Slot | Gun | Revive (channel) | Mob brain | Match phase | Pickup |
|---|---|---|---|---|---|
| **State** | `gun_fsm`, `ammo`, `reload_cd` | `rev_target`, `rev_pct`, `hp` | mob `x/y/hp` | `world.stage` (Machine) | scrap entities |
| **Cadence** | `next_shot` (Pace f64) | channel ramp | `next_act`/`next_add` (Pace u64) | `over_at` (Pace) | — |
| **Intent** | `runner_fire` (predict) | `runner_revive` (plain) | — | — | — |
| **Authority** | fire hook + tick dwell | `host_honor_revive` | the `*_brain` procs | `play.set` sites | proximity scan |
| **Prediction** | `try_fire` + `jam_roll` | — | — | — | — |
| **Reconcile** | `gun_reconcile` | — | — | — | — |
| **Cue** | `gun_edges` (step) | revive-bar marker | telegraph + logs | `step` → banner | despawn |

**Revive — a channeled ability.** A plain (non-predicted) command: `runner_revive` only
asserts the target is down; `host_honor_revive` re-checks `kinter.in_range` and the reviver's
pulse before granting `hp`. It skips Prediction and Reconcile because you can't honestly
predict "did my friend agree I'm in reach" — but the *channel bar* is pure local presentation
off the replicated `rev_pct`, built once and driven with `play.marker`:

```odin
play.show(self.revive_bar, active)
play.follow(self.revive_bar, d.x, d.y - 44)
play.fill(cast(gd.Node2d)self.revive_fill, f32(pct) / 255)   // bar shows on EVERY screen
```

**Mob brain — a host-only actor.** No player is behind it, so it fills only Cadence +
Authority + State + Cue and **skips Intent, Prediction, and Reconcile outright.** Its whole
behavior is one host proc; its timers are a `play.Deadlines`-style bundle of `Pace` on the net
tick:

```odin
Mob_Brain :: struct {
    next_act: play.Pace(u64),   // next bite / spit / slam tick
    next_add: play.Pace(u64),   // boss only: next add-spawn tick
}
// in boss_brain:
if play.due(&m.brain.next_act, s.tick) && s.dist <= reach { m.tele = SLAM_WIND; return }
if frac <= BOSS_ADDS_AT && play.due(&m.brain.next_add, s.tick) {
    play.arm(&m.brain.next_add, s.tick + BOSS_ADD_CD); spawn_adds()
}
```

**Match phase — a singleton Machine.** The recipe at *game* scope. `world.stage` is a
`play.Machine(u8)` on the world/session singleton; the host drives it through `play.set`
(lobby → fight → clear → over), and every system reads `w.stage.cur` to gate what it does.
There's no per-player Intent, so no Prediction or Reconcile — it's the *same* Machine as the
gun's, owned by a singleton instead of a runner:

```odin
if from, to, moved := play.step(&w.stage); moved { /* trace / banner the phase change */ }
if all_runners_down(self) { play.set(&w.stage, STAGE_OVER); play.arm(&self.over_at, now_s() + 2.5) }
```

**Pickup — an ambient world rule.** No command at all: the host scans proximity each tick,
credits the stat, and despawns the entity. Pure Authority + State + Cue. The client "feels" it
as its scrap counter ticking up — the fewest slots an item can fill and still be a thing:

```odin
reach := PICKUP_R + (part_has(r.parts, PART_MAGNET) ? MAGNET_REACH : 0)
if dist2(sc.x, sc.y, r.x, r.y) <= reach*reach {
    ksess.session_stat_add(&self.ses, pid, self.scrap_col, i64(sc.amount)); append(&picked, id)
}
```

**Contact attack — a short idiom, not a block.** Several games in this repo independently
rebuild "attacker in range + per-attacker cooldown → deal damage" (a scuttler's bite, a
wolf's maul, an arena enemy's touch). Against the blocks it's three lines — a `play.Pace` on
the attacker's host brain, a range check, `play.health_hurt` on the victim. There's no
`play.Melee` block: at this length a block would add a name without hiding anything hard.

```odin
// in the attacker's host brain (bite_cd: play.Pace(u64) rides the brain scratch):
if dist2(m.x, m.y, prey.x, prey.y) <= reach*reach && play.ready(&m.brain.bite_cd, tick, BITE_CD) {
    play.health_hurt(&prey.health, BITE_DMG)
}
```

**The authority's ledger — positions, a moment ago.** Every receiver already keeps a ring of
*where things were, as seen* (the interp buffer). Some mechanics need the authority-side twin
— *where things were, as true*: a hitscan beam judged where the shooter saw the mob
(scrapyard's lance rewinds ping/2 + interp delay through it), a recall ability rewinding its
owner, a death recap. The idiom is a fixed ring on host scratch: one write per tick, one
modulo read at query time. Unwritten slots need a sentinel (or a validity flag) — a mob
younger than the window tests live:

```odin
Mob_Brain :: struct { hist: [30][2]f32, ... }        // 30 ticks = 500ms at 60Hz
m.brain.hist[tick % 30] = {m.x, m.y}                 // top of the host tick loop
h := m.brain.hist[(tick - rewind) % 30]              // the query — clamp rewind to the window
```

No block packages this; write the ring inline. The window size, value type, and whether it
rides the host or the owner vary by mechanic.

---

## Checklist for a new item

When you sit down to build a gameplay item, walk the seven slots and answer each. The ones
that trip people up have hard rules:

1. **State: replicate the minimum, and make a *mode* a `Machine`.** If every screen needs to
   render it or the host needs it to gate, it's `gd:"replicate"`. If it's a small set of
   named states, it's a `play.Machine` — you get the replicated `cur` and the local step
   shadow from one field. Everything else (`Edge`, `Pace`, timers, clocks) stays **off the
   wire**.

2. **Predict only what's deterministic from shared inputs.** Client prediction is honest
   *only* when the client can compute the exact answer the host will. Cooldowns and the
   deterministic `jam_roll` qualify; an AOE that mutates many entities, or a check against
   another player's state, does **not** — those stay host-only (see revive, slime). When in
   doubt, don't predict: a plain command that resolves a few frames later beats a prediction
   that has to visibly snap back.

3. **The pacer, not the wait.** A responsive client *paces*: it acts on its own clock and
   lets the host silently gate, rather than waiting for replicated state to change before it
   does anything. The gun fires on `play.due(&next_shot, ...)`, never on "did `gun_fsm.cur`
   come back Ready." This is the difference between instant and laggy.

4. **Reconcile on transitions, not every frame.** Snapping prediction to truth every frame
   claws back good in-flight guesses and looks like rubber-banding. Snap only when the host's
   state *changes* (`play.see` on the replicated `cur`) — those moments are the boundaries
   where the two already agree.

5. **Cue off edges, on every peer, and never decide there.** Presentation reads
   `play.step` / `play.Edge` transitions and fires effects; it's pure, runs identically on
   host and client, and has zero authority. A snapshot catch-up (a late join) must
   `play.sync` the shadows first so a wound taken out of view doesn't replay as a fresh hit.

Answer all seven for your item — and cross off the ones it legitimately skips — and you've
designed a networked gameplay item that will feel right, without re-deriving the client/host
dance each time.

---

## See also

- **[kit/ overview](kit/index.md)** — the per-package reference for the systems the Intent
  and Authority slots are built on (`session`, `combat`, `interact`, `net`, …).
- **[Pure-Odin Events](events.md)** — when a Cue wants a real one-to-many dispatch across
  systems instead of a per-frame edge read.
- **The `play/` source** — every primitive is documented at its definition
  (`play/edge.odin`, `pace.odin`, `fsm.odin`, `anim.odin`, `marker.odin`); the doc comments
  are the authoritative API reference.
