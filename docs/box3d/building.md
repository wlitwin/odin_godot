# Build and export Box3D

Build the pinned native backend, select it explicitly when building scripts, and
keep the deployed backend with its SDK core. Use the checkout's Nix shell for
the compiler, CMake, and export tools.

## Build the backend

From the repository root:

```sh
nix develop
bash build/build_box3d.sh Release "$PWD/.box3d-cache"
```

The script fetches the pinned source, applies the SDK's patches, builds the
backend, runs its registered native checks, and records a build manifest. Its
output includes `.box3d-cache/build/Release/libogb3.a`, the platform's shared
library, and `build-manifest.json`. Keep these together.

## Build a project

On macOS:

```sh
export BOX3D_NATIVE_LIBRARY="$PWD/.box3d-cache/build/Release/libogb3.dylib"
bash build/build_scripts.sh /absolute/path/to/your/project
"$GODOT" --editor --path /absolute/path/to/your/project
```

Linux uses `libogb3.so`. The builder verifies the backend's metadata and deploys
one shared image beside the core. All gameplay modules in the process must use
that image. The ordinary bridge and native-free framework packages can build
without selecting Box3D.

Launch the editor with this environment so save-time builds inherit the backend
selection. If the build reports a changed runtime, stop Godot before rebuilding
with `BOX3D_REPLACE_RUNTIME=1`. Reloading scripts does not replace a native
backend that still owns worlds or snapshots.

## Export desktop builds

Use the normal [Godot export workflow](../exporting.md). Keep
`BOX3D_NATIVE_LIBRARY` and `ODIN_GODOT_ROOT` available to the export subprocess,
and select a backend built for the target. The export plugin deploys the backend
beside the exported core and modules; keep these files together.

The authored Kit and Replay samples provide `macOS arm64` and `Linux x86_64`
presets. The macOS preset uses a universal Godot launcher with arm64 SDK/backend
libraries, so it does not provide an Intel-compatible SDK bundle. Signing and
notarization for public distribution require your own configuration.

## Export the offline browser example

```sh
nix develop --command bash examples/box3d_offline/export_web.sh
nix develop --command bash build/serve.sh examples/box3d_offline/out/web
```

The browser build links the WebAssembly backend into the game's module rather
than loading a desktop `.dylib` or `.so`. Use the example's export helper and
presets. A threaded browser build requires cross-origin isolation; the local
server supplies the headers.

The desktop authored samples and the offline web example have different
deployment paths. Read [Support](support.md) before combining a browser export
with multiplayer physics or selecting another platform.
