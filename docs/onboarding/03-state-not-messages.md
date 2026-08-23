# 3 · State, not messages

Most Godot projects reach for multiplayer late: you open the RPC docs and find
that multiplayer isn't a feature you add so much as a structure you either have
or don't. Every script that mutates state has to know *who* may mutate it,
*which* machine it runs on, and *what* to tell everyone else. The retrofit
touches everything.

This post is the mental-model shift that removes the problem: **stop thinking
in messages ("tell the other peers X happened") and start thinking in state
("this field is true everywhere").** Structure a game this way from the first
hour (the toolkit makes it nearly free), and multiplayer is a property the
code already has.

## The model

One machine, the **host**, owns the truth. Every replicated field lives in a
struct on every machine, and the toolkit makes everyone's copy converge on the
host's automatically and incrementally, every network tick.

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

The host writes `self.hole.idx = 2`; a beat later that byte is true on every
screen. **Change a field, and you're done.** No `rpc("set_hole", 2)`, no
MultiplayerSynchronizer node to configure, no late-joiner-missed-the-call bug:
a field is *state*, so whoever joins next gets it in their snapshot. An RPC
only exists at the moment it's sent; a field exists whenever anyone looks.

## Entities: the world as a table of structs

Replicated structs are **entities** in a registry. Each has a type, a numeric
`net_id`, and an owner. You declare one with a tag on the scene you already
export, capturing what the scene bodies and its stable wire id:

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
code to write. When a player joins mid-game, the session replays the registry
through the same table, and a resumed save uses the same table. Drop-in-join
and load-game are already handled.

## Setup

`kit/boot` reduces standing this up to declaring what's yours and attaching:

```odin
golf_ready :: proc(self: ^Golf) {
	kboot.boot_attach(&self.boot, self.owner, &self.ses, &self.comms, kboot.Options{
		title    = "P U T T P U T T",
		status   = "Host a course, or join one at localhost",
		msg_kind = MSG_SESSION,
		methods  = {"on_host", "on_join", "on_start", "on_chat",
		            "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
	golf_entities(self, &self.boot) // the generated factory
}

@(gd_step = "authority") // the host's fixed step — the gate and loop are generated
golf_host_tick :: proc(self: ^Golf) { run_the_course(self) }

golf_process :: proc(self: ^Golf, delta: f64) {
	events, _, ticks := kboot.boot_pump(&self.boot, delta, now_s())
	golf_step(self, ticks)     // generated: hosts step, clients no-op
	golf_events(self, events)  // generated: dispatch to the event halves you declared
}
```

That is a hosted, joinable game: lobby UI, chat, scoreboard, host/join buttons
(`kboot.boot_host` / `boot_join`), connection lifecycle, and the pump that
drives it all. Your game reacts by declaring **event halves**: plain procs
named for the event (`golf_player_joined`, `golf_entity_spawned`, an
authority-only `golf_player_joined_then` for consequences) that the generated
`golf_events` dispatches to. There are no callbacks into a half-initialized
script, and no role branch of your own to write.

One concept in the join call pays off for the rest of the series: a player
joins with a **reconnect token** (`ksave.token`, an env var, or a small file
under `user://`). The token *is* their identity. Crash, restart, rejoin with
the same token, and you get the same seat, the same stats, the same entities.
There is no separate reconnect system; identity is state too.

## Movement: owner-written fields

Host-authoritative fields would make *your own avatar* feel like molasses,
with every keypress waiting on a round trip. So there is one other flavor of
replication: fields the entity's **owner** writes,

```odin
x, y: f32 `gd:"owner,interp"`,
```

streamed unreliably at tick rate, and rendered by everyone else through a short
interpolation buffer that stays smooth through jitter and packet loss. Your
machine moves your avatar with local, zero-latency code; remote screens watch
a slightly delayed, smoothed version. (That "slightly delayed" becomes post 5.)

The host owns deltas for truth; the owner owns streams for motion. The two are
disjoint sets, both just fields, and the word *message* never appeared.

## What the model gives you

Structuring state this way feels like discipline until you list what falls out
of it, each item a direct consequence of *state-is-the-protocol*:

- **Drop-in joins**: the registry replays through your factory.
- **Reconnect after a crash**: the token reclaims the seat, and the snapshot
  restores the world.
- **Saves**: a save file is the snapshot machinery pointed at disk
  (`ksave.save_write` / `ksave.resume`, post 6).
- **Host migration**: a backup snapshot plus "everyone rejoins the new host";
  the toolkit automates the handoff (post 6).
- **Single-player**: a session with one seat, using the same code. You never
  build the game twice.

These are consequences of the model rather than separate features. That is the
value of learning it: you are not learning six systems, you are learning one
shape that implies six systems.

What's missing is the other half: players don't just *watch* state, they *act*
on it. Two players acting on the same chest at once is where netcode
traditionally gets ugly. That's the next post.

*Next: [Verbs, not RPCs →](04-verbs-not-rpcs.md)*
