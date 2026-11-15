<a id="your-scripts-go-here--odin_godot-starter-template"></a>

# odin_godot script starter template

For the separate experimental Replay multiplayer starter, use `replay/` instead.
It includes its own project, scene, scripts and pure gameplay model. Do not merge
both starters into one scripts package without adapting their package declarations.

odin_godot supplies the prebuilt engine core. The project compiles its authored
Odin gameplay scripts into a separate scripts library. This template supplies
the initial script for that library.

## Get started

1. **Copy `scripts/` into your project root** as `res://scripts/`.
   - `hello.odin` — a minimal example class (`Hello`, extends `Node`). Edit or replace it
     with your own.
   - The build generates the `*.gen.odin` files for you and you never write or edit them:
     `odin_godot_scripts.gen.odin` (the registration code for every script in the
     directory), `odin_godot_boot.gen.odin` (the required `odin_scripts_boot` export the
     core needs after it loads your dll), and `odin_godot_guard.gen.odin` (a staleness
     guard). To customize the boot shim, define `odin_scripts_boot` in an authored
     file; the generator omits its default implementation.

2. **Build the scripts dll** (you need `odin` on your PATH):
   - **macOS / Linux:**
     ```sh
     ODIN_GODOT_ROOT="$PWD/addons/odin_godot" SKIP_CORE=1 \
       bash addons/odin_godot/build/build_scripts.sh .
     ```
   - **Windows** (from a "x64 Native Tools Command Prompt for VS"):
     ```powershell
     powershell -ExecutionPolicy Bypass -File addons\odin_godot\build\build_scripts.ps1 `
       -Root addons\odin_godot -Project . -SkipCore
     ```
   This writes `bin/libodinscripts.<ext>`. (Drop `SKIP_CORE`/`-SkipCore` to rebuild the
   core too — normally unnecessary, it's prebuilt in the addon.)

3. **Use it in Godot:** open the project, add a `Node` to a scene, **Attach Script** and
   pick `res://scripts/hello.odin`, which defines `Hello`, then press **Play**.
   The Output panel prints the hello message.

## Adding your own scripts

A script needs a struct whose first field is `owner` and lifecycle/method procs named
`<struct>_<hook>`. Both common markers are optional: the base derives from `owner`, and
`//gd:class <Name>` is only needed for a Godot global-class alias. The authored `res://`
path binds the script to its compiled descriptor. The editor rebuilds the scripts dll on
save once the project is set up. See the full reference in the addon's
[`../docs/authoring-guide.md`](../docs/authoring-guide.md) (and
[`../README.md`](../README.md) for install/prerequisites).
