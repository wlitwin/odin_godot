# odin_godot

**Write Godot scripts in [Odin](https://odin-lang.org/).** odin_godot is a Godot 4.6
GDExtension that implements the full `ScriptLanguageExtension` API, so a `.odin` file is a
**first-class Godot script** — attach one to a Node and its `_ready` / `_process` / signals /
`@export` vars run as **compiled, AOT native Odin**, dispatched through a typed registry (no
interpreter, no per-call string marshalling). It is built to **replace GDScript** for a
project: lifecycle, `@export` of every Variant type, custom methods, signals, `extends` any
class, custom resources, autoloads, `@tool`/editor plugins, multiplayer RPCs, hot reload, and
**native + WebAssembly** export — all reproducible from a single Nix flake.

> **Status: working engine.** `nix develop --command bash tests/run_all.sh` is green across a
> 39-test end-to-end suite (every feature below, plus the showcase, the examples' co-op runs,
> and the Asset-Library drop-in layout), plus 7 browser-gated web tests that verify the WASM
> export in a real headless Chrome when one is available. The headline examples are a pure-Odin coin-collector
> (`tests/showcase/`), a complete top-down arena shooter (`examples/survivors/`), a
> drop-in co-op cave crawler on the friendslop multiplayer toolkit
> (`examples/cavecrawl/`), and a server-authoritative western duel with lag-compensated
> hitscan on the kit/sim lane (`examples/quickdraw/`, A/B-proven at 240 ms RTT) —
> **zero GDScript gameplay code**.

## What you can do (the 60-second tour)

```odin
//gd:extends Area2D            // base Godot class
//gd:class Coin                // global class_name
package game_scripts

import gd "godot:godot"

Coin :: struct {
	owner:     gd.Area2d,                        // first field = the node, always
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
	gd.node_queue_free(self.owner)               // gd.* ergonomic helper
}
```

You get the **whole engine API** as typed Odin (the generated `godot` binding), a curated
`gd.*` ergonomic layer for the common one-liners, and GDScript parity for the things that
matter:

| | |
|---|---|
| **Lifecycle** | `_ready` / `_process` / `_physics_process` / `_enter_tree` / `_exit_tree` by proc name |
| **`@export`** | every Variant type + Inspector hints (range/enum/multiline/file/resource), groups, defaults, getters/setters, `@onready` refs |
| **Signals** | declare (typed `gd.Signal0`…`Signal4` struct fields), emit (typed generated helper), connect (`gd.connect_to` / `@(gd_connect)`) |
| **Methods** | `@(gd_method)` — callable from GDScript, as signal targets, and **typed cross-script** (`rt.script_of`) |
| **Classes** | `extends` any engine class, global `class_name`, custom **resources** (`.tres`), **autoload** singletons |
| **Editor** | `@tool` scripts, `gd.is_editor()`, custom icons, **EditorPlugin**, live error squiggles + autocomplete |
| **Multiplayer** | TWO netcodes, one declarative surface. The [friendslop co-op toolkit](docs/kit/index.md): `gd:"replicate"` fields, predicted commands + `_then` consequences, generated entity factories, drop-in join, reconnect, host migration. And the [server-authority sim lane](docs/kit/sim.md) beside it for contested/competitive games: `gd:"predict"` fields + a `@(gd_tick)` proc buy rollback-resimulation, client prediction, and lag-compensated hitscan — per-field opt-in, so hybrid games compose ([choosing a model](docs/kit/timelines.md)). Plus `@(gd_rpc)` mirroring GDScript's `@rpc` for the engine-native path |
| **Ship it** | hot reload on save, native desktop export, WebAssembly export |
| **Scale it** | opt-in [script modules](docs/modules.md) — one dll per `res://modules/<name>`, rebuilt + hot-swapped independently so save latency stays flat in large projects |

Because Odin is **ahead-of-time compiled** there are honest, inherent differences from
interpreted GDScript — no `eval`/REPL, no in-editor breakpoints (use `lldb`), and `@export`
changes need a recompile (the editor does it for you on save). These are documented up front,
not hidden — see [Workflow](docs/workflow.md).

## Quickstart

```sh
nix develop                  # toolchain shell: odin, ols, emcc, llvm/lld, + $GODOT (4.6.2)

# Build the extension + the example's scripts, then play it:
bash build/build_scripts.sh examples/survivors
$GODOT --path examples/survivors          # arrow keys move; auto-fire; survive

# Or verify everything headless (reproducible from one command):
nix develop --command bash tests/run_all.sh
```

```
==> phase1  PASS   ==> resources    PASS   ==> editortools  PASS
==> phase2  PASS   ==> crossscript  PASS   ==> debug        PASS
   ...                  ...                    ...
==> survivors PASS ==> web          PASS browser-verified   ALL GREEN
```

New here? Start with **[Getting Started](docs/getting-started.md)** — it installs the
toolchain, wires the extension into a Godot project, and walks you through your first Odin
script from empty file to a moving node. Here for multiplayer? The
**[quickstart](docs/kit/quickstart.md)** goes zero-to-two-windows in two small files, and
its **[sim twin](docs/kit/quickstart-sim.md)** promotes the same game to server authority.

## Documentation

| Doc | What it covers |
|---|---|
| **[docs/index.md](docs/index.md)** | The documentation map — start here to navigate |
| **[Getting Started](docs/getting-started.md)** | Install the toolchain, add the extension to a project, write + attach your first script |
| **[Authoring Guide](docs/authoring-guide.md)** | The feature reference: struct convention, `//gd:` markers, `@export` (all types/hints/groups/defaults), lifecycle, methods, signals, `@(gd_connect)`, `@(gd_rpc)`, `@onready`, resources, autoloads, cross-script, the `gd.*` helper catalog, editor tooling |
| **[Workflow](docs/workflow.md)** | The dev loop: build, live-edit (show-on-save recompile), editor DX (validation/autocomplete/highlighting), debugging (`gd.print`, `lldb`, crash backtraces), and the honest AOT limitations |
| **[Exporting](docs/exporting.md)** | Shipping: native desktop export and web/WASM export (COOP/COEP) |
| **[Distribution](docs/distribution.md)** | Building the drop-in addon (`nix build`), cross-compiling the core for Linux/Windows, the consumer install workflow, per-platform status |
| **[Debugging](docs/debugging.md)** | The full `lldb` + crash-backtrace reference |
| [PLAN.md](PLAN.md) | The original architecture + phased design plan (design history) |
| [docs/design/](docs/design) | Internal notes: the `ScriptLanguageExtension` surface, export/web internals, the WASM spike |

## Examples

**Building multiplayer? Start with the [friendslop toolkit](docs/kit/index.md)** — these
three are its references:

- **`examples/cavecrawl/`** — THE co-op reference: a drop-in-join cave crawler exercising
  every toolkit package (replicated fields, predicted commands + `_then` consequences,
  generated entity factory, reconnect, save/resume, host migration, Steam), grown
  brick-by-brick with a latency-injected acid test.
- **`examples/slopball/`** — the smallest complete kit game: a physics co-op ball pitch
  (~850 lines), engine physics replicated through `play.Puppet`. Start here to see the
  whole multiplayer surface in one sitting.
- **`examples/slopball3d/`** — the same pitch in 3D: proof the toolkit's model is
  dimension-blind (`play.Puppet3`, Node3D containers).

Single-player and engine-plumbing references:

- **`examples/survivors/`** — a complete top-down arena shooter in pure Odin; each script is
  commented to teach one slice of the binding ([README](examples/survivors/README.md)). Its
  net layer uses the ENGINE-NATIVE path (`MultiplayerSpawner`/`@(gd_rpc)`) — kept as the
  GDScript-parity demonstration, not the recommended way to build co-op (that's the kit).
- **`examples/coop_arena/`** — the engine-native multiplayer path end-to-end: ONE
  peer-authoritative codebase over `MultiplayerSynchronizer` + `@(gd_rpc)` that runs
  single-player, over native ENet, and in the browser over WebRTC (room-code lobby)
  ([README](examples/coop_arena/README.md)). Predates the friendslop toolkit; it shows the
  raw engine surface the kit absorbs.
- **`tests/showcase/`** — a minimal pure-Odin coin-collector; the smallest "everything wired"
  scene. Run it: `$GODOT --path tests/showcase`.
- **`examples/hello/`** — the lowest-level path: a hand-registered GDExtension class (not a
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
| `scriptgen/` | the codegen preprocessor (nice authoring form → registration boilerplate) |
| `build/` | the compose+compile pipelines (scripts → dll / wasm; export builds) |
| `tests/` | per-feature headless milestones + `run_all.sh` |
| `docs/` | this documentation set |

## Installing (without cloning this repo)

The distributable is a **drop-in addon**: `addons/odin_godot/` with prebuilt core dlls, the
docs, the build scripts, and a starter template. Get it from the `release` branch (what the
Godot Asset Library entry points at) or build it yourself with `nix build .#release`, then
follow [Distribution → Install into a Godot project](docs/distribution.md). The one host
tool you need is the `odin` compiler (the addon README names the exact pinned release).

## Platform status

macOS is the development platform and is verified end-to-end by the suite (including the
Asset-Library drop-in layout and the web export). **Windows** ships prebuilt core dlls and
builds scripts natively via `build_scripts.ps1`, with limited runtime verification so far;
**Linux** is build-verified only. Reports from either platform are very welcome — the crash
reporter and build scripts are designed to produce actionable output, so please file what
you see.

## License / attribution

**Apache-2.0** — see [LICENSE](LICENSE) and [NOTICE](NOTICE). The binding generator +
C-ABI runtime were vendored from
[`dresswithpockets/odin-godot`](https://github.com/dresswithpockets/odin-godot) (Apache-2.0);
attribution and provenance are kept in [`bindgen/ATTRIBUTION.md`](bindgen/ATTRIBUTION.md).
