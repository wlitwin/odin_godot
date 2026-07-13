# godot:play — drop-in gameplay blocks

`godot:play` is the shelf of building blocks the kit games are assembled
from: embed a struct field and the entity gains working, already-networked
behavior — its replicated state joins the entity's descriptor and its verbs
hoist onto the entity's command table through scriptgen's
[composition](net.md#composing-verbs-from-embedded-blocks). One block per
authority model, so picking a block IS picking where its state lives across
the wire (see [recipes](../recipes.md) for the full pattern).

| Block | Authority model | The shape it ships |
| --- | --- | --- |
| `play.Gun` | host-written, client-predicted verb | mag + reload + jam behind a `gun_fire` verb, knob-configured (`Gun_Def`) |
| `play.Ability` | cooldown-gated verb | the slow cast (lob/cone/buff) — the block owns its cooldown |
| `play.Channel` | owner-streamed progress + plain claim verb | hold-to-progress: revive, capture, cast bar — every screen draws the fill |
| `play.Health` | host-written state, VERB-FREE | hp + max + the per-peer damage edge (numbers, topples, death cues) |
| `play.Telegraph` | host countdown, verb-free | the wind-up that lands — every screen grows the same warning ring |
| `play.Machine(E)` | replicated FSM state | `cur` replicates through the embed; a local edge shadow presents transitions |
| `play.Puppet` / `Puppet3` | owner-simulated engine physics | a RigidBody every screen agrees about (below) |

Presentation-side (never on the wire): `play.Edge(T)` (fire once on a
change), `play.Anim` clocks (tiny float eases), `play.Marker` (lazy world
markers — rings, bars, beacons), `play.Pace` (the re-armed deadline every
host tick loop re-spells), and `play.Trail` (the authority's
where-was-it-a-moment-ago ledger — lag-compensated hitscan reads it).

A block's cross-entity effects stay YOURS, as the composed verb's
[`_then` consequence](net.md#consequences-verb_then):
`runner_weapon_fire_then` spawns the slug; `play.Gun` only resolves the
trigger. Blocks are the reference for writing your own — the pattern is
documented on their source headers (`play/*.odin`), which remain the long
answer to everything on this page.

## play.Puppet — engine physics, one simulator per body

THE ENGINE TRAP this block exists to hide: Godot's solver cannot be rewound
or reconciled, and a `RigidBody2D` IGNORES node-transform writes — live ones
are stomped by the physics server's next sync, and writes made while frozen
vanish when the freeze lifts. So a shared dynamic body (the ball, the crate,
the ragdoll) gets exactly ONE simulating peer — the entity's session OWNER —
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
// every frame:           play.puppet_frame(&self.puppet)
// Ev_Owner_Changed:      play.puppet_seat(&b.puppet, e.owner == ses.me)
```

WHO owns it is the game's call, made with `ksess.session_set_owner` from
host code or a `_then` — last-toucher-owns (a ball), the carrier (a crate),
the driver (a vehicle), or the host forever (world debris). The handoff
carries momentum: the new simulator seeds its solver from the streamed pose
AND velocity, so a rolling ball keeps rolling through the seam; remote
screens snap across it (the `Ev_Owner_Changed` contract).

The feel ledger, all inside the block:

- **Render-error smoothing** — authority snaps (a seat seed, a handoff
  re-anchor) move the BODY instantly, but the drawn `skin` child holds its
  ground and glides in over ~100ms. Deliberate CUTS (kickoff teleports) past
  `PUPPET_CUT` still snap outright — smoothing a teleport looks worse.
- **Predicted possession** (`puppet_claim`) — seize the simulation ON SPEC
  the frame YOUR screen sees the touch, without waiting for the grant round
  trip. Confirmed: the provisional flight becomes canon seamlessly. Denied or
  timed out: freeze and glide back onto the real owner's stream. Slopball's
  anticipatory ball seat is this call.
- **Verbs for the simulator** — `puppet_place` (kickoff/round-reset teleport;
  pair with `session_teleport` so remote interp snaps) and `puppet_shove`
  (the impulse kick — a claimed possession kicks like a real one).

`play.Puppet3` is the same contract for `RigidBody3D` — slopball3d is the
proof the model is dimension-blind. Character avatars DON'T need a puppet:
each peer already `move_and_slide`s only its OWN body and streams x/y like
any owner field; frozen-kinematic remote pucks stay solid to them.

Worked references: `examples/slopball` (2D, claim + handoffs + kickoffs),
`examples/slopball3d` (3D). See also [net](net.md) for the stream/delta
machinery underneath and [session](session.md#ownership-transfer) for the
ownership contract.
