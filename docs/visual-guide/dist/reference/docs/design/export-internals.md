# Phase 5 — the export pipeline

Turns the working extension into a shippable game: `.odin` scripts are compiled
**ahead of time, at export**, into the exported build (an exported game has no Odin
compiler). Native desktop (macOS) is the **firm** milestone; web/WASM is secondary.

## Verdict

- **Native desktop (macOS): GREEN — `PHASE5_OK` via the exported-run path.**
  An actual exported `.app` (not the editor) loads the extension and runs an Odin
  script compiled at export time. Verified headless end to end by
  `tests/phase5/run.sh`.
- **Cross-compile (linux/windows): supported-but-unverified-here** (see below).
- **Web/WASM: RED for a real in-browser load** — two specific, named blockers found
  when compiling the *full* binding to wasm (Spike W only compiled a leaf proc). The
  SIDE_MODULE mechanics + Godot's web-export bundling remain proven (Spike W, 🟡).

---

## 1. The export plugin (how scripts get compiled + bundled per platform)

Two GDExtension classes, in `core/export_plugin.odin`, registered **only at the
`.Editor` initialization level** (`core/main.odin`). An exported game never reaches
`.Editor`, so neither exists at runtime — the same `core` dll plays both roles.

- **`OdinExportPlugin`** (extends `EditorExportPlugin`) — the work. In `_export_begin`:
  1. reads the export feature set to determine the target OS (`macos`/`linux`/`windows`/`web`);
  2. runs `build/build_export_scripts.sh <proj> <target> <out.dll>` via `libc.system`
     (inherits the editor process's nix PATH, so `odin` resolves) — this is the
     scriptgen + `odin build -build-mode:dll` pipeline producing a fresh scripts dll
     for the target;
  3. `add_shared_object`s that dll so the exporter copies it **beside the executable**
     (macOS → `Contents/Frameworks/`, alongside the auto-exported core dll).

- **`OdinEditorPlugin`** (extends `EditorPlugin`) — a thin host. GDExtension can only
  register an *editor* plugin by class name (`editor_add_plugin`); the binding exposes
  no `EditorExport` singleton. So this plugin, in its `_enter_tree`, constructs the
  `OdinExportPlugin` and `add_export_plugin`s it. Registered with
  `gdext.editor_add_plugin(&class_name)` at `.Editor` init.

The **core dll** itself is exported automatically by Godot's GDExtension export
handling (it is listed in `[libraries]` of the `.gdextension`), so the plugin does
**not** re-add it; it only bundles the dynamically-loaded scripts dll, which Godot
does not otherwise know about.

### Runtime dll resolution (the load-bearing change)

In an exported game `res://` is packed and cannot be `dlopen`ed, so the old
`globalize("res://bin/libodinscripts.<ext>")` resolution breaks. `core/scripts.odin`
now finds the scripts dll as a **sibling of the core dll**, via `dladdr` on one of the
core's own procs → directory → `libodinscripts.<ext>`. Resolution order:
`ODIN_SCRIPTS_DLL` env (test harness) → sibling-of-core → `res://` globalize (dev
fallback). Works unchanged in both dev and exported builds; no test regressions.

## 2. Run it (firm milestone)

```sh
nix develop --command bash -c 'bash tests/phase5/run.sh'      # prints PHASE5_OK
```

Which does: build the core dll → headless `--export-release "macOS"` (the plugin
compiles + bundles the scripts dll) → run the exported `.app` headless and assert the
Odin `_ready` sentinels `EXPORT_RAN` + `EXPORT_ASSERT_OK`.

Verified output bundle:

```
out/OdinGamePhase5.app/Contents/MacOS/OdinGodotPhase5          (universal template, ad-hoc signed)
out/OdinGamePhase5.app/Contents/Resources/OdinGodotPhase5.pck  (project + rewritten .gdextension)
out/OdinGamePhase5.app/Contents/Frameworks/libodin_godot.dylib (core — auto-exported by Godot)
out/OdinGamePhase5.app/Contents/Frameworks/libodinscripts.dylib(scripts — add_shared_object'd by us)
```

### Gotchas encountered (macOS export)

- The installed `macos.zip` template ships only `godot_macos_*.universal`, so the
  preset must use `binary_format/architecture="universal"` (not `"arm64"`), else
  "Requested template binary godot_macos_release.arm64 not found". The universal
  binary runs fine on arm64; the arm64-only dylibs load fine under it.
- arm64 export requires ETC2 ASTC: `rendering/textures/vram_compression/import_etc2_astc=true`
  in `project.godot`, else export aborts with a config error.
- Two non-fatal `Required virtual method OdinScript::_update_exports / _get_script_signal_list`
  errors print during the export's script-class scan. Harmless here; candidates to
  implement in a later phase to quiet the log.

## 3. Cross-compile (linux / windows) — supported-but-unverified-here

`build/build_export_scripts.sh` passes `-target:linux_amd64` / `-target:windows_amd64`
for those targets. Odin emits the object, but producing the final `.so`/`.dll` needs
the matching cross **linker** on PATH (lld is in the dev shell; a full target sysroot
may still be required for the system libs the core links: `core:os`/`core:dynlib`/
`libc`). The bundling half is platform-agnostic (`add_shared_object` + sibling-of-core
resolution). Not exercised on this macOS host; no auto-download of templates was done.
Linux/Windows 4.6.2 templates ARE installed, so only the cross-toolchain is missing.

## 4. Web / WASM — RED for in-browser load (precise blockers)

Goal: compile `core` + `runtime` + scripts + the `godot`/`gdext` binding to `wasm32`
and link an `emcc -sSIDE_MODULE=1` exporting the real `entry_symbol`. Spike W
(`docs/wasm-spike.md`) proved the mechanics with a **leaf proc**; compiling the **full
binding** surfaces two independent, specific blockers:

1. **Core host-only dependencies don't compile `freestanding_wasm32`.** `core/` pulls
   in `core:os` (path/file/dir/errno), `core:dynlib`, `core:c/libc`, and `core:fmt`
   (via `strconv`/`locale`) — none of which build for `freestanding_wasm32`
   (`odin build core -target:freestanding_wasm32` errors in `core/os/path.odin`,
   `core/dynlib/lib.odin`, `core/c/libc/locale.odin`, …). These are used for the
   scripts-dll `dlopen` + boot handshake and for stderr logging. **Web has no dlopen
   and no second SIDE_MODULE the engine will load**, so the path forward is a
   wasm-specific core that (a) links the scripts **into the same module** (one
   SIDE_MODULE, no `dlopen`/boot handshake) and (b) drops `os`/`dynlib`/`libc` and
   trims `fmt`→`strconv` (the documented footprint note).

2. **32-bit enum overflow in the generated binding.** On `wasm32`, Odin's `int` is
   32-bit, so generated enums backed by `int` that carry a `>2^31` flag value fail to
   compile, e.g. `godot/rendering_server.gen.odin`:
   `Cannot convert numeric value '34359738368' … to 'Rendering_Server_Array_Format'`
   (`= 0x8_0000_0000`). A few `*.gen.odin` files contain such constants. The real fix
   is in **`bindgen`** (emit `enum i64` / a 64-bit backing type for flag enums) and a
   regeneration of `godot/` — `bindgen`/`extension_api.json` are out of scope to edit
   here, so this is flagged, not patched.

Because (1) is a core rearchitecture and (2) needs a bindgen change, no new full-stack
wasm was produced; the leaf-proc → SIDE_MODULE → Godot-web-export-bundles-it path from
Spike W is the current high-water mark (🟡). The web export *wiring* (`.gdextension`
`web.{debug,release}.wasm32` → wasm, headless `--export-release "Web"`, COOP/COEP
serve) is documented in `docs/wasm-spike.md` §5 and unchanged.

### Emscripten 4.0.20 pin — outcome

Unchanged from Spike W: time-boxed out. nixpkgs couples `emscripten` to a bundled
LLVM/binaryen, so a bare version override doesn't work; the dev shell ships 5.0.6.
Recommended (see `flake.nix`): pin **4.0.20** via an emsdk-based derivation (emsdk
fetches the matching prebuilt LLVM) or a second `nixpkgs` input at a rev that shipped
4.0.20. Moot until blockers (1)+(2) above are resolved — there is no full-binding wasm
to re-link yet.

## Files added / changed

- `core/export_plugin.odin` — **new.** `OdinExportPlugin` + `OdinEditorPlugin`.
- `core/main.odin` — register/unregister the export plugin at `.Editor` level.
- `core/scripts.odin` — sibling-of-core-dll resolution via `dladdr` (export-safe).
- `build/build_export_scripts.sh` — **new.** Per-target scriptgen + `odin build`.
- `tests/phase5/` — **new.** Export project: `main.tscn` (main scene) + Node with the
  `Main` Odin script, `scripts/{main,boot}.odin`, `project.godot`,
  `export_presets.cfg` (macOS/universal), `odin_godot.gdextension`, `run.sh`.
- `.gitignore` — ignore `tests/*/out/`, `tests/*/.export_build/`, `tests/*/.godot/`.
