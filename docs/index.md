# odin_godot documentation

Use these guides to install odin_godot, write compiled Odin scripts, choose a
multiplayer framework, and export a game.

## Start here

- **[SDK documentation site](https://wlitwin.github.io/odin_godot/)** provides task-based guides for
  setup, scripting, Kit, Replay, and export, plus system diagrams, an interactive
  correction lab, examples, and searchable reference.
- **[Getting Started](getting-started.md)**: install the Nix toolchain, build the extension,
  add it to a Godot project, and write + attach your first `.odin` script (a Node that moves
  on `_process`). Continue to the [quickstart](kit/quickstart.md) for multiplayer.
- **[The onboarding series](onboarding/index.md)** collects seven posts for Godot developers
  coming from GDScript/C#: compiled scripts, struct composition, replicated state,
  predicted commands, and presentation timing. Read it alongside your first build.

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
  - `gd.*` helpers grouped by task
  - editor tooling: `@tool`, `gd.is_editor()`, custom icons, EditorPlugin
- **[Shared API conventions](authoring-guide.md#api-conventions-shared-by-kit-and-replay)**:
  Odin names, generated prefixes, owner lifetimes, and the normal Kit/Replay frame loops.

<a id="use-it-day-to-day"></a>

## Development workflow

- **[Workflow](workflow.md)** covers building, editing, and debugging scripts:
  - building (`build/build_scripts.sh`) and the project layout it expects
  - live editing: recompile-and-reload on save, plus the manual `script.reload(true)` fallback
  - editor support: inline errors (`_validate`), autocomplete (`ols`), syntax highlighting
  - debugging: `gd.print` / `gd.error`, `lldb`, reading crash backtraces
  - **AOT limitations** (no in-editor breakpoints, recompile-on-save latency, …)
- **[Debugging](debugging.md)** expands on Workflow's `lldb` and crash-backtrace
  guidance.
- **[Pure-Odin Events](events.md)** explains typed one-to-many dispatch through
  `events.Event(T)` for scripts in the same dll. It covers direct-call cost,
  comparison with engine signals and batching, module boundaries, and
  resubscribing after hot reload.
- **[Script Modules](modules.md)** describes splitting a large project into
  `res://modules/<name>/` directories, each compiled to its own dll and rebuilt
  independently on save. It explains full-build and save-time costs, import
  isolation, communication between modules, reload, collisions, and export.
  It also covers organization within a single dll through script subpackages,
  and **`res://shared/`** for types, constants, and pure procedures that several
  modules may import.

## Build multiplayer with Kit

- **[Multiplayer quickstart](kit/quickstart.md)** builds the smallest two-peer
  session in two source files (`examples/hello_net` is the maintained copy).
  The [simulation quickstart](kit/quickstart-sim.md) then moves its fast state
  to server authority.
- **[kit/ overview](kit/index.md)** provides reusable multiplayer game systems (`godot:kit/*`):
  sessions, reconnect identity, declarative replication, commands, chat,
  items, combat, NPC helpers, save/resume, moderation, and transport adapters.
- **[kit/sim](kit/sim.md)** provides fixed-tick, server-authoritative prediction
  and reconciliation for contested state. It composes with ordinary session
  replication on a per-field basis and includes bounded lag-compensation tools.
- **[Timelines: choosing a model](kit/timelines.md)** compares authority and
  display timing for coop, predict-self, contested-object, and predict-world.
  Use its worked games and interaction-based selection guide to choose a Kit
  model.
- **[Build a game in a day](kit/build-a-game-in-a-day.md)** follows a coop cave
  crawler from scene setup through Steam invites, using `examples/cavecrawl`
  as the reference implementation.
- **[Gameplay recipes: the kit + play recipe](recipes.md)** shows how to compose
  an entity from `play` structs and divide a networked behavior into seven
  responsibilities: State, Cadence, Intent, Authority, Prediction, Reconcile,
  and Presentation. A worked gun example and five gameplay items show where
  their fields, commands, and hooks belong.

## Learn from the examples

The experimental [Replay library](../replay/getting-started.md) provides a
complete-world simulation model alongside Kit. Start with its local Timeline or
Godot Session lifecycle; add Party/Room for enrollment and host migration, or
P2P for deterministic peer rollback. The
[starter project](../build/template/replay/README.md) uses Session for offline
and native server/client play. [Replay Loot](../examples/replay_loot/README.md)
is the headless model; [Hello](../examples/replay_hello/README.md) demonstrates
lower-level runners and diagnostics. The
[support envelope](../replay/support.md) distinguishes implemented policies
from deployment and full-game parity claims. Kit and the original games remain
independently runnable.

- `examples/cavecrawl` is the **co-op reference** (see [kit/](kit/index.md)):
  the main Kit packages in one game, covered by a latency-injected,
  multi-process integration test (`run.sh`).
- `examples/slopball` / `examples/slopball3d` are small complete Kit games:
  coop soccer with engine physics through `play.Puppet`, in 2D and 3D.
- `examples/quickdraw` is the **server-authority reference** (kit/sim): a western duel
  that exercises lag-compensated hitscan with an A/B acceptance test at
  240 ms RTT.
- `examples/speedball` uses kit/sim for the same soccer game, with every peer
  predicting the ball so local touches respond immediately. Compare it with
  Slopball to see the effect of changing simulation models.
- **[examples/survivors](../examples/survivors/README.md)** is a complete
  single-player survivors-like in pure Odin with a per-file feature map.
  Its engine-native host-authoritative coop layer is retained for interop tests.
- **[examples/coop_arena](../examples/coop_arena/README.md)** is the engine-native
  **peer-authoritative** path end-to-end: one codebase, three modes (single-player, native
  ENet, browser WebRTC with a room-code lobby). It predates the toolkit and shows the raw
  networking calls that Kit's helpers now coordinate.
- `tests/showcase/` is a minimal pure-Odin coin-collector scene.

<a id="ship-it"></a>

## Export and distribution

- **[Exporting](exporting.md)**: native desktop export (the `OdinExportPlugin`) and web/WASM
  export (the Emscripten SIDE_MODULE + COOP/COEP serving).
- **[Distribution](distribution.md)**: building the drop-in addon with `nix build`,
  cross-compiling the core for Linux/Windows, the consumer install workflow, and the
  per-platform build and runtime verification status.
- **[Publishing](publishing.md)** is the Godot Asset Library runbook: the `release` branch
  (`build/release.sh`), the submission form values, and consumer-facing quirks.

## Design history & internals

These contributor records describe implementation decisions, earlier development,
and the behavior verified at the time:

- [PLAN.md](../PLAN.md): the original architecture and phased delivery plan.
- [design/script-language-api.md](design/script-language-api.md): the
  `ScriptLanguageExtension` / `ScriptExtension` / instance-vtable surface, method by method.
- [design/export-internals.md](design/export-internals.md): how the export plugin compiles +
  bundles scripts per platform.
- [design/native-boundary.md](design/native-boundary.md): the core↔scripts ABI fingerprint,
  compiler compatibility rule, allocator ownership, and why it adds no dispatch cost.
- [design/web-internals.md](design/web-internals.md): the `when WEB` split, the five wasm
  blockers found and fixed, in-browser verification.
- [design/wasm-spike.md](design/wasm-spike.md): the original Odin → Emscripten SIDE_MODULE
  proof-of-concept.

- [Replay editor authoring workflow](../replay/editor/README.md)
