# odin_godot

**Write Godot scripts in [Odin](https://odin-lang.org/).** odin_godot is a Godot 4.7
GDExtension implementing the `ScriptLanguageExtension` API. Attach a `.odin` file
to a Godot node; generated registration connects its lifecycle procedures,
methods, signals, and Inspector properties to the engine. Scripts compile ahead
of time to native code and dispatch through a typed registry. The SDK supports
custom resources, autoloads, editor tools, multiplayer RPCs, hot reload, and
native and WebAssembly exports. A Nix flake pins the development toolchain.

> The recorded verification summary covers a 39-test end-to-end suite, including
> the showcase, example co-op runs, and Asset-Library drop-in layout, through
> `nix develop --command bash tests/run_all.sh`. It also includes 7 browser-gated
> web tests that verify WASM exports in headless Chrome when available. Examples
> include a pure-Odin coin-collector
> (`tests/showcase/`), a complete top-down arena shooter (`examples/survivors/`), a
> drop-in co-op cave crawler built with the Kit multiplayer toolkit
> (`examples/cavecrawl/`), and a server-authoritative western duel with lag-compensated
> hitscan on the kit/sim lane (`examples/quickdraw/`, tested at 240 ms RTT). All of
> them use zero GDScript gameplay code.

<a id="what-you-can-do-the-60-second-tour"></a>

## Script example and SDK features

```odin
//gd:extends Area2D            // base Godot class
//gd:class Coin                // global class_name
package game_scripts

import gd "godot:godot"

Coin :: struct {
	owner:     gd.Area2d,                        // first field stores the engine node handle
	collected: gd.Signal1(int) `gd:"args=value"`, // typed signal field -> collected(value: int)
	value:     gd.Int `gd:"export,range=1:100"`, // @export var with an Inspector slider
	taken:     bool,                             // untagged = private per-instance state
}

coin_ready :: proc(self: ^Coin) {            // lifecycle, matched by name
	if self.value == 0 { self.value = 1 }
}

// Auto-wire body_entered -> this method on _ready (no manual connect call):
@(gd_method, gd_connect = "body_entered")
coin_collect :: proc(self: ^Coin, body: gd.Node2d) {
	if self.taken { return }
	self.taken = true
	coin_emit_collected(self, i64(self.value))   // typed emitter generated from the signal field
	gd.node_queue_free(self.owner)               // gd.* helper queues node deletion
}
```

In the example, `self` points to script data and `self.owner` is the Godot node
handle. The generated `godot` binding exposes the engine API as typed Odin. The `gd.*`
helpers wrap common engine calls and their argument conversions:

| | |
|---|---|
| **Lifecycle** | `_ready` / `_process` / `_physics_process` / `_enter_tree` / `_exit_tree` by proc name |
| **`@export`** | every Variant type + Inspector hints (range/enum/multiline/file/resource), groups, defaults, getters/setters, `@onready` refs |
| **Signals** | declare (typed `gd.Signal0`…`Signal4` struct fields), emit (typed generated helper), connect (`gd.connect_to` / `@(gd_connect)`) |
| **Methods** | `@(gd_method)`: callable from GDScript, as signal targets, and **typed cross-script** (`rt.script_of`) |
| **Classes** | `extends` any engine class, global `class_name`, custom **resources** (`.tres`), **autoload** singletons |
| **Editor** | `@tool` scripts, `gd.is_editor()`, custom icons, **EditorPlugin**, live error squiggles + autocomplete |
| **Multiplayer** | Kit provides session replication with `gd:"replicate"` and `gd:"owner"` fields, commands, generated entity factories, drop-in join, reconnect, and host migration. Its [simulation lane](docs/kit/sim.md) adds `gd:"predict"`, fixed ticks, server authority, reconciliation, and bounded lag compensation for contested state. The lanes compose per field ([choosing a model](docs/kit/timelines.md)); [named profiles](docs/kit/profiles.md) validate coherent co-op, listen-server, or dedicated settings. `@(gd_rpc)` remains available for Godot's engine-native path. |
| **Build and export** | hot reload on save, native desktop export, WebAssembly export |
| **Script modules** | opt-in [script modules](docs/modules.md): one dll per `res://modules/<name>`, rebuilt + hot-swapped independently so edits to one module avoid rebuilding unrelated modules |
| **Box3D** | [Authored worlds, shapes, characters and joints](docs/box3d-authoring.md), one explicitly stepped backend with distinct Kit/Replay complete-state adapters, and optional editor/debug tools; reference-platform limits are stated in the linked reports |

Odin compiles ahead of time, so scripts have no `eval`/REPL or Godot script-line
breakpoints; use `lldb` for native debugging. Changing `@export` declarations
requires recompilation, which the editor starts on save. See [Workflow](docs/workflow.md).

## Quickstart

```sh
nix develop                  # toolchain shell: odin, ols, emcc, llvm/lld, + $GODOT (4.7.1)

# Build the extension + the example's scripts, then play it:
bash build/build_scripts.sh examples/survivors
$GODOT --path examples/survivors          # arrow keys move; auto-fire; survive

# Run the repository's headless suite:
nix develop --command bash tests/run_all.sh
```

```
==> phase1  PASS   ==> resources    PASS   ==> editortools  PASS
==> phase2  PASS   ==> crossscript  PASS   ==> debug        PASS
   ...                  ...                    ...
==> survivors PASS ==> web          PASS browser-verified   ALL GREEN
```

Start with [Getting Started](docs/getting-started.md) to install the toolchain,
load the extension in a Godot project, and write a script that moves a node.
For multiplayer, the [quickstart](docs/kit/quickstart.md) builds a two-window
example in two files. Its [simulation version](docs/kit/quickstart-sim.md) moves
motion to server authority. Choose trust and timing settings through
[network profiles](docs/kit/profiles.md).

## Documentation

The **[SDK documentation site](https://wlitwin.github.io/odin_godot/)** has guides for setup,
Odin scripting, Kit, Replay, and export, plus an illustrated multiplayer guide and
searchable reference. For a playable example, **[try Scrapyard in your browser](https://itchyitches.itch.io/scrapyard)**.

Use the **[documentation index](https://wlitwin.github.io/odin_godot/reading.html)**
to browse every published guide, reference page, example, and source listing by topic.

| Doc | What it covers |
|---|---|
| **[docs/index.md](docs/index.md)** | The documentation map: start here to navigate |
| **[Getting Started](docs/getting-started.md)** | Install the toolchain, add the extension to a project, write + attach your first script |
| **[Authoring Guide](docs/authoring-guide.md)** | The feature reference: struct convention, `//gd:` markers, `@export` (all types/hints/groups/defaults), lifecycle, methods, signals, `@(gd_connect)`, `@(gd_rpc)`, `@onready`, resources, autoloads, cross-script, the `gd.*` helper catalog, editor tooling |
| **[Workflow](docs/workflow.md)** | The development loop: build, reload on save, editor validation/completion/highlighting, debugging (`gd.print`, `lldb`, crash backtraces), and AOT limitations |
| **[Box3D authoring](docs/box3d-authoring.md)** | Separate authored Kit/Replay samples, editor and bake workflow, complete-state ownership, migration and unsupported operations |
| **[Exporting](docs/exporting.md)** | Shipping: native desktop export and web/WASM export (COOP/COEP) |
| **[Distribution](docs/distribution.md)** | Building the drop-in addon (`nix build`), cross-compiling the core for Linux/Windows, the consumer install workflow, per-platform status |
| **[Debugging](docs/debugging.md)** | The full `lldb` + crash-backtrace reference |
| [PLAN.md](PLAN.md) | The original architecture + phased design plan (design history) |
| [docs/design/](docs/design) | Internal notes: the `ScriptLanguageExtension` surface, export/web internals, the WASM spike |

## Examples

**[Play Scrapyard on itch.io](https://itchyitches.itch.io/scrapyard)** to try an Odin +
Godot arena shooter in the browser. The repository also includes the
[Replay Scrapyard port](examples/replay_scrapyard/contributor-guide.md), with a visual
guide to its authored scenes, replayable World, input, and presentation.

The [Kit overview](docs/kit/index.md) introduces the multiplayer packages.
These three projects demonstrate their use:

- **`examples/cavecrawl/`** is the co-op reference: a drop-in-join cave crawler exercising
  every toolkit package (replicated fields, predicted commands + `_then` consequences,
  generated entity factory, reconnect, save/resume, host migration, Steam), covered by a
  latency-injected integration test.
- **`examples/slopball/`** is the smallest complete kit game: a physics co-op ball pitch
  (~850 lines), with engine physics replicated through `play.Puppet`. It shows
  session setup, entity replication, and gameplay in one project.
- **`examples/slopball3d/`** uses the same replication model with 3D bodies
  (`play.Puppet3`, Node3D containers).

Single-player and engine-plumbing references:

- **`examples/survivors/`** is a complete top-down arena shooter in pure Odin; each script is
  commented to teach one slice of the binding ([README](examples/survivors/README.md)). Its
  network layer uses Godot's engine-native path (`MultiplayerSpawner`/`@(gd_rpc)`)
  to demonstrate those APIs. The Kit examples above provide the higher-level
  session and replication workflow for co-op.
- **`examples/coop_arena/`** uses one peer-authoritative codebase for engine-native multiplayer over `MultiplayerSynchronizer` + `@(gd_rpc)` that runs
  single-player, over native ENet, and in the browser over WebRTC (room-code lobby)
  ([README](examples/coop_arena/README.md)). It configures the engine APIs that
  Kit wraps for session-based games.
- **`tests/showcase/`** is a minimal pure-Odin coin-collector combining script
  registration, input, signals, and scene behavior. Run it: `$GODOT --path tests/showcase`.
- **`examples/hello/`** is the lowest-level path: a hand-registered GDExtension class (not a
  script) proving the Odin↔GDExtension ABI.

## Repository layout

| dir | purpose |
|---|---|
| `flake.nix` | reproducible toolchain: Odin, `ols`, LLVM, Emscripten, + `$GODOT` |
| `bindgen/` | generates the typed `godot/` package from `extension_api.json` |
| `godot/` | the generated typed binding (Variant, builtins, every class) + the hand-written `gd.*` `Ergonomics_*.odin` layer |
| `gdext/`, `libgd/` | the hand-owned GDExtension C-ABI runtime the binding sits on |
| `core/` | the extension core (`-build-mode:dll`): `ScriptLanguageExtension`, `OdinScript`, instance dispatch, loader, hot reload, export plugin, editor tooling, web entry |
| `runtime/` | the shared registry contract (`Class_Desc`) imported by both core and scripts |
| `scriptgen/` | reads script tags/attributes and generates registration code |
| `build/` | the compose+compile pipelines (scripts → dll / wasm; export builds) |
| `tests/` | per-feature headless milestones + `run_all.sh` |
| `docs/` | this documentation set |

## Installing (without cloning this repo)

The distributable is a **drop-in addon**: `addons/odin_godot/` with prebuilt core dlls, the
docs, the build scripts, and a starter template. Get it from the `release` branch (what the
Godot Asset Library entry points at) or build it yourself with `nix build .#release`, then
follow [Distribution → Install into a Godot project](docs/distribution.md). The one host
tool you need is the `odin` compiler (the addon README names the tested release and explains
the ABI-fingerprint compatibility check).

## Platform status

macOS is the development platform and is verified end-to-end by the suite (including the
Asset-Library drop-in layout and the web export). **Windows** ships prebuilt core dlls and
builds scripts natively via `build_scripts.ps1`, with limited runtime verification so far;
**Linux** is build-verified only. Reports from either platform are very welcome. The crash
reporter and build scripts are designed to produce actionable output, so please file what
you see.

## License / attribution

**Apache-2.0**: see [LICENSE](LICENSE) and [NOTICE](NOTICE). The binding generator +
C-ABI runtime were vendored from
[`dresswithpockets/odin-godot`](https://github.com/dresswithpockets/odin-godot) (Apache-2.0);
attribution and provenance are kept in [`bindgen/ATTRIBUTION.md`](bindgen/ATTRIBUTION.md).
