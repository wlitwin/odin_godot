# Exporting — shipping your game

An exported game has **no Odin compiler**. So `.odin` scripts are compiled **ahead of time, at
export**, by an editor export plugin, and the resulting library is bundled into the build. This
covers the two targets: native desktop and web/WASM.

The internals (how the plugin is registered, per-platform bundling, the `when WEB` split, every
wasm blocker found and fixed) live in
[design/export-internals.md](design/export-internals.md) and
[design/web-internals.md](design/web-internals.md). This page is the user-facing how-to.

## How export works (both targets)

Two GDExtension classes in `core/export_plugin.odin` are registered **only at editor
initialization**, so they don't exist in a running/exported game:

- **`OdinExportPlugin`** (`EditorExportPlugin`) does the work. On `_export_begin` it reads the
  target OS from the export feature set, resolves the toolchain (the `odin_godot/odin_bin` /
  `odin_godot/emcc_bin` project settings → `ODIN`/`EMCC` env → `PATH`, so it works even when
  the editor is launched outside a toolchain shell), shells the matching build script, and
  `add_shared_object`s the freshly-compiled scripts library so the exporter copies it **beside
  the executable**.
- **`OdinEditorPlugin`** (`EditorPlugin`) is a thin host that constructs and registers the
  export plugin.

The **core** dll is exported automatically by Godot's own GDExtension handling (it's listed in
the `.gdextension`'s `[libraries]`); the plugin only bundles the dynamically-loaded scripts
library, which Godot doesn't otherwise know about. At runtime an exported game finds the scripts
library as a **sibling of the core dll** (via `dladdr`), since `res://` is packed and can't be
`dlopen`ed.

> **Keep your scripts self-contained.** The exporter bundles `libodinscripts` but **not its
> transitive native dependencies**. A pure-Odin scripts library is self-contained and ships
> fine; but if your scripts `foreign import` a third-party native lib, that lib is **not**
> bundled automatically — `dlopen` will fail on a player's machine (the game then runs with no
> Odin scripts). If you pull in native deps, add them to the export yourself (e.g. another
> `add_shared_object` via your own export plugin, or place them beside the executable).

**Script modules.** If the project uses [script modules](modules.md)
(`res://modules/<name>/`), the export plugin builds **one optimized dll per module** and
bundles each beside the main scripts dll — the exact sibling layout the exported game scans
for at runtime. A module whose dll is missing **fails the export loudly, naming the module**
(an export must never silently ship without a module's classes). The `BUILD_MODULES=0` env
var skips modules at build *and* bundling — also loudly, since the result intentionally
lacks the module classes; it is a scoped-build/CI switch, not a shipping configuration. On
**web**, all modules compose into the single wasm. See
[Script Modules — Exporting](modules.md#exporting-with-modules).

## Native desktop (macOS) — verified

This is the firm, end-to-end-verified path. The exported `.app` loads the extension and runs an
Odin script compiled at export time.

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

`tests/phase5/run.sh` reproduces this headless end to end (`PHASE5_OK`): build core → headless
`--export-release "macOS"` (the plugin compiles + bundles the scripts dll) → run the exported
`.app` headless and assert the Odin `_ready` ran.

**macOS export gotchas:**

- The installed `macos.zip` template ships only a **universal** binary, so the preset must use
  `binary_format/architecture="universal"` (not `"arm64"`), else "Requested template binary …
  arm64 not found". It runs fine on arm64.
- arm64 export needs ETC2 ASTC:
  `rendering/textures/vram_compression/import_etc2_astc=true` in `project.godot`, else export
  aborts.
- Two non-fatal `Required virtual method … _update_exports / _get_script_signal_list` warnings
  may print during the export's class scan. Harmless.

## Cross-compile (Linux / Windows) — build-verified

odin_godot now cross-builds the Linux `.so` and Windows `.dll` (core + scripts) from macOS.
Odin's own driver refuses to *cross-link* a dll, so `build/build_cross.sh` emits a single
relocatable object (`-build-mode:obj -use-single-module -target:<t>`) and links it with a Nix
cross **gcc wrapper** (`pkgsCross.gnu64` / `pkgsCross.mingwW64`) that carries the target glibc
/ mingw sysroot:

```sh
nix develop .#cross --command bash -c 'bash build/build_cross.sh linux   tests/phase35'
nix develop .#cross --command bash -c 'bash build/build_cross.sh windows tests/phase35'
```

The outputs are the right format/arch and **export the entry symbol** (`tests/cross/run.sh`
asserts this; gated to SKIP when no cross toolchain is present). These targets are
**build-verified but NOT runtime-verified on this macOS host** — a Linux/Windows Godot has to
load them. See **[distribution.md](distribution.md)** for the full status table, the
packaged addon, and the exact CI steps to runtime-confirm.

## Web / WASM — verified in a real browser

The full extension (core `ScriptLanguageExtension` + the generated binding + your compiled
scripts) builds into **one Emscripten `SIDE_MODULE` wasm**, Godot's web export bundles it, and
an Odin script's `_ready` **runs in a real browser** — verified by a headless-Chrome driver
asserting the Odin script ran (and that a `@(gd_method)` returns the right value). The full
pure-Odin coin-collector game loop is also verified in-browser (`tests/web_showcase/`).

### Toolchain setup (one-time)

Web export needs the **Odin compiler** *and* **Emscripten** on the machine doing the export
(the same as a desktop build, plus emcc). If you work from the Nix dev shell both are already
present; if you installed the addon into your own project, set them up once:

1. **Install the Emscripten SDK** — <https://emscripten.org/docs/getting_started/downloads.html>:
   ```sh
   git clone https://github.com/emscripten-core/emsdk && cd emsdk
   ./emsdk install 4.0.20 && ./emsdk activate 4.0.20
   ```
   **Pin 4.0.20** — it's the exact version Godot 4.6's web templates were built with, so the
   dylink/longjmp ABI matches. (Newer emcc generally works too; 4.0.20 is the safe default.)

2. **Point the editor at the binaries.** When you launch Godot from Finder/Steam/the Project
   Manager, the editor process doesn't inherit your shell `PATH`, so it can't see `odin` or
   `emcc`. Set these **project settings** to their absolute paths (Project → Project Settings,
   "Add" a custom property):
   - `odin_godot/odin_bin` → your `odin`
   - `odin_godot/emcc_bin` → `…/emsdk/upstream/emscripten/emcc`

   With those set, **web export Just Works from the export dialog** — the plugin finds the
   tools, builds the wasm, and bundles it. Alternatively, launch the editor from a terminal
   where both are already on `PATH` (e.g. after `source ./emsdk/emsdk_env.sh`).

### Build the wasm

```sh
bash build/build_web.sh your_project
# -> your_project/bin/libodin_godot.wasm  (one Emscripten SIDE_MODULE)
```

Unlike native (a stable core dll that `dlopen`s a swappable scripts dll), the browser has no
dynamic loader we control and no compiler: **everything links AOT into a single side module.**
A build switch (`-define:ODIN_GODOT_WEB=true`) plus arch-gated files select the in-module path
(no `dlopen`, no hot reload, no editor/export code).

### Export and serve

```sh
$GODOT --headless --path your_project --export-release "Web" out/index.html
```

Requirements, all automated by the example projects:

- The project `.gdextension` keeps its **native** `macos.*` entries **and** adds
  `web.{debug,release}.wasm32 = "res://bin/libodin_godot.wasm"`. The native entry is what loads
  the extension **on the macOS export host** so the loader recognizes your `.odin` files and
  **packs them** into the `.pck` — without it the sources are excluded and base types can't
  resolve in the browser.
- The Web export preset needs `variant/extensions_support=true` (selects Godot's dlink web
  runtime).
- The editor's export plugin builds the wasm at export time (it shells `build/build_web.sh`),
  so the file the `.gdextension` references actually exists.
- Script code must not import `core:os` — Odin's native OS layer doesn't compile for the wasm
  target, so the export fails with `Undeclared name: _read_directory_iterator`-style compile
  errors naming `core/os` files. Go through the engine instead: `gd.singleton_os()` +
  `gd.os_get_environment(...)` / `gd.os_has_environment(...)` work on every platform
  (see `examples/barrage/scripts/game_state.odin` for the pattern).

**Serving:** Godot web needs `SharedArrayBuffer`, which requires two HTTP headers:

```
Cross-Origin-Opener-Policy:   same-origin
Cross-Origin-Embedder-Policy: require-corp
```

A plain static host or `python -m http.server` does **not** set these — the usual cause of "my
web export won't start". The addon bundles a one-command Node server that does:

```sh
bash addons/odin_godot/build/serve.sh path/to/export_dir   # then open http://localhost:8099/
```

Deploying instead of testing locally? Set the same two headers on your host. On **itch.io**,
tick the **"SharedArrayBuffer support"** box in the HTML5 settings and it configures them.

### Web caveats

- **No hot reload** in the browser (no `dlopen`, one shared linear memory with the engine).
- **No native debugging** — debug with `gd.print` → the JS console + browser devtools.
- **Emscripten version:** Godot 4.6.2's web templates were built with emscripten **4.0.20**;
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
</content>
