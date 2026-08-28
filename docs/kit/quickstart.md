# Hello, multiplayer with session replication

This guide builds `examples/hello_net`: two Godot windows, one player-controlled
square per window, with both squares visible to both players. It introduces the
default Kit stack:

- a host-authoritative session and roster;
- generated entity spawning and lookup;
- owner-streamed movement with interpolation on remote peers;
- reliable replicated fields for shared state; and
- the stock lobby, chat, transport, and reconnect flow.

The guide uses focused excerpts. The complete, buildable sources are
[`hello.odin`](../../examples/hello_net/scripts/hello.odin) and
[`player.odin`](../../examples/hello_net/scripts/player.odin).

## Prerequisite

Complete [Getting Started](../getting-started.md) first. In this repository,
enter `nix develop` so that `odin` and `$GODOT` refer to the pinned tools. In an
installed addon, use `addons/odin_godot/build/build_scripts.sh` in place of the
repository build script shown below.

## Build and run the example

From the repository root:

```sh
bash build/build_scripts.sh examples/hello_net
$GODOT --path examples/hello_net &
$GODOT --path examples/hello_net
```

Select **Host** in the first window and **Join** in the second. Arrow keys move
the square owned by the active window. A remote square is deliberately rendered
slightly behind its owner so that Kit can interpolate between received samples.

If this checkpoint fails, check the build output first, then confirm that both
processes use the same build and that port `4242` is available.

## 1. Declare a replicated entity

`Player` is an ordinary Odin script struct. The field tags select how each value
is replicated:

```odin
//gd:extends Node2D
//gd:class Player
package hello_net

import gd "godot:godot"
import knet "godot:kit/net"

Player :: struct {
	owner:  gd.Node2d,
	skin:   gd.Polygon2d `gd:"onready=Skin"`,
	net_id: knet.Net_Id,
	x, y:   f32 `gd:"owner,interp,wire=f16"`,
	pid:    u8 `gd:"replicate"`,
	mine:   bool,
	tinted: bool,
}
```

| Field | Meaning |
| --- | --- |
| `net_id` | Stable entity identifier assigned by the session. Generated entity helpers require this field. |
| `x`, `y` | The entity owner writes these values. Other peers receive the stream and interpolate it. `wire=f16` reduces their encoded size. |
| `pid` | The host writes this value and sends changes reliably on the delta lane. |
| `mine`, `tinted` | Local implementation state. Untagged fields do not cross the network. |

The script renders the current presentation values each frame. The same proc
runs for local and remote entities:

```odin
player_process :: proc(self: ^Player, delta: f64) {
	_ = delta
	if !self.tinted && self.pid != 0 {
		self.tinted = true
		hues := [4]gd.Color{
			{0.9, 0.5, 0.2, 1}, {0.3, 0.7, 0.9, 1},
			{0.5, 0.9, 0.4, 1}, {0.9, 0.4, 0.7, 1},
		}
		gd.polygon2d_set_color(self.skin, hues[int(self.pid) % 4])
	}
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
}
```

For the owning player, `x` and `y` are the values just written by local input.
For every other player, Kit has already replaced them with interpolated
presentation values before `_process` reads them.

## 2. Register the entity scene

The game script owns the session components and exports the scene used to create
players:

```odin
HelloNet :: struct {
	owner: gd.Node2d,
	ses:   ksess.Session,
	comms: kcomms.Comms,
	boot:  kboot.Boot,

	player_scene: ^gd.Resource `gd:"entity=Player:1"`,
	me: ^Player,
}
```

The `entity=Player:1` tag associates wire type `1` with `Player` and generates:

- `hello_net_entities`, which installs the entity factory;
- `player_spawn`, `player_of`, `player_owned_by`, and `player_ids`;
- spawn/free bookkeeping hooks; and
- scalar probes used by the integration-test harness.

Assign `player.tscn` to `player_scene` in the Inspector. Entity type numbers are
part of the wire protocol, so keep them stable once compatible builds may meet.

## 3. Attach the standard stack

Set up Kit from the game's `_ready` proc:

```odin
hello_net_ready :: proc(self: ^HelloNet) {
	kboot.boot_attach(
		&self.boot,
		cast(gd.Node)self.owner,
		&self.ses,
		&self.comms,
		kboot.Options{
			title = "HELLO, MULTIPLAYER",
			status = "Host a room, or join one at localhost",
			legend = "Arrows move · Enter chat",
			env = "HELLO",
			min_players = 1,
		},
	)
	hello_net_entities(self, &self.boot)
}
```

`boot_attach` creates the stock UI, initializes the Godot transport adapter,
wires the session and chat packages, and connects the standard signal methods.
`Options.env = "HELLO"` also defines the prefix for settings such as
`HELLO_PORT`, `HELLO_NAME`, `HELLO_TOKEN`, and the link simulator variables used
later in this guide.

Call the generated `hello_net_entities` after `boot_attach`. It connects the
entity scenes and generated event dispatch to the initialized `Boot` value.

## 4. Host, join, and start

The stock lobby calls these `@(gd_method)` procedures. Authority-specific
lifecycle work remains explicit: only the host creates the initial entities and
starts replication.

```odin
@(gd_method)
hello_net_on_host :: proc(self: ^HelloNet) {
	if kboot.boot_phase(&self.boot) != .Menu {return}
	if !kboot.boot_host(
		&self.boot,
		kboot.boot_port(&self.boot, 4242),
		kboot.boot_name(&self.boot, "player"),
	) {return}
	hello_net_on_start(self)
}

@(gd_method)
hello_net_on_join :: proc(self: ^HelloNet) {
	if kboot.boot_phase(&self.boot) != .Menu {return}
	kboot.boot_join(
		&self.boot,
		"127.0.0.1",
		kboot.boot_port(&self.boot, 4242),
		kboot.boot_token(&self.boot),
		kboot.boot_name(&self.boot, "player"),
	)
}

@(gd_method)
hello_net_on_start :: proc(self: ^HelloNet) {
	if !self.ses.is_host || kboot.boot_phase(&self.boot) == .Playing {return}
	for _, player in self.ses.players {
		if player.connected {spawn_player(self, player.id)}
	}
	ksess.session_start_replicating(&self.ses)
}
```

The full example also supports relay-backed join codes. Address-based hosting is
enough for the first run; see [Native ENet join codes](netgd.md#native-enet-join-codes)
when you need the relay flow.

## 5. Spawn one player entity per seat

Spawning has two stages: create and initialize the entity locally, then send its
spawn record.

```odin
spawn_player :: proc(self: ^HelloNet, pid: knet.Player_Id) {
	if _, exists := player_owned_by(&self.boot, pid); exists {return}
	p, id := player_spawn(&self.boot, owner = pid)
	p.pid = u8(pid)
	p.x = 120 + f32(u64(pid) % 8) * 56
	p.y = 180
	kboot.boot_spawn_send(&self.boot, id)
}
```

`player_spawn` uses the generated factory and returns a typed pointer.
`boot_spawn_send` serializes the initialized fields. Call it only after all
spawn-time values have been assigned.

When a player joins after the game has started, an authority-only generated
event half creates that player's entity:

```odin
@(gd_half)
hello_net_player_joined_then :: proc(
	self: ^HelloNet,
	id: knet.Player_Id,
	rejoin: bool,
) {
	if kboot.boot_phase(&self.boot) == .Playing && !rejoin {
		spawn_player(self, id)
	}
}
```

The `_then` suffix is significant: script generation routes this consequence on
the authority. The proc still contains the game-specific decision about whether
this event needs a new entity.

## 6. Track the locally owned entity

Generated entity hooks maintain any small amount of game-specific bookkeeping:

```odin
@(gd_half)
player_spawned :: proc(
	game: ^HelloNet,
	self: ^Player,
	id: knet.Net_Id,
	owner: knet.Player_Id,
) {
	_ = id
	if owner == game.ses.me {
		self.mine = true
		game.me = self
	}
}

@(gd_half)
player_freed :: proc(game: ^HelloNet, self: ^Player, id: knet.Net_Id) {
	_ = id
	if self == game.me {game.me = nil}
}
```

These hooks run when the generated entity census changes. Use the later
`<game>_entity_spawned` session event for presentation that depends on replicated
spawn fields. In particular, place a new node there so it does not render one
frame at the scene's default origin:

```odin
@(gd_half)
hello_net_entity_spawned :: proc(
	self: ^HelloNet,
	id: knet.Net_Id,
	type: ksess.Entity_Type,
	owner: knet.Player_Id,
) {
	_ = type
	_ = owner
	if p, ok := player_of(&self.boot, id); ok {
		gd.node2d_set_position(cast(gd.Node2d)p.owner, {p.x, p.y})
	}
	gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false)
}
```

At this point the spawn fields have been applied on every peer.

## 7. Pump the session and move the local player

`boot_pump` must run once per active frame. It advances the transport, session,
replication clocks, chat, and any attached simulation lane, then returns the
events generated during that work.

```odin
hello_net_process :: proc(self: ^HelloNet, delta: f64) {
	was := kboot.boot_phase(&self.boot)
	if was == .Menu {return}

	events, _, _ := kboot.boot_pump(&self.boot, delta, knet.now_s())
	if self.me != nil {
		dx, dy: f32
		if gd.is_action_pressed("ui_right") {dx += 1}
		if gd.is_action_pressed("ui_left")  {dx -= 1}
		if gd.is_action_pressed("ui_down")  {dy += 1}
		if gd.is_action_pressed("ui_up")    {dy -= 1}
		self.me.x = clamp(self.me.x + dx * 160 * f32(delta), 8, 632)
		self.me.y = clamp(self.me.y + dy * 160 * f32(delta), 8, 352)
	}
	hello_net_events(self, events)

	if was != .Playing && kboot.boot_phase(&self.boot) == .Playing {
		gd.print_str("HELLO_STARTED")
	}
}
```

`boot_phase` is derived from session state. Read it before and after the pump
when you need the frame on which a phase changes; do not maintain a second
`started` flag for the same state.

This movement model is intentionally owner-authoritative: a client writes its
own position directly. It is appropriate for cooperative play among invited
peers, but the host cannot use these coordinates as cheat-resistant truth. Use
the [simulation quickstart](quickstart-sim.md) when the authority must derive
movement from validated inputs.

## Test with latency and packet loss

`Options.env` enables the built-in link simulator:

```sh
HELLO_LATENCY=120 HELLO_JITTER=20 HELLO_LOSS=5 \
  $GODOT --path examples/hello_net
```

The values are one-way latency in milliseconds, jitter in milliseconds, and
loss as a percentage. Under latency, the local square should still respond
immediately while the remote square follows on its interpolation timeline.

The example's automated test launches real headless processes, verifies the
replicated state, and exercises join codes:

```sh
bash examples/hello_net/run.sh
```

See [Integration-test your game](testing.md) before adapting that harness.

## Next steps

- Read [kit/net](net.md) to add a host-validated `@(gd_command)` action or a
  replicated-field edge handler.
- Read [kit/session](session.md) for reconnect behavior, ownership transfer,
  late joins, moderation, backup hosts, and app messages.
- Use [`play.Puppet`](play.md#owner-simulated-physics-with-playpuppet)
  for a shared Godot `RigidBody2D` or `RigidBody3D` in the co-op model.
- Continue to [Server authority and client prediction](quickstart-sim.md) for
  `gd:"predict"`, fixed ticks, input validation, and reconciliation.
- Use [Build a multiplayer game](build-a-game-in-a-day.md) for a broader tour of
  chat, interaction, items, combat, AI, saves, and Steam.
