# godot:play — drop-in gameplay blocks

`godot:play` is the shelf of building blocks the kit games are assembled
from: embed a struct field and the entity gains working, already-networked
behavior. Its replicated state joins the entity's descriptor, and its verbs
hoist onto the entity's command table through scriptgen's
[composition](net.md#composing-verbs-from-embedded-blocks). There is one
block per authority model, so picking a block IS picking where its state
lives across the wire (see [recipes](../recipes.md) for the full pattern).

| Block | Authority model | The shape it ships |
| --- | --- | --- |
| `play.Gun` | host-written, client-predicted verb | mag + reload + jam behind a `gun_fire` verb, knob-configured (`Gun_Def`) |
| `play.Ability` | cooldown-gated verb | the slow cast (lob/cone/buff): the block owns its cooldown |
| `play.Channel` | owner-streamed progress + plain claim verb | hold-to-progress: revive, capture, cast bar; every screen draws the fill |
| `play.Health` | host-written state, VERB-FREE | hp + max + the damage policy (`hurt`'s killing-blow-once contract) |
| `play.Telegraph` | host countdown, verb-free | the wind-up that lands; every screen grows the same warning ring |
| `play.Puppet` / `Puppet3` | owner-simulated engine physics | a RigidBody every screen agrees about (below) |

**A block never shadows a replicated field.** Its state diffs like any
tagged field, so its PRESENTATION is the game's generated
[`<field>_edge` half](net.md#edges-class_field_edge--presenting-delta-lane-changes)
on the embedding entity: `mob_health_hp_edge` for the hit/death/revive
cues, `runner_weapon_mode_edge` for the gun's jam/reload pops,
`mob_tele_left_edge` (+ `play.telegraph_landed`, which holds the cancel
contract) for the eruption. First sight and resyncs seed silently, so the
blocks carry no birth guards or re-baseline rituals. (A replicated FSM is a
plain enum field plus its edge half.)

Presentation-side blocks (never on the wire) include `play.Edge(T)` (fires
once on a change of DERIVED or local state, such as a boolean computed from
a replicated array or a persistence profile; a replicated field itself
takes the generated half above), `play.Anim` clocks (tiny float eases),
`play.Marker` (lazy world markers: rings, bars, beacons), `play.Pace` (the
re-armed deadline every host tick loop re-spells), and `play.Trail` (an
authority-side where-was-it-a-moment-ago ledger for host-only state —
lag-compensated hitscan against streamed bodies reads the session's own
history through `ksess.session_rewound` instead).

PREDICTED blocks live on the sibling shelf, `godot:play/sim` (alias
`psim`): `psim.Cool` (Pace's twin, with the same due/arm/ready verbs,
counting itself down inside the sim), `psim.Mover` (momentum movement), and
`psim.Roller` (the contested rolling body). These blocks share the same
embedding but run on the other timeline: their `predict` fields resim, and
their block ticks hoist onto the entity's. scriptgen polices the split both
ways, so the shelf an import names IS the lane the state lives on; the
block list and the contract live in [sim](sim.md#predicted-blocks--godotplaysim).

A block's cross-entity effects stay YOURS, as the composed verb's
[`_then` consequence](net.md#consequences-verb_then):
`runner_weapon_fire_then` spawns the slug — from the pull's carried origin
(the wielder's own muzzle, leashed against the host's copy with
`kcombat.leash`); `play.Gun` only resolves the trigger. Blocks are the
reference for writing your own; the pattern is
documented on their source headers (`play/*.odin`), which remain the long
answer to everything on this page.

## play.Puppet — engine physics, one simulator per body

THE ENGINE TRAP this block exists to hide: Godot's solver cannot be rewound
or reconciled, and a `RigidBody2D` IGNORES node-transform writes. Live ones
are stomped by the physics server's next sync, and writes made while frozen
vanish when the freeze lifts. So a shared dynamic body (the ball, the crate,
the ragdoll) gets exactly ONE simulating peer, the entity's session OWNER,
and every other screen freezes the body kinematic (still solid to the local
scene) and glides it along the owner's interpolated stream. Every pose the
puppet imposes goes through `PhysicsServer2D.body_set_state`, because that's
the only write the solver honors.

```odin
Ball :: struct {
	owner:  gd.Rigid_Body2d,
	net_id: knet.Net_Id,
	puppet: play.Puppet, // pose + velocity replicate through the embed (wire=f16)
}

// spawn (every peer):    play.puppet_attach(&self.puppet, self.owner, x, y)
// Ev_Spawned (born):     play.puppet_born(&b.puppet)   // the BODY onto the spawned fields, then the seat below
// every frame:           play.puppet_frame(&self.puppet)
// Ev_Owner_Changed:      play.puppet_seat(&b.puppet, e.owner == ses.me)
```

`puppet_born` is the body's FIRST placement (the node's, for a puppet): call it
from `<game>_entity_spawned`, before the seat. The scene instanced the body at
its default pose, and a body born mid-frame (a host-step spawn, an arrival under
an injected delay) gets no `puppet_frame` until the NEXT frame — one rendered
frame in the corner, then a cut. See [boot.md](boot.md#the-entity-factory),
"Where the first placement goes".

WHO owns it is the game's call, made with `ksess.session_set_owner` from
host code or a `_then`: last-toucher-owns (a ball), the carrier (a crate),
the driver (a vehicle), or the host forever (world debris). The handoff
carries momentum: the new simulator seeds its solver from the streamed pose
AND velocity, so a rolling ball keeps rolling through the seam; remote
screens snap across it (the `Ev_Owner_Changed` contract).

The feel ledger lives entirely inside the block:

- **Render-error smoothing**: authority snaps (a seat seed, a handoff
  re-anchor) move the BODY instantly, but the drawn `skin` child holds its
  ground and glides in over ~100ms. CUTS (kickoff teleports) past
  `PUPPET_CUT` still snap outright; smoothing a teleport looks worse.
- **Predicted possession** (`puppet_claim`) seizes the simulation ON SPEC
  the frame YOUR screen sees the touch, without waiting for the grant round
  trip. If confirmed, the provisional flight becomes canon seamlessly. If
  denied or timed out, it freezes and glides back onto the real owner's
  stream. Slopball's anticipatory ball seat is this call.
- **Verbs for the simulator** include `puppet_place` (kickoff/round-reset
  teleport; pair with `session_teleport` so remote interp snaps) and
  `puppet_shove` (the impulse kick; a claimed possession kicks like a real
  one).

`play.Puppet3` is the same contract for `RigidBody3D`; slopball3d is the
proof that the model is dimension-blind. Character avatars DON'T need a
puppet: each peer already `move_and_slide`s only its OWN body and streams
x/y like any owner field; frozen-kinematic remote pucks stay solid to them.

Worked references: `examples/slopball` (2D, claim + handoffs + kickoffs),
`examples/slopball3d` (3D). See also [net](net.md) for the stream/delta
machinery underneath and [session](session.md#ownership-transfer) for the
ownership contract.
