# Building gameplay: the kit + play recipe

A networked gameplay item has data, player intent, authority decisions, and
presentation that may run on different peers or clocks. Kit represents its
shared state in registered entities; the `play` package supplies local state
machines, timing, and transition tracking. This recipe shows how to compose
those pieces without mixing authority decisions into presentation.

The recipe first embeds reusable state in an entity, then assigns the work
for an item to seven responsibilities: state, cadence, intent, authority,
prediction, reconciliation, and presentation. A gun example shows all seven,
and a table compares five gameplay items.

Several examples use an earlier Scrapyard implementation and the removed
`play.Machine`, `play.step`, and `play.set` APIs. Those examples are retained
as design references and cannot be copied into this checkout unchanged.
Current blocks such as `play.Gun` use generated command reconciliation; see
[kit/play](kit/play.md). `Runner` below names the game's character script.

The networking distinctions used here are:

- Replicated fields retain shared state for updates and snapshots. Events
  represent occurrences that do not need the same persistence.
- Commands ask the authority to validate a target mutation. Owner streams are
  a separate policy for fields whose values the game trusts the owner to write.
- State updates arrive before delayed remote motion is necessarily displayed.
  Spatial effects need to follow the clock of their visible cause.

---

## Layer 1: an entity is a struct of `play` fields

An entity is a struct, and its behaviors are `play` primitives embedded as fields. From
scrapyard, the co-op twin-stick example:

```odin
Runner :: struct {
    owner:  gd.Node2d,
    x, y:   f32 `gd:"owner,wire=f16"`, // continuous owner fields interpolate by default
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

The example groups gun state, damage transition tracking, and revive progress
in `Runner`. Embedding a struct keeps that behavior's data together without
adding another Godot node.

Scriptgen recursively includes tagged fields from embedded structs in the
containing entity's wire descriptor. In the earlier
`play.Machine(Gun_State)` example, `cur: Gun_State \`gd:"replicate"\`` was
replicated as part of `Runner`, while its untagged `shadow` stayed local for
presentation change tracking.

How these differ from Godot components:

- The "components" are **plain Odin sub-structs** (data + free procs), not nodes. There is no
  tree, no `get_node`, and no per-instance allocation: they're fields, resolved at build time.
- Their **"signals" are edges**, not engine signals: you read a `play.Edge` / `play.step`
  transition in the render path, rather than connecting a callback (see
  [Pure-Odin Events](events.md) for callbacks across systems).
- They compose at the **struct** level, flattened by scriptgen, not at the scene-tree level
  at runtime.

Scriptgen carries an embedded block's wire, export, `@onready`, signal, and
command declarations into the containing entity. A `@(gd_command)` whose
receiver is the block gets an entry in the entity's command table. If its
signature requests the containing entity, the generated call supplies that
pointer, called the wielder. Nested blocks compose recursively, such as gun →
loadout → character. The game still implements cross-entity consequences. See
[kit/ — composing verbs from embedded blocks](kit/net.md#composing-verbs-from-embedded-blocks).

<a id="the-play-toolbox"></a>

### Gameplay primitives

These primitives have different execution requirements. `Edge`, `Pace`,
`anim`, and the earlier `Machine` operate on Odin data. `marker` calls the
engine for presentation; `Puppet` and `Puppet3` drive engine physics. The last
column lists each one's usual responsibility in the next section.

| Primitive | What it is | Pure? | Usually the… |
|---|---|---|---|
| `play.Edge(T)` | A client-local shadow of a value; `see` reports the one frame it moved. | ✅ | **Presentation** trigger |
| `play.Pace(T)` | A re-armable deadline; the earlier `Deadlines(K,T)` keyed several. | ✅ | **Cadence** gate |
| `play.Machine(S)` | Earlier state machine with replicated `cur`; absent from this checkout. | ✅ | **State** (a mode) |
| `play.anim` | Presentation float clocks: `decay`/`ramp`/`advance`/`hold`/`pulse`. | ✅ | **Presentation** rendering |
| `play.marker` | Lazy world-markers: `show`/`follow`/`fill`/`depth` over a built node. | ❌ engine | **Presentation** rendering |
| `play.Puppet` | The owner's RigidBody2D solver streams pose and velocity; other peers freeze the body and interpolate it. `session_set_owner` transfers control with velocity retained. | ❌ engine | **State** (a shared body) |
| `play.Puppet3` | RigidBody3D version with quaternion rotation through stream-layer `.Quat` nlerp, linear and angular velocity transfer, and positions in meters. The 2D version snaps rotation. | ❌ engine | **State** (a shared body) |

Tags on a block's fields determine what replicates. The earlier
`Machine.cur` used `gd:"replicate"`; current `Puppet` and `Puppet3` fields
carry owner-streamed pose and velocity. `Edge`, `Pace`, `anim` clocks, and
marker handles are local scratch, stored in authority bookkeeping or a
render-side `view`. Embedding a block includes the network tags it declares.

---

<a id="layer-2-one-behavior-sliced-by-authority"></a>

## Layer 2: assigning authority and presentation

After choosing the entity's fields, assign each operation to the process
allowed to perform it. An item's work can span the client, authority, and
presentation loop. The following seven responsibilities help identify where
that work belongs:

| # | Slot | The question it answers | Lives on | Filled by |
|---|---|---|---|---|
| 1 | **State** | What's true on every screen? | everyone (replicated) | kit `gd:"replicate"`; `play.Machine` for a mode |
| 2 | **Cadence** | When is it allowed to act? | client gate + host | `play.Pace` / `Deadlines` |
| 3 | **Intent** | Which mutation does the client request? | client → host | `@(gd_command)` |
| 4 | **Authority** | Who decides, and what decays each tick? | host only | the command hook + `host_*_tick` |
| 5 | **Prediction** | Which result can be computed before a reply? | client | the `predict` command body |
| 6 | **Reconcile** | How is the local result updated from authority state? | client | this example's view adopts host transitions; generated commands use built-in reconciliation |
| 7 | **Presentation** | How does it read, once per change, on every screen? | everyone | `play.Edge`/`step` → `anim`/`marker` |

Use only the responsibilities the item needs. An authority-controlled pickup
can need State, Authority, and Presentation without a player-issued Intent.
The mob example similarly needs no local Prediction or Reconcile. The
[matrix](#the-same-skeleton-five-ways) compares the work required by each item.

Prediction provides a local response before an authority result arrives.
Reconciliation applies accepted state when the local result differs. The gun
example shows how those operations affect cadence and presentation.

---

## Worked example: the fire / reload / jam gun

The gun uses all seven responsibilities. An empty magazine moves it from
`Ready → (fire) → Reloading`; a dud moves it from `Ready → Jammed`, and
repeated trigger pulls clear the jam. The host accepts gameplay results.
The client predicts eligible transitions before receiving authority updates.

Current reusable blocks include `play.Gun` for magazine, reload, and jam
state; `play.Ability` for a cooldown cast; and `play.Channel` for a
hold-to-progress action such as revive. Their tagged command mutations use
kit/net's built-in prediction and reconciliation. The earlier manual example
below separates these responsibilities for explanation. See
[composing verbs from embedded blocks](kit/net.md#composing-verbs-from-embedded-blocks).

The following excerpts show each responsibility with surrounding game code
omitted.

**1. State** is the minimum every screen needs to render the HUD and let the host gate:

```odin
ammo:      u8 `gd:"replicate"`,
gun_fsm:   play.Machine(Gun_State),   // cur ∈ {Ready, Reloading, Jammed}, replicated
reload_cd: u16 `gd:"replicate"`,      // ticks left on the reload dwell
jam_taps:  u8,                        // host-only scratch — never replicated
```

**2. Cadence** uses one local clock for fire cooldown, reload duration, and
jam-clear attempts. Check the deadline before issuing the next command:

```odin
if !play.due(&self.next_shot, now) { return false }
cd := gun_cooldown(r.gun, r.boost_rate, r.parts)
play.arm(&self.next_shot, now + f64(cd + 1) / hz)   // +1 tick of grace over the host's gate
```

**3. Intent** requests a target mutation. A predicted command runs the same
procedure locally on the client and authoritatively on the host:

```odin
@(gd_command = knet.ACTION_OWNER_PREDICTED)
runner_fire :: proc(self: ^Runner, dx, dy, ox, oy: f32) -> bool { ... }
```

**4. Authority** accepts the fire, jam, or clear result in the command hook.
The per-tick `host_*_tick` advances the reload countdown. The `play.set` calls
in these earlier excerpts update accepted state on the host:

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
    // ... spawn the authoritative damaging projectile ...
}

// in host_combat_tick — the authoritative half of the reload dwell:
if r.gun_fsm.cur == .Reloading && r.reload_cd > 0 {
    r.reload_cd -= 1
    if r.reload_cd == 0 { r.ammo = gun_mag(r.gun); play.set(&r.gun_fsm, Gun_State.Ready) }
}
```

**5. Prediction** computes a local result before the network round trip.
The jam calculation is deterministic: equal player, ammo, floor, and gun values
produce the same roll. The prediction can still differ if the client has
stale state; the host's result remains authoritative.

```odin
// runner.odin — equal inputs on client and host produce the same result:
jam_roll :: proc "contextless" (player: knet.Player_Id, ammo, floor, gun: u8) -> bool {
    if g_no_jam { return false }
    h := u32(player)*2654435761 + u32(ammo)*40503 + u32(floor)*2246822519 + u32(gun)*668265263
    h ~= h>>15; h *= 2246822519; h ~= h>>13
    thresh := gun == GUN_RIVETER ? u32(30) : u32(12)   // 3% / 1.2% per shot
    return (h % 1000) < thresh
}
```

The client predicts fire, ammo consumption, and jams locally. It also holds
the pacer through the predicted reload duration.

**6. Reconcile** updates this example's separate client gun view when the
host's mode changes. It adopts the opening magazine once, then copies the
mode and ammo at a transition. This is a view-specific policy, not a
replacement for generated command reconciliation.

```odin
gun_reconcile :: proc(self: ^Scrapyard, r: ^Runner) {
    if !self.gun_init { /* adopt the host's opening mag once */ ... return }
    if _, moved := play.see(&self.gun_seen, r.gun_fsm.cur); moved {
        self.gun_state = r.gun_fsm.cur   // a reload finished / a jam landed or cleared
        self.gun_ammo  = r.ammo
    }
}
```

**7. Presentation** reacts to changes in the replicated `cur`. In this
earlier example, `play.step` reports the transition for effects without
accepting gameplay results:

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

The host reads the state it set, and clients read the state received through
replication. Each runs the transition check locally. Effects therefore follow
observed state changes rather than a separate RPC for each effect. Changes
that begin and end between comparisons can coalesce; use occurrence events
when each instance must be presented.

---

<a id="the-same-skeleton-five-ways"></a>

## Responsibilities across five gameplay items

The gun uses all seven responsibilities. The five earlier Scrapyard items
below show which work each item requires; an empty cell means that example
needs no separate implementation for that responsibility.

| Slot | Gun | Revive (channel) | Mob brain | Match phase | Pickup |
|---|---|---|---|---|---|
| **State** | `gun_fsm`, `ammo`, `reload_cd` | `rev_target`, `rev_pct`, `hp` | mob `x/y/hp` | `world.stage` (Machine) | scrap entities |
| **Cadence** | `next_shot` (Pace f64) | channel ramp | `next_act`/`next_add` (Pace u64) | `over_at` (Pace) | — |
| **Intent** | `runner_fire` (predict) | `runner_revive` (plain) | — | — | — |
| **Authority** | fire hook + tick dwell | `host_honor_revive` | the `*_brain` procs | `play.set` sites | proximity scan |
| **Prediction** | `try_fire` + `jam_roll` | — | — | — | — |
| **Reconcile** | `gun_reconcile` | — | — | — | — |
| **Presentation** | `gun_edges` (step) | revive-bar marker | telegraph + logs | `step` → banner | despawn |

**Revive: a channeled ability.** A plain (non-predicted) command: `runner_revive` only
asserts the target is down; `host_honor_revive` re-checks `kinter.in_range` and the reviver's
pulse before granting `hp`. This example does not predict the result because
reach depends on another player's authoritative state. Each peer renders the
channel bar from `rev_pct`, building it once and updating it with `play.marker`:

```odin
play.show(self.revive_bar, active)
play.follow(self.revive_bar, d.x, d.y - 44)
play.fill(cast(gd.Node2d)self.revive_fill, f32(pct) / 255)   // each peer renders the bar
```

**Mob brain: a host-only actor.** This example needs Cadence, Authority, State,
and Presentation. One host procedure drives its behavior, with no player
Intent or local Prediction and Reconcile. Its timers group `Pace` values on
the network tick in the style of `play.Deadlines`:

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

**Match phase: a singleton Machine.** In the earlier example, `world.stage` is a
`play.Machine(u8)` on the world/session singleton; the host drives it through `play.set`
(lobby → fight → clear → over), and every system reads `w.stage.cur` to gate what it does.
There is no per-player Intent, Prediction, or Reconcile. This is the same
Machine used by the gun, stored on the singleton instead of the character:

```odin
if from, to, moved := play.step(&w.stage); moved { /* trace / banner the phase change */ }
if all_runners_down(self) { play.set(&w.stage, STAGE_OVER); play.arm(&self.over_at, now_s() + 2.5) }
```

**Pickup: an ambient world rule.** No command at all: the host scans proximity each tick,
credits the stat, and despawns the entity. It needs Authority, State, and
Presentation. The client displays the updated scrap counter:

```odin
reach := PICKUP_R + (part_has(r.parts, PART_MAGNET) ? MAGNET_REACH : 0)
if dist2(sc.x, sc.y, r.x, r.y) <= reach*reach {
    ksess.session_stat_add(&self.ses, pid, self.scrap_col, i64(sc.amount)); append(&picked, id)
}
```

**Contact attack.** A bite, maul, or touch attack can combine a `play.Pace` in
the attacker's authority bookkeeping, a range check, and `play.health_hurt`
on the victim. There is no `play.Melee` block; these operations express the
attack directly.

```odin
// in the attacker's host brain (bite_cd: play.Pace(u64) rides the brain scratch):
if dist2(m.x, m.y, prey.x, prey.y) <= reach*reach && play.ready(&m.brain.bite_cd, tick, BITE_CD) {
    play.health_hurt(&prey.health, BITE_DMG)
}
```

**Authority position history.** The interpolation buffer retains received
samples for rendering. Mechanics such as hitscan judgment, recall, or a death
recap may also need history recorded by the authority. The earlier Scrapyard
lance used ping/2 + interp delay to select a past mob position. A fixed ring
in host scratch can store one position per tick and select an entry by modulo
index at query time. Unwritten slots need a sentinel or validity flag; test a
mob at its live position when it is younger than the history window:

```odin
Mob_Brain :: struct { hist: [30][2]f32, ... }        // 30 ticks = 500ms at 60Hz
m.brain.hist[tick % 30] = {m.x, m.y}                 // top of the host tick loop
h := m.brain.hist[(tick - rewind) % 30]              // the query — clamp rewind to the window
```

This example uses an inline ring because the window, value type, and process
recording it depend on the mechanic.

---

## Checklist for a new item

For each item, identify the state, cadence, request, authority result,
prediction, reconciliation, and presentation work it needs:

1. **State:** replicate the values peers need. The earlier `play.Machine`
   grouped a replicated `cur` tagged `gd:"replicate"` with a local change shadow.
   In current code, represent modes with explicit state fields and use
   generated field edges for replicated transitions. Keep `Edge`, `Pace`,
   timers, and presentation clocks local unless deliberately included in
   network state.

2. **Prediction:** predict results that are deterministic from shared inputs.
   Cooldowns and `jam_roll` can qualify. An AOE that mutates many entities, or
   a check against another player's authoritative state, stays host-only in
   these examples, such as revive and slime. A plain command avoids showing
   speculative success when the client cannot make a reliable local check.

3. **Cadence:** use the local pacer to schedule eligible attempts while the
   host validates them. The example issues fire through
   `play.due(&next_shot, ...)` rather than waiting for a received
   `gun_fsm.cur` to become Ready. This avoids adding a network wait to each
   local attempt.

4. **Reconciliation:** generated predicted commands apply authority updates
   and replay pending commands. For the separate gun view shown above,
   `play.see` detects mode transitions before adopting `cur` and ammo. Keep
   this view policy separate from the runtime's correction of replicated
   entity state.

5. **Presentation:** read transitions to show effects without accepting
   gameplay results. The earlier example used `play.step`; `play.Edge` remains
   useful for local or derived state. After snapshot catch-up, call `play.sync`
   on manually maintained shadows so a prior wound does not look like a fresh
   hit. Generated field edges handle their own baseline seeding.

Record which of the seven responsibilities the item needs, which process
performs each one, and which state or event carries its result to other peers.

---

## See also

- **[kit/ overview](kit/index.md)**: the per-package reference for the systems the Intent
  and Authority slots are built on (`session`, `combat`, `interact`, `net`, …).
- **[Pure-Odin Events](events.md)**: one-to-many callback dispatch across
  systems instead of a per-frame edge read.
- **The `play/` source**: current primitives are documented at their definitions
  (`play/edge.odin`, `pace.odin`, `anim.odin`, `marker.odin`). The earlier
  `fsm.odin` reference belongs to the historical examples; that file is absent
  from this checkout. Use the current source comments for API details.
