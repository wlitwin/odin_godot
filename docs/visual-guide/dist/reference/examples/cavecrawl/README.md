# cavecrawl — the co-op reference

This co-op cave crawler combines Kit's session, replication and interaction APIs
in one runnable game. Sessions retain player identity across reconnects; tagged
entity fields replicate state; predicted Kit commands give local feedback before
the host validates them. A command's `_then` hook applies accepted consequences
that affect other entities. The game also includes items and chests, host-validated
combat, hostile AI, positional pings, quit-and-resume saves, host migration,
and the ENet↔Steam transport swap. Follow
[build-a-game-in-a-day](../../docs/kit/build-a-game-in-a-day.md) for a staged
walkthrough, then use the file table below to find each feature's implementation.

The example contains about 4,500 hand-written lines and shows these patterns
working together. For the
smallest complete kit game read [slopball](../slopball/) first; for the
server-authority model read [quickdraw](../quickdraw/) and
[speedball](../speedball/) ([choosing a model](../../docs/kit/timelines.md)).

Author multiplayer behavior in the entity files: a struct declares replicated
fields with `gd:"replicate"` tags, `@(gd_command)` procedures request validated
changes, and `_process` updates the Godot view from those fields:

```odin
@(gd_command = knet.ACTION_OWNER_PREDICTED)
door_toggle :: proc(self: ^Door, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	self.open = !self.open
	return true
}
```

The lobby class spans several files; each entity has its own file:

| file | owns |
| --- | --- |
| `cavecrawl.odin` | the vocabulary, the CaveLobby state, ready/process |
| `net.odin` | identity + the Host/Join/Steam doors (the transport forwards are generated) |
| `world.odin` | census hooks, spawns, the interact prompt |
| `input.odin` | keys/mouse and the player verbs they drive |
| `rocks.odin` | projectile visuals spawned locally by the firing peer |
| `host.odin` | the authority: game tick, dweller brains |
| `save.odin` | the run on disk (session snapshot + game blob) |
| `queries.odin` | read-only queries for HUDs and test drivers |
| `spelunker/chest/door/pickup/dweller/relic.odin` | the entities, a file each |

```sh
bash build/build_scripts.sh examples/cavecrawl
$GODOT --path examples/cavecrawl          # host, join from a second window

bash examples/cavecrawl/run.sh            # integration test: multiple real ENet processes,
                                          # 120ms injected latency (CAVECRAWL_OK)
```

The integration test (`run.sh` + `cave_test.gd`) is a reusable pattern for
testing a game: real processes over real sockets drive the `@(gd_method)`
surface and assert against log lines. Loot
races, predicted combat under latency, a kill mid-flight, quit-and-resume,
and a host handover all run headless from `tests/run_all.sh`.

WASD walk · E use · click throw · Q drop · G set down · R heal · Tab scores
· Enter chat. Env: `CAVE_PORT` · `CAVE_NAME` · `CAVE_TOKEN` (distinct
same-machine identities) · `CAVE_STEAM=0` (force ENet when Steam is
running; Steam lobbies use the Spacewar app id, see
[steamgd](../../docs/kit/steamgd.md)).
