# Build and export a game

The native editor and an exported game have different loading arrangements.
Understand the build products before choosing an export target. Keep the SDK,
Odin compiler, Godot engine, and export templates compatible with the checkout
or addon release you are using.

## Native development

The core GDExtension loads a separately compiled scripts library. The normal
repository build command compiles both:

```sh
bash build/build_scripts.sh /absolute/path/to/your_game
```

An installed addon can reuse its prebuilt core with `SKIP_CORE=1`. Generated
registration and boot files are compiled with authored source. A successful
compile is the first check; open the game and inspect the engine output for
library or ABI errors.

## Desktop exports

The editor export plugin compiles scripts for the target and packages them with
the core. Cross-target builds need the matching native toolchain. Use the
[export reference](../../exporting.md) for presets, cross compilation, and the
platform-specific evidence. The [distribution guide](../../distribution.md)
distinguishes build verification from execution on a target machine.

Check the exported game itself. Opening a project in the editor does not exercise
the exported library locations or prove that the target has all required assets.

## Browser exports

The web build links the extension and scripts into one Emscripten side module:

```sh
bash build/build_web.sh /absolute/path/to/your_game
```

Use a Web export preset with extension support and a compatible Emscripten
toolchain. The repository's [web instructions](../../exporting.md#web--wasm--verified-in-a-real-browser)
explain template compatibility, editor tool paths, manifest entries, and the
actual export command.

Avoid native-only imports in code compiled for WASM. Store Godot instance IDs in
the documented 64-bit type rather than pointer-sized Odin `int`. Web does not
provide the native library reload path; inspect browser console output when
debugging a web build.

## Serve the exported game

Godot web configurations that use shared memory require cross-origin isolation.
The bundled local server supplies the relevant headers:

```sh
bash addons/odin_godot/build/serve.sh path/to/export_dir
```

Configure the same requirements on the production game host. On itch.io, use its
SharedArrayBuffer support option for a build that needs it. The SDK documentation
website is ordinary static HTML; serving the docs and serving a Godot game are
separate hosting tasks.

## Check the network deployment separately

A local native host/client run does not establish internet reachability. Browser
multiplayer needs an appropriate RTC/Party configuration. Plan signaling, relay
or TURN policy, admission, identity storage, and trusted authority deployment
according to the chosen runner. The small Replay starter's browser mode is
offline until the game supplies that network configuration.

Use [debugging](../../debugging.md) for native failures and the examples' focused
checks for input, correction, recovery, and browser workflows.
