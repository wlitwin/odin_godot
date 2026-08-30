# odin_godot — write Godot scripts in Odin

This addon makes [Odin](https://odin-lang.org) a first-class scripting language in Godot
4.7+. You attach `.odin` files to nodes exactly like GDScript — with `_ready`, `_process`,
signals, `@export`, and methods — but they compile to fast native code.

**You are reading this inside an installed addon** (`res://addons/odin_godot/`). Godot has
already discovered `odin_godot.gdextension`; you just need the Odin toolchain and your first
script. This page gets you there. The full reference lives in [`docs/`](docs/index.md).

Building a co-op game? The addon includes the **friendslop toolkit** (`godot:kit/*`) —
multiplayer sessions, replication with prediction, items/combat/NPCs, save/resume, live
host migration, and ENet + Steam + WebRTC (browser) transports. Start at
[docs/kit/](docs/kit/index.md).

---

## How it works (read this first)

odin_godot ships a **prebuilt engine core** (the `.dylib`/`.so`/`.dll` under `bin/`). Your
**gameplay code is yours** — your `.odin` scripts compile into a *separate* scripts library
(`res://bin/libodinscripts.*`) that the core loads at runtime.

That means:

- **A fresh install has nothing to run yet.** Until you add and build scripts, the editor
  prints a one-time warning ("no compiled Odin scripts found") — that's expected, not a bug.
- **There is no interpreter.** Odin is compiled ahead of time, so you need the Odin compiler
  installed *while developing*. An **exported game does not** — scripts are compiled into the
  build at export time.

## Prerequisites

| Need | Where |
|------|-------|
| **Godot 4.7+** | <https://godotengine.org> |
| **Odin compiler — `@ODIN_VERSION@` tested/recommended** (`odin` on your PATH) | <https://github.com/odin-lang/Odin/releases> |
| **A C linker** Odin can drive | macOS: Xcode Command Line Tools (`xcode-select --install`) · Linux: `gcc`/`clang` · Windows: Visual Studio Build Tools (run builds from a *"x64 Native Tools Command Prompt for VS"*) |

> **Compiler compatibility:** this addon ships a **prebuilt** core library. `@ODIN_VERSION@`
> is the release used by the addon and remains the safest choice, especially before Odin 1.0.
> It is not an artificial lockstep requirement: before boot, the core verifies a complete ABI
> fingerprint (every boundary size, alignment, and field offset), so another release that
> compiles the bundled sources to the same contract loads safely. An actual ABI mismatch fails
> before user code runs and tells you to rebuild/update. If the editor can't find `odin` (common when launched from
> Finder/Steam, which don't inherit your shell PATH), set the **`odin_godot/odin_bin`**
> project setting to the absolute path of your `odin` binary.

**Optional, per feature** — everything below works without these:

| For | Install |
|------|-------|
| Autocomplete / hover / call hints + **format on save** | [`ols`](https://github.com/DanielGavin/ols) on PATH (or the `odin_godot/ols_bin` setting) — `odinfmt` ships with it |
| Project > Tools debugger items (macOS/Linux) | macOS: nothing extra (lldb is in the Xcode CLT above) · Linux: `lldb` + a terminal emulator |
| VS Code debugging | VS Code + the **CodeLLDB** extension (`vadimcn.vscode-lldb`) |
| JetBrains editing (Rider/CLion/…) | the **Odin Support** plugin (import the generated `ols.json`) |
| Local **web-export preview** (`build/serve.sh`) | Node.js (deployed hosts just need the COOP/COEP headers — see docs/exporting.md) |
| **Web export** itself | Emscripten (`emcc`) + Godot's web export templates |

## Quick start — your first script

1. **Copy the starter** — easiest from inside Godot: **Project → Tools → Set Up Odin Scripts**
   (copies the template into `res://scripts/` and refreshes the dock). Or from a terminal:
   ```sh
   cp -r addons/odin_godot/template/scripts ./scripts
   ```
   This gives you `res://scripts/hello.odin` (a minimal `Hello` node that prints on
   `_ready`). The required boot boilerplate is generated for you at build time
   (`odin_godot_boot.gen.odin`) — you never write it.

2. **Build the scripts library** — easiest from inside Godot: **Project → Tools → Build Odin
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
   add a `Node` to a scene, **Attach Script → pick `Hello`**, and press **Play**. The Output
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
- **[Workflow](docs/workflow.md)** — the build/edit/iterate loop, editor DX, and honest limits.
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

Then just **Export → Web**. Full walkthrough — including serving headers — in
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

## Platform status (honest)

Developed on macOS. macOS and Web are runtime-verified. Linux and Windows desktop cores are
**cross-build verified** (correct format/arch, entry symbol exported) but not yet runtime-
tested by the maintainer — please report issues. The C-ABI GDExtension boundary is identical
across platforms, so they are expected to work.
