# odin_godot documentation

Write Godot scripts in compiled Odin. Start with the addon
[README](../README.md) for installation, then choose a guide below for setup,
authoring, multiplayer, or export.

## Start here

- **[Getting Started](getting-started.md)** — install the Odin toolchain, copy the starter,
  build, and write + attach your first `.odin` script (a Node that moves on `_process`).

## Reference

- **[Authoring Guide](authoring-guide.md)** — the complete feature reference: the script
  struct convention (`owner` first field) and `//gd:` markers, `@export` of every type,
  lifecycle, methods, signals, resources, autoloads, cross-script access, and the `gd.*`
  helper catalog.
- **[Workflow](workflow.md)** — the build/edit/iterate loop and editor tools
  (autocomplete, goto-definition, rebuild-on-save), with the limits of ahead-of-time scripting.

## Build multiplayer

- **[Replay](replay.md)** — the experimental value-world, rollback and session
  library, with a separately included offline/native multiplayer starter.

- **[Kit](kit/index.md)** — reusable multiplayer systems under
  `godot:kit/*`: host-authoritative sessions with reconnect identity, declarative
  replication with client prediction, chat, items, combat, NPCs, save/resume,
  moderation, and ENet + Steam transports — for 2-8 player co-op games.
- **[Build a game in a day](kit/build-a-game-in-a-day.md)** — the tutorial arc.
- **[Gameplay recipes](recipes.md)** — embedding `play` fields in entities and
  assigning State, Cadence, Intent, Authority, Prediction, Reconcile, and Cue
  responsibilities across peers and clocks. A gun example and five gameplay
  items illustrate the pattern. The page identifies older API examples that
  remain as design references.

## Ship

- **[Exporting](exporting.md)** — compiling and bundling scripts for desktop and web exports.
- **[Debugging](debugging.md)** — `gd.print`/`gd.error` logging, native `lldb`, and reading
  crash backtraces with Odin proc names.
- **[Native boundary](design/native-boundary.md)** — compiler compatibility, the pre-boot ABI
  fingerprint, ownership, and performance characteristics of the core↔scripts split.
