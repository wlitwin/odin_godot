# 3 · State, not messages

Adding multiplayer requires a rule for each shared value: who may write it,
and how other peers receive it. Hand-written RPCs can scatter those rules
across scripts. Kit puts them on fields and lets the session synchronize the
registered state. This post sets up that arrangement, including entity creation
and player identity.

## The model

One machine, the **host**, runs the authority that decides shared state. Every
registered entity has replicated fields on each peer. At network ticks, the
session sends changes from the authority to those copies.

You know why this works from post 2: your state is a struct with a fixed
layout. The toolkit keeps a shadow copy, diffs it after each tick, and ships
only the bytes that changed. So the entire replication API is a tag:

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

## Entities: the world as a table of structs

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

scriptgen turns those tags into a factory table, and the same factory runs on
every machine, host included. There is no separate "server spawns, then sends a
spawn message you handle differently" path. The host asks the session to spawn;
the session builds the scene *locally* and tells everyone else to build *the
same scene*. You write the declaration once, and there is no per-role creation
code to write. When a player joins mid-game, the session recreates the registry
through the same table. A resumed save uses that table too.

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

That is a hosted, joinable game: lobby UI, chat, scoreboard, host/join buttons
(`kboot.boot_host` / `boot_join`), connection lifecycle, and the pump that
drives it all. Your game reacts by declaring **event halves**: plain procs
named for the event (`golf_player_joined`, `golf_entity_spawned`, an
authority-only `golf_player_joined_then` for consequences) that the generated
`golf_net_frame` dispatches to synchronously. There are no callbacks into a
half-initialized script. The component
calls remain available when a game needs custom dispatch ordering.

One concept in the join call pays off for the rest of the series: a player
joins with a **reconnect token** (`ksave.token`, an env var, or a small file
under `user://`). The token *is* their identity. Crash, restart, rejoin with
the same token, and you get the same seat, the same stats, the same entities.
There is no separate reconnect system; identity is state too.

## Movement: owner-written fields

Waiting for authority updates would delay local movement by a round trip. In
cooperative games that trust player motion, the entity's **network owner** can
write movement fields instead:

```odin
x, y: f32 `gd:"owner"`, // continuous owner fields interpolate by default
```

streamed unreliably at tick rate, and rendered by everyone else through a short
interpolation buffer that stays smooth through jitter and packet loss. Your
machine moves your avatar with local, zero-latency code; remote screens watch
a slightly delayed, smoothed version. (That "slightly delayed" becomes post 5.)

Authority-written fields use state deltas; owner-written fields use motion
streams. Each field selects one policy.

## What the model gives you

The same registry and snapshot mechanism supports these session operations:

- **Drop-in joins**: the registry replays through your factory.
- **Reconnect after a crash**: the token reclaims the seat, and the snapshot
  restores the world.
- **Saves**: a save file is the snapshot machinery pointed at disk
  (`ksave.save_write` / `ksave.resume`, post 6).
- **Host migration**: a backup snapshot plus "everyone rejoins the new host";
  the toolkit automates the handoff (post 6).
- **Single-player**: a session with one seat, using the same gameplay code.

Each operation needs its documented setup, but uses the same entity identities
and field declarations. The next post adds actions on shared state: two players
taking the same item need an authority verdict as well as local feedback.

*Next: [Verbs, not RPCs →](04-verbs-not-rpcs.md)*
