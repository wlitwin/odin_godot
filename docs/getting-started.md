# Getting started

This walks you from nothing to a running Odin script: install the toolchain, build the
extension, wire it into a Godot project, then write, attach, and run your first `.odin`
script. By the end you'll have a Node that prints on `_ready` and moves every frame.

> **Want to skip ahead?** `examples/survivors/` and `tests/showcase/` are complete, working
> projects. The fastest way to a running Odin script is to copy one and edit it:
> ```sh
> nix develop
> bash build/build_scripts.sh tests/showcase
> $GODOT --path tests/showcase
> ```
> This page explains how those projects are wired so you can build your own.

## 1. Install the toolchain (Nix)

Everything is pinned in a Nix flake: Odin, the `ols` language server, LLVM/lld, Emscripten,
Node, and a `$GODOT` pointing at Godot 4.7.1. You need [Nix with flakes enabled](https://nixos.org/)
and Godot 4.7.x installed.

```sh
cd /path/to/odin_godot
nix develop                    # drops you in the toolchain shell
```

```
odin_godot dev shell  (target: Godot 4.7.1 stable)
  odin:  /nix/store/.../odin  dev-2025-...
  emcc:  /nix/store/.../emcc
  godot: /Applications/Godot.app/Contents/MacOS/Godot
```

`$GODOT` defaults to the installed macOS Godot; override it with `GODOT=/path/to/godot nix
develop`. Confirm it works headless:

```sh
nix develop --command bash tests/run_all.sh    # the full suite — should end "ALL GREEN"
```

## 2. How a project is wired

An odin_godot project needs three things beyond your normal Godot project:

1. **A `.gdextension` manifest** that loads the compiled **core** dll.
2. **A `scripts/` package** containing your `.odin` scripts (the required boot shim is
   generated for you; see 2b).
3. **A build** (`build/build_scripts.sh`) that compiles your scripts (and the core) into the
   project's `bin/`.

We'll use the showcase as the working reference and build the same structure.

### 2a. The `.gdextension` manifest

Drop this at the project root as `odin_godot.gdextension` (this is `examples/survivors/odin_godot.gdextension`,
verbatim):

```ini
[configuration]
entry_symbol = "odin_godot_init"
compatibility_minimum = "4.6"

[libraries]
macos.debug = "res://bin/libodin_godot.dylib"
macos.release = "res://bin/libodin_godot.dylib"
macos.debug.arm64 = "res://bin/libodin_godot.dylib"
macos.release.arm64 = "res://bin/libodin_godot.dylib"

; Web target (built by build/build_web.sh — see docs/exporting.md):
web.debug.wasm32 = "res://bin/libodin_godot.wasm"
web.release.wasm32 = "res://bin/libodin_godot.wasm"
```

`entry_symbol = "odin_godot_init"` is the core's GDExtension entry point. It registers the
"Odin" scripting language so the editor recognizes `.odin` files. The **core** dll is what the
manifest loads; the **scripts** dll (`libodinscripts.dylib`) is loaded *by* the core at runtime,
so it is not listed here.

### 2b. The `scripts/` package and its boot shim

The `.odin` files in `scripts/` are **one Odin package** compiled into one shared dll. Pick a
package name and use the *same* `package` line at the top of every `.odin` file in the
directory. (Subfolders are separate packages that compile into the same dll; you don't need
them to start, and [Script Modules](modules.md) covers them when you do.)

That package needs one init shim: an `@(export) odin_scripts_boot` the core calls right after
it loads the dll, so the dll initializes its own `gdext`/`godot` package globals. **`scriptgen`
generates this for you** as `scripts/odin_godot_boot.gen.odin` on every build, so you normally
write nothing. For reference, the generated file is:

```odin
package my_game_scripts

import "godot:gdext"
import "godot:godot"

@(export)
odin_scripts_boot :: proc "c" (
	get_proc_address: gdext.ExtensionInterfaceGetProcAddress,
	library: gdext.ExtensionClassLibraryPtr,
) {
	gdext.init(library, get_proc_address)
	godot.init()
}
```

To customize it (rare), add a hand-written file defining `odin_scripts_boot`; scriptgen
detects it and skips generating its own. The in-repo `tests/`/`examples/` projects take this
opt-out, carrying a hand-written `boot.odin`.

### 2c. Tell the editor where odin_godot lives

The build and the editor's tooling resolve the Odin `godot` collection (the binding) from the
odin_godot checkout. Point one of these at it:

- the `ODIN_GODOT_ROOT` environment variable (used by the build scripts), or
- the **`odin_godot/root`** project setting (used by the editor's validation), set to the
  absolute path of your odin_godot checkout.

If you launch the editor from outside the Nix shell, it usually can't find `odin` on its
`PATH`; point it at the compiler with the **`odin_godot/odin_bin`** project setting (absolute
path to the `odin` binary) so reload-on-save works. (For autocomplete, `odin_godot/ols_bin`
similarly points at `ols`.) These settings are summarized in
[Workflow → editor settings](workflow.md#editor-settings-reference).

## 3. Write your first script

Create `scripts/mover.odin`. This is a `Node2D` that prints once on `_ready` and walks right
every frame, built only from constructs verified in the showcase and survivors examples:

```odin
//gd:extends Node2D       // the Godot base class this script extends
//gd:class Mover          // optional global class alias; path identity works without it
package my_game_scripts

import gd "godot:godot"

// The script struct. The FIRST field MUST be the owner node handle — the core writes the
// node pointer there. Its type is just the handle you want to use (Node2d here).
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
- **Prefix proc names with the struct name** (`mover_ready`, `mover_process`). All scripts
  share one package, so the prefix avoids collisions, and the prefix is stripped to derive the
  GDScript-facing name.
- The `//gd:` comment markers declare the class. `//gd:extends` names the base class and the
  `owner` field is the handle you use in code. The two are cross-checked (the handle must be
  the base or an ancestor of it), and `//gd:extends` may be omitted entirely, in which case the
  base is derived from the handle.

You do **not** write the registration boilerplate: `build/build_scripts.sh` runs `scriptgen`,
which emits it into `scripts/odin_godot_scripts.gen.odin`, one generated file for the whole
directory (a build artifact you never edit, hidden in the FileSystem dock).

## 4. Build

From the Nix shell, point the build script at your project directory:

```sh
nix develop --command bash -c 'bash build/build_scripts.sh /path/to/your/project'
```

This (1) builds `scriptgen`, (2) generates the `*.gen.odin` build artifacts, (3) compiles your
`scripts/` package into `bin/libodinscripts.dylib`, and (4) compiles the core into
`bin/libodin_godot.dylib`. (`build_scripts.sh` takes the project dir as its first argument and
defaults the scripts dir to `<project>/scripts`.)

## 5. Attach and run

1. Open the project in Godot (`$GODOT --path /path/to/your/project`, or via the Project
   Manager). The editor loads `odin_godot.gdextension` and recognizes `.odin` files.
2. Add a **`Node2D`** to your scene (the base must match `//gd:extends`).
3. In the Inspector's **Script** slot, attach `res://scripts/mover.odin`, the same file you
   wrote (there is no separate resource stub; the `.odin` *is* the attachable script).
4. The Inspector now shows the **Speed** `@export` (default 120).
5. **Run the scene.** You'll see `Mover ready!` in the Output panel and the node walking
   right.

To verify headless without the GUI, mirror what the example `run.sh` scripts do:

```sh
$GODOT --path /path/to/your/project          # windowed
$GODOT --headless --path /path/to/your/project --quit-after 30   # smoke test
```

## Next steps

- **Building multiplayer?** → the [co-op quickstart](kit/quickstart.md): it takes you from
  zero to two windows moving a player, in two small files.
- **[Authoring Guide](authoring-guide.md)** covers exports of every type, signals, methods,
  resources, cross-script calls, autoloads, and the full `gd.*` helper catalog.
- **[Workflow](workflow.md)** covers the edit→reload loop, editor squiggles/autocomplete, and
  debugging.
- Read `examples/survivors/scripts/*.odin`. Each is heavily commented to teach one feature.
</content>
