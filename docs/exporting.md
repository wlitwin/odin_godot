# Exporting — shipping your game

The editor export plugin compiles `.odin` scripts ahead of time and bundles
the resulting library into the exported game. Players do not need an Odin
compiler. Native desktop and web/WASM exports use different library layouts,
described below.

## How export works (both targets)

Two GDExtension classes in `core/export_plugin.odin` are registered at editor
initialization and are absent from running/exported games:

- **`OdinExportPlugin`** (`EditorExportPlugin`) builds and bundles scripts. On
  `_export_begin`, it reads the target OS from export features and resolves
  tools in this order: `odin_godot/odin_bin` / `odin_godot/emcc_bin` project
  settings, `ODIN`/`EMCC` environment variables, then `PATH`. Project settings
  let it find tools when the editor starts outside a toolchain shell. It runs
  the matching build script and calls `add_shared_object` to include the
  compiled library beside the executable.
- **`OdinEditorPlugin`** (`EditorPlugin`) constructs and registers the export
  plugin.

Godot exports the core library from the `.gdextension` manifest's
`[libraries]` entries. The plugin adds the dynamically loaded scripts library,
which is not listed there. At runtime, native exports locate scripts beside
the core through `dladdr`; the packed `res://` filesystem cannot provide a
library to `dlopen`.

> The exporter bundles `libodinscripts` without collecting its transitive
> native dependencies. Pure-Odin scripts are self-contained. If scripts use
> `foreign import` for a third-party native library, bundle that dependency
> separately, for example through `add_shared_object` in a custom export
> plugin or by placing it beside the executable. A missing dependency causes
> `dlopen` to fail on the player's machine, leaving the game without Odin scripts.

**Script modules.** If the project uses [script modules](modules.md)
(`res://modules/<name>/`), the export plugin builds **one optimized dll per module** and
bundles each beside the main scripts library, where the exported game scans
for them at runtime. A missing module library fails export with an error
naming the module. `BUILD_MODULES=0` skips module building and bundling and
warns that their classes will be absent. Use it for scoped builds or CI checks,
not release exports. On web, all modules link into the single wasm. See
[Script Modules — Exporting](modules.md#exporting-with-modules).

**Box3D.** The normal exporter deploys the selected shared backend beside
Core and the script modules. Use a backend built for the export target, keep
its build environment available to the exporter, and retain the deployed files
together. See [Box3D build and export](box3d/building.md) and
[platform support](box3d/support.md).

## Native desktop on macOS

The macOS export bundles the core and scripts into the application. The export
host needs the compiler; the player does not.

```sh
$GODOT --headless --path your_project --export-release "macOS" out/Game.app
```

The bundle layout is:

```
out/Game.app/Contents/MacOS/Game                          (universal template, ad-hoc signed)
out/Game.app/Contents/Resources/Game.pck                  (project + rewritten .gdextension)
out/Game.app/Contents/Frameworks/libodin_godot.dylib      (core — auto-exported by Godot)
out/Game.app/Contents/Frameworks/libodinscripts.dylib     (scripts — bundled by the plugin)
```

For the authored Box3D samples, the `macOS arm64` preset uses a universal
Godot launcher with arm64 SDK/backend libraries. Check every bundled library's
architecture and minimum OS; a universal launcher alone does not make the
whole application universal.

**macOS export gotchas:**

- The installed `macos.zip` template ships only a **universal** binary, so the preset must use
  `binary_format/architecture="universal"` (not `"arm64"`), else "Requested template binary …
  arm64 not found". It runs fine on arm64.
- arm64 export needs ETC2 ASTC:
  `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot`, else export
  aborts.
- Two non-fatal `Required virtual method … _update_exports / _get_script_signal_list` warnings
  may print during the export's class scan. These are harmless.

## Cross-compile for Linux or Windows

odin_godot cross-builds the Linux `.so` and Windows `.dll` (core + scripts) from macOS.
Odin's own driver refuses to *cross-link* a dll, so `build/build_cross.sh` emits a single
relocatable object (`-build-mode:obj -use-single-module -target:<t>`) and links it with a Nix
cross **gcc wrapper** (`pkgsCross.gnu64` / `pkgsCross.mingwW64`) that carries the target glibc
/ mingw sysroot:

```sh
nix develop .#cross --command bash -c 'bash build/build_cross.sh linux   tests/phase35'
nix develop .#cross --command bash -c 'bash build/build_cross.sh windows tests/phase35'
```

`tests/cross/run.sh` checks output format, architecture, and exported entry
symbols. It reports SKIP if the cross toolchain is unavailable. These checks
verify builds; they do not run Linux/Windows Godot or load the resulting
libraries on those targets. See [distribution.md](distribution.md) for the
status table, packaged addon, and target-host runtime checks.

## Browser export

The core `ScriptLanguageExtension`, generated binding, and compiled scripts
link into one Emscripten `SIDE_MODULE` wasm bundled by Godot's web exporter.
### Toolchain setup (one-time)

Web export needs the Odin compiler and Emscripten on the export host. The Nix
development shell supplies both. For an addon installed in another project,
configure them once:

1. **Install the Emscripten SDK** from <https://emscripten.org/docs/getting_started/downloads.html>:
   ```sh
   git clone https://github.com/emscripten-core/emsdk && cd emsdk
   ./emsdk install 4.0.20 && ./emsdk activate 4.0.20
   ```
   Use 4.0.20 to match the dylink/longjmp ABI of Godot 4.7's web templates.
   The Web caveats below describe verification with another emcc version.

2. **Build once from the toolchain shell.** Successful builds remember tool paths
   in the project's ignored `.godot` directory. The editor can then find them
   after reopening from Finder/Steam/the Project Manager without inheriting your
   shell `PATH`. To supply explicit overrides, set these project settings:
   - `odin_godot/odin_bin` → your `odin`
   - `odin_godot/emcc_bin` → `…/emsdk/upstream/emscripten/emcc`

   The export plugin uses the same tool resolution as the build helpers. You can
   also launch the editor from a terminal where both tools are already on `PATH`
   (e.g. after `source ./emsdk/emsdk_env.sh`).

### Build the wasm

```sh
bash build/build_web.sh your_project
# -> your_project/bin/libodin_godot.wasm  (one Emscripten SIDE_MODULE)
```

Native builds load scripts separately through `dlopen`. Web builds link the
core, binding, and scripts ahead of time into one side module. The build
switch `-define:ODIN_GODOT_WEB=true` and architecture-gated files select this
in-module path, excluding `dlopen`, hot reload, and editor/export code.

### Export and serve

```sh
$GODOT --headless --path your_project --export-release "Web" out/index.html
```

The example projects configure these requirements:

- The project `.gdextension` keeps its **native** `macos.*` entries **and** adds
  `web.{debug,release}.wasm32 = "res://bin/libodin_godot.wasm"`. The native entry is what loads
  the extension **on the macOS export host** so the loader recognizes your `.odin` files and
  **packs them** into the `.pck`. Without it, the sources are excluded and base types can't
  resolve in the browser.
- The Web export preset needs `variant/extensions_support=true` (selects Godot's dlink web
  runtime).
- The editor's export plugin runs `build/build_web.sh` at export time to
  produce the wasm file referenced by `.gdextension`.
- **Thread Support** selects the memory mode for both Godot and the compiled
  extension. The exporter passes the active preset to the build; ordinary
  native-free games support either mode. The Box3D Web backend requires the
  threaded mode and reports an incompatible preset before compilation.
- Script code must not import `core:os`, because Odin's native OS layer does
  not compile for wasm. Importing it produces errors in `core/os` files, such
  as `Undeclared name: _read_directory_iterator`. Use engine APIs instead: `gd.singleton_os()` +
  `gd.os_get_environment(...)` / `gd.os_has_environment(...)` work on every platform
  (see `examples/barrage/scripts/game_state.odin` for the pattern).
- Odin's `int` is **32-bit on wasm32** (it's pointer-sized). Never store an engine 64-bit
  value, especially instance IDs from `object_get_instance_id`, in `int`. The
  code can compile and work natively while truncating IDs on web, causing
  `gd_instance_from_id` to return no object. Use `i64`/`gd.Int` for IDs and anything
  else that is 64-bit engine-side.

Direct `build_web.sh` calls read the project's Web presets. If several presets
use different memory modes, export the desired preset through Godot, or select
`ODIN_WEB_THREADS=0` / `1` for a deliberate standalone side-module build. No
duplicate setting is needed for normal editor or command-line Godot exports.

**Serving:** threaded Web exports use `SharedArrayBuffer`, which requires two HTTP headers:

```
Cross-Origin-Opener-Policy:   same-origin
Cross-Origin-Embedder-Policy: require-corp
```

Configure these headers on the serving host. `python -m http.server` does not
set them by default. The addon includes a Node server that supplies them:

```sh
bash addons/odin_godot/build/serve.sh path/to/export_dir   # then open http://localhost:8099/
```

Use the same two headers in deployment. On itch.io, enable
**"SharedArrayBuffer support"** in the HTML5 settings to configure them.

### Web caveats

- **Engine shutdown:** on the tested Godot 4.7.1 single-threaded Web runtime,
  quitting the entire engine after audio playback reports a
  `WorkerThreadPool::Group` allocator diagnostic even in a plain GDScript project.
  Scene/audio retirement and normal browser play/save/reload are separate checks;
  error-free engine shutdown is not qualified for that runtime. Remove owned game
  scenes and let their audio references retire before requesting engine exit.
  The threaded variant passes that strict orderly-shutdown check. The reproduction
  and exact scope are retained in `tests/web_memory/`.
- The browser offers **no hot reload** (there is no `dlopen`, and only one shared linear
  memory is used with the engine).
- **Native debugging isn't available**: debug with `gd.print`, which prints to the JS console
  and browser devtools.
- **Emscripten version:** Godot 4.7.1's web templates were built with emscripten **4.0.20**;
  the module runs with the dev shell's **5.0.6** too (`-sSUPPORT_LONGJMP=wasm` keeps the
  longjmp ABI self-contained and the dylink format is cross-compatible). To pin the exact
  version anyway: `EMCC=/path/to/emsdk/.../emcc bash build/build_web.sh`.

## Check the exported game

Run the exported application from a clean directory with only its packaged
files. Exercise script startup, input, and a gameplay interaction. For web,
serve the export with the required headers and inspect the browser console.
A successful file export alone does not establish that scripts ran.

SDK contributors can use the focused export fixtures described in
[Contributing](contributing/index.md).
