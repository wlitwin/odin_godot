# Getting started

Install the Odin toolchain, copy the starter, and build a scripts library.
Then write and attach a `.odin` script to a `Node2D` that prints on `_ready`
and moves every frame.

> This page is written for the **drop-in addon** (you copied `addons/odin_godot/` into your
> project). If you're working from the odin_godot *source repo* instead, its `nix develop`
> shell provides the whole toolchain — see the repo's own docs.

## 1. Install the toolchain

You need three things on your machine (the addon already provides the prebuilt engine core):

1. **Godot 4.7+** — <https://godotengine.org> (the addon's `.gdextension` minimum)
2. **The Odin compiler — release `@ODIN_VERSION@` tested/recommended** —
   <https://github.com/odin-lang/Odin/releases>. The bundled prebuilt core validates a
   scripts library's complete native ABI fingerprint before boot. Another compiler release
   is accepted when it can compile the bundled sources and produces the same boundary layout;
   a real ABI mismatch fails safely before user code runs. The tested release remains the
   lowest-risk choice, especially before Odin 1.0.
3. **A C linker Odin can drive:**
   - **macOS:** Xcode Command Line Tools — `xcode-select --install`
   - **Linux:** `gcc` or `clang` from your package manager
   - **Windows:** Visual Studio Build Tools; run all build commands from a *"x64 Native
     Tools Command Prompt for VS"* so `link.exe` + the Windows SDK are set up.

You only need Odin **while developing**. An exported game compiles your scripts at export
time and ships no compiler.

## 2. How a project is wired

Once the addon is in `res://addons/odin_godot/`, Godot auto-discovers its
`odin_godot.gdextension` and recognizes `.odin` files. Beyond that, a project needs:

1. **A `scripts/` package** — your `.odin` files. (The build auto-generates the one piece of
   required boilerplate, `odin_godot_boot.gen.odin`, so you don't write it.)
2. **A build** — `addons/odin_godot/build/build_scripts.sh` (or `.ps1` on Windows) compiles
   that package into `res://bin/libodinscripts.<ext>`, which the core loads at runtime.

The bundled starter supplies the scripts package for this build.

### 2a. Copy the starter

**In Godot:** **Project → Tools → Set Up Odin Scripts**. This copies the
template into `res://scripts/` and refreshes the FileSystem dock (the template lives inside the
addon, so it isn't visible there to drag yourself). Or from a terminal:

```sh
cp -r addons/odin_godot/template/scripts ./scripts
```

You now have `res://scripts/`:

- **`hello.odin`** — a minimal example class you'll replace below. Every `.odin` in
  `scripts/` shares the same `package scripts` line at the top.

The first build writes three generated files beside it. These `*.gen.odin`
files are build artifacts; edit the authored source instead: **`odin_godot_scripts.gen.odin`** (the registration code for every script
in the directory), **`odin_godot_boot.gen.odin`** (the `odin_scripts_boot` export the core
calls after it loads your dll), and **`odin_godot_guard.gen.odin`** (a staleness guard that
fails the build when generated code no longer matches its sources). To
customize the boot shim, define `odin_scripts_boot` in an authored file;
the generator then omits its default implementation.

### 2b. (Optional) editor settings

If you launch Godot from Finder/Steam/the Project Manager, the editor process often can't see
`odin` on its `PATH` — so rebuild-on-save and validation are disabled with a one-time
warning. Point the editor at your compiler with the **`odin_godot/odin_bin`** project setting
(absolute path to the `odin` binary). For autocomplete, **`odin_godot/ols_bin`** similarly
points at an `ols` binary if you have one.

## 3. Write your first script

Replace `scripts/hello.odin` with `scripts/mover.odin` — a `Node2D` that prints once on
`_ready` and walks right every frame:

```odin
//gd:extends Node2D       // the Godot base class this script extends
//gd:class Mover          // optional global class alias; path identity works without it
package scripts

import gd "godot:godot"

// The script struct's first field must be the owner node handle. The core writes the
// node pointer there. Use the engine handle type needed by the script (Node2d here).
Mover :: struct {
	owner: gd.Node2d,
	speed: f32 `gd:"export,default=120"`,   // @export var, tunable in the Inspector
}

// Lifecycle: a proc named `<struct>_ready` (the `mover_` prefix is stripped) runs on READY.
mover_ready :: proc(self: ^Mover) {
	gd.print("Mover ready!")                // -> stdout + the editor Output panel
}

// `<struct>_process` runs every frame; the second param is the frame delta (seconds).
mover_process :: proc(self: ^Mover, delta: f64) {
	pos := gd.node2d_get_position(self.owner)
	pos.x += self.speed * f32(delta)        // walk right at `speed` px/s
	gd.node2d_set_position(self.owner, pos)
}
```

A few rules this demonstrates (full details in the [Authoring Guide](authoring-guide.md)):

- **One script struct per file**, identified by its first field being named `owner`.
- **Prefix proc names with the struct name** (`mover_ready`, `mover_process`) — all scripts
  share one package, so the prefix avoids collisions and is stripped to derive the
  GDScript-facing name.
- The `//gd:` markers supply engine metadata. `//gd:extends` selects the base
  class; if omitted, the base derives from the `owner` handle. A declared
  base requires an `owner` handle of that type or one of its ancestors.

The build runs `scriptgen` to generate registration code in
`scripts/odin_godot_scripts.gen.odin`, one file for the directory. The editor
hides that build artifact from the FileSystem dock.

## 4. Build

**In Godot:** **Project → Tools → Build Odin Scripts**. This compiles
your `scripts/` package into `res://bin/libodinscripts.<ext>` and reports progress in the
Output panel — no terminal needed. (The editor also rebuilds automatically when you save a
script.)

**From a terminal** (CI, scripting, or if you prefer):

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

Either way it (1) builds `scriptgen`, (2) generates the `*.gen.odin` build artifacts, and (3) compiles
your `scripts/` package into `res://bin/libodinscripts.<ext>`. (`SKIP_CORE`/`-SkipCore` skips
rebuilding the engine core — it's already prebuilt in the addon, so you rarely need it.) Either
path needs the **Odin compiler** installed (and findable — see `odin_godot/odin_bin`).

> **Version control:** the build produces artifacts you don't commit. The bundled
> `scripts/.gitignore` already excludes the generated `*.gen.odin`; add `/bin/` and `*.dSYM/`
> to your project's `.gitignore` for the compiled library + debug symbols.

## 5. Attach and run

1. Open the project in Godot (Project Manager, or `godot --path .`). **Restart the editor after
   adding _or updating_ the addon** so Godot (re)registers `.odin` as a script language — and
   never replace the addon's dll while the editor is open (Godot can't hot-swap a GDExtension in
   place and will crash; quit first, replace, reopen).
2. Add a **`Node2D`** to your scene (the base must match `//gd:extends`).
3. In the Inspector's **Script** slot, **Attach** and pick `res://scripts/mover.odin` — the
   same file you wrote (there's no separate resource stub; the `.odin` *is* the script).
4. The Inspector now shows the **Speed** `@export` (default 120).
5. **Run the scene.** You'll see `Mover ready!` in the Output panel and the node walking right.

After this, the editor **rebuilds your scripts on save**, so edits and new `@export`s appear
after a moment's compile.

## Next steps

- **[Authoring Guide](authoring-guide.md)** — exports of every type, signals, methods,
  resources, cross-script calls, autoloads, the full `gd.*` helper catalog.
- **[Workflow](workflow.md)** — the edit→reload loop, editor squiggles/autocomplete, limits.
- **[Exporting](exporting.md)** — shipping desktop and web builds.
- **[Debugging](debugging.md)** — `gd.print`, `lldb`, and reading crash backtraces.
