# odin_godot — write Godot scripts in Odin

Attach [Odin](https://odin-lang.org) `.odin` scripts to nodes in Godot 4.7+.
The addon registers `_ready`, `_process`, signals, `@export`, and methods
with the engine. The scripts compile into a native library.

This guide is for an installed addon at `res://addons/odin_godot/`. Godot
discovers `odin_godot.gdextension`; install the Odin toolchain and build a
scripts library using the steps below. The full reference is in
[`docs/`](docs/index.md).

Kit (`godot:kit/*`) provides multiplayer sessions, replication with prediction,
items/combat/NPCs, save/resume, live host migration, and ENet + Steam + WebRTC
(browser) transports. Start at
[docs/kit/](docs/kit/index.md).

The addon also includes **Replay**, an experimental simulation-first multiplayer
library beside Kit, and `template/replay/` as a separate starter project. See the
[Replay guide](docs/replay.md) for its API model, supported configurations,
and limitations.

---

<a id="how-it-works-read-this-first"></a>

## Core and scripts libraries

odin_godot supplies a prebuilt engine core: the `.dylib`/`.so`/`.dll` under
`bin/`. The project's `.odin` files compile into a separate scripts library,
`res://bin/libodinscripts.*`, which the core loads at runtime.

Until you add and build scripts, the editor prints the one-time warning
"no compiled Odin scripts found". Odin compiles ahead of time, so development
requires the compiler. Export compiles and bundles the scripts; the exported
game needs no compiler.

## Prerequisites

| Need | Where |
|------|-------|
| **Godot 4.7+** | <https://godotengine.org> |
| **Odin compiler — `@ODIN_VERSION@` tested/recommended** (`odin` on your PATH) | <https://github.com/odin-lang/Odin/releases> |
| **A C linker** Odin can drive | macOS: Xcode Command Line Tools (`xcode-select --install`) · Linux: `gcc`/`clang` · Windows: Visual Studio Build Tools (run builds from a *"x64 Native Tools Command Prompt for VS"*) |

> **Compiler compatibility:** `@ODIN_VERSION@` is the tested release used to
> build the addon's core. Prefer it for the tested toolchain, especially
> before Odin 1.0. Before boot, the core checks the complete ABI fingerprint:
> every boundary size, alignment, and field offset. Another compiler release
> can load when it compiles the bundled sources to the same contract. A
> mismatch is rejected before user code runs and reports the need to
> rebuild/update. If a Finder/Steam-launched editor cannot find `odin` on its
> PATH, set `odin_godot/odin_bin` to the binary's absolute path.

Install these tools when using the corresponding features:

| For | Install |
|------|-------|
| Autocomplete / hover / call hints + **format on save** | [`ols`](https://github.com/DanielGavin/ols) on PATH (or the `odin_godot/ols_bin` setting) — `odinfmt` ships with it |
| Project > Tools debugger items (macOS/Linux) | macOS: nothing extra (lldb is in the Xcode CLT above) · Linux: `lldb` + a terminal emulator |
| VS Code debugging | VS Code + the **CodeLLDB** extension (`vadimcn.vscode-lldb`) |
| JetBrains editing (Rider/CLion/…) | the **Odin Support** plugin (import the generated `ols.json`) |
| Local **web-export preview** (`build/serve.sh`) | Node.js (deployed hosts just need the COOP/COEP headers — see docs/exporting.md) |
| **Web export** itself | Emscripten (`emcc`) + Godot's web export templates |

## Quick start — your first script

1. **Copy the starter** using Godot's **Project → Tools → Set Up Odin Scripts**
   (copies the template into `res://scripts/` and refreshes the dock). Or from a terminal:
   ```sh
   cp -r addons/odin_godot/template/scripts ./scripts
   ```
   This gives you `res://scripts/hello.odin` (a minimal `Hello` node that prints on
   `_ready`). The required boot boilerplate is generated for you at build time
   (`odin_godot_boot.gen.odin`) — you never write it.

2. **Build the scripts library** using Godot's **Project → Tools → Build Odin
   Scripts** (progress shows in the Output panel; the editor also rebuilds on save). Or from a
   terminal:
   - **macOS / Linux:**
     ```sh
     ODIN_GODOT_ROOT="$PWD/addons/odin_godot" SKIP_CORE=1 \
       bash addons/odin_godot/build/build_scripts.sh .
     ```
   - **Windows** (from a *"x64 Native Tools Command Prompt for VS"*):
     ```powershell
     powershell -ExecutionPolicy Bypass -File addons\odin_godot\build\build_scripts.ps1 `
       -Root addons\odin_godot -Project . -SkipCore
     ```
   This writes `res://bin/libodinscripts.<ext>` (needs the Odin compiler installed).

3. **Run it:** open the project in Godot (**restart the editor after adding _or updating_ the
   addon** — Godot registers `.odin` at load and can't hot-swap the extension dll in place),
   add a `Node` to a scene, attach `res://scripts/hello.odin` (the `Hello` script),
   and press **Play**. The Output
   panel prints "Hello from Odin!".

From here, edit `hello.odin` (or add your own) — the editor **rebuilds on save** so new
`@export`s and code appear after a moment. See [`template/README.md`](template/README.md)
for the same walkthrough with more detail, and the docs below for everything else.

## Documentation

All bundled under [`docs/`](docs/index.md):

- **[Getting Started](docs/getting-started.md)** — the install-and-first-script path, in full.
- **[Authoring Guide](docs/authoring-guide.md)** — the complete feature reference: the script
  struct convention, `//gd:` markers, every `@export` form, signals, methods, resources,
  autoloads, and the `gd.*` helper catalog.
- **[Workflow](docs/workflow.md)** — builds, editing, reloads, editor tools,
  and scripting limits.
- **[Exporting](docs/exporting.md)** — shipping desktop and web builds.
- **[Debugging](docs/debugging.md)** — `gd.print`, one-click lldb sessions from **Project →
  Tools → Debug Game (LLDB)** (line breakpoints, stepping, live struct inspection; also a
  break-at-cursor variant and a VS Code config generator), and reading crash backtraces.

## Exporting

**Desktop** (macOS/Linux/Windows): export normally — an editor export plugin compiles your
scripts and bundles them into the build. The prebuilt cores for all three desktop platforms
ship in this addon (`bin/macos`, `bin/linux`, `bin/windows`).

**Web/WASM:** there is **no prebuilt web binary** — the whole extension (core + your scripts)
is ahead-of-time linked into one Emscripten module *per project*. The editor's export plugin
**builds it automatically** when you export to Web, provided you've done the one-time setup:

1. Install the **Emscripten SDK** and activate **4.0.20** (the version Godot 4.7's web
   templates use) — see <https://emscripten.org/docs/getting_started/downloads.html>.
2. Set the **`odin_godot/emcc_bin`** project setting to the absolute path of `emcc` (and
   `odin_godot/odin_bin` to `odin`) so a Finder/Steam-launched editor can find them.

Choose **Export → Web**. For the full procedure, including serving headers, see
[docs/exporting.md](docs/exporting.md). (You can also prebuild manually with
`addons/odin_godot/build/build_web.sh .`.)

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| **Editor crashes after updating / replacing the addon** | Don't swap the addon's core dll while the editor is open — Godot tries to hot-reload the GDExtension in place and crashes ("class already registered"). **Quit Godot first, replace `addons/odin_godot/`, then reopen.** (Same restart rule as first install.) |
| Editor warns **"no compiled Odin scripts found"** | Normal on a fresh install — follow *Quick start* to build the scripts library. |
| Editor warns **"`odin` not found"** (validation/reload off) | The editor process can't see `odin` on PATH. Set the `odin_godot/odin_bin` project setting to the absolute path of your `odin`, or launch the editor from a shell where `odin` is on PATH. |
| Web export logs **"Emscripten `emcc` not found"** | Install the Emscripten SDK (activate 4.0.20) and set the `odin_godot/emcc_bin` project setting to its `emcc`. See [docs/exporting.md](docs/exporting.md). |
| Build error **"no Odin scripts found"** | You have no `scripts/` folder yet — copy the template (*Quick start*, step 1). |
| **Headless/CI runs can't find the extension** ("No loader found for resource: …odin") | Godot registers the addon during the editor's import step, which headless runs skip. Run `godot --headless --path . --import` once (per fresh checkout / addon update) before `--script`/server runs — your CI script should do this unconditionally. |
| Windows: odin errors on a path with spaces | The build scripts use relative paths to cope, but the most reliable fix is a space-free project path (e.g. `C:\games\mygame`). |

<a id="platform-status-honest"></a>

## Platform validation

Development and runtime validation cover macOS and Web. Linux and Windows
desktop cores have cross-build checks for format, architecture, and exported
entry symbol; the maintainer has not runtime-tested them. They use the same
GDExtension C interface, but those build checks do not establish runtime
behavior on either platform.
