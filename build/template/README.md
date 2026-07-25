# Your scripts go here — odin_godot starter template

odin_godot ships a **prebuilt core** (the engine integration); your gameplay code is
**yours**, compiled into a separate *scripts dll*. A fresh project therefore has nothing
to build until you add scripts — this template is that starting point.

## Get started

1. **Copy `scripts/` into your project root** as `res://scripts/`.
   - `hello.odin` — a minimal example class (`Hello`, extends `Node`). Edit or replace it
     with your own.
   - The build generates the `*.gen.odin` files for you and you never write or edit them:
     `odin_godot_scripts.gen.odin` (the registration code for every script in the
     directory), `odin_godot_boot.gen.odin` (the required `odin_scripts_boot` export the
     core needs after it loads your dll), and `odin_godot_guard.gen.odin` (a staleness
     guard). To customize the boot shim, drop in your own file defining `odin_scripts_boot`
     and the generated one steps aside.

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
   pick the `Hello` class (it appears once the scripts dll is built), then press **Play**.
   The Output panel prints the hello message.

## Adding your own scripts

A script needs the two `//gd:` markers (`//gd:extends <Base>`, `//gd:class <Name>`), a
struct whose first field is `owner`, and lifecycle/method procs named `<class>_<hook>`
(`hello_ready`, `hello_process`, …). The editor rebuilds the scripts dll on save once the
project is set up. See the full reference in the addon's
[`../docs/authoring-guide.md`](../docs/authoring-guide.md) (and
[`../README.md`](../README.md) for install/prerequisites).
