# Getting started

Install the toolchain, build the extension, add it to a Godot project, then
write and attach an Odin script. The resulting `Node2D` prints on `_ready` and
moves every frame.

> **Run an existing project:** `examples/survivors/` and `tests/showcase/` are complete, working
> projects. To run one before creating a project:
> ```sh
> nix develop
> bash build/build_scripts.sh tests/showcase
> $GODOT --path tests/showcase
> ```
> The steps below explain their project structure so you can create your own.

## 1. Install the toolchain (Nix)

The Nix flake pins Odin, the `ols` language server, LLVM/lld, Emscripten, and
Node, and configures `$GODOT` for Godot 4.7.1. Install
[Nix with flakes enabled](https://nixos.org/) and Godot 4.7.x first.

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

<a id="2-how-a-project-is-wired"></a>

## 2. Project files and library loading

Add three parts to a Godot project:

1. **A `.gdextension` manifest** that loads the compiled **core** dll.
2. **A `scripts/` package** containing your `.odin` scripts (the required boot shim is
   generated for you; see 2b).
3. **A build** (`build/build_scripts.sh`) that compiles your scripts (and the core) into the
   project's `bin/`.

The following setup uses the same structure as the showcase.

### 2a. The `.gdextension` manifest

Create `odin_godot.gdextension` at the project root using the manifest from
`examples/survivors/odin_godot.gdextension`:

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
"Odin" scripting language so the editor recognizes `.odin` files. The manifest
loads the core library, which then loads the scripts library
(`libodinscripts.dylib`) at runtime. The scripts library is not listed here.

### 2b. The `scripts/` package and its boot shim

The `.odin` files in `scripts/` form one Odin package compiled into a shared
library. Use the same `package` line in every file in that directory.
Subfolders form separate packages that can compile into the same library.
Start with one directory; see [Script Modules](modules.md) when a project
needs separately compiled modules.

After loading the scripts library, the core calls `@(export) odin_scripts_boot`
to initialize its `gdext`/`godot` package globals. On each build, `scriptgen` generates the
procedure in `scripts/odin_godot_boot.gen.odin`, so a normal project does not
need to define it. The generated file contains:

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

To customize initialization, define `odin_scripts_boot` in an authored file.
scriptgen detects it and skips generating its own. The repository's
`tests/`/`examples/` projects use this option with a hand-written `boot.odin`.

### 2c. Tell the editor where odin_godot lives

The build and editor tools need the odin_godot checkout to resolve the Odin
`godot` collection, which contains the engine bindings. Configure its location
through:

- the `ODIN_GODOT_ROOT` environment variable (used by the build scripts), or
- the **`odin_godot/root`** project setting (used by the editor's validation), set to the
  absolute path of your odin_godot checkout.

If you launch the editor from outside the Nix shell, it usually can't find `odin` on its
`PATH`; point it at the compiler with the **`odin_godot/odin_bin`** project setting (absolute
path to the `odin` binary) so reload-on-save works. (For autocomplete, `odin_godot/ols_bin`
similarly points at `ols`.) These settings are summarized in
[Workflow → editor settings](workflow.md#editor-settings-reference).

## 3. Write your first script

Create `scripts/mover.odin`. This script extends `Node2D`, prints once on
`_ready`, and moves right each frame. Its declarations and lifecycle methods
are also used in the showcase and survivors examples:

```odin
//gd:extends Node2D       // the Godot base class this script extends
//gd:class Mover          // optional global class alias; path identity works without it
package my_game_scripts

import gd "godot:godot"

// The script struct's first field must be the owner node handle; the core writes
// the node pointer there. Use the required engine handle type (Node2d here).
Mover :: struct {
	owner: gd.Node2d,
	speed: f32 `gd:"export,default=120"`,   // @export var, tunable in the Inspector
}

// `<struct>_ready` runs when the node is ready; the `mover_` prefix is stripped.
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

`self` points to the Odin script data. `self.owner` is the Godot node handle
used to read and change the engine node's position.

The example follows these declaration rules; see the
[Authoring Guide](authoring-guide.md) for details:

- **One script struct per file**, identified by its first field being named `owner`.
- **Prefix proc names with the struct name** (`mover_ready`, `mover_process`). All scripts
  share one package, so the prefix avoids collisions, and the prefix is stripped to derive the
  GDScript-facing name.
- The `//gd:` comment markers declare the class. `//gd:extends` names the base class and the
  `owner` field is the handle you use in code. The two are cross-checked (the handle must be
  the base or an ancestor of it), and `//gd:extends` may be omitted entirely, in which case the
  base is derived from the handle.

`build/build_scripts.sh` runs `scriptgen` to generate registration in
`scripts/odin_godot_scripts.gen.odin`, one file for the directory. Edit the
authored scripts; this build output is regenerated and hidden in the FileSystem dock.

## 4. Build

From the Nix shell, point the build script at your project directory:

```sh
nix develop --command bash -c 'bash build/build_scripts.sh /path/to/your/project'
```

The build (1) compiles `scriptgen`, (2) generates the `*.gen.odin` build artifacts, (3) compiles your
`scripts/` package into `bin/libodinscripts.dylib`, and (4) compiles the core into
`bin/libodin_godot.dylib`. (`build_scripts.sh` takes the project dir as its first argument and
defaults the scripts dir to `<project>/scripts`.)

## 5. Attach and run

1. Open the project in Godot (`$GODOT --path /path/to/your/project`, or via the Project
   Manager). The editor loads `odin_godot.gdextension` and recognizes `.odin` files.
2. Add a **`Node2D`** to your scene (the base must match `//gd:extends`).
3. In the Inspector's **Script** slot, attach `res://scripts/mover.odin` directly.
   The `.odin` file is the script resource; no separate resource stub is needed.
4. The Inspector now shows the **Speed** `@export` (default 120).
5. **Run the scene.** You'll see `Mover ready!` in the Output panel and the node walking
   right.

To verify headless without the GUI, mirror what the example `run.sh` scripts do:

```sh
$GODOT --path /path/to/your/project          # windowed
$GODOT --headless --path /path/to/your/project --quit-after 30   # smoke test
```

## Next steps

- The [co-op quickstart](kit/quickstart.md) builds a multiplayer example in two
  files, with a player moving in two game windows.
- **[Authoring Guide](authoring-guide.md)** covers exports of every type, signals, methods,
  resources, cross-script calls, autoloads, and the full `gd.*` helper catalog.
- **[Workflow](workflow.md)** covers the edit→reload loop, editor squiggles/autocomplete, and
  debugging.
- Read `examples/survivors/scripts/*.odin`. Each is heavily commented to teach one feature.
