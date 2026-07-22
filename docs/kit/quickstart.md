# Hello, multiplayer — zero to two windows

This page gets you from an empty folder to **two windows moving squares on
both screens** in about ten minutes. Every line below is real, shipped code
from `examples/hello_net/` — copy the folder outright, or type along. (Want to
*feel* it before reading anything? `examples/slopball` in two windows is the
five-minute version: `bash build/build_scripts.sh examples/slopball`, then
run `$GODOT --path examples/slopball` twice, Host in one, Join in the other.)

Prerequisite: the toolchain from [Getting Started](../getting-started.md) —
`nix develop` in this repo, or the installed addon in your own project (then
`addons/odin_godot/build/build_scripts.sh` is the build command below).

## The whole game: two files

A kit game is declarations plus plain procs. You write **no RPCs, no role
branches, no spawn messages, and no interpolation code** — none of that
appears below.

**`scripts/player.odin`** — one player's square. The struct *is* the
netcode: `x`/`y` are owner-streamed (you write your own; every other screen
interpolates them), `pid` rides the host's reliable lane:

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
	pid:    u8 `gd:"replicate"`, // the seat this square belongs to (its color)
	mine:   bool, // set by the census hook: this peer drives this body
	tinted: bool,
}

player_process :: proc(self: ^Player, delta: f64) {
	_ = delta
	if !self.tinted && self.pid != 0 {
		self.tinted = true
		hues := [4]gd.Color{{0.9, 0.5, 0.2, 1}, {0.3, 0.7, 0.9, 1}, {0.5, 0.9, 0.4, 1}, {0.9, 0.4, 0.7, 1}}
		gd.polygon2d_set_color(self.skin, hues[int(self.pid) % 4])
	}
	gd.node2d_set_position(cast(gd.Node2d)self.owner, {self.x, self.y})
}

@(gd_half)
player_spawned :: proc(game: ^HelloNet, self: ^Player, id: knet.Net_Id, owner: knet.Player_Id) {
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

**`scripts/hello.odin`** — the game. One struct field declares the entity
(the tag mints the wire id, the factory, a typed `player_spawn()`, the
census, and the test probes); `boot_attach` brings the stock lobby, chat,
transport, and reconnect; the event *halves* at the bottom are how the game
hears the session (the generated dispatch holds every role gate):

```odin
//gd:extends Node2D
//gd:class HelloNet
package hello_net

import "core:fmt"
import gd "godot:godot"
import kboot "godot:kit/boot"
import kcomms "godot:kit/comms"
import knet "godot:kit/net"
import ksess "godot:kit/session"

DEFAULT_PORT :: 4242
SPEED :: f32(160)

HelloNet :: struct {
	owner:   gd.Node2d,
	ses:     ksess.Session,
	comms:   kcomms.Comms,
	boot:    kboot.Boot,
	player_scene: ^gd.Resource `gd:"entity=Player:1"`,
	me: ^Player,
}

now_s :: knet.now_s

hello_net_ready :: proc(self: ^HelloNet) {
	kboot.boot_attach(&self.boot, cast(gd.Node)self.owner, &self.ses, &self.comms, kboot.Options{
		title = "HELLO, MULTIPLAYER",
		status = "Host a room, or join one at localhost",
		legend = "Arrows move · Enter chat",
		env = "HELLO",
		min_players = 1,
	})
	kboot.boot_entities(&self.boot, self, hello_net_entity_kinds[:])
	switch gd.env_string("HELLO_ROLE", "") {
	case "host": hello_net_on_host(self)
	case "join": hello_net_on_join(self)
	}
}

hello_net_process :: proc(self: ^HelloNet, delta: f64) {
	was := kboot.boot_phase(&self.boot) // read BEFORE the pump: the rising edge
	if was == .Menu {return}
	events, _, _ := kboot.boot_pump(&self.boot, delta, now_s())
	if self.me != nil {
		dx, dy: f32
		if gd.is_action_pressed("ui_right") {dx += 1}
		if gd.is_action_pressed("ui_left") {dx -= 1}
		if gd.is_action_pressed("ui_down") {dy += 1}
		if gd.is_action_pressed("ui_up") {dy -= 1}
		self.me.x = clamp(self.me.x + dx * SPEED * f32(delta), 8, 632)
		self.me.y = clamp(self.me.y + dy * SPEED * f32(delta), 8, 352)
	}
	hello_net_events(self, events)
	if was != .Playing && kboot.boot_phase(&self.boot) == .Playing {
		gd.print_str("HELLO_STARTED") // the world arrived — once
	}
}

@(gd_method)
hello_net_on_host :: proc(self: ^HelloNet) {
	if kboot.boot_phase(&self.boot) != .Menu {return}
	if !kboot.boot_host(&self.boot, kboot.boot_port(&self.boot, DEFAULT_PORT), kboot.boot_name(&self.boot, "player")) {return}
	hello_net_on_start(self)
}

@(gd_method)
hello_net_on_join :: proc(self: ^HelloNet) {
	if kboot.boot_phase(&self.boot) != .Menu {return}
	kboot.boot_join(&self.boot, "127.0.0.1", kboot.boot_port(&self.boot, DEFAULT_PORT), kboot.boot_token(&self.boot), kboot.boot_name(&self.boot, "player"))
}

@(gd_method)
hello_net_on_start :: proc(self: ^HelloNet) {
	if !self.ses.is_host || kboot.boot_phase(&self.boot) == .Playing {return}
	for _, p in self.ses.players {
		if p.connected {spawn_player(self, p.id)}
	}
	ksess.session_start_replicating(&self.ses)
}

@(gd_method)
hello_net_on_chat :: proc(self: ^HelloNet, text: gd.String) {
	if kboot.boot_phase(&self.boot) != .Menu {kboot.boot_chat(&self.boot, text)}
}

spawn_player :: proc(self: ^HelloNet, pid: knet.Player_Id) {
	if _, has := player_owned_by(&self.boot, pid); has {return}
	p, id := player_spawn(&self.boot, owner = pid)
	p.pid = u8(pid)
	p.x = 120 + f32(u64(pid) % 8) * 56
	p.y = 180
	kboot.boot_spawn_send(&self.boot, id)
}

@(gd_half)
hello_net_welcomed :: proc(self: ^HelloNet, me: knet.Player_Id) {
	gd.print_str(fmt.tprintf("HELLO_SEATED me=%d", u64(me)))
}

@(gd_half)
hello_net_player_joined_then :: proc(self: ^HelloNet, id: knet.Player_Id, rejoin: bool) {
	if kboot.boot_phase(&self.boot) == .Playing && !rejoin {spawn_player(self, id)}
}

@(gd_half)
hello_net_entity_spawned :: proc(self: ^HelloNet, id: knet.Net_Id, type: ksess.Entity_Type, owner: knet.Player_Id) {
	_ = type; _ = id; _ = owner
	gd.set_bool(cast(gd.Object)self.boot.ui.root, "visible", false) // a level, applied
}
```

**Lifecycle state lives in
[`boot_phase`](boot.md#the-event-loop), not in bools.** `boot_phase`
is derived from the session, so it is right even for a game that never touched
a boot door. It reports a LEVEL, so a swap that must happen exactly once needs
the rising EDGE: read the phase before `boot_pump` (the only place it rises)
and compare after, as `process` does above. Nothing is stored.

The full `hello.odin` also carries the optional **join-code doors**: with a
relay configured, `on_host` mints a shareable code via `boot_host_coded` and
`on_join` takes a typed one via `boot_join_code`. This page shows the
address-only forms; see the join-codes bullet below.

## The scenes

Two tiny scenes wire it into the editor: `player.tscn` (a `Node2D` with the
Player script and a `Skin` Polygon2D square) and `hello.tscn` (a `Node2D`
with the HelloNet script, its `player_scene` export pointed at
`player.tscn`). `examples/hello_net/*.tscn` are both under 15 lines of text.
Plus the standard `project.godot` (main scene = `hello.tscn`) and the
`odin_godot.gdextension` from the template.

## Run it

```sh
bash build/build_scripts.sh examples/hello_net    # scriptgen + compile
$GODOT --path examples/hello_net &                # window 1: press Host
$GODOT --path examples/hello_net                  # window 2: press Join
```

**Checkpoint:** two colored squares in both windows; arrows move *your*
square, and the other window's copy glides after it. That glide is the
owner-stream + interpolation you declared with `gd:"owner,interp"`
— you wrote none of it.

Then test under real latency: `HELLO_LATENCY=120 $GODOT --path
examples/hello_net` injects 120ms each way (every kit game gets the
`<ENV>_LATENCY/_JITTER/_LOSS` shim from `Options.env`). The remote square
lags visibly; yours never does. `examples/hello_net/run.sh` runs this exact
scenario as its first act — two processes, generated probes, one verdict —
then a second act joins by code through the relay; the
[testing guide](testing.md) is how you grow your own.

## Where to go next

- A **verb** (an action the host must validate — loot, doors, purchases):
  `@(gd_command)` + a `_then` half — [net.md](net.md), or cavecrawl's
  41-line `chest.odin`.
- A **reaction to state changing** (score flash, death jingle):
  a `<class>_<field>_edge` half — [net.md](net.md#edges-class_field_edge--presenting-delta-lane-changes).
- **Physics bodies** (a real RigidBody2D all peers see): `play.Puppet` —
  slopball is the worked example.
- **Save/resume, reconnect, host migration, Steam**: already on — see
  [session.md](session.md) for what the stock stack gave you.
- **Join codes** ("send your friend `KWXP`" instead of an IP): swap
  `boot_host` for `boot_host_coded` and join with `boot_join_code` — the
  full `hello.odin` carries the optional relay branch;
  [netgd.md](netgd.md#join-codes-for-native-enet-codeodin) covers the options.
- **Competitive play** (server authority, prediction, lag comp): the sim
  lane — [quickstart-sim.md](quickstart-sim.md) promotes THIS game, then
  [sim.md](sim.md).
- **Glossary**: halves, census, doors, and integration tests each get a
  paragraph in the [glossary](glossary.md).
