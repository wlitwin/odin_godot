# odin_godot documentation

Write Godot scripts in compiled Odin. These docs are organized as a path: **learn → build →
use → ship.**

## Start here

- **[Getting Started](getting-started.md)**: install the Nix toolchain, build the extension,
  add it to a Godot project, and write + attach your first `.odin` script (a Node that moves
  on `_process`). It's a real, copy-pasteable hello-world, and for multiplayer, the
  [quickstart](kit/quickstart.md) is the next stop.
- **[The onboarding series](onboarding/index.md)** collects seven posts for Godot developers
  coming from GDScript/C#: why compiled scripts, the struct mental model, and the multiplayer
  shift (state-not-messages, verbs-not-RPCs, the two timelines). It's the *why* behind
  everything below. Read it alongside your first build, or whenever the toolkit's way of
  structuring a game feels alien.

## Reference

- **[Authoring Guide](authoring-guide.md)**: the complete feature reference for writing Odin
  scripts:
  - the script struct convention (`owner` first field) and `//gd:` markers
    (`class` / `extends` / `tool` / `icon` / `signal`)
  - `@export`: every Variant type, hint tags (`range` / `enum` / `multiline` / `file` /
    `resource`), groups, defaults, getters/setters
  - lifecycle procs, custom methods (`@(gd_method)`), signals, `@(gd_connect)`, `@onready`
  - multiplayer RPCs (`@(gd_rpc)`)
  - custom resources, global class names, typed cross-script references, autoloads
  - the full `gd.*` ergonomic-helper catalog (a task → one-liner table)
  - editor tooling: `@tool`, `gd.is_editor()`, custom icons, EditorPlugin

## Use it day-to-day

- **[Workflow](workflow.md)**: the dev loop and editor experience:
  - building (`build/build_scripts.sh`) and the project layout it expects
  - live editing: recompile-and-reload on save, plus the manual `script.reload(true)` fallback
  - editor DX: live error squiggles (`_validate`), autocomplete (`ols`), syntax highlighting
  - debugging: `gd.print` / `gd.error`, `lldb`, reading crash backtraces
  - **the honest AOT limitations** (no in-editor breakpoints, recompile-on-save latency, …)
- **[Debugging](debugging.md)**: the deep `lldb` + crash-backtrace reference (what Workflow
  summarizes).
- **[Pure-Odin Events](events.md)**: `events.Event(T)` provides typed one-to-many dispatch at
  direct-call cost for scripts in the same dll (the C#-events-vs-Godot-signals split). It
  covers when to use it vs an engine signal vs batching, the module-boundary rule, and the
  hot-reload resubscribe pattern.
- **[Script Modules](modules.md)**: the opt-in scaling tool for large projects. It splits
  scripts into `res://modules/<name>/` packages, one dll each, rebuilt + hot-swapped
  independently on save. It covers the cost model (when NOT to use them), the no-cross-imports
  rule and why, cross-module communication patterns, reload/collision semantics, and export.

## Build multiplayer: the friendslop toolkit — and the server-authority companion

- **[Multiplayer quickstart](kit/quickstart.md)**: zero to TWO WINDOWS in two small
  files (`examples/hello_net` is its living copy); the [sim twin](kit/quickstart-sim.md)
  then promotes the same game to server authority. Start multiplayer here.
- **[kit/ overview](kit/index.md)** provides reusable multiplayer game systems (`godot:kit/*`):
  host-authoritative sessions with reconnect identity, declarative replication with
  client prediction, chat, items, combat, NPCs, save/resume, moderation, ENet + Steam
  transports, for 2–8 player "you and your friends" games.
- **[kit/sim](kit/sim.md)** is the OTHER netcode, used beside the coop kit rather than
  instead of it, providing server-authoritative rollback/resimulation for contested,
  cheat-resistant, twitch-fair games. Tag fields `predict`, write a `@(gd_tick)`, and
  lag-compensated hitscan, client prediction, and reconcile come generated. It's per-FIELD
  opt-in, so hybrid games can compose.
- **[Timelines: choosing a model](kit/timelines.md)** explains whose timeline each thing
  presents from and who arbitrates disagreement: the four shipped answers (coop,
  predict-self, contested-object, predict-world) with their worked games, and the
  choose-by-what-is-contested guide. Read this when picking between the two kits.
- **[Build a game in a day](kit/build-a-game-in-a-day.md)** is the tutorial: a co-op cave
  crawler from empty scene to Steam invite, the same arc `examples/cavecrawl` proves.
- **[Gameplay recipes: the kit + play recipe](recipes.md)** is the compositional *pattern*
  the tutorial uses without naming: an entity is a struct of `play` primitives, and each
  networked behavior is sliced into seven authority/time slots (State, Cadence, Intent,
  Authority, Prediction, Reconcile, Cue). It includes one worked example (a gun) and five
  real items set against the skeleton. Read this when "how do I structure *this* gameplay
  item?" is the question. It's the multiplayer answer to Godot's component-composition
  articles.

## Learn from the examples

- `examples/cavecrawl` is THE **co-op reference** (see [kit/](kit/index.md)): every
  friendslop-toolkit package in one game, grown brick-by-brick with a latency-injected
  multi-process integration test (`run.sh`) that doubles as the pattern to steal.
- `examples/slopball` / `examples/slopball3d` are the **smallest complete kit games**: a
  physics co-op pitch (engine physics via `play.Puppet`), in 2D and 3D.
- `examples/quickdraw` is the **server-authority reference** (kit/sim): a western duel
  whose premise is lag compensation: hitscan is judged by where the shooter's screen aimed,
  proven by an A/B acceptance test at 240 ms RTT.
- `examples/speedball` is **the contested object** (kit/sim): slopball's soccer premise
  on the other netcode, where every peer predicts the ball and touches resolve locally.
  Read the two side by side to pick a model.
- **[examples/survivors](../examples/survivors/README.md)** is the headline single-player
  example: a complete survivors-like in pure Odin, with a per-file feature map. Its co-op
  layer is the ENGINE-NATIVE (host-authoritative) variant, retained for the interop tests.
- **[examples/coop_arena](../examples/coop_arena/README.md)** is the engine-native
  **peer-authoritative** path end-to-end: one codebase, three modes (single-player, native
  ENet, browser WebRTC with a room-code lobby). It predates the toolkit and shows the raw
  surface the kit absorbs.
- `tests/showcase/`: the smallest "everything wired" pure-Odin scene (coin collector).

## Ship it

- **[Exporting](exporting.md)**: native desktop export (the `OdinExportPlugin`) and web/WASM
  export (the Emscripten SIDE_MODULE + COOP/COEP serving).
- **[Distribution](distribution.md)**: building the drop-in addon with `nix build`,
  cross-compiling the core for Linux/Windows, the consumer install workflow, and the honest
  per-platform build-vs-runtime status.
- **[Publishing](publishing.md)** is the Godot Asset Library runbook: the `release` branch
  (`build/release.sh`), the submission form values, and consumer-facing quirks.

## Design history & internals

These are *not* on the learning path. They record how the engine is built and what was
verified, for contributors:

- [PLAN.md](../PLAN.md): the original architecture and phased delivery plan.
- [design/script-language-api.md](design/script-language-api.md): the
  `ScriptLanguageExtension` / `ScriptExtension` / instance-vtable surface, method by method.
- [design/export-internals.md](design/export-internals.md): how the export plugin compiles +
  bundles scripts per platform.
- [design/web-internals.md](design/web-internals.md): the `when WEB` split, the five wasm
  blockers found and fixed, in-browser verification.
- [design/wasm-spike.md](design/wasm-spike.md): the original Odin → Emscripten SIDE_MODULE
  proof-of-concept.
