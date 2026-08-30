# odin_godot documentation

Write Godot scripts in compiled Odin. New here? Start at the addon
[README](../README.md), then follow this path: **learn → build → use → ship.**

## Start here

- **[Getting Started](getting-started.md)** — install the Odin toolchain, copy the starter,
  build, and write + attach your first `.odin` script (a Node that moves on `_process`).

## Reference

- **[Authoring Guide](authoring-guide.md)** — the complete feature reference: the script
  struct convention (`owner` first field) and `//gd:` markers, `@export` of every type,
  lifecycle, methods, signals, resources, autoloads, cross-script access, and the `gd.*`
  helper catalog.
- **[Workflow](workflow.md)** — the day-to-day build/edit/iterate loop, editor DX
  (autocomplete, goto-definition, rebuild-on-save), and the honest limits of AOT scripting.

## Build multiplayer

- **[The friendslop toolkit](kit/index.md)** — reusable multiplayer systems under
  `godot:kit/*`: host-authoritative sessions with reconnect identity, declarative
  replication with client prediction, chat, items, combat, NPCs, save/resume,
  moderation, and ENet + Steam transports — for 2-8 player co-op games.
- **[Build a game in a day](kit/build-a-game-in-a-day.md)** — the tutorial arc.
- **[Gameplay recipes](recipes.md)** — the compositional pattern for `kit` + `play`: an
  entity is a struct of `play` primitives, and each networked behavior is sliced into seven
  authority/time slots (State, Cadence, Intent, Authority, Prediction, Reconcile, Cue). One
  worked gun, five real items against the skeleton — the multiplayer answer to Godot's
  component-composition pattern.

## Ship

- **[Exporting](exporting.md)** — compiling and bundling scripts for desktop and web exports.
- **[Debugging](debugging.md)** — `gd.print`/`gd.error` logging, native `lldb`, and reading
  crash backtraces with Odin proc names.
- **[Native boundary](design/native-boundary.md)** — compiler compatibility, the pre-boot ABI
  fingerprint, ownership, and performance characteristics of the core↔scripts split.
