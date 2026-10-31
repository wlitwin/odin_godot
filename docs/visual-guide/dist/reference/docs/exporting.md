# Exporting — shipping your game

The editor export plugin compiles `.odin` scripts ahead of time and bundles
the resulting library into the exported game. Players do not need an Odin
compiler. Native desktop and web/WASM exports use different library layouts,
described below.

Implementation notes on plugin registration, per-platform bundling, and the
`when WEB` split are in
[design/export-internals.md](design/export-internals.md) and
[design/web-internals.md](design/web-internals.md).

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

## Native desktop (macOS) — verified

The macOS export test verifies that the exported `.app` loads the extension
and runs an Odin script compiled during export.

```sh
$GODOT --headless --path your_project --export-release "macOS" out/Game.app
```

A verified bundle looks like:

```
out/Game.app/Contents/MacOS/Game                          (universal template, ad-hoc signed)
out/Game.app/Contents/Resources/Game.pck                  (project + rewritten .gdextension)
out/Game.app/Contents/Frameworks/libodin_godot.dylib      (core — auto-exported by Godot)
out/Game.app/Contents/Frameworks/libodinscripts.dylib     (scripts — bundled by the plugin)
```

`tests/phase5/run.sh` reproduces this headless end to end (`PHASE5_OK`): it builds core, runs a
headless `--export-release "macOS"` export (the plugin compiles and bundles the scripts dll),
then runs the exported `.app` headless and asserts the Odin `_ready` ran.

**macOS export gotchas:**

- The installed `macos.zip` template ships only a **universal** binary, so the preset must use
  `binary_format/architecture="universal"` (not `"arm64"`), else "Requested template binary …
  arm64 not found". It runs fine on arm64.
- arm64 export needs ETC2 ASTC:
  `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot`, else export
  aborts.
- Two non-fatal `Required virtual method … _update_exports / _get_script_signal_list` warnings
  may print during the export's class scan. These are harmless.

## Cross-compile (Linux / Windows) — build-verified

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

## Web / WASM — verified in a real browser

The core `ScriptLanguageExtension`, generated binding, and compiled scripts
link into one Emscripten `SIDE_MODULE` wasm bundled by Godot's web exporter.
A headless-Chrome test checks that a script's `_ready` runs in the browser and
a `@(gd_method)` returns the expected value. `tests/web_showcase/` also checks
the pure-Odin coin-collector game loop in-browser.

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

2. **Point the editor at the binaries.** When you launch Godot from Finder/Steam/the Project
   Manager, the editor process doesn't inherit your shell `PATH`, so it can't see `odin` or
   `emcc`. Set these **project settings** to their absolute paths (Project → Project Settings,
   "Add" a custom property):
   - `odin_godot/odin_bin` → your `odin`
   - `odin_godot/emcc_bin` → `…/emsdk/upstream/emscripten/emcc`

   The export plugin uses these settings to find tools, build the wasm, and
   bundle it from the export dialog. Alternatively, launch the editor from a terminal
   where both are already on `PATH` (e.g. after `source ./emsdk/emsdk_env.sh`).

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

**Serving:** Godot web needs `SharedArrayBuffer`, which requires two HTTP headers:

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

- The browser offers **no hot reload** (there is no `dlopen`, and only one shared linear
  memory is used with the engine).
- **Native debugging isn't available**: debug with `gd.print`, which prints to the JS console
  and browser devtools.
- **Emscripten version:** Godot 4.7.1's web templates were built with emscripten **4.0.20**;
  the module runs with the dev shell's **5.0.6** too (`-sSUPPORT_LONGJMP=wasm` keeps the
  longjmp ABI self-contained and the dylink format is cross-compatible). To pin the exact
  version anyway: `EMCC=/path/to/emsdk/.../emcc bash build/build_web.sh`.

## Verify it headless

```sh
nix develop --command bash -c 'bash tests/phase5/run.sh'        # native -> PHASE5_OK
nix develop --command bash -c 'bash tests/web/run.sh'           # web    -> PHASEWEB_OK
nix develop --command bash -c 'bash tests/web_showcase/run.sh'  # web game loop -> PHASEWEBSHOWCASE_OK
```

The web tests are **browser-gated**: with Chrome + `puppeteer-core` present they run in a
headless browser and assert the Odin script ran; without them they still build + web-export and
report a non-fatal `SKIP`. The full suite (`tests/run_all.sh`) wires all of these in.
