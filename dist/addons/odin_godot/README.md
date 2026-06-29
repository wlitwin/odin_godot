# odin_godot — write Godot scripts in Odin

This addon makes [Odin](https://odin-lang.org) a first-class scripting language in Godot
4.6+. You attach `.odin` files to nodes exactly like GDScript — with `_ready`, `_process`,
signals, `@export`, and methods — but they compile to fast native code.

**You are reading this inside an installed addon** (`res://addons/odin_godot/`). Godot has
already discovered `odin_godot.gdextension`; you just need the Odin toolchain and your first
script. This page gets you there. The full reference lives in [`docs/`](docs/index.md).

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
| **Godot 4.6+** | <https://godotengine.org> |
| **Odin compiler** (`odin` on your PATH) | <https://odin-lang.org/docs/install/> |
| **A C linker** Odin can drive | macOS: Xcode Command Line Tools (`xcode-select --install`) · Linux: `gcc`/`clang` · Windows: Visual Studio Build Tools (run builds from a *"x64 Native Tools Command Prompt for VS"*) |

> Verify Odin works: `odin version` should print a version. If the editor can't find `odin`
> (common when launched from Finder/Steam, which don't inherit your shell PATH), set the
> **`odin_godot/odin_bin`** project setting to the absolute path of your `odin` binary.

## Quick start — your first script

1. **Copy the starter** into your project root:
   ```sh
   cp -r addons/odin_godot/template/scripts ./scripts
   ```
   This gives you `res://scripts/boot.odin` (required boilerplate — never edit it) and
   `res://scripts/hello.odin` (a minimal `Hello` node that prints on `_ready`).

2. **Build the scripts library:**
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
   This writes `res://bin/libodinscripts.<ext>`.

3. **Run it:** open the project in Godot, add a `Node` to a scene, **Attach Script → pick
   `Hello`**, and press **Play**. The Output panel prints "Hello from Odin!".

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
- **[Debugging](docs/debugging.md)** — `gd.print`, `lldb`, and reading crash backtraces.

## Exporting

**Desktop** (macOS/Linux/Windows): export normally — an editor export plugin compiles your
scripts and bundles them into the build. The prebuilt cores for all three desktop platforms
ship in this addon (`bin/macos`, `bin/linux`, `bin/windows`).

**Web/WASM:** there is **no prebuilt web binary** — the whole extension (core + your scripts)
is ahead-of-time linked into one Emscripten module *per project*. Build it before a web
export with `addons/odin_godot/build/build_web.sh`. If you export to web without that step,
Godot reports a missing `res://bin/libodin_godot.wasm`. See [Exporting](docs/exporting.md).

## Troubleshooting

| Symptom | Cause / fix |
|---------|-------------|
| Editor warns **"no compiled Odin scripts found"** | Normal on a fresh install — follow *Quick start* to build the scripts library. |
| Editor warns **"`odin` not found"** (validation/reload off) | The editor process can't see `odin` on PATH. Set the `odin_godot/odin_bin` project setting to the absolute path of your `odin`, or launch the editor from a shell where `odin` is on PATH. |
| Build error **"no Odin scripts found"** | You have no `scripts/` folder yet — copy the template (*Quick start*, step 1). |
| Windows: odin errors on a path with spaces | The build scripts use relative paths to cope, but the most reliable fix is a space-free project path (e.g. `C:\games\mygame`). |

## Platform status (honest)

Developed on macOS. macOS and Web are runtime-verified. Linux and Windows desktop cores are
**cross-build verified** (correct format/arch, entry symbol exported) but not yet runtime-
tested by the maintainer — please report issues. The C-ABI GDExtension boundary is identical
across platforms, so they are expected to work.
