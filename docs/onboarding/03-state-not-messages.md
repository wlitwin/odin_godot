# 3 · State, not messages

Every Godot developer has told themselves the same lie: *"I'll add multiplayer
later."* Later arrives, you open the RPC docs, and you discover that
multiplayer isn't a feature you add — it's a structure you either have or
don't. Every script that mutates state now needs to know *who* is allowed to
mutate it, *which* machine it's running on, and *what* to tell everyone else.
The retrofit touches everything, so most projects either ship without it or
rewrite around it.

This post is the mental-model shift that dissolves the problem: **stop
thinking in messages ("tell the other peers X happened") and start thinking in
state ("this field is true everywhere").** If you structure a game this way
from the first hour — and the toolkit makes that nearly free — multiplayer is
a property your code already has.

## The model

One machine, the **host**, owns the truth. Every replicated field lives in a
struct on every machine, and the toolkit's job is to make everyone's copy
converge on the host's — automatically, incrementally, every network tick.

You already know why this works from post 2: your state is a struct with a
fixed layout. The toolkit keeps a shadow copy, diffs it after each tick, and
ships only the bytes that changed. Which means the entire replication API is:

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
screen. **Change a field, done.** No `rpc("set_hole", 2)`, no
MultiplayerSynchronizer node to configure, no "did the late joiner miss the
call" bug — a field is *state*, so whoever joins next gets it in their
snapshot for free. That last clause is where messages structurally lose:
an RPC only exists at the moment it's sent; a field exists whenever anyone
looks.

## Entities: the world as a table of structs

Replicated structs are **entities** in a registry. Each has a type, a numeric
`net_id`, and an owner. Declaring one is a tag on the scene you already
export — what the scene bodies, and its stable wire id:

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

scriptgen turns those tags into a factory table, and — this is the detail to
sit with — **the same factory runs on every machine, host included**. There
is no "server spawns, then sends a spawn message you handle differently."
The host asks the session to spawn; the session builds the scene *locally*
and tells everyone else to build *the same scene*. Creation code exists —
nowhere, actually, but the one declaration exists once. A player who joins
mid-game? The session replays the registry through the same table. A resumed
save? Same table. You have already written the drop-in-join and load-game
code without noticing.

## The ceremony (there barely is one)

Standing this up used to be the intimidating part; `kit/boot` reduced it to
declaring what's yours and attaching:

```odin
golf_ready :: proc(self: ^Golf) {
	kboot.boot_attach(&self.boot, self.owner, &self.ses, &self.comms, kboot.Options{
		title    = "P U T T P U T T",
		status   = "Host a course, or join one at localhost",
		msg_kind = MSG_SESSION,
		methods  = {"on_host", "on_join", "on_start", "on_chat",
		            "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
	kboot.boot_entities(&self.boot, self, golf_entity_kinds[:]) // the generated factory
}

@(gd_step = "authority") // the host's fixed step — the gate and loop are generated
golf_host_tick :: proc(self: ^Golf) { run_the_course(self) }

golf_process :: proc(self: ^Golf, delta: f64) {
	events, _, ticks := kboot.boot_pump(&self.boot, delta, now_s())
	golf_step(self, ticks)     // generated: hosts step, clients no-op
	golf_events(self, events)  // generated: dispatch to the event halves you declared
}
```

That's a hosted, joinable game: lobby UI, chat, scoreboard, host/join buttons
(`kboot.boot_host` / `boot_join`), connection lifecycle, and the pump that
drives it all. Your game reacts by declaring **event halves** — plain procs
named for the event (`golf_player_joined`, `golf_entity_spawned`, an
authority-only `golf_player_joined_then` for consequences) that the generated
`golf_events` dispatches to — never callbacks into a half-initialized script,
and never a role branch of your own.

One concept in the join call deserves a sentence now, because it pays off for
the rest of the series: a player joins with a **token** (`ksave.token` — an
env var, or a little file under `user://`). The token *is* their identity.
Crash, restart, rejoin with the same token → same seat, same stats, same
entities. There is no separate reconnect system; identity is just state too.

## Movement: the one exception to "the host writes"

Host-authoritative fields would make *your own avatar* feel like molasses —
every keypress waiting on a round trip. So the toolkit has exactly one other
flavor of replication: fields the entity's **owner** writes,

```odin
x, y: f32 `gd:"owner,interp"`,
```

streamed unreliably at tick rate, and rendered by everyone else with a short
interpolation buffer — smooth through jitter and packet loss. Your machine
moves your avatar with local, zero-latency code; remote screens watch a
slightly-delayed, smoothed version of it. (Hold that thought — "slightly
delayed" becomes post 5.)

Deltas for truth the host owns, streams for motion the owner owns. Disjoint
sets, both just fields, and the word *message* never appeared.

## What this buys you (the part that's hard to see up front)

Structuring state this way feels like discipline until you list what falls
out of it, each "for free" a direct consequence of *state-is-the-protocol*:

- **Drop-in joins** — the registry replays through your factory.
- **Reconnect after a crash** — the token reclaims the seat; the snapshot
  restores the world.
- **Saves** — a save file is the snapshot machinery pointed at disk
  (`ksave.save_write` / `ksave.resume`, post 6).
- **Host migration** — a backup snapshot plus "everyone rejoins the new
  host"; the toolkit automates the choreography (post 6).
- **Single-player** — a session with one seat. Same code. You never build
  the game twice.

None of these are features of the toolkit so much as consequences of the
model. That's the value proposition of learning it: you're not learning six
systems, you're learning one shape that implies six systems.

What's missing is the interesting half: players don't just *watch* state,
they *act* on it — and two players acting on the same chest at once is where
netcode traditionally gets ugly. That's the next post, and it's the toolkit's
best trick.

*Next: [Verbs, not RPCs →](04-verbs-not-rpcs.md)*
