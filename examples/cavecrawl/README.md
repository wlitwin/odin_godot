# cavecrawl — the co-op reference

This is the broadest co-op Kit example: a drop-in cave crawler that exercises
sessions with reconnect
identity, declarative replication, predicted commands with `_then`
consequences, the generated entity factory, items and chests, host-validated
combat, hostile AI, positional pings, quit-and-resume saves, host migration,
and the ENet↔Steam transport swap. It was grown one phase at a time (lobby →
chat → lootable world → predicted combat → dwellers → saves), and
[build-a-game-in-a-day](../../docs/kit/build-a-game-in-a-day.md) retraces
that arc brick by brick — when a step there feels terse, the corresponding
file here is the long answer.

The example contains about 4,500 hand-written lines and is deliberately the largest
example — the place to see every pattern coexisting in one game. For the
smallest complete kit game read [slopball](../slopball/) first; for the
server-authority model read [quickdraw](../quickdraw/) and
[speedball](../speedball/) ([choosing a model](../../docs/kit/timelines.md)).

The multiplayer author surface is the entity files — a struct with
`gd:"replicate"` tags, verbs as `@(gd_command)` procs, a `_process` that
dresses from fields:

```odin
@(gd_command = "predict")
door_toggle :: proc(self: ^Door, px: f32, py: f32) -> bool {
	if !kinter.in_range({px, py, 0}, {self.x, self.y, 0}, REACH) {return false}
	self.open = !self.open
	return true
}
```

One class, many files, split the way a real game is:

| file | owns |
| --- | --- |
| `cavecrawl.odin` | the vocabulary, the CaveLobby state, ready/process |
| `net.odin` | identity + the Host/Join/Steam doors (the transport forwards are generated) |
| `world.odin` | census hooks, spawns, the interact prompt |
| `input.odin` | keys/mouse and the player verbs they drive |
| `rocks.odin` | peer-owned projectile visuals — the zero-felt-lag story |
| `host.odin` | the authority: game tick, dweller brains |
| `save.odin` | the run on disk (session snapshot + game blob) |
| `queries.odin` | read-only windows for HUDs and test drivers |
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
