# Add Odin to an existing project

An existing Godot project needs the core extension, a scripts package, and a
build command. Its scenes and assets can stay in their current layout. The
installed addon supplies engine bindings and build helpers; your project owns
its scripts and generated library.

## Install the addon

Copy the distributable's `addons/odin_godot` directory into the project's
`res://addons/`. Godot discovers its `.gdextension` manifest when the project
opens. Use the manifest and native binaries from the same distribution.

If you are building the core yourself, follow the
[full wiring guide](../../getting-started.md#2-how-a-project-is-wired). The native
core library registers Odin with Godot and loads the separate scripts library.

## Create a scripts package

Create a `scripts/` directory and add an Odin script. All `.odin` files in this
directory use the same package name. Copy the addon's ordinary starter scripts
when you want a working scene to modify; use the optional Replay starter when
you want a complete-world simulation.

The build generates the boot registration normally required to initialize the
script library. Keep custom registration only when the project intentionally
owns that setup. [Your first script](first-script.md) shows a small attached node.

## Compile the scripts

Run this from your project's root, replacing the addon path if necessary:

```sh
ODIN_GODOT_ROOT="$PWD/addons/odin_godot" SKIP_CORE=1 \
  bash addons/odin_godot/build/build_scripts.sh .
```

`SKIP_CORE=1` uses the addon's prebuilt core. The script library is written under
the project's `bin/`, using the platform's shared-library extension. An Odin
compiler must be available on `PATH`, or configured in the editor's settings.

For a checkout-based build, use the checkout's `build/build_scripts.sh` and pass
the game directory as its first argument. Set `ODIN_GODOT_ROOT` or the editor's
`odin_godot/root` consistently so imports resolve to the same SDK.

## Work with the editor

Attach an `.odin` file directly to a matching node type. Inspector exports,
signals, animation callbacks, and typed engine calls use the regular authoring
surface. Use [reload-on-save and editor settings](../../workflow.md) to configure
the development loop.

The scripts are compiled ahead of time. Changing code or exported layout requires
a rebuild. For a loader failure, read the engine's library error and check that
the scripts library, core, and compiler ABI are compatible before changing gameplay.

## Add a multiplayer framework

Kit and Replay are optional imports. Kit integrates field declarations with script
entities; Replay puts the mutable simulation in a separate pure Odin model.
Choose [the state and authority model](multiplayer.md) before splitting gameplay
between nodes and shared state.

For larger games, [script modules](../../modules.md) provide independently built
script packages. Use them when rebuild boundaries matter; a small project can
start with one scripts package.
