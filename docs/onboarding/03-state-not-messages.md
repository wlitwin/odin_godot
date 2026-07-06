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
`net_id`, and an owner. You provide one factory proc — and this is the
detail to sit with — **the same factory runs on every machine, host
included**:

```odin
golf_make_entity :: proc(user: rawptr, type: ksess.Entity_Type,
                         id: knet.Net_Id, owner: knet.Player_Id) -> (rawptr, ^knet.Command_Set) {
	self := cast(^Golf)user
	switch type {
	case HOLE_TYPE:
		node := spawn_scene(self, self.hole_scene)   // instantiate + add_child
		h := rt.script_of(node, Hole)
		return h, &hole_command_set                  // the struct + its generated verbs
	// ... BALL_TYPE, POWERUP_TYPE
	}
	return nil, nil
}
```

There is no "server spawns, then sends a spawn message you handle
differently." The host asks the session to spawn; the session runs *your
factory locally* and tells everyone else to run *the same factory*. Creation
code exists once. A player who joins mid-game? The session replays the
registry through the same factory. A resumed save? Same factory. You have
already written the drop-in-join and load-game code without noticing.

## The ceremony (there barely is one)

Standing this up used to be the intimidating part; `kit/boot` reduced it to
declaring what's yours and attaching:

```odin
golf_ready :: proc(self: ^Golf) {
	ksess.session_set_factory(&self.ses, self, golf_make_entity, golf_free_entity)
	ksess.session_set_command_hook(&self.ses, self, golf_command_hook)   // post 4
	kboot.boot_attach(&self.boot, self.owner, &self.ses, &self.comms, kboot.Options{
		title    = "P U T T P U T T",
		status   = "Host a course, or join one at localhost",
		msg_kind = MSG_SESSION,
		methods  = {"on_host", "on_join", "on_start", "on_chat",
		            "on_packet", "on_peer_left", "on_net_up", "on_net_down"},
	})
}

golf_process :: proc(self: ^Golf, delta: f64) {
	events, _, ticks := kboot.boot_pump(&self.boot, delta, now_s())
	if self.ses.is_host { for _ in 0 ..< ticks { host_tick(self) } }
	for ev in events { react(self, ev) }
}
```

That's a hosted, joinable game: lobby UI, chat, scoreboard, host/join buttons
(`kboot.boot_host` / `boot_join`), connection lifecycle, and the pump that
drives it all. The `events` loop is where your game reacts — a player joined,
an entity spawned, a command was rejected — as plain values you switch on,
never callbacks into a half-initialized script.

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
x, y: f32 `gd:"replicate,interp,owner"`,
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
