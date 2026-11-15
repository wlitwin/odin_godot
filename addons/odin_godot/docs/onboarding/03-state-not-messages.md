<a id="3--state-not-messages"></a>

# 3 · Field replication

Adding multiplayer requires a rule for each shared value: who may write it,
and how other peers receive it. Hand-written RPCs can scatter those rules
across scripts. Kit puts them on fields and lets the session synchronize the
registered state. This post sets up that arrangement, including entity creation
and player identity.

<a id="the-model"></a>

## Authority-written state

One machine, the **host**, runs the authority that decides shared state. Every
registered entity has replicated fields on each peer. At network ticks, the
session sends changes from the authority to those copies.

The struct layout lets Kit keep a shadow copy of selected fields and compare
their bytes at each network tick. It sends changed fields to peers. Tag a
field to include it in reliable replication:

```odin
Hole :: struct {
	owner:  gd.Node2d,
	net_id: knet.Net_Id,
	idx:    u8 `gd:"replicate"`,   // which hole the party is playing
	cup_x:  f32 `gd:"replicate"`,
	cup_y:  f32 `gd:"replicate"`,
	sinks:  u8 `gd:"replicate"`,
}
```

The host writes `self.hole.idx = 2`; the next state update carries that value
to clients. A player who joins later receives the current value in a snapshot.
The field retains the result, so a late joiner does not need the original call
that changed it.

<a id="entities-the-world-as-a-table-of-structs"></a>

## Registered entities and owners

Replicated structs are **entities** in a registry. Each has a type, a numeric
`net_id`, and a network owner: the player allowed to write its owner-streamed
fields. This differs from the script's `owner` field, which holds a Godot node.
Tags on the exported scene declare the entity type and stable wire ID:

```odin
Golf :: struct {
	owner: gd.Node2d,
	...
	hole_scene: ^gd.Resource `gd:"entity=Hole:1"`,
	ball_scene: ^gd.Resource `gd:"entity=Ball:2"`,
}

// Optional, typed, name-paired: your bookkeeping when one is born or freed.
@(gd_half)
hole_spawned :: proc(game: ^Golf, self: ^Hole, id: knet.Net_Id, owner: knet.Player_Id) {
	game.holes[id] = self
}
```

Scriptgen turns these tags into a factory table used on the host and remote
peers. When the host requests a spawn, the session creates the scene locally
and sends peers the information needed to create the same entity. The
generated factory handles each role. Mid-game joins and resumed saves use
the table to recreate the entities included in their state.

## Setup

`kit/boot` configures the session and its frame pump from your entity and
container declarations:

```odin
golf_ready :: proc(self: ^Golf) {
	golf_net_attach(self, kboot.Options{
		title    = "P U T T P U T T",
		status   = "Host a course, or join one at localhost",
		msg_kind = MSG_SESSION,
		methods  = {"on_host", "on_join", "on_start", "on_chat",
		            "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
}

@(gd_step = "authority") // the host's fixed step — the gate and loop are generated
golf_host_tick :: proc(self: ^Golf) { run_the_course(self) }

golf_process :: proc(self: ^Golf, delta: f64) {
	frame := golf_net_frame(self, delta, now_s())
}
```

With the declared scenes, containers, and handlers in place, these generated
procedures drive the lobby UI, chat, scoreboard, host/join controls
(`kboot.boot_host` / `boot_join`), and connection lifecycle. The game receives
events through name-paired procedures called event halves, marked
`@(gd_half)`. Examples include `golf_player_joined`, `golf_entity_spawned`, and
the authority-only `golf_player_joined_then` for consequences.
`golf_net_frame` dispatches these synchronously after attachment, once the
script is initialized. Lower-level component calls remain available for
custom dispatch ordering.

A player joins with a reconnect token obtained through `ksave.token`, an
environment variable, or a small file under `user://`. The session uses that
token to recognize a returning identity. Rejoining with the same token after
a crash reclaims the seat, stats, and entities retained for that identity.

## Movement: owner-written fields

Waiting for authority updates would delay local movement by a round trip. In
cooperative games that trust player motion, the entity's **network owner** can
write movement fields instead:

```odin
x, y: f32 `gd:"owner"`, // continuous owner fields interpolate by default
```

The session streams these fields unreliably at tick rate. Remote peers render
them through a short interpolation buffer to absorb jitter and packet loss.
The owner moves locally without waiting for a network round trip; remote
screens display a delayed, smoothed version. Post 5 explains that timing.

Authority-written fields use state deltas; owner-written fields use motion
streams. Each field selects one policy.

<a id="what-the-model-gives-you"></a>

## Session operations

The same registry and snapshot mechanism supports these session operations:

- **Drop-in joins**: the registry replays through your factory.
- **Reconnect after a crash**: the token reclaims the seat, and the snapshot
  restores the world.
- **Saves**: `ksave.save_write` / `ksave.resume` write and restore an authority
  session snapshot with the game's additional saved state (post 6).
- **Host migration**: cooperative sessions can restore a backup and reconnect
  peers to the new host after the game's migration setup (post 6).
- **Single-player**: a session with one seat, using the same gameplay code.

Each operation needs its documented setup, but uses the same entity identities
and field declarations. The next post adds actions on shared state: two players
taking the same item need an authority verdict as well as local feedback.

*Next: [Predicted commands →](04-verbs-not-rpcs.md)*
