# Replay Hello and Loot views

New Godot scenes built on Replay. The original `hello_net`, `hello_sim`,
Cavecrawl, and Scrapyard projects remain in their original locations. These
Hello and Loot scenes remain **offline**; the separate Network scene now uses
the new server/client/observer runner.

From the repository root:

```sh
# Interactive Hello: arrows move, Space/Enter fires, Escape restarts.
nix develop --command bash examples/replay_hello/play.sh

# Interactive loot: Space corrects the predicted winner, Escape restarts.
nix develop --command bash examples/replay_hello/play.sh loot

# Builds both scenes and exercises real Godot processes headlessly.
nix develop --command bash examples/replay_hello/run.sh

# Four-process networking gate, including injected 240 ms round-trip latency.
nix develop --command bash examples/replay_hello/network_run.sh

# Interactive network host, then join from another terminal.
nix develop --command bash examples/replay_hello/play.sh network
REPLAY_ROLE=client nix develop --command bash examples/replay_hello/play.sh network
```

The Network scene accepts `REPLAY_ROLE=host|server|client|observer`, `REPLAY_PORT`,
`REPLAY_ADDRESS`, and receive-delay `REPLAY_LATENCY` (milliseconds). `server` is an
avatarless authority; `host` has a local player. `REPLAY_TOKEN` provides a
deterministic identity label for tests; normal clients generate random credentials.
Persistence across app restarts and host migration remain future work.

The fault decorator also accepts `REPLAY_JITTER` in milliseconds and
`REPLAY_LOSS`/`REPLAY_DUPLICATE` in packets per 10,000. Loss/duplication affect
unreliable traffic; reliable ordering/delivery is preserved. For example:

```sh
REPLAY_JITTER=20 REPLAY_LOSS=1000 REPLAY_DUPLICATE=1000 \
  nix develop --command bash examples/replay_hello/network_run.sh
```

The gameplay gate requires acknowledged delta traffic on every participant,
alongside movement, action, state, and effect assertions.

The scripts set the collection root and scripts DLL path for the engine; the
project has its own name and build outputs. `REPLAY_PREBUILT=1` skips compilation
only when running the acceptance gate against already current binaries.

## Hello

The script uses the shared `game.Timeline` runtime alias directly; generated Godot
registration stays separate from the pure model package.

`shared/hello/game.odin` contains the complete simulation, shared with native
tests: frame-owned actors, static kinematic collision, fire cooldowns, and
projectile creation/expiry. `scripts/hello.odin` samples devices, advances fixed
ticks, commits local results, and presents copies through `replay/godot`.

The offline Hello scene's second avatar is a stationary reference. Both avatars
are player-controlled in the separate Network scene.
Short button presses are buffered across render frames that produce no tick.
Ordinary pause discards buffered gameplay edges and fixed-clock remainder. A
control already held when pausing or resuming must be released before it can act
again; presses made entirely while paused do not become deferred gameplay.
Normal local state is immediately confirmed. Explicit playback rewind creates a
fresh epoch from a retained frame; it does not rewrite already committed history
inside the original epoch.

The test walks and fires using Godot's Input API, waits for projectile expiry,
rewinds to a retained live-projectile frame, and verifies that its scene instance
returns without replaying the historical muzzle effect. It also audits the real
gameplay state after presentation.

## Loot

`scripts/loot.odin` imports the unchanged M1 loot model from
`godot:examples/replay_loot/game`. This example therefore requires a repository
checkout rather than only a packaged addon. It shows the blue player's predicted
inventory transfer, then lets you correct the action to the orange player.

The complete world is revised; the presentation journal cancels the original
take and begins the replacement while keeping the unchanged projectile effect.
Repeated correction produces no duplicate effects. The fixture intentionally
leaves that interaction unconfirmed and advances by commands for inspection.

## Validation

`run.sh` requires `REPLAY_HELLO_OK` and `REPLAY_LOOT_VIEW_OK` and rejects script
errors, engine errors, and scenario failures. It builds on the engine-free
`tests/replay` and `tests/replay_view` suites, including a WASM type-check of the
instantiated view/clock/adapter/game surface. The broader [input/history/recording acceptance](../../tests/replay_hello_input/README.md)
now also runs real Chrome workflows. These are technical behavior checks, not a
network comparison or a claim of human play-feel parity.


Set the scene’s `debug_enabled` inspector property or launch with `REPLAY_DEBUG=1`
for the [local diagnostic overlay](../../replay/godot/debug.md). F8 toggles the panel
and F9 explicitly audits recent replayable history. It is disabled by default.

The same option enables the [local history dock](../../replay/godot/scrubber.md).
F10 pauses for inspection; its slider paints retained frames without changing the
live world. Resume keeps the original future, while Branch starts from the selected
frame under a fresh presentation epoch. F8 can hide the audit panel while leaving
the dock visible. Input held during inspection must be released before it controls
the resumed game. This is an offline authoring workflow, independent of the network
scene and the original Hello projects.

With `REPLAY_DEBUG=1`, F10 opens local history inspection. Choose a retained tick
and a field, then Apply to preview. Reset or Resume discards edits; Branch starts
from the edited frame. Game invariants are checked before accepting each edit.
See [ownership, supported values and limits](../../replay/godot/scrubber.md).

The history dock also exports a portable recent recording: `user://hello.rplrec`
on native (override with `REPLAY_RECORDING_PATH`), or a browser download. Export
uses original history; preview edits are recorded after Branch. The separate
[headless verifier](../../replay/diagnostic/recording.md#godot-export-and-hello-verifier)
replays the file with Hello's shared model and reports the first mismatch.

**Open recording** loads a native `.rplrec` file or browser file selection. Play
and the slider inspect recorded frames; Details shows verification results. Return
to game restores the original pause, while Continue from recording starts a new
local branch. Rejected replacements keep the previous loaded recording. See the
[playback ownership and limits](../../replay/diagnostic/playback.md).
